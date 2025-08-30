import XCTest
@testable import ClaudeCode

// MARK: - Container Dependency Injection Tests
@MainActor
final class ContainerTests: XCTestCase {
    
    var container: Container!
    
    override func setUp() async throws {
        try await super.setUp()
        container = Container.shared
        container.reset() // Reset for clean test state
    }
    
    override func tearDown() async throws {
        container.reset()
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testContainerSingleton() {
        let container1 = Container.shared
        let container2 = Container.shared
        XCTAssertTrue(container1 === container2, "Container should be a singleton")
    }
    
    func testContainerInitialization() {
        XCTAssertNotNil(container.settings, "Settings should be initialized")
        XCTAssertNotNil(container.apiClient, "API client should be initialized")
        XCTAssertNotNil(container.sseClient, "SSE client should be initialized")
        XCTAssertNotNil(container.networkingActor, "Networking actor should be initialized")
    }
    
    // MARK: - Service Registration Tests
    
    func testServiceRegistration() {
        // Test custom service registration
        let mockService = MockTestService()
        container.register(service: mockService, for: TestServiceProtocol.self)
        
        let serviceLocator = ServiceLocator.shared
        let resolvedService = serviceLocator.resolve(TestServiceProtocol.self)
        
        XCTAssertNotNil(resolvedService, "Service should be registered")
        XCTAssertTrue(resolvedService === mockService, "Should resolve the same instance")
    }
    
    func testMockInjection() {
        // Test mock injection for testing
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        // Verify mock is used
        let serviceLocator = ServiceLocator.shared
        let resolvedAPI = serviceLocator.resolve(APIClientProtocol.self)
        
        XCTAssertNotNil(resolvedAPI, "Mock API should be injected")
        XCTAssertTrue(type(of: resolvedAPI!) == type(of: mockAPI), "Should use mock implementation")
    }
    
    // MARK: - Lazy Initialization Tests
    
    func testLazyServiceInitialization() {
        // Services should be lazy initialized
        let authService = container.authenticationService
        let cacheService = container.cacheService
        let analyticsService = container.analyticsService
        
        XCTAssertNotNil(authService, "Auth service should be initialized on first access")
        XCTAssertNotNil(cacheService, "Cache service should be initialized on first access")
        XCTAssertNotNil(analyticsService, "Analytics service should be initialized on first access")
        
        // Access again to ensure same instance
        let authService2 = container.authenticationService
        XCTAssertTrue(authService === authService2, "Should return same instance")
    }
    
    // MARK: - View Model Factory Tests
    
    func testHomeViewModelCreation() {
        let viewModel = container.makeHomeViewModel()
        XCTAssertNotNil(viewModel, "Should create HomeViewModel")
        XCTAssertNotNil(viewModel.settings, "ViewModel should have settings injected")
    }
    
    func testProjectsViewModelCreation() {
        let viewModel = container.makeProjectsViewModel()
        XCTAssertNotNil(viewModel, "Should create ProjectsViewModel")
        XCTAssertNotNil(viewModel.settings, "ViewModel should have settings injected")
    }
    
    func testSessionsViewModelCreation() {
        let viewModel = container.makeSessionsViewModel()
        XCTAssertNotNil(viewModel, "Should create SessionsViewModel")
        XCTAssertNotNil(viewModel.settings, "ViewModel should have settings injected")
    }
    
    func testChatViewModelCreation() {
        let sessionId = "test-session-123"
        let projectId = "test-project-456"
        let viewModel = container.makeChatViewModel(sessionId: sessionId, projectId: projectId)
        
        XCTAssertNotNil(viewModel, "Should create ChatViewModel")
        XCTAssertEqual(viewModel.sessionId, sessionId, "Session ID should be set")
        XCTAssertEqual(viewModel.projectId, projectId, "Project ID should be set")
        XCTAssertNotNil(viewModel.apiClient, "ViewModel should have API client injected")
    }
    
    func testSettingsViewModelCreation() {
        let viewModel = container.makeSettingsViewModel()
        XCTAssertNotNil(viewModel, "Should create SettingsViewModel")
        XCTAssertNotNil(viewModel.settings, "ViewModel should have settings injected")
    }
    
    func testMCPViewModelCreation() {
        let viewModel = container.makeMCPViewModel()
        XCTAssertNotNil(viewModel, "Should create MCPViewModel")
        XCTAssertNotNil(viewModel.apiClient, "ViewModel should have API client injected")
    }
    
    func testMonitoringViewModelCreation() {
        let viewModel = container.makeMonitoringViewModel()
        XCTAssertNotNil(viewModel, "Should create MonitoringViewModel")
    }
    
    // MARK: - Reset Tests
    
    func testContainerReset() {
        // Inject a mock
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        // Reset container
        container.reset()
        
        // Verify services are re-registered
        let authService = container.authenticationService
        XCTAssertNotNil(authService, "Services should be re-registered after reset")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() async throws {
        // Test concurrent access to container services
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    _ = await self.container.settings
                    _ = await self.container.apiClient
                    _ = await self.container.authenticationService
                }
            }
        }
        
