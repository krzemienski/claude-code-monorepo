# Actor-Based Concurrency Architecture

## Overview
ClaudeCode iOS leverages Swift's actor model for thread-safe concurrent programming, eliminating data races and ensuring memory safety through compile-time guarantees.

## Architecture Components

### 1. ActorBasedTaskManagement
Location: `/Sources/App/Core/Concurrency/ActorBasedTaskManagement.swift`

#### Purpose
Provides centralized task lifecycle management with cancellation support, preventing memory leaks and ensuring proper cleanup.

#### Key Components

##### ActorCancellationToken
```swift
actor ActorCancellationToken {
    private var isCancelledValue = false
    private var cancellationHandlers: [() -> Void] = []
    
    func cancel() {
        // Thread-safe cancellation
        guard !isCancelledValue else { return }
        isCancelledValue = true
        
        // Execute registered cleanup handlers
        for handler in cancellationHandlers {
            handler()
        }
    }
}
```

##### ActorTaskCoordinator
Manages task lifecycle with automatic cleanup:
```swift
actor ActorTaskCoordinator {
    private var activeTasks = Set<TaskIdentifier>()
    
    func register(task: Task<Void, Never>) -> TaskIdentifier {
        let id = TaskIdentifier()
        activeTasks.insert(id)
        
        Task { [weak self] in
            await task.value
            await self?.unregister(id)
        }
        
        return id
    }
    
    func cancelAll() {
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}
```

#### Usage Pattern
```swift
class ChatViewModel: ObservableObject {
    private let taskCoordinator = ActorTaskCoordinator()
    
    func startStreaming() {
        Task {
            let taskId = await taskCoordinator.register(
                task: streamMessages()
            )
            // Task automatically cleaned up on completion
        }
    }
    
    deinit {
        Task {
            await taskCoordinator.cancelAll()
        }
    }
}
```

### 2. ActorBasedMemoryManagement
Location: `/Sources/App/Core/Memory/ActorBasedMemoryManagement.swift`

#### Purpose
Provides thread-safe memory management primitives that prevent retain cycles and memory leaks.

#### Key Components

##### ActorWeakSet
Thread-safe weak reference collection:
```swift
actor ActorWeakSet<T: AnyObject & Hashable> {
    private var storage = Set<WeakBox<T>>()
    
    func insert(_ object: T) {
        // Automatically removes deallocated objects
        storage = storage.filter { $0.value != nil }
        storage.insert(WeakBox(object))
    }
    
    var allObjects: [T] {
        return storage.compactMap { $0.value }
    }
}
```

##### ActorWeakValueDictionary
Dictionary with weak values for cache management:
```swift
actor ActorWeakValueDictionary<Key: Hashable, Value: AnyObject> {
    private var storage = [Key: WeakBox<Value>]()
    
    func get(_ key: Key) -> Value? {
        return storage[key]?.value
    }
    
    func set(_ key: Key, value: Value?) {
        if let value = value {
            storage[key] = WeakBox(value)
        } else {
            storage[key] = nil
        }
    }
}
```

##### ActorMemoryCache
LRU cache with automatic memory pressure handling:
```swift
actor ActorMemoryCache<Key: Hashable, Value> {
    private var cache = [Key: CacheEntry<Value>]()
    private let maxSize: Int
    
    func get(_ key: Key) async -> Value? {
        if let entry = cache[key], !entry.isExpired {
            // Update access time for LRU
            cache[key]?.lastAccessed = Date()
            return entry.value
        }
        return nil
    }
    
    func set(_ key: Key, value: Value, ttl: TimeInterval = 300) {
        // Evict if needed
        if cache.count >= maxSize {
            evictLRU()
        }
        
        cache[key] = CacheEntry(
            value: value,
            expiration: Date().addingTimeInterval(ttl)
        )
    }
    
    private func evictLRU() {
        let oldest = cache.min { $0.value.lastAccessed < $1.value.lastAccessed }
        if let key = oldest?.key {
            cache.removeValue(forKey: key)
        }
    }
}
```

#### Usage Pattern
```swift
class ProjectManager {
    private let projectCache = ActorMemoryCache<String, Project>(maxSize: 100)
    private let observers = ActorWeakSet<ProjectObserver>()
    
    func loadProject(id: String) async -> Project? {
        // Check cache first
        if let cached = await projectCache.get(id) {
            return cached
        }
        
        // Load from backend
        let project = try? await api.fetchProject(id)
        if let project = project {
            await projectCache.set(id, value: project)
        }
        
        return project
    }
    
    func addObserver(_ observer: ProjectObserver) async {
        await observers.insert(observer)
    }
    
    func notifyObservers() async {
        let activeObservers = await observers.allObjects
        for observer in activeObservers {
            observer.projectsDidUpdate()
        }
    }
}
```

### 3. Actor-Based Networking
Location: `/Sources/App/Core/Networking/ActorAPIClient.swift`

#### Purpose
Thread-safe API client with automatic request deduplication and response caching.

#### Implementation
```swift
actor ActorAPIClient {
    private let session: URLSession
    private var inflightRequests = [URLRequest: Task<Data, Error>]()
    private let responseCache = ActorMemoryCache<URL, CachedResponse>()
    
    func perform(_ request: URLRequest) async throws -> Data {
        // Deduplicate inflight requests
        if let existingTask = inflightRequests[request] {
            return try await existingTask.value
        }
        
        // Check cache for GET requests
        if request.httpMethod == "GET",
           let url = request.url,
           let cached = await responseCache.get(url) {
            return cached.data
        }
        
        // Create new request task
        let task = Task {
            let (data, response) = try await session.data(for: request)
            
            // Cache successful GET responses
            if request.httpMethod == "GET",
               let url = request.url,
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await responseCache.set(url, value: CachedResponse(data: data))
            }
            
            return data
        }
        
        inflightRequests[request] = task
        
        defer {
            inflightRequests.removeValue(forKey: request)
        }
        
        return try await task.value
    }
}
```

