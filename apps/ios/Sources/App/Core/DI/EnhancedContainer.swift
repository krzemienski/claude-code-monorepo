import Foundation
import SwiftUI
import OSLog

// MARK: - Advanced Dependency Injection Container with Swift 5.9+ Features

/// Protocol for service registration and resolution
protocol ServiceContainer {
    func register<T>(_ serviceType: T.Type, factory: @escaping () -> T)
    func register<T>(_ serviceType: T.Type, instance: T)
    func resolve<T>(_ serviceType: T.Type) -> T?
    func resolve<T>() -> T?
}

/// Protocol for lazy-loadable services
protocol LazyLoadable {
    associatedtype Service
    func load() async throws -> Service
}

/// Property wrapper for dependency injection
@propertyWrapper
@MainActor
struct Injected<T> {
    private var service: T?
    private let serviceType: T.Type
    
    init(_ serviceType: T.Type) {
        self.serviceType = serviceType
    }
    
    var wrappedValue: T {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.resolve(serviceType)
            }
            guard let service = service else {
                fatalError("❌ No registered service of type \(serviceType)")
            }
            return service
        }
    }
}

/// Property wrapper for optional dependency injection
@propertyWrapper
@MainActor
struct OptionalInjected<T> {
    private var service: T?
    private let serviceType: T.Type
    
    init(_ serviceType: T.Type) {
        self.serviceType = serviceType
    }
    
    var wrappedValue: T? {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.resolve(serviceType)
            }
            return service
        }
    }
}

/// Property wrapper for weak dependency injection (prevents retain cycles)
@propertyWrapper
@MainActor
struct WeakInjected<T: AnyObject> {
    private weak var service: T?
    private let serviceType: T.Type
    
    init(_ serviceType: T.Type) {
        self.serviceType = serviceType
    }
    
    var wrappedValue: T? {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.resolve(serviceType)
            }
            return service
        }
    }
}

// MARK: - Service Locator Pattern with Thread Safety

@MainActor
final class ServiceLocator: ServiceContainer {
    static let shared = ServiceLocator()
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ServiceLocator")
    private var services: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let lock = NSRecursiveLock()
    
    private init() {}
    
    /// Register a factory for lazy loading
    func register<T>(_ serviceType: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        factories[key] = factory
        logger.debug("✅ Registered factory for \(String(describing: serviceType))")
    }
    
    /// Register a singleton instance
    func register<T>(_ serviceType: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        services[key] = instance
        logger.debug("✅ Registered instance for \(String(describing: serviceType))")
    }
    
    /// Resolve a service with type parameter
    func resolve<T>(_ serviceType: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        
        // Check for existing instance
        if let service = services[key] as? T {
            return service
        }
        
        // Check for factory and create instance
        if let factory = factories[key] {
            let service = factory() as? T
            if let service = service {
                services[key] = service  // Cache the instance
                return service
            }
        }
        
        logger.warning("⚠️ No service registered for \(String(describing: serviceType))")
        return nil
    }
    
    /// Resolve a service with type inference
    func resolve<T>() -> T? {
        resolve(T.self)
    }
    
    /// Clear all registered services (useful for testing)
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        services.removeAll()
        factories.removeAll()
        logger.info("🔄 Service locator reset")
    }
}

// MARK: - Enhanced Container with Modern Patterns

@MainActor
final class EnhancedContainer: ObservableObject {
    static let shared = EnhancedContainer()
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "EnhancedContainer")
    private let serviceLocator = ServiceLocator.shared
    
    // MARK: - Service Protocols
    
    /// Protocol-based services for better testability
    private(set) lazy var networkingService: NetworkingServiceProtocol = {
        createNetworkingService()
    }()
    
    private(set) lazy var authenticationService: AuthenticationServiceProtocol = {
        createAuthenticationService()
    }()
    
    private(set) lazy var cacheService: CacheServiceProtocol = {
        createCacheService()
    }()
    
    private(set) lazy var analyticsService: AnalyticsServiceProtocol = {
        createAnalyticsService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        registerServices()
        logger.info("🚀 Enhanced Container initialized")
    }
    
    // MARK: - Service Registration
    
    private func registerServices() {
        // Register core services with factories for lazy loading
        serviceLocator.register(AppSettings.self) {
            AppSettings()
        }
        
        serviceLocator.register(APIClientProtocol.self) { [weak self] in
            guard let settings = self?.serviceLocator.resolve(AppSettings.self),
                  let apiClient = EnhancedAPIClient(settings: settings, retryPolicy: .default) else {
                return MockAPIClient()
            }
            return apiClient
        }
        
        serviceLocator.register(NetworkingServiceProtocol.self) { [weak self] in
            self?.createNetworkingService() ?? MockNetworkingService()
        }
        
        serviceLocator.register(AuthenticationServiceProtocol.self) { [weak self] in
            self?.createAuthenticationService() ?? MockAuthenticationService()
        }
        
        serviceLocator.register(CacheServiceProtocol.self) { [weak self] in
            self?.createCacheService() ?? InMemoryCacheService()
        }
        
        serviceLocator.register(AnalyticsServiceProtocol.self) { [weak self] in
            self?.createAnalyticsService() ?? MockAnalyticsService()
        }
        
        logger.debug("✅ All services registered")
    }
    
    // MARK: - Factory Methods
    
    private func createNetworkingService() -> NetworkingServiceProtocol {
        guard let settings = serviceLocator.resolve(AppSettings.self),
              let apiClient = EnhancedAPIClient(settings: settings, retryPolicy: .default) else {
            logger.error("Failed to create networking service, using mock")
            return MockNetworkingService()
        }
        return NetworkingService(apiClient: apiClient)
    }
    
    private func createAuthenticationService() -> AuthenticationServiceProtocol {
        guard let settings = serviceLocator.resolve(AppSettings.self) else {
            return MockAuthenticationService()
        }
        return AuthenticationService(settings: settings)
    }
    
    private func createCacheService() -> CacheServiceProtocol {
        #if DEBUG
        return InMemoryCacheService()
        #else
        return PersistentCacheService()
        #endif
    }
    
    private func createAnalyticsService() -> AnalyticsServiceProtocol {
        #if DEBUG
        return MockAnalyticsService()
        #else
        return ProductionAnalyticsService()
        #endif
    }
    
    // MARK: - View Model Factory with Dependency Injection
    
    @ViewModelBuilder
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }
    
    @ViewModelBuilder
    func makeProjectsViewModel() -> ProjectsViewModel {
        ProjectsViewModel()
    }
    
    @ViewModelBuilder
    func makeSessionsViewModel() -> SessionsViewModel {
        SessionsViewModel()
    }
    
    @ViewModelBuilder
    func makeChatViewModel(sessionId: String, projectId: String = "default") -> ChatViewModel {
        ChatViewModel(
            sessionId: sessionId,
            projectId: projectId
        )
    }
    
    @ViewModelBuilder
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel()
    }
    
    @ViewModelBuilder
    func makeMCPViewModel() -> MCPViewModel {
        MCPViewModel()
    }
    
    @ViewModelBuilder
    func makeMonitoringViewModel() -> MonitoringViewModel {
        MonitoringViewModel()
    }
    
    // MARK: - Testing Support
    
    func injectMock<T>(_ serviceType: T.Type, mock: T) {
        serviceLocator.register(serviceType, instance: mock)
        logger.debug("💉 Injected mock for \(String(describing: serviceType))")
    }
    
    func reset() {
        serviceLocator.reset()
        registerServices()
        logger.info("🔄 Container reset for testing")
    }
}

