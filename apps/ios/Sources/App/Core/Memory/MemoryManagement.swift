import Foundation
import SwiftUI
import Combine
import OSLog

// MARK: - Advanced Memory Management Patterns

/// Weak box for storing weak references
final class WeakBox<T: AnyObject>: Hashable {
    weak var value: T?
    
    init(_ value: T?) {
        self.value = value
    }
    
    static func == (lhs: WeakBox<T>, rhs: WeakBox<T>) -> Bool {
        lhs.value === rhs.value
    }
    
    func hash(into hasher: inout Hasher) {
        if let value = value {
            hasher.combine(ObjectIdentifier(value))
        }
    }
}

/// Collection that automatically removes deallocated objects
final class WeakSet<T: AnyObject & Hashable> {
    private var storage = Set<WeakBox<T>>()
    private let lock = NSLock()
    
    func insert(_ object: T) {
        lock.lock()
        defer { lock.unlock() }
        
        // Clean up nil references
        storage = storage.filter { $0.value != nil }
        storage.insert(WeakBox(object))
    }
    
    func remove(_ object: T) {
        lock.lock()
        defer { lock.unlock() }
        
        storage = storage.filter { $0.value !== object }
    }
    
    func contains(_ object: T) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return storage.contains { $0.value === object }
    }
    
    var allObjects: [T] {
        lock.lock()
        defer { lock.unlock() }
        
        return storage.compactMap { $0.value }
    }
    
    var count: Int {
        allObjects.count
    }
}

/// Dictionary with weak values
final class WeakValueDictionary<Key: Hashable, Value: AnyObject> {
    private var storage = [Key: WeakBox<Value>]()
    private let lock = NSRecursiveLock()
    
    subscript(key: Key) -> Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            
            return storage[key]?.value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            
            if let newValue = newValue {
                storage[key] = WeakBox(newValue)
            } else {
                storage[key] = nil
            }
        }
    }
    
    func clean() {
        lock.lock()
        defer { lock.unlock() }
        
        storage = storage.filter { _, box in box.value != nil }
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        return storage.filter { _, box in box.value != nil }.count
    }
}

// MARK: - Lazy Loading with Memory Management

/// Lazy loader with automatic memory management
@propertyWrapper
final class LazyLoaded<T> {
    private var loader: (() -> T)?
    private var storage: T?
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "LazyLoaded")
    
    init(wrappedValue: @autoclosure @escaping () -> T) {
        self.loader = wrappedValue
    }
    
    var wrappedValue: T {
        lock.lock()
        defer { lock.unlock() }
        
        if let storage = storage {
            return storage
        }
        
        guard let loader = loader else {
            fatalError("LazyLoaded loader is nil")
        }
        
        let value = loader()
        storage = value
        self.loader = nil // Release the loader closure
        
        logger.debug("✅ Lazy loaded value of type \(String(describing: T.self))")
        return value
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        storage = nil
        // Note: loader is not restored after reset
    }
}

/// Async lazy loader
actor AsyncLazyLoader<T> {
    private var loader: (() async throws -> T)?
    private var storage: T?
    private var loadingTask: Task<T, Error>?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "AsyncLazyLoader")
    
    init(loader: @escaping () async throws -> T) {
        self.loader = loader
    }
    
    func load() async throws -> T {
        // Return cached value if available
        if let storage = storage {
            return storage
        }
        
        // Join existing loading task if in progress
        if let loadingTask = loadingTask {
            return try await loadingTask.value
        }
        
        // Start new loading task
        guard let loader = loader else {
            throw MemoryError.loaderDeallocated
        }
        
        let task = Task<T, Error> {
            let value = try await loader()
            self.storage = value
            self.loader = nil // Release the loader
            self.loadingTask = nil
            
            logger.debug("✅ Async loaded value of type \(String(describing: T.self))")
            return value
        }
        
        loadingTask = task
        return try await task.value
    }
    
    func reset() {
        storage = nil
        loadingTask?.cancel()
        loadingTask = nil
    }
}

// MARK: - Memory-Efficient SwiftUI State Management

/// State container with automatic cleanup
@MainActor
final class StateContainer<T>: ObservableObject {
    @Published private(set) var value: T
    private var cancellables = Set<AnyCancellable>()
    private var memoryWarningObserver: Any?
    
    init(initialValue: T, cleanupHandler: (() -> Void)? = nil) {
        self.value = initialValue
        
        // Monitor memory warnings
        self.memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
            cleanupHandler?()
        }
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func update(_ newValue: T) {
        value = newValue
    }
    
    private func handleMemoryWarning() {
        // Subclasses can override for custom cleanup
    }
}

