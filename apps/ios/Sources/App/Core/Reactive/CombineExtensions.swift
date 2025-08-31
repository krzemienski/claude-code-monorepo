import SwiftUI
import Combine

// MARK: - Publisher Extensions for SwiftUI

public extension Publisher where Failure == Never {
    /// Assigns output to a @Published property with weak self capture
    func assignWeakly<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> AnyCancellable {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }
    
    /// Converts publisher to @Binding
    func toBinding(
        initialValue: Output,
        receiveValue: @escaping (Output) -> Void = { _ in }
    ) -> Binding<Output> {
        var value = initialValue
        let cancellable = sink { newValue in
            value = newValue
            receiveValue(newValue)
        }
        
        return Binding(
            get: { value },
            set: { newValue in
                value = newValue
                receiveValue(newValue)
            }
        )
    }
}

// MARK: - Debounce and Throttle Extensions

public extension Publisher where Failure == Never {
    /// Debounces input with default UI interaction delay
    func debounceUI(
        for duration: TimeInterval = 0.3,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<Output, Never> {
        debounce(for: .seconds(duration), scheduler: scheduler)
            .eraseToAnyPublisher()
    }
    
    /// Throttles input for real-time updates
    func throttleUI(
        for duration: TimeInterval = 0.1,
        scheduler: DispatchQueue = .main,
        latest: Bool = true
    ) -> AnyPublisher<Output, Never> {
        throttle(for: .seconds(duration), scheduler: scheduler, latest: latest)
            .eraseToAnyPublisher()
    }
}

// MARK: - Validation Publishers

public struct ValidationPublisher {
    /// Validates text input with rules
    static func validate(
        _ text: String,
        rules: [ValidationRule]
    ) -> AnyPublisher<ValidationResult, Never> {
        Just(text)
            .map { input in
                let errors = rules.compactMap { rule in
                    rule.validate(input)
                }
                return ValidationResult(
                    isValid: errors.isEmpty,
                    errors: errors
                )
            }
            .eraseToAnyPublisher()
    }
    
    /// Combines multiple validation publishers
    static func combineValidations(
        _ publishers: [AnyPublisher<ValidationResult, Never>]
    ) -> AnyPublisher<ValidationResult, Never> {
        Publishers.CombineLatest(publishers[0], publishers[1])
            .map { results in
                let allResults = [results.0, results.1]
                let errors = allResults.flatMap { $0.errors }
                return ValidationResult(
                    isValid: errors.isEmpty,
                    errors: errors
                )
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Validation Types

public protocol ValidationRule {
    func validate(_ input: String) -> String?
}

public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    
    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}

// MARK: - Common Validation Rules

public struct RequiredRule: ValidationRule {
    let message: String
    
    public init(message: String = "This field is required") {
        self.message = message
    }
    
    public func validate(_ input: String) -> String? {
        input.isEmpty ? message : nil
    }
}

public struct MinLengthRule: ValidationRule {
    let length: Int
    let message: String
    
    public init(length: Int, message: String? = nil) {
        self.length = length
        self.message = message ?? "Must be at least \(length) characters"
    }
    
    public func validate(_ input: String) -> String? {
        input.count < length ? message : nil
    }
}

public struct EmailRule: ValidationRule {
    let message: String
    
    public init(message: String = "Invalid email address") {
        self.message = message
    }
    
    public func validate(_ input: String) -> String? {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let isValid = input.range(of: emailRegex, options: .regularExpression) != nil
        return isValid ? nil : message
    }
}

// MARK: - Network Request Publishers

public extension URLSession {
    /// Creates a type-safe publisher for API requests
    func dataTaskPublisher<T: Decodable>(
        for request: URLRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) -> AnyPublisher<T, Error> {
        dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - State Management Publishers

public class ReactiveStateContainer<State> {
    @Published public private(set) var state: State
    private var cancellables = Set<AnyCancellable>()
    
    public init(initialState: State) {
        self.state = initialState
    }
    
    /// Updates state with an action
    public func dispatch<Action>(_ action: Action, reducer: (State, Action) -> State) {
        state = reducer(state, action)
    }
    
    /// Binds a publisher to state updates
    public func bind<T>(
        _ publisher: AnyPublisher<T, Never>,
        transform: @escaping (State, T) -> State
    ) {
        publisher
            .sink { [weak self] value in
                guard let self = self else { return }
                self.state = transform(self.state, value)
            }
            .store(in: &cancellables)
    }
}

// MARK: - UI Event Publishers

public extension View {
    /// Creates a publisher for view appearance events
    func onAppearPublisher() -> AnyPublisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher for keyboard events
    func keyboardHeightPublisher() -> AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { notification in
                    (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
                        .cgRectValue.height
                },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - Timer Publishers

public extension Timer {
    /// Creates a repeating timer publisher
    static func publishUI(
        every interval: TimeInterval,
        on runLoop: RunLoop = .main
    ) -> AnyPublisher<Date, Never> {
        Timer.publish(every: interval, on: runLoop, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
    }
}

// MARK: - Combine Operators for SwiftUI

public extension Publisher {
    /// Maps to a loading state enum
    func mapToLoadingState<T>() -> AnyPublisher<LoadingState<T>, Never> where Output == T, Failure == Error {
        self
            .map { LoadingState.loaded($0) }
            .catch { Just(LoadingState<T>.error($0)) }
            .prepend(.loading)
            .eraseToAnyPublisher()
    }
    
    /// Retries with exponential backoff
    func retryWithBackoff(
        retries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0
    ) -> AnyPublisher<Output, Failure> {
        var currentDelay = initialDelay
        
        return self.catch { error -> AnyPublisher<Output, Failure> in
            if retries <= 0 {
                return Fail(error: error)
                    .eraseToAnyPublisher()
            }
            
            return Just(())
                .delay(for: .seconds(currentDelay), scheduler: DispatchQueue.main)
                .flatMap { _ -> AnyPublisher<Output, Failure> in
                    currentDelay = Swift.min(currentDelay * 2, maxDelay)
                    return self.retryWithBackoff(
                        retries: retries - 1,
                        initialDelay: currentDelay,
                        maxDelay: maxDelay
                    )
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Loading State

public enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    public var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    public var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}