// MARK: - Result Builder for View Models

@resultBuilder
enum ViewModelBuilder {
    static func buildBlock<VM>(_ viewModel: VM) -> VM {
        viewModel
    }
}

// MARK: - Service Protocols

protocol NetworkingServiceProtocol {
    var apiClient: APIClientProtocol { get }
    func cancelAllRequests()
}

protocol AuthenticationServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate(apiKey: String) async throws
    func logout()
}

protocol CacheServiceProtocol {
    func cache<T: Codable>(_ object: T, forKey key: String) async
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    func remove(forKey key: String) async
    func clearAll() async
}

protocol AnalyticsServiceProtocol {
    func track(event: String, properties: [String: Any]?)
    func identify(userId: String, traits: [String: Any]?)
    func screen(name: String, properties: [String: Any]?)
}

// MARK: - Default Implementations

@MainActor
struct NetworkingService: NetworkingServiceProtocol {
    let apiClient: APIClientProtocol
    
    func cancelAllRequests() {
        apiClient.cancelAllRequests()
    }
}

@MainActor
final class AuthenticationService: AuthenticationServiceProtocol {
    private let settings: AppSettings
    
    init(settings: AppSettings) {
        self.settings = settings
    }
    
    var isAuthenticated: Bool {
        !settings.apiKeyPlaintext.isEmpty
    }
    
    func authenticate(apiKey: String) async throws {
        settings.apiKeyPlaintext = apiKey
    }
    
    func logout() {
        settings.apiKeyPlaintext = ""
    }
}

// MARK: - Mock Implementations

@MainActor
struct MockNetworkingService: NetworkingServiceProtocol {
    var apiClient: APIClientProtocol {
        MockAPIClient()
    }
    
    func cancelAllRequests() {}
}

final class MockAuthenticationService: AuthenticationServiceProtocol {
    var isAuthenticated: Bool { false }
    func authenticate(apiKey: String) async throws {}
    func logout() {}
}

struct MockAnalyticsService: AnalyticsServiceProtocol {
    func track(event: String, properties: [String: Any]?) {}
    func identify(userId: String, traits: [String: Any]?) {}
    func screen(name: String, properties: [String: Any]?) {}
}

struct InMemoryCacheService: CacheServiceProtocol {
    private let cache = NSCache<NSString, NSData>()
    
    func cache<T: Codable>(_ object: T, forKey key: String) async {
        guard let data = try? JSONEncoder().encode(object) else { return }
        cache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        guard let data = cache.object(forKey: key as NSString) as Data? else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) async {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clearAll() async {
        cache.removeAllObjects()
    }
}

struct PersistentCacheService: CacheServiceProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("com.claudecode.cache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cache<T: Codable>(_ object: T, forKey key: String) async {
        let url = cacheDirectory.appendingPathComponent(key)
        guard let data = try? JSONEncoder().encode(object) else { return }
        try? data.write(to: url)
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        let url = cacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) async {
        let url = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: url)
    }
    
    func clearAll() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

struct ProductionAnalyticsService: AnalyticsServiceProtocol {
    func track(event: String, properties: [String: Any]?) {
        // Implement production analytics
    }
    
    func identify(userId: String, traits: [String: Any]?) {
        // Implement user identification
    }
    
    func screen(name: String, properties: [String: Any]?) {
        // Implement screen tracking
    }
}

// MARK: - Environment Extensions

extension EnvironmentValues {
    private struct EnhancedContainerKey: EnvironmentKey {
        @MainActor static let defaultValue = EnhancedContainer.shared
    }
    
    var enhancedContainer: EnhancedContainer {
        get { self[EnhancedContainerKey.self] }
        set { self[EnhancedContainerKey.self] = newValue }
    }
}

extension View {
    @MainActor
    func withEnhancedContainer(_ container: EnhancedContainer = .shared) -> some View {
        self.environment(\.enhancedContainer, container)
    }
}