/// Cached state with expiration
@MainActor
final class CachedState<T>: ObservableObject {
    @Published private(set) var value: T?
    private var expirationDate: Date?
    private let cacheDuration: TimeInterval
    private var refreshTask: Task<Void, Never>?
    
    init(cacheDuration: TimeInterval = 300) { // 5 minutes default
        self.cacheDuration = cacheDuration
    }
    
    func set(_ value: T) {
        self.value = value
        self.expirationDate = Date().addingTimeInterval(cacheDuration)
        scheduleRefresh()
    }
    
    var isValid: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() < expirationDate
    }
    
    func invalidate() {
        value = nil
        expirationDate = nil
        refreshTask?.cancel()
    }
    
    private func scheduleRefresh() {
        refreshTask?.cancel()
        
        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            
            try? await Task.sleep(for: .seconds(self.cacheDuration))
            
            await MainActor.run {
                self.invalidate()
            }
        }
    }
}

// MARK: - Resource Pool Pattern

/// Object pool for reusable resources
final class ResourcePool<T> {
    private var available: [T] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let maxSize: Int
    private let factory: () -> T
    private let reset: (T) -> Void
    private let lock = NSRecursiveLock()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ResourcePool")
    
    init(
        maxSize: Int = 10,
        factory: @escaping () -> T,
        reset: @escaping (T) -> Void = { _ in }
    ) {
        self.maxSize = maxSize
        self.factory = factory
        self.reset = reset
    }
    
    func acquire() -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let resource: T
        
        if available.isEmpty {
            resource = factory()
            logger.debug("🏗️ Created new resource")
        } else {
            resource = available.removeLast()
            logger.debug("♻️ Reused resource from pool")
        }
        
        if let obj = resource as? AnyObject {
            inUse.insert(ObjectIdentifier(obj))
        }
        
        return resource
    }
    
    func release(_ resource: T) {
        lock.lock()
        defer { lock.unlock() }
        
        if let obj = resource as? AnyObject {
            inUse.remove(ObjectIdentifier(obj))
        }
        
        reset(resource)
        
        if available.count < maxSize {
            available.append(resource)
            logger.debug("🔄 Returned resource to pool")
        } else {
            logger.debug("🗑️ Discarded resource (pool full)")
        }
    }
    
    func drain() {
        lock.lock()
        defer { lock.unlock() }
        
        available.removeAll()
        inUse.removeAll()
        logger.info("💧 Drained resource pool")
    }
}

// MARK: - Memory Profiler

// Note: Using the MemoryProfiler from MemoryProfiler.swift
// This is an extension for memory monitoring
@MainActor
final class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()
    
    @Published private(set) var currentUsage: MemoryUsageInfo = .init(used: 0, peak: 0, available: 0)
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MemoryMonitor")
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            currentUsage = MemoryUsageInfo(
                used: Int(info.resident_size),
                peak: max(currentUsage.peak, Int(info.resident_size)),
                available: ProcessInfo.processInfo.physicalMemory
            )
            
            if currentUsage.percentage > 80 {
                logger.warning("⚠️ High memory usage: \(self.currentUsage.percentage)%")
            }
        }
    }
}

// MARK: - Supporting Types

struct MemoryUsageInfo {
    let used: Int
    let peak: Int
    let available: UInt64
    
    init(used: Int = 0, peak: Int = 0, available: UInt64 = 0) {
        self.used = used
        self.peak = peak
        self.available = available
    }
    
    var usedMB: Double {
        Double(used) / 1024 / 1024
    }
    
    var peakMB: Double {
        Double(peak) / 1024 / 1024
    }
    
    var availableMB: Double {
        Double(available) / 1024 / 1024
    }
    
    var percentage: Double {
        guard available > 0 else { return 0 }
        return (Double(used) / Double(available)) * 100
    }
}

enum MemoryError: LocalizedError {
    case loaderDeallocated
    case resourceExhausted
    
    var errorDescription: String? {
        switch self {
        case .loaderDeallocated:
            return "Loader was deallocated before loading"
        case .resourceExhausted:
            return "Resource pool exhausted"
        }
    }
}

// MARK: - SwiftUI Memory-Efficient Components

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

struct ConditionalView<TrueContent: View, FalseContent: View>: View {
    let condition: Bool
    let trueContent: () -> TrueContent
    let falseContent: () -> FalseContent
    
    var body: some View {
        if condition {
            trueContent()
        } else {
            falseContent()
        }
    }
}

// MARK: - Memory-Aware Image Loading

struct MemoryEfficientAsyncImage: View {
    let url: URL?
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Clear image on disappear to free memory
            image = nil
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    // Downsample image for memory efficiency
                    if let uiImage = UIImage(data: data) {
                        self.image = downsample(image: uiImage, to: CGSize(width: 300, height: 300))
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func downsample(image: UIImage, to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}