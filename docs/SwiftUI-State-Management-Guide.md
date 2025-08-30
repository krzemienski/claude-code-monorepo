# SwiftUI State Management Guide for Claude Code iOS

## Overview

This guide provides comprehensive state management patterns and recommendations for the Claude Code iOS app, focusing on scalability, performance, and maintainability.

## 1. State Management Architecture

### 1.1 Recommended Architecture Pattern

Implement a **Clean MVVM + Coordinator** pattern:

```swift
// View Layer - Pure UI
struct ChatConsoleView: View { }

// ViewModel Layer - Business Logic
@MainActor
class ChatConsoleViewModel: ObservableObject { }

// Coordinator Layer - Navigation
class ChatCoordinator: ObservableObject { }

// Service Layer - Data Operations
protocol ChatService { }
class ChatServiceImpl: ChatService { }

// Repository Layer - Data Access
protocol ChatRepository { }
class ChatRepositoryImpl: ChatRepository { }
```

### 1.2 State Categories

#### Local View State
```swift
struct ContentView: View {
    // UI-only state that doesn't need persistence
    @State private var isExpanded = false
    @State private var selectedTab = 0
    @State private var searchText = ""
}
```

#### Shared Component State
```swift
class FeatureViewModel: ObservableObject {
    // State shared within a feature
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: Error?
}
```

#### Global App State
```swift
class AppState: ObservableObject {
    // App-wide state
    @Published var user: User?
    @Published var settings: Settings
    @Published var activeSession: Session?
}
```

## 2. Implementation Patterns

### 2.1 ViewModel Pattern

```swift
@MainActor
class ChatConsoleViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var transcript: [ChatBubble] = []
    @Published private(set) var timeline: [ToolRow] = []
    @Published private(set) var isStreaming = false
    @Published private(set) var error: Error?
    
    // MARK: - Dependencies
    private let chatService: ChatService
    private let sessionRepository: SessionRepository
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        chatService: ChatService = ChatServiceImpl(),
        sessionRepository: SessionRepository = SessionRepositoryImpl()
    ) {
        self.chatService = chatService
        self.sessionRepository = sessionRepository
        setupBindings()
    }
    
    // MARK: - Public Methods
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatBubble(role: .user, text: text)
        transcript.append(userMessage)
        
        // Start streaming
        isStreaming = true
        error = nil
        
        do {
            let stream = try await chatService.streamChat(message: text)
            
            for try await event in stream {
                handleStreamEvent(event)
            }
        } catch {
            self.error = error
        }
        
        isStreaming = false
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Auto-save transcript changes
        $transcript
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] transcript in
                self?.saveTranscript(transcript)
            }
            .store(in: &cancellables)
    }
    
    private func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        case .message(let text):
            updateAssistantMessage(with: text)
        case .toolUse(let tool):
            addToolToTimeline(tool)
        case .error(let error):
            self.error = error
        }
    }
}
```

### 2.2 Environment State Pattern

```swift
// Define environment key
private struct ChatViewModelKey: EnvironmentKey {
    static let defaultValue = ChatConsoleViewModel()
}

// Extend environment
extension EnvironmentValues {
    var chatViewModel: ChatConsoleViewModel {
        get { self[ChatViewModelKey.self] }
        set { self[ChatViewModelKey.self] = newValue }
    }
}

// Usage in app
@main
struct ClaudeCodeApp: App {
    @StateObject private var chatViewModel = ChatConsoleViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.chatViewModel, chatViewModel)
        }
    }
}

// Access in views
struct ChatView: View {
    @Environment(\.chatViewModel) private var viewModel
    
    var body: some View {
        // Use viewModel
    }
}
```

### 2.3 Dependency Injection Pattern

