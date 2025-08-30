import Foundation
import SwiftUI
import Combine
import OSLog

// MARK: - Actor-Based Memory Management

/// Actor-based weak set that automatically removes deallocated objects
actor ActorWeakSet<T: AnyObject & Hashable> {
    private var storage = Set<WeakBox<T>>()
    
    func insert(_ object: T) {
        // Clean up nil references
        storage = storage.filter { $0.value != nil }
        storage.insert(WeakBox(object))
    }
    
    func remove(_ object: T) {
        storage = storage.filter { $0.value !== object }
    }
    
    func contains(_ object: T) -> Bool {
        return storage.contains { $0.value === object }
    }
    
    var allObjects: [T] {
        return storage.compactMap { $0.value }
    }
    
    var count: Int {
        allObjects.count
    }
}

/// Actor-based dictionary with weak values
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
    
    func clean() {
        storage = storage.filter { _, box in box.value != nil }
    }
    
    var count: Int {
        return storage.filter { _, box in box.value != nil }.count
    }
}

/// Actor-based lazy loader with automatic memory management
actor ActorLazyLoader<T: Sendable> {
    private var loader: (@Sendable () -> T)?
    private var storage: T?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ActorLazyLoader")
    
    init(loader: @escaping @Sendable () -> T) {
        self.loader = loader
    }
    
    func load() -> T {
        if let storage = storage {
            return storage
        }
        
        guard let loader = loader else {
            fatalError("ActorLazyLoader loader is nil")
        }
        
        let value = loader()
        storage = value
        self.loader = nil // Release the loader closure
        
        logger.debug("✅ Lazy loaded value of type \(String(describing: T.self))")
        return value
    }
    
    func reset() {
        storage = nil
        // Note: loader is not restored after reset
    }
}

/// Actor-based resource pool for reusable resources
actor ActorResourcePool<T: Sendable> {
    private var available: [T] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let maxSize: Int
    private let factory: @Sendable () -> T
    private let reset: @Sendable (T) -> Void
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ActorResourcePool")
    
    init(
        maxSize: Int = 10,
        factory: @escaping @Sendable () -> T,
        reset: @escaping @Sendable (T) -> Void = { _ in }
    ) {
        self.maxSize = maxSize
        self.factory = factory
        self.reset = reset
    }
    
    func acquire() -> T {
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
        available.removeAll()
        inUse.removeAll()
        logger.info("💧 Drained resource pool")
    }
}

// MARK: - Safe Wrapper for Non-Sendable Types

/// A sendable wrapper for non-sendable weak sets
final class SendableWeakSet<T: AnyObject & Hashable>: @unchecked Sendable {
    private let actor: ActorWeakSet<T>
    
    init() {
        self.actor = ActorWeakSet<T>()
    }
    
    func insert(_ object: T) async {
        await actor.insert(object)
    }
    
    func remove(_ object: T) async {
        await actor.remove(object)
    }
    
    func contains(_ object: T) async -> Bool {
        await actor.contains(object)
    }
    
    var allObjects: [T] {
        get async {
            await actor.allObjects
        }
    }
    
    var count: Int {
        get async {
            await actor.count
        }
    }
}

/// A sendable wrapper for non-sendable weak value dictionaries
final class SendableWeakValueDictionary<Key: Hashable, Value: AnyObject>: @unchecked Sendable {
    private let actor: ActorWeakValueDictionary<Key, Value>
    
    init() {
        self.actor = ActorWeakValueDictionary<Key, Value>()
    }
    
    subscript(key: Key) -> Value? {
        get async {
            await actor.get(key)
        }
    }
    
    func set(_ key: Key, value: Value?) async {
        await actor.set(key, value: value)
    }
    
    func clean() async {
        await actor.clean()
    }
    
    var count: Int {
        get async {
            await actor.count
        }
    }
}