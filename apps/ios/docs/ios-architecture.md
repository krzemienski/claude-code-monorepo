# ClaudeCode iOS Architecture Documentation

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Core Principles](#core-principles)
4. [Module Architecture](#module-architecture)
5. [Design Patterns](#design-patterns)
6. [Data Flow Architecture](#data-flow-architecture)
7. [Dependency Injection](#dependency-injection)
8. [Navigation Architecture](#navigation-architecture)
9. [State Management](#state-management)
10. [Networking Layer](#networking-layer)
11. [Module Boundaries](#module-boundaries)
12. [Future Modularization](#future-modularization)

---

## Executive Summary

The ClaudeCode iOS application adopts a **hybrid MVVM-C (Model-View-ViewModel-Coordinator)** architecture with **TCA (The Composable Architecture)** patterns for complex state management. This architecture prioritizes:

- **Scalability**: Support for 10x growth in features and team size
- **Testability**: 90%+ code coverage potential through dependency injection
- **Maintainability**: Clear separation of concerns and module boundaries
- **Performance**: Optimized for iOS 16+ with modern Swift concurrency

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │    Views    │  │  ViewModels │  │ Coordinators│        │
│  │  (SwiftUI)  │◄─┤   (@State)  │◄─┤ (Navigation)│        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Use Cases │  │   Entities  │  │ Repositories│        │
│  │  (Business) │  │   (Models)  │  │ (Protocols) │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ API Clients │  │   Storage   │  │    Cache    │        │
│  │   (Network) │  │  (CoreData) │  │   (Memory)  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. **Single Responsibility**
Each component has one clear purpose:
- Views: UI rendering only
- ViewModels: Presentation logic and state management
- Coordinators: Navigation flow
- Services: Business logic
- Repositories: Data access abstraction

### 2. **Dependency Inversion**
- All dependencies flow inward toward the domain layer
- Domain layer has no external dependencies
- Use protocols for abstraction boundaries

### 3. **Unidirectional Data Flow**
```
User Action → ViewModel → Use Case → Repository → API/Storage
            ←─────────────────────────────────────┘
                     State Update
```

### 4. **Immutability First**
- Prefer `let` over `var`
- Use value types (structs) for models
- Leverage `@State` and `@Published` for reactive updates

## Module Architecture

### Feature Modules
Each feature is self-contained with clear boundaries:

```
Features/
├── Sessions/
│   ├── Domain/
│   │   ├── Models/          # Session, Message entities
│   │   ├── UseCases/        # CreateSessionUseCase, SendMessageUseCase
│   │   └── Repositories/    # SessionRepositoryProtocol
│   ├── Presentation/
│   │   ├── ViewModels/      # SessionsViewModel, ChatViewModel
│   │   ├── Views/           # SessionsView, ChatView
│   │   └── Components/      # MessageBubble, InputBar
│   └── Data/
│       ├── Repositories/    # SessionRepository implementation
│       ├── DataSources/     # Remote/Local data sources
│       └── DTOs/            # Data Transfer Objects
```

### Core Modules

```
App/Core/
├── DI/                      # Dependency Injection Container
├── Networking/              # API Client, SSE, WebSocket
├── Navigation/              # Coordinators, Routers
├── Storage/                 # CoreData, UserDefaults, Keychain
├── Concurrency/             # Actor-based task management
├── Memory/                  # Memory management, profiling
├── Reactive/                # Combine extensions, Publishers
└── UI/                      # Design system, components
```

### Shared Modules

```
Shared/
├── Extensions/              # Swift standard library extensions
├── Utilities/              # Helper functions, formatters
├── Resources/              # Localizations, assets
└── Constants/              # App-wide constants
```

## Design Patterns

### 1. MVVM-C (Model-View-ViewModel-Coordinator)

**ViewModel Pattern:**
```swift
@MainActor
final class SessionsViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    // MARK: - Dependencies
    private let sessionUseCase: SessionUseCaseProtocol
    private let coordinator: SessionCoordinator
    
    // MARK: - Initialization
    init(sessionUseCase: SessionUseCaseProtocol,
         coordinator: SessionCoordinator) {
        self.sessionUseCase = sessionUseCase
        self.coordinator = coordinator
    }
    
    // MARK: - Intent Methods
    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sessions = try await sessionUseCase.fetchSessions()
        } catch {
            self.error = error
        }
    }
    
    func selectSession(_ session: Session) {
        coordinator.navigateToChat(session)
    }
}
```

### 2. Repository Pattern

**Protocol Definition:**
```swift
protocol SessionRepositoryProtocol {
    func fetchSessions() async throws -> [Session]
    func createSession(_ session: Session) async throws -> Session
    func updateSession(_ session: Session) async throws -> Session
    func deleteSession(id: String) async throws
    func observeSessions() -> AsyncStream<[Session]>
}
```

**Implementation:**
```swift
actor SessionRepository: SessionRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let localStorage: LocalStorageProtocol
    private let cache: CacheProtocol
    
    func fetchSessions() async throws -> [Session] {
        // Try cache first
        if let cached = await cache.get(key: "sessions") {
            return cached
        }
        
        // Fetch from API
        let sessions = try await apiClient.fetchSessions()
        
        // Update cache and local storage
        await cache.set(key: "sessions", value: sessions)
        try await localStorage.save(sessions)
        
        return sessions
    }
}
```

### 3. Use Case Pattern

```swift
protocol CreateSessionUseCaseProtocol {
    func execute(with request: CreateSessionRequest) async throws -> Session
}

final class CreateSessionUseCase: CreateSessionUseCaseProtocol {
    private let repository: SessionRepositoryProtocol
    private let validator: SessionValidatorProtocol
    
    func execute(with request: CreateSessionRequest) async throws -> Session {
        // Validate request
        try validator.validate(request)
        
        // Create session
        let session = Session(from: request)
        
        // Persist
        return try await repository.createSession(session)
    }
}
```

### 4. Coordinator Pattern

```swift
@MainActor
protocol SessionCoordinatorProtocol {
    func start()
    func navigateToChat(_ session: Session)
    func navigateToSettings()
    func dismiss()
}

@MainActor
final class SessionCoordinator: SessionCoordinatorProtocol {
    @Published var navigationPath = NavigationPath()
    weak var parentCoordinator: AppCoordinator?
    
    func navigateToChat(_ session: Session) {
        navigationPath.append(SessionRoute.chat(session))
    }
}
```

## Data Flow Architecture

### State Management Strategy

1. **Local Component State**: `@State` for view-specific state
2. **Shared Feature State**: `@StateObject` ViewModels
3. **Global App State**: `@EnvironmentObject` for app-wide state
4. **Async State**: Combine publishers and async/await

### Reactive Data Flow

```swift
// Publisher-based reactive flow
class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    private var cancellables = Set<AnyCancellable>()
    
    func observeMessages() {
        repository.messagesPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.messages = messages
            }
            .store(in: &cancellables)
    }
}
```

## Dependency Injection

### Container-Based DI

```swift
@MainActor
final class AppContainer {
    static let shared = AppContainer()
    
    // MARK: - Service Registration
    private lazy var apiClient: APIClientProtocol = {
        ActorAPIClient(configuration: .production)
    }()
    
    private lazy var sessionRepository: SessionRepositoryProtocol = {
        SessionRepository(
            apiClient: apiClient,
            localStorage: localStorage,
            cache: memoryCache
        )
    }()
    
    // MARK: - Factory Methods
    func makeSessionsViewModel() -> SessionsViewModel {
        SessionsViewModel(
            sessionUseCase: makeSessionUseCase(),
            coordinator: makeSessionCoordinator()
        )
    }
    
    private func makeSessionUseCase() -> SessionUseCaseProtocol {
        CreateSessionUseCase(
            repository: sessionRepository,
            validator: SessionValidator()
        )
    }
}
```

### Property Wrapper DI

```swift
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<AppContainer, T>
    
    var wrappedValue: T {
        AppContainer.shared[keyPath: keyPath]
    }
    
    init(_ keyPath: KeyPath<AppContainer, T>) {
        self.keyPath = keyPath
    }
}

// Usage
class SomeViewModel {
    @Injected(\.sessionRepository) var repository
}
```

## Navigation Architecture

### Hierarchical Navigation Structure

```swift
enum AppRoute: Hashable {
    case home
    case sessions(SessionRoute)
    case projects(ProjectRoute)
    case settings(SettingsRoute)
}

enum SessionRoute: Hashable {
    case list
    case detail(Session)
    case chat(Session)
}

@MainActor
class AppNavigationState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var homePath = NavigationPath()
    @Published var sessionsPath = NavigationPath()
    @Published var projectsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    
    func navigate(to route: AppRoute) {
        switch route {
        case .sessions(let sessionRoute):
            selectedTab = .sessions
            sessionsPath.append(sessionRoute)
        // ... other cases
        }
    }
}
```

## State Management

### TCA Integration for Complex Features

```swift
// For complex features like the chat interface
struct ChatFeature: Reducer {
    struct State: Equatable {
        var messages: IdentifiedArrayOf<Message> = []
        var isLoading = false
        var error: String?
    }
    
    enum Action: Equatable {
        case loadMessages
        case messagesLoaded(TaskResult<[Message]>)
        case sendMessage(String)
        case messageReceived(Message)
    }
    
    @Dependency(\.sessionClient) var sessionClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadMessages:
                state.isLoading = true
                return .run { send in
                    await send(
                        .messagesLoaded(
                            TaskResult { 
                                try await sessionClient.fetchMessages() 
                            }
                        )
                    )
                }
                
            case .messagesLoaded(.success(let messages)):
                state.messages = IdentifiedArray(uniqueElements: messages)
                state.isLoading = false
                return .none
                
            // ... other cases
            }
        }
    }
}
```

## Networking Layer

### API Client Architecture

```swift
// Actor-based API Client for thread safety
actor EnhancedAPIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // Request builder pattern
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            headers: headers
        )
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        return try decoder.decode(T.self, from: data)
    }
}

// Endpoint definition
enum SessionEndpoint: Endpoint {
    case list
    case create(CreateSessionRequest)
    case detail(id: String)
    case delete(id: String)
    
    var path: String {
        switch self {
        case .list, .create:
            return "/api/sessions"
        case .detail(let id), .delete(let id):
            return "/api/sessions/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .list, .detail:
            return .get
        case .create:
            return .post
        case .delete:
            return .delete
        }
    }
}
```

### SSE (Server-Sent Events) Support

```swift
actor EnhancedSSEClient {
    private var eventSource: EventSource?
    private let decoder = JSONDecoder()
    
    func connect(to url: URL) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let config = EventSource.Config(
                handler: EventHandler(),
                url: url
            )
            
            eventSource = EventSource(config: config)
            
            eventSource?.onMessage { _, _, data in
                if let event = try? self.decoder.decode(SSEEvent.self, from: data) {
                    continuation.yield(event)
                }
            }
            
            eventSource?.onComplete { _, _, _ in
                continuation.finish()
            }
            
            eventSource?.connect()
        }
    }
}
```

## Module Boundaries

### Dependency Rules

1. **Presentation → Domain**: Views/ViewModels can depend on domain
2. **Domain → Nothing**: Domain layer has no external dependencies
3. **Data → Domain**: Data layer implements domain protocols
4. **No Circular Dependencies**: Enforced through protocol abstraction

### Module Communication

```swift
// Protocol-based module communication
protocol SessionModuleInterface {
    func startSessionFlow() -> AnyView
    func sessionDetailView(for id: String) -> AnyView
}

struct SessionModule: SessionModuleInterface {
    private let container: SessionContainer
    
    func startSessionFlow() -> AnyView {
        AnyView(
            SessionsView()
                .environmentObject(container.makeViewModel())
        )
    }
}
```

## Future Modularization

### Tuist Module Structure

```
Modules/
├── Core/
│   ├── Network/            # Networking utilities
│   ├── Storage/            # Data persistence
│   ├── UI/                 # Design system
│   └── Common/             # Shared utilities
├── Features/
│   ├── Sessions/           # Chat sessions feature
│   ├── Projects/           # Project management
│   ├── MCP/                # MCP tools integration
│   ├── Analytics/          # Analytics dashboard
│   └── Settings/           # App settings
└── App/                    # Main app target
```

### Module Definition (Tuist)

```swift
// Module.swift for Sessions feature
import ProjectDescription

public enum Sessions {
    public static let project = Project(
        name: "Sessions",
        targets: [
            Target(
                name: "Sessions",
                platform: .iOS,
                product: .framework,
                bundleId: "com.claudecode.sessions",
                sources: ["Sources/**"],
                dependencies: [
                    .project(target: "Core", path: "../Core"),
                    .project(target: "UI", path: "../UI")
                ]
            ),
            Target(
                name: "SessionsTests",
                platform: .iOS,
                product: .unitTests,
                bundleId: "com.claudecode.sessions.tests",
                sources: ["Tests/**"],
                dependencies: [
                    .target(name: "Sessions")
                ]
            )
        ]
    )
}
```

## Performance Considerations

### Memory Management
- Use `weak` references in closures to prevent retain cycles
- Implement proper cleanup in `deinit`
- Use `@StateObject` for view-owned objects
- Leverage Swift's automatic reference counting

### Concurrency
- Use `async/await` for all asynchronous operations
- Leverage `Actor` for thread-safe components
- Use `@MainActor` for UI updates
- Implement proper task cancellation

### Optimization Strategies
- Lazy loading for heavy resources
- Image caching with size limits
- Pagination for large data sets
- Background processing for non-UI tasks

## Testing Strategy

### Unit Testing
- Test ViewModels with mock dependencies
- Test Use Cases with stub repositories
- Test domain logic in isolation
- Achieve 80%+ code coverage

### Integration Testing
- Test complete feature flows
- Test API integration with mock server
- Test data persistence layer
- Test navigation flows

### UI Testing
- Snapshot testing for critical views
- Accessibility testing
- Performance testing for scrolling
- Device-specific layout testing

## Security Architecture

### Data Protection
- Keychain for sensitive data
- Encrypted CoreData for local storage
- Certificate pinning for API calls
- Biometric authentication support

### Network Security
- TLS 1.3 minimum
- JWT token management
- Automatic token refresh
- Request signing for critical operations

## Scalability Roadmap

### Phase 1: Foundation (Current)
- MVVM-C architecture
- Basic modularization
- Dependency injection
- Navigation coordination

### Phase 2: Modularization (Next)
- Tuist integration
- Feature modules
- Shared component library
- Module-level testing

### Phase 3: Advanced (Future)
- Micro-features architecture
- Dynamic feature delivery
- A/B testing framework
- Analytics pipeline

## Best Practices

### Code Organization
- One type per file
- Consistent naming conventions
- Clear folder structure
- Documentation for public APIs

### Swift Style
- Use Swift 5.9+ features
- Leverage property wrappers
- Prefer structs over classes
- Use extensions for organization

### SwiftUI Guidelines
- Composition over inheritance
- Small, focused views
- Extracted subviews for reusability
- Environment for dependency injection

## Conclusion

This architecture provides a solid foundation for the ClaudeCode iOS application that:
- Scales with team and feature growth
- Maintains high code quality
- Enables efficient testing
- Supports rapid feature development
- Ensures long-term maintainability

The modular structure and clear separation of concerns make it easy to onboard new developers and maintain consistent quality across the codebase.