```swift
// Service Protocol
protocol APIService {
    func fetchSessions() async throws -> [Session]
    func streamChat(message: String) async throws -> AsyncStream<ChatEvent>
}

// Service Implementation
class APIServiceImpl: APIService {
    private let baseURL: URL
    private let apiKey: String
    
    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    func fetchSessions() async throws -> [Session] {
        // Implementation
    }
    
    func streamChat(message: String) async throws -> AsyncStream<ChatEvent> {
        // Implementation
    }
}

// Dependency Container
class DependencyContainer {
    static let shared = DependencyContainer()
    
    lazy var apiService: APIService = {
        APIServiceImpl(
            baseURL: AppSettings.shared.baseURL,
            apiKey: AppSettings.shared.apiKey
        )
    }()
    
    lazy var sessionRepository: SessionRepository = {
        SessionRepositoryImpl(apiService: apiService)
    }()
    
    func makeChatViewModel() -> ChatConsoleViewModel {
        ChatConsoleViewModel(
            apiService: apiService,
            repository: sessionRepository
        )
    }
}
```

## 3. Reactive State Management with Combine

### 3.1 Publisher Chains

```swift
class SessionViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filterScope: FilterScope = .all
    @Published private var allSessions: [Session] = []
    @Published private(set) var filteredSessions: [Session] = []
    
    init() {
        // Reactive filtering
        Publishers.CombineLatest($searchText, $filterScope)
            .combineLatest($allSessions)
            .map { (searchAndScope, sessions) in
                let (search, scope) = searchAndScope
                return self.filter(sessions, search: search, scope: scope)
            }
            .assign(to: &$filteredSessions)
    }
    
    private func filter(_ sessions: [Session], search: String, scope: FilterScope) -> [Session] {
        var filtered = sessions
        
        // Apply scope filter
        switch scope {
        case .active:
            filtered = filtered.filter { $0.isActive }
        case .completed:
            filtered = filtered.filter { !$0.isActive }
        case .all:
            break
        }
        
        // Apply search filter
        if !search.isEmpty {
            filtered = filtered.filter { session in
                session.title.localizedCaseInsensitiveContains(search) ||
                session.id.localizedCaseInsensitiveContains(search)
            }
        }
        
        return filtered
    }
}
```

### 3.2 Error Handling Pattern

```swift
class NetworkViewModel: ObservableObject {
    @Published private(set) var state: ViewState = .idle
    
    enum ViewState {
        case idle
        case loading
        case loaded([Item])
        case error(Error)
    }
    
    func load() {
        state = .loading
        
        apiService.fetchItems()
            .map(ViewState.loaded)
            .catch { error in
                Just(ViewState.error(error))
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }
}
```

## 4. Advanced State Patterns

### 4.1 State Machine Pattern

```swift
enum ChatState {
    case idle
    case connecting
    case streaming(assistantMessage: String)
    case processing(tool: String)
    case completed
    case error(Error)
    
    var canSendMessage: Bool {
        switch self {
        case .idle, .completed, .error:
            return true
        default:
            return false
        }
    }
}

class ChatStateMachine: ObservableObject {
    @Published private(set) var state: ChatState = .idle
    
    func transition(to newState: ChatState) {
        // Validate transition
        guard isValidTransition(from: state, to: newState) else {
            print("Invalid transition from \(state) to \(newState)")
            return
        }
        
        state = newState
        handleStateChange()
    }
    
    private func isValidTransition(from: ChatState, to: ChatState) -> Bool {
        switch (from, to) {
        case (.idle, .connecting),
             (.connecting, .streaming),
             (.streaming, .processing),
             (.processing, .streaming),
             (.streaming, .completed),
             (.processing, .completed),
             (_, .error):
            return true
        default:
            return false
        }
    }
}
```

### 4.2 Redux-like Pattern

```swift
// State
struct AppState {
    var sessions: [Session] = []
    var activeSession: Session?
    var user: User?
    var settings: Settings = .default
}

// Actions
enum AppAction {
    case sessionsFetched([Session])
    case sessionSelected(Session)
    case userLoggedIn(User)
    case settingsUpdated(Settings)
}

// Reducer
func appReducer(state: inout AppState, action: AppAction) {
    switch action {
    case .sessionsFetched(let sessions):
        state.sessions = sessions
    case .sessionSelected(let session):
        state.activeSession = session
    case .userLoggedIn(let user):
        state.user = user
    case .settingsUpdated(let settings):
        state.settings = settings
    }
}

// Store
class AppStore: ObservableObject {
    @Published private(set) var state = AppState()
    
    func dispatch(_ action: AppAction) {
        appReducer(state: &state, action: action)
    }
}
```

## 5. Performance Optimizations