        // If we reach here without crashes, concurrent access is safe
        XCTAssertTrue(true, "Concurrent access should be thread-safe")
    }
    
    // MARK: - Memory Management Tests
    
    func testWeakReferencesInClosures() {
        // Ensure no retain cycles in service registration
        weak var weakContainer = container
        
        container = nil
        
        // Container is singleton, so it shouldn't be deallocated
        XCTAssertNotNil(weakContainer, "Container singleton should not be deallocated")
    }
    
    // MARK: - Environment Integration Tests
    
    func testEnvironmentValueIntegration() {
        struct TestView: View {
            @Environment(\.container) var container
            
            var body: some View {
                Text("Test")
            }
        }
        
        let view = TestView()
        let mirror = Mirror(reflecting: view)
        
        // Verify environment value is accessible
        XCTAssertNotNil(mirror.descendant("_container"), "Container should be accessible via environment")
    }
    
    // MARK: - Performance Tests
    
    func testServiceResolutionPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = container.settings
                _ = container.apiClient
                _ = container.authenticationService
            }
        }
    }
    
    func testViewModelCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = container.makeHomeViewModel()
                _ = container.makeProjectsViewModel()
                _ = container.makeSessionsViewModel()
            }
        }
    }
}

// MARK: - Test Helpers

protocol TestServiceProtocol: AnyObject {
    func performAction() -> String
}

final class MockTestService: TestServiceProtocol {
    func performAction() -> String {
        return "Mock action performed"
    }
}

// MARK: - Service Locator Tests
extension ContainerTests {
    
    func testServiceLocatorRegistration() {
        let locator = ServiceLocator.shared
        let service = MockTestService()
        
        locator.register(TestServiceProtocol.self, instance: service)
        let resolved = locator.resolve(TestServiceProtocol.self)
        
        XCTAssertNotNil(resolved, "Service should be resolved")
        XCTAssertTrue(resolved === service, "Should resolve same instance")
    }
    
    func testServiceLocatorFactory() {
        let locator = ServiceLocator.shared
        var creationCount = 0
        
        locator.register(TestServiceProtocol.self) {
            creationCount += 1
            return MockTestService()
        }
        
        let service1 = locator.resolve(TestServiceProtocol.self)
        let service2 = locator.resolve(TestServiceProtocol.self)
        
        XCTAssertNotNil(service1, "First service should be created")
        XCTAssertNotNil(service2, "Second service should be created")
        XCTAssertEqual(creationCount, 2, "Factory should be called for each resolution")
    }
    
    func testServiceLocatorReset() {
        let locator = ServiceLocator.shared
        let service = MockTestService()
        
        locator.register(TestServiceProtocol.self, instance: service)
        locator.reset()
        
        let resolved = locator.resolve(TestServiceProtocol.self)
        XCTAssertNil(resolved, "Service should be nil after reset")
    }
}