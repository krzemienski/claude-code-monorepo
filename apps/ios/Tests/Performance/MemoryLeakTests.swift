import XCTest
import Combine
@testable import ClaudeCode

@MainActor
final class MemoryLeakTests: XCTestCase {
    
    // MARK: - ViewModels Memory Leak Tests
    
    func testHomeViewModelNoRetainCycle() {
        // Given
        var viewModel: HomeViewModel? = HomeViewModel()
        weak var weakViewModel = viewModel
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertNil(weakViewModel, "HomeViewModel should be deallocated")
    }
    
    func testChatViewModelNoRetainCycle() {
        // Given
        var viewModel: ChatViewModel? = ChatViewModel(
            sessionId: "test",
            projectId: "test"
        )
        weak var weakViewModel = viewModel
        
        // Set up subscriptions that might cause retain cycles
        let cancellable = viewModel?.objectWillChange.sink { _ in
            // Subscription handler
        }
        
        // When
        viewModel = nil
        _ = cancellable // Keep reference to prevent warning
        
        // Then
        XCTAssertNil(weakViewModel, "ChatViewModel should be deallocated")
    }
    
    func testProjectsViewModelNoRetainCycle() {
        // Given
        var viewModel: ProjectsViewModel? = ProjectsViewModel()
        weak var weakViewModel = viewModel
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertNil(weakViewModel, "ProjectsViewModel should be deallocated")
    }
    
    func testSessionsViewModelNoRetainCycle() {
        // Given
        var viewModel: SessionsViewModel? = SessionsViewModel()
        weak var weakViewModel = viewModel
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertNil(weakViewModel, "SessionsViewModel should be deallocated")
    }
    
    // MARK: - Container Memory Leak Tests
    
    func testContainerServiceNoRetainCycle() {
        // Given
        autoreleasepool {
            let container = EnhancedContainer.shared
            weak var weakNetworking = container.networkingService as AnyObject
            weak var weakAuth = container.authenticationService as AnyObject
            weak var weakCache = container.cacheService as AnyObject
            weak var weakAnalytics = container.analyticsService as AnyObject
            
            // When - Reset container
            container.reset()
            
            // Then - Services should be deallocated after reset
            XCTAssertNil(weakNetworking, "NetworkingService should be deallocated")
            XCTAssertNil(weakAuth, "AuthenticationService should be deallocated")
            XCTAssertNil(weakCache, "CacheService should be deallocated")
            XCTAssertNil(weakAnalytics, "AnalyticsService should be deallocated")
        }
    }
    
    // MARK: - Network Layer Memory Leak Tests
    
    func testAPIClientNoRetainCycle() async {
        // Given
        weak var weakClient: EnhancedAPIClient?
        
        autoreleasepool {
            let settings = AppSettings()
            let client = EnhancedAPIClient(
                settings: settings,
                retryPolicy: .default
            )
            weakClient = client
            
            // Perform operations
            Task {
                _ = try? await client.health()
            }
        }
        
        // Wait for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertNil(weakClient, "APIClient should be deallocated")
    }
    
    func testSSEClientNoRetainCycle() async {
        // Given
        weak var weakClient: EnhancedSSEClient?
        
        autoreleasepool {
            let client = EnhancedSSEClient(retryPolicy: .default)
            weakClient = client
            
            // Connect and disconnect
            let url = URL(string: "http://localhost:8000/stream")!
            _ = client.connect(to: url, headers: [:])
            
            Task {
                await client.disconnect()
            }
        }
        
        // Wait for cleanup
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertNil(weakClient, "SSEClient should be deallocated")
    }
    
    // MARK: - Combine Subscription Memory Leak Tests
    
    func testCombineSubscriptionNoRetainCycle() {
        // Given
        class Publisher: ObservableObject {
            @Published var value = 0
        }
        
        class Subscriber {
            var cancellables = Set<AnyCancellable>()
            
            func subscribe(to publisher: Publisher) {
                publisher.$value
                    .sink { [weak self] _ in
                        self?.handleValue()
                    }
                    .store(in: &cancellables)
            }
            
            func handleValue() {
                // Handle value
            }
        }
        
        var publisher: Publisher? = Publisher()
        var subscriber: Subscriber? = Subscriber()
        weak var weakPublisher = publisher
        weak var weakSubscriber = subscriber
        
        subscriber?.subscribe(to: publisher!)
        
        // When
        publisher = nil
        subscriber = nil
        
        // Then
        XCTAssertNil(weakPublisher, "Publisher should be deallocated")
        XCTAssertNil(weakSubscriber, "Subscriber should be deallocated")
    }
    