### 5.1 Selective Updates

```swift
class OptimizedViewModel: ObservableObject {
    // Separate publishers for different UI sections
    @Published private(set) var headerData = HeaderData()
    @Published private(set) var contentData = ContentData()
    @Published private(set) var footerData = FooterData()
    
    // Update only what changed
    func updateHeader(_ data: HeaderData) {
        if headerData != data {
            headerData = data
        }
    }
}
```

### 5.2 Lazy State Loading

```swift
class LazyViewModel: ObservableObject {
    @Published private(set) var visibleItems: [Item] = []
    private var allItems: [Item] = []
    private let pageSize = 20
    
    func loadMore() {
        let currentCount = visibleItems.count
        let nextBatch = Array(allItems[currentCount..<min(currentCount + pageSize, allItems.count)])
        visibleItems.append(contentsOf: nextBatch)
    }
}
```

## 6. Testing State Management

### 6.1 ViewModel Testing

```swift
class ChatViewModelTests: XCTestCase {
    var viewModel: ChatConsoleViewModel!
    var mockService: MockChatService!
    
    override func setUp() {
        super.setUp()
        mockService = MockChatService()
        viewModel = ChatConsoleViewModel(chatService: mockService)
    }
    
    func testSendMessage() async {
        // Given
        let message = "Test message"
        mockService.mockResponse = .success("Response")
        
        // When
        await viewModel.sendMessage(message)
        
        // Then
        XCTAssertEqual(viewModel.transcript.count, 2)
        XCTAssertEqual(viewModel.transcript[0].text, message)
        XCTAssertEqual(viewModel.transcript[1].text, "Response")
    }
    
    func testErrorHandling() async {
        // Given
        mockService.mockResponse = .failure(TestError.network)
        
        // When
        await viewModel.sendMessage("Test")
        
        // Then
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isStreaming)
    }
}
```

### 6.2 State Snapshot Testing

```swift
func testStateTransitions() {
    let stateMachine = ChatStateMachine()
    
    // Record state transitions
    var stateHistory: [ChatState] = []
    let cancellable = stateMachine.$state.sink { state in
        stateHistory.append(state)
    }
    
    // Perform transitions
    stateMachine.transition(to: .connecting)
    stateMachine.transition(to: .streaming(assistantMessage: "Hello"))
    stateMachine.transition(to: .completed)
    
    // Verify
    XCTAssertEqual(stateHistory, [.idle, .connecting, .streaming(assistantMessage: "Hello"), .completed])
}
```

## 7. Migration Strategy

### Phase 1: Extract ViewModels (Week 1-2)
1. Create ViewModels for complex views (ChatConsole, Sessions)
2. Move business logic from views to ViewModels
3. Maintain backward compatibility

### Phase 2: Implement Service Layer (Week 3)
1. Define service protocols
2. Extract API calls to services
3. Add dependency injection

### Phase 3: Add Reactive Patterns (Week 4)
1. Implement Combine publishers
2. Add reactive filtering and search
3. Optimize state updates

### Phase 4: Testing Infrastructure (Week 5)
1. Create mock services
2. Write ViewModel tests
3. Add integration tests

## 8. Best Practices Checklist

### Do's
- ✅ Use @StateObject for view-owned ViewModels
- ✅ Use @ObservedObject for injected ViewModels
- ✅ Keep views simple and focused on UI
- ✅ Test ViewModels independently
- ✅ Use Combine for complex data flows
- ✅ Implement proper error handling
- ✅ Clean up subscriptions in deinit

### Don'ts
- ❌ Don't put business logic in views
- ❌ Don't create massive ViewModels
- ❌ Don't ignore memory management
- ❌ Don't skip testing state changes
- ❌ Don't mix UI and data concerns
- ❌ Don't create circular dependencies

## Conclusion

This state management guide provides a comprehensive approach to handling state in the Claude Code iOS app. By following these patterns and best practices, the app will be more maintainable, testable, and performant.

## References

- [SwiftUI State Management Documentation](https://developer.apple.com/documentation/swiftui/state-and-data-flow)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [MVVM Pattern in SwiftUI](https://www.raywenderlich.com/4161005-mvvm-with-combine-tutorial-for-ios)