import Foundation
@testable import ClaudeCode

// MARK: - Mock Networking Service

@MainActor
final class MockNetworkingService: NetworkingServiceProtocol {
    var apiClient: APIClientProtocol
    var cancelRequestsCalled = false
    var cancelRequestsCallCount = 0
    
    init(apiClient: APIClientProtocol? = nil) {
        self.apiClient = apiClient ?? MockAPIClient()
    }
    
    func cancelAllRequests() {
        cancelRequestsCalled = true
        cancelRequestsCallCount += 1
    }
}

// MARK: - Mock Authentication Manager

@MainActor
final class MockAuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    
    var authenticateCalled = false
    var authenticateCallCount = 0
    var lastAuthenticateToken: String?
    
    var logoutCalled = false
    var logoutCallCount = 0
    
    var validateTokenCalled = false
    var shouldFailValidation = false
    
    struct User {
        let id: String
        let email: String
    }
    
    func authenticate(with token: String) async throws {
        authenticateCalled = true
        authenticateCallCount += 1
        lastAuthenticateToken = token
        
        if shouldFailValidation {
            throw AuthenticationError.invalidToken
        }
        
        isAuthenticated = true
        user = User(id: "test-user", email: "test@example.com")
    }
    
    func logout() {
        logoutCalled = true
        logoutCallCount += 1
        isAuthenticated = false
        user = nil
    }
    
    func validateToken(_ token: String) async throws -> Bool {
        validateTokenCalled = true
        if shouldFailValidation {
            throw AuthenticationError.invalidToken
        }
        return !token.isEmpty
    }
}

enum AuthenticationError: Error {
    case invalidToken
    case networkError
    case unauthorized
}

// MARK: - Mock Keychain Service

final class MockKeychainService {
    private var storage: [String: String] = [:]
    
    var saveCallCount = 0
    var loadCallCount = 0
    var deleteCallCount = 0
    var shouldFailOperations = false
    
    func save(_ value: String, forKey key: String) throws {
        saveCallCount += 1
        if shouldFailOperations {
            throw KeychainError.unableToStore
        }
        storage[key] = value
    }
    
    func load(forKey key: String) throws -> String? {
        loadCallCount += 1
        if shouldFailOperations {
            throw KeychainError.itemNotFound
        }
        return storage[key]
    }
    
    func delete(forKey key: String) throws {
        deleteCallCount += 1
        if shouldFailOperations {
            throw KeychainError.unableToDelete
        }
        storage.removeValue(forKey: key)
    }
    
    func reset() {
        storage.removeAll()
        saveCallCount = 0
        loadCallCount = 0
        deleteCallCount = 0
        shouldFailOperations = false
    }
}

enum KeychainError: Error {
    case itemNotFound
    case unableToStore
    case unableToDelete
}

// MARK: - Mock Analytics Manager

@MainActor
final class MockAnalyticsManager: AnalyticsServiceProtocol {
    var trackedEvents: [(event: String, properties: [String: Any]?)] = []
    var identifiedUsers: [(userId: String, traits: [String: Any]?)] = []
    var screenViews: [(name: String, properties: [String: Any]?)] = []
    
    var isEnabled = true
    
    func track(event: String, properties: [String: Any]?) {
        guard isEnabled else { return }
        trackedEvents.append((event: event, properties: properties))
    }
    
    func identify(userId: String, traits: [String: Any]?) {
        guard isEnabled else { return }
        identifiedUsers.append((userId: userId, traits: traits))
    }
    
    func screen(name: String, properties: [String: Any]?) {
        guard isEnabled else { return }
        screenViews.append((name: name, properties: properties))
    }
    
    func reset() {
        trackedEvents.removeAll()
        identifiedUsers.removeAll()
        screenViews.removeAll()
    }
}

// MARK: - Mock Cache Manager

actor MockCacheManager: CacheServiceProtocol {
    private var cache: [String: Data] = [:]
    
    var cacheHits = 0
    var cacheMisses = 0
    var itemsCached = 0
    var itemsRemoved = 0
    
    func cache<T: Codable>(_ object: T, forKey key: String) async {
        guard let data = try? JSONEncoder().encode(object) else { return }
        cache[key] = data
        itemsCached += 1
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        guard let data = cache[key] else {
            cacheMisses += 1
            return nil
        }
        cacheHits += 1
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) async {
        if cache.removeValue(forKey: key) != nil {
            itemsRemoved += 1
        }
    }
    
    func clearAll() async {
        let count = cache.count
        cache.removeAll()
        itemsRemoved += count
    }
    
    func reset() {
        cache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        itemsCached = 0
        itemsRemoved = 0
    }
    
    func getCacheStats() -> (hits: Int, misses: Int, cached: Int, removed: Int) {
        (cacheHits, cacheMisses, itemsCached, itemsRemoved)
    }
}