    // MARK: - Closure Capture Memory Leak Tests
    
    func testClosureCaptureNoRetainCycle() async {
        // Given
        class Service {
            var completion: (() -> Void)?
            
            func performTask() {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.completion?()
                }
            }
        }
        
        weak var weakService: Service?
        
        autoreleasepool {
            let service = Service()
            weakService = service
            
            service.completion = { [weak service] in
                service?.performTask()
            }
            
            service.performTask()
        }
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertNil(weakService, "Service should be deallocated")
    }
    
    // MARK: - Task and Actor Memory Leak Tests
    
    func testTaskNoRetainCycle() async {
        // Given
        class TaskHolder {
            var task: Task<Void, Never>?
            
            func startTask() {
                task = Task { [weak self] in
                    while !Task.isCancelled {
                        self?.doWork()
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
            }
            
            func doWork() {
                // Perform work
            }
            
            deinit {
                task?.cancel()
            }
        }
        
        weak var weakHolder: TaskHolder?
        
        autoreleasepool {
            let holder = TaskHolder()
            weakHolder = holder
            holder.startTask()
        }
        
        // Wait for cleanup
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertNil(weakHolder, "TaskHolder should be deallocated")
    }
    
    func testActorNoRetainCycle() async {
        // Given
        actor DataManager {
            private var data: [String] = []
            
            func addData(_ item: String) {
                data.append(item)
            }
            
            func getData() -> [String] {
                data
            }
        }
        
        weak var weakManager: DataManager?
        
        autoreleasepool {
            let manager = DataManager()
            weakManager = manager
            
            Task {
                await manager.addData("test")
                _ = await manager.getData()
            }
        }
        
        // Wait for operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertNil(weakManager, "Actor should be deallocated")
    }
    
    // MARK: - Notification Observer Memory Leak Tests
    
    func testNotificationObserverNoRetainCycle() {
        // Given
        class Observer {
            var notificationToken: NSObjectProtocol?
            
            init() {
                notificationToken = NotificationCenter.default.addObserver(
                    forName: .init("TestNotification"),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.handleNotification()
                }
            }
            
            func handleNotification() {
                // Handle notification
            }
            
            deinit {
                if let token = notificationToken {
                    NotificationCenter.default.removeObserver(token)
                }
            }
        }
        
        weak var weakObserver: Observer?
        
        autoreleasepool {
            let observer = Observer()
            weakObserver = observer
            
            // Post notification
            NotificationCenter.default.post(name: .init("TestNotification"), object: nil)
        }
        
        // Then
        XCTAssertNil(weakObserver, "Observer should be deallocated")
    }
    
    // MARK: - Cache Memory Management Tests
    
    func testCacheMemoryManagement() async {
        // Given
        let cache = InMemoryCacheService()
        
        // Create large objects
        struct LargeObject: Codable {
            let data: [Int]
        }
        
        // When - Add many large objects
        for i in 0..<1000 {
            let object = LargeObject(data: Array(repeating: i, count: 1000))
            await cache.cache(object, forKey: "key-\(i)")
        }
        
        // Then - Cache should handle memory pressure
        await cache.clearAll()
        
        // Verify cleanup
        let retrieved = await cache.retrieve(LargeObject.self, forKey: "key-0")
        XCTAssertNil(retrieved, "Cache should be cleared")
    }
    
    // MARK: - Performance Monitoring
    
    func testMemoryFootprint() {
        // Measure memory usage during operations
        let metrics: [XCTMetric] = [
            XCTMemoryMetric(),
            XCTCPUMetric(),
            XCTStorageMetric()
        ]
        
        measure(metrics: metrics) {
            // Create and destroy objects
            for _ in 0..<100 {
                autoreleasepool {
                    let _ = HomeViewModel()
                    let _ = ProjectsViewModel()
                    let _ = SessionsViewModel()
                }
            }
        }
    }
}