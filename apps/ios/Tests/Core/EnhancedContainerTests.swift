import XCTest
@testable import ClaudeCode

@MainActor
final class EnhancedContainerTests: XCTestCase {
    
    var container: EnhancedContainer!
    var serviceLocator: ServiceLocator!
    
    override func setUp() async throws {
        try await super.setUp()
        container = EnhancedContainer.shared
        serviceLocator = ServiceLocator.shared
        container.reset()
    }
    
    override func tearDown() async throws {
        container.reset()
        try await super.tearDown()
    }
    
    // MARK: - Service Locator Tests
    
    func testServiceRegistration() {
        // Given
        let mockService = MockAuthenticationService()
        
        // When
        serviceLocator.register(AuthenticationServiceProtocol.self, instance: mockService)
        
        // Then
        let resolved = serviceLocator.resolve(AuthenticationServiceProtocol.self)
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved is MockAuthenticationService)
    }
    
    func testFactoryRegistration() {
        // Given
        var factoryCallCount = 0
        serviceLocator.register(AppSettings.self) {
            factoryCallCount += 1
            return AppSettings()
        }
        
        // When
        let settings1 = serviceLocator.resolve(AppSettings.self)
        let settings2 = serviceLocator.resolve(AppSettings.self)
        
        // Then
        XCTAssertNotNil(settings1)
        XCTAssertNotNil(settings2)
        XCTAssertEqual(factoryCallCount, 1, "Factory should only be called once (singleton behavior)")
    }
    
    func testServiceResolution() {
        // Given
        let mockAnalytics = MockAnalyticsService()
        serviceLocator.register(AnalyticsServiceProtocol.self, instance: mockAnalytics)
        
        // When
        let resolved: AnalyticsServiceProtocol? = serviceLocator.resolve()
        
        // Then
        XCTAssertNotNil(resolved)
    }
    
    func testServiceLocatorReset() {
        // Given
        serviceLocator.register(AppSettings.self, instance: AppSettings())
        
        // When
        serviceLocator.reset()
        let resolved = serviceLocator.resolve(AppSettings.self)
        
        // Then
        XCTAssertNil(resolved, "Service should be nil after reset")
    }
    
    // MARK: - Property Wrapper Tests
    
    func testInjectedPropertyWrapper() {
        // Given
        serviceLocator.register(AppSettings.self, instance: AppSettings())
        
        // When
        struct TestService {
            @Injected(AppSettings.self) var settings: AppSettings
        }
        
        var service = TestService()
        
        // Then
        XCTAssertNotNil(service.settings)
    }
    
    func testOptionalInjectedPropertyWrapper() {
        // Given - No registration
        
        // When
        struct TestService {
            @OptionalInjected(AppSettings.self) var settings: AppSettings?
        }
        
        var service = TestService()
        
        // Then
        XCTAssertNil(service.settings)
        
        // When - Register service
        serviceLocator.register(AppSettings.self, instance: AppSettings())
        service = TestService()
        
        // Then
        XCTAssertNotNil(service.settings)
    }
    
    func testWeakInjectedPropertyWrapper() {
        // Given
        class TestClass: ObservableObject {}
        let testObject = TestClass()
        serviceLocator.register(TestClass.self, instance: testObject)
        
        // When
        struct TestService {
            @WeakInjected(TestClass.self) var weakObject: TestClass?
        }
        
        var service = TestService()
        
        // Then
        XCTAssertNotNil(service.weakObject)
    }
    
    // MARK: - Container Service Tests
    
    func testNetworkingServiceCreation() {
        // When
        let networkingService = container.networkingService
        
        // Then
        XCTAssertNotNil(networkingService)
        XCTAssertNotNil(networkingService.apiClient)
    }
    
    func testAuthenticationServiceCreation() {
        // When
        let authService = container.authenticationService
        
        // Then
        XCTAssertNotNil(authService)
        XCTAssertFalse(authService.isAuthenticated)
    }
    
    func testCacheServiceCreation() {
        // When
        let cacheService = container.cacheService
        
        // Then
        XCTAssertNotNil(cacheService)
        #if DEBUG
        XCTAssertTrue(cacheService is InMemoryCacheService)
        #else
        XCTAssertTrue(cacheService is PersistentCacheService)
        #endif
    }
    
    func testAnalyticsServiceCreation() {
        // When
        let analyticsService = container.analyticsService
        
        // Then
        XCTAssertNotNil(analyticsService)
        #if DEBUG
        XCTAssertTrue(analyticsService is MockAnalyticsService)
        #else
        XCTAssertTrue(analyticsService is ProductionAnalyticsService)
        #endif
    }
    
    // MARK: - ViewModels Factory Tests
    
    func testHomeViewModelCreation() {
        // When
        let viewModel = container.makeHomeViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    func testProjectsViewModelCreation() {
        // When
        let viewModel = container.makeProjectsViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    func testSessionsViewModelCreation() {
        // When
        let viewModel = container.makeSessionsViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    func testChatViewModelCreation() {
        // When
        let viewModel = container.makeChatViewModel(sessionId: "test-session", projectId: "test-project")
        
        // Then
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.sessionId, "test-session")
        XCTAssertEqual(viewModel.projectId, "test-project")
    }
    
    func testSettingsViewModelCreation() {
        // When
        let viewModel = container.makeSettingsViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    func testMCPViewModelCreation() {
        // When
        let viewModel = container.makeMCPViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    func testMonitoringViewModelCreation() {
        // When
        let viewModel = container.makeMonitoringViewModel()
        
        // Then
        XCTAssertNotNil(viewModel)
    }
    
    // MARK: - Mock Injection Tests
    
    func testMockInjection() {
        // Given
        let mockAuth = MockAuthenticationService()
        
        // When
        container.injectMock(AuthenticationServiceProtocol.self, mock: mockAuth)
        let resolved = serviceLocator.resolve(AuthenticationServiceProtocol.self)
        
        // Then
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved is MockAuthenticationService)
    }
    
    func testContainerReset() {
        // Given
        let mockAuth = MockAuthenticationService()
        container.injectMock(AuthenticationServiceProtocol.self, mock: mockAuth)
        
        // When
        container.reset()
        
        // Then
        let authService = container.authenticationService
        XCTAssertNotNil(authService)
        // After reset, should have default services registered
    }
    
    // MARK: - Cache Service Tests
    
    func testInMemoryCacheOperations() async {
        // Given
        let cache = InMemoryCacheService()
        let testObject = TestCodableObject(id: "1", name: "Test")
        
        // When - Cache object
        await cache.cache(testObject, forKey: "test-key")
        
        // Then - Retrieve object
        let retrieved = await cache.retrieve(TestCodableObject.self, forKey: "test-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "1")
        XCTAssertEqual(retrieved?.name, "Test")
        
        // When - Remove object
        await cache.remove(forKey: "test-key")
        
        // Then - Object should be gone
        let removedObject = await cache.retrieve(TestCodableObject.self, forKey: "test-key")
        XCTAssertNil(removedObject)
    }
    
    func testCacheClearAll() async {
        // Given
        let cache = InMemoryCacheService()
        let object1 = TestCodableObject(id: "1", name: "Test1")
        let object2 = TestCodableObject(id: "2", name: "Test2")
        
        await cache.cache(object1, forKey: "key1")
        await cache.cache(object2, forKey: "key2")
        
        // When
        await cache.clearAll()
        
        // Then
        let retrieved1 = await cache.retrieve(TestCodableObject.self, forKey: "key1")
        let retrieved2 = await cache.retrieve(TestCodableObject.self, forKey: "key2")
        XCTAssertNil(retrieved1)
        XCTAssertNil(retrieved2)
    }
    
    // MARK: - Authentication Service Tests
    
    func testAuthenticationFlow() async throws {
        // Given
        let settings = AppSettings()
        let authService = AuthenticationService(settings: settings)
        
        // Initially not authenticated
        XCTAssertFalse(authService.isAuthenticated)
        
        // When - Authenticate
        try await authService.authenticate(apiKey: "test-api-key")
        
        // Then
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertEqual(settings.apiKeyPlaintext, "test-api-key")
        
        // When - Logout
        authService.logout()
        
        // Then
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertEqual(settings.apiKeyPlaintext, "")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentServiceResolution() async {
        // Given
        serviceLocator.register(AppSettings.self) {
            AppSettings()
        }
        
        // When - Concurrent resolution
        await withTaskGroup(of: AppSettings?.self) { group in
            for _ in 0..<100 {
                group.addTask { [weak self] in
                    self?.serviceLocator.resolve(AppSettings.self)
                }
            }
            
            // Then - All resolutions should succeed
            var resolutionCount = 0
            for await result in group {
                if result != nil {
                    resolutionCount += 1
                }
            }
            XCTAssertEqual(resolutionCount, 100)
        }
    }
    
    // MARK: - Performance Tests
    
    func testServiceResolutionPerformance() {
        // Given
        serviceLocator.register(AppSettings.self, instance: AppSettings())
        
        // When & Then
        measure {
            for _ in 0..<1000 {
                _ = serviceLocator.resolve(AppSettings.self)
            }
        }
    }
    
    func testViewModelCreationPerformance() {
        // When & Then
        measure {
            for _ in 0..<100 {
                _ = container.makeHomeViewModel()
            }
        }
    }
}

// MARK: - Test Helpers

private struct TestCodableObject: Codable, Equatable {
    let id: String
    let name: String
}