## Actor Design Patterns

### 1. Coordinator Pattern
Use actors to coordinate complex workflows:
```swift
actor WorkflowCoordinator {
    enum State {
        case idle
        case processing
        case completed(Result<Output, Error>)
    }
    
    private var state = State.idle
    private var steps: [WorkflowStep] = []
    
    func execute() async throws -> Output {
        guard case .idle = state else {
            throw WorkflowError.alreadyExecuting
        }
        
        state = .processing
        
        do {
            var result: Any = ()
            for step in steps {
                result = try await step.execute(input: result)
            }
            
            let output = result as! Output
            state = .completed(.success(output))
            return output
        } catch {
            state = .completed(.failure(error))
            throw error
        }
    }
}
```

### 2. Publisher Pattern
Combine actors with Combine for reactive updates:
```swift
actor StateManager {
    private let stateSubject = CurrentValueSubject<AppState, Never>(.initial)
    
    nonisolated var statePublisher: AnyPublisher<AppState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    func update(_ transform: (AppState) -> AppState) {
        let newState = transform(stateSubject.value)
        stateSubject.send(newState)
    }
}
```

### 3. Resource Pool Pattern
Manage limited resources with actors:
```swift
actor ResourcePool<Resource> {
    private var available: [Resource]
    private var waiting: [CheckedContinuation<Resource, Never>] = []
    
    func acquire() async -> Resource {
        if let resource = available.popLast() {
            return resource
        }
        
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }
    
    func release(_ resource: Resource) {
        if let continuation = waiting.popLast() {
            continuation.resume(returning: resource)
        } else {
            available.append(resource)
        }
    }
}
```

## Best Practices

### 1. Avoid Blocking Operations
```swift
// ❌ Bad: Blocking in actor
actor DataProcessor {
    func process() {
        Thread.sleep(forTimeInterval: 1.0) // Blocks actor
    }
}

// ✅ Good: Use async alternatives
actor DataProcessor {
    func process() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
```

### 2. Minimize Actor Hops
```swift
// ❌ Bad: Multiple actor hops
func updateUI() async {
    let data = await dataActor.getData()
    let processed = await processorActor.process(data)
    let formatted = await formatterActor.format(processed)
    await MainActor.run {
        label.text = formatted
    }
}

// ✅ Good: Batch operations
func updateUI() async {
    let formatted = await dataActor.getFormattedData()
    await MainActor.run {
        label.text = formatted
    }
}
```

### 3. Use Sendable Types
```swift
// ✅ Ensure types crossing actor boundaries are Sendable
struct ProjectData: Sendable {
    let id: String
    let name: String
    let createdAt: Date
}

// Use @unchecked Sendable carefully
final class ImageCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: UIImage] = [:]
    
    func get(_ key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
}
```

### 4. Handle Task Cancellation
```swift
actor DataLoader {
    func loadData() async throws -> Data {
        try Task.checkCancellation()
        
        let data = try await fetchFromNetwork()
        
        try Task.checkCancellation()
        
        return try await processData(data)
    }
}
```

## Testing Actors

### Unit Testing
```swift
@MainActor
class ActorTests: XCTestCase {
    func testActorBehavior() async {
        let cache = ActorMemoryCache<String, String>(maxSize: 2)
        
        await cache.set("key1", value: "value1")
        let retrieved = await cache.get("key1")
        
        XCTAssertEqual(retrieved, "value1")
    }
}
```

### Performance Testing
```swift
func testActorPerformance() async {
    let coordinator = ActorTaskCoordinator()
    
    measure {
        let expectation = expectation(description: "Tasks complete")
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<1000 {
                    group.addTask {
                        await coordinator.register(task: someAsyncWork())
                    }
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
}
```

## Migration Guide

### From Dispatch Queues to Actors
```swift
// Before: DispatchQueue
class OldDataManager {
    private let queue = DispatchQueue(label: "data.queue")
    private var data: [String] = []
    
    func add(_ item: String, completion: @escaping () -> Void) {
        queue.async {
            self.data.append(item)
            completion()
        }
    }
}

// After: Actor
actor NewDataManager {
    private var data: [String] = []
    
    func add(_ item: String) {
        data.append(item)
    }
}
```

### From Locks to Actors
```swift
// Before: NSLock
class OldCache {
    private let lock = NSLock()
    private var cache: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
}

// After: Actor
actor NewCache {
    private var cache: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        return cache[key]
    }
}
```

## Performance Considerations

### Actor Reentrancy
Actors are reentrant, allowing suspension points:
```swift
actor DataManager {
    var counter = 0
    
    func increment() async {
        counter += 1
        await someAsyncOperation() // Suspension point
        counter += 1 // Another actor method could run between these
    }
}
```

### Actor Isolation
Minimize data copying with nonisolated properties:
```swift
actor ConfigManager {
    // Immutable data can be nonisolated
    nonisolated let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    // Mutable state must be isolated
    private var settings: [String: Any] = [:]
}
```

## Debugging

### Actor Deadlocks
Use Instruments to detect actor deadlocks:
1. Profile with Time Profiler
2. Look for actor contention
3. Check for circular dependencies

### Memory Leaks
Use Memory Graph Debugger:
1. Look for retain cycles in actor closures
2. Check weak reference handling
3. Verify task cancellation

## Resources
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [WWDC: Meet Swift Concurrency](https://developer.apple.com/wwdc21/10132)
- [Actor Isolation](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)