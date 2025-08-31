import SwiftUI
import Combine

/// Base class for reactive view models with Combine integration
open class ReactiveViewModel: ObservableObject {
    public var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    /// Binds a publisher to a published property with weak self
    public func bind<T>(
        _ publisher: AnyPublisher<T, Never>,
        to keyPath: ReferenceWritableKeyPath<ReactiveViewModel, T>
    ) {
        publisher
            .receive(on: DispatchQueue.main)
            .assignWeakly(to: keyPath, on: self)
            .store(in: &cancellables)
    }
    
    /// Creates a cancellable that's automatically stored
    public func subscribe<T>(
        to publisher: AnyPublisher<T, Never>,
        receiveValue: @escaping (T) -> Void
    ) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: receiveValue)
            .store(in: &cancellables)
    }
}

// MARK: - Search View Model with Reactive Patterns

public class ReactiveSearchViewModel: ReactiveViewModel {
    @Published public var searchText = ""
    @Published public var searchResults: [SearchResult] = []
    @Published public var isSearching = false
    @Published public var error: Error?
    
    private let searchService: SearchServiceProtocol
    
    public init(searchService: SearchServiceProtocol) {
        self.searchService = searchService
        super.init()
        setupSearchPipeline()
    }
    
    private func setupSearchPipeline() {
        // Debounced search with loading states
        $searchText
            .debounceUI(for: 0.5)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    self?.isSearching = true
                    self?.error = nil
                }
            )
            .flatMap { [weak self] query -> AnyPublisher<[SearchResult], Never> in
                guard let self = self else {
                    return Just([]).eraseToAnyPublisher()
                }
                
                return self.searchService.search(query: query)
                    .catch { [weak self] error -> Just<[SearchResult]> in
                        self?.error = error
                        return Just([])
                    }
                    .eraseToAnyPublisher()
            }
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    self?.isSearching = false
                }
            )
            .assign(to: &$searchResults)
    }
    
    public func clearSearch() {
        searchText = ""
        searchResults = []
        error = nil
    }
}

// MARK: - Form Validation View Model

public class ReactiveFormViewModel: ReactiveViewModel {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var confirmPassword = ""
    @Published public var isFormValid = false
    @Published public var validationErrors: [String: String] = [:]
    
    private let emailRules: [ValidationRule] = [
        RequiredRule(message: "Email is required"),
        EmailRule()
    ]
    
    private let passwordRules: [ValidationRule] = [
        RequiredRule(message: "Password is required"),
        MinLengthRule(length: 8, message: "Password must be at least 8 characters")
    ]
    
    override public init() {
        super.init()
        setupValidation()
    }
    
    private func setupValidation() {
        // Email validation
        $email
            .debounceUI(for: 0.5)
            .map { [weak self] email in
                self?.emailRules.compactMap { $0.validate(email) }.first
            }
            .sink { [weak self] error in
                self?.validationErrors["email"] = error
            }
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounceUI(for: 0.5)
            .map { [weak self] password in
                self?.passwordRules.compactMap { $0.validate(password) }.first
            }
            .sink { [weak self] error in
                self?.validationErrors["password"] = error
            }
            .store(in: &cancellables)
        
        // Confirm password validation
        Publishers.CombineLatest($password, $confirmPassword)
            .debounceUI(for: 0.5)
            .map { password, confirmPassword in
                if confirmPassword.isEmpty {
                    return "Please confirm your password"
                } else if password != confirmPassword {
                    return "Passwords do not match"
                }
                return nil
            }
            .sink { [weak self] error in
                self?.validationErrors["confirmPassword"] = error
            }
            .store(in: &cancellables)
        
        // Overall form validation
        $validationErrors
            .map { $0.values.allSatisfy { $0 == nil } }
            .assign(to: &$isFormValid)
    }
    
    public func submit() -> AnyPublisher<Bool, Error> {
        guard isFormValid else {
            return Fail(error: ValidationError.invalidForm)
                .eraseToAnyPublisher()
        }
        
        // Simulate API call
        return Future<Bool, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Real-time Data View Model

public class ReactiveRealtimeViewModel: ReactiveViewModel {
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var messages: [Message] = []
    @Published public var latestUpdate: Date?
    
    private let updateInterval: TimeInterval = 5.0
    private var updateTimer: AnyCancellable?
    
    public override init() {
        super.init()
        setupRealtimeUpdates()
    }
    
    private func setupRealtimeUpdates() {
        // Simulate real-time updates
        updateTimer = Timer.publishUI(every: updateInterval)
            .sink { [weak self] date in
                self?.latestUpdate = date
                self?.fetchLatestData()
            }
    }
    
    private func fetchLatestData() {
        // Simulate fetching new data
        let newMessage = Message(
            id: UUID().uuidString,
            content: "Update at \(Date())",
            timestamp: Date()
        )
        messages.append(newMessage)
        
        // Limit message history
        if messages.count > 100 {
            messages.removeFirst()
        }
    }
    
    public func connect() {
        connectionState = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.connectionState = .connected
        }
    }
    
    public func disconnect() {
        connectionState = .disconnected
        updateTimer?.cancel()
        updateTimer = nil
    }
}

// MARK: - Supporting Types

public protocol SearchServiceProtocol {
    func search(query: String) -> AnyPublisher<[SearchResult], Error>
}

public struct SearchResult: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    
    public init(id: String, title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
    }
}

public enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(Error)
}

public struct Message: Identifiable, Codable, Hashable {
    public let id: String
    public let content: String
    public let timestamp: Date
    
    public init(id: String = UUID().uuidString, content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
}

public enum ValidationError: LocalizedError {
    case invalidForm
    
    public var errorDescription: String? {
        switch self {
        case .invalidForm:
            return "Please correct the errors in the form"
        }
    }
}