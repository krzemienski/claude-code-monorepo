import XCTest
import Combine
@testable import ClaudeCode

// MARK: - View Model Business Logic Tests
@MainActor
final class ViewModelTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    var container: Container!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
        container = Container.shared
        container.reset()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        container.reset()
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - HomeViewModel Tests
    
    func testHomeViewModelInitialization() {
        let viewModel = container.makeHomeViewModel()
        
        XCTAssertNotNil(viewModel.settings, "Settings should be injected")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertTrue(viewModel.projects.isEmpty, "Projects should be empty initially")
        XCTAssertTrue(viewModel.recentSessions.isEmpty, "Recent sessions should be empty initially")
    }
    
    func testHomeViewModelLoadDashboard() async throws {
        let viewModel = container.makeHomeViewModel()
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        // Test loading state
        let expectation = XCTestExpectation(description: "Dashboard loaded")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await viewModel.loadDashboard()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        XCTAssertFalse(viewModel.projects.isEmpty, "Should have loaded projects")
    }
    
    func testHomeViewModelRefresh() async throws {
        let viewModel = container.makeHomeViewModel()
        
        await viewModel.refresh()
        
        XCTAssertFalse(viewModel.isLoading, "Should complete refresh")
    }
    
    // MARK: - ProjectsViewModel Tests
    
    func testProjectsViewModelInitialization() {
        let viewModel = container.makeProjectsViewModel()
        
        XCTAssertNotNil(viewModel.settings, "Settings should be injected")
        XCTAssertTrue(viewModel.projects.isEmpty, "Projects should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.selectedProject, "No project should be selected initially")
    }
    
    func testProjectsViewModelLoadProjects() async throws {
        let viewModel = container.makeProjectsViewModel()
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        await viewModel.loadProjects()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testProjectsViewModelCreateProject() async throws {
        let viewModel = container.makeProjectsViewModel()
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        let projectName = "Test Project"
        let projectDescription = "Test Description"
        
        await viewModel.createProject(name: projectName, description: projectDescription)
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after creation")
    }
    
    func testProjectsViewModelSelectProject() {
        let viewModel = container.makeProjectsViewModel()
        let project = APIClient.Project(
            id: "test-123",
            name: "Test",
            description: "Test Project",
            path: "/test",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        viewModel.selectProject(project)
        
        XCTAssertEqual(viewModel.selectedProject?.id, project.id, "Project should be selected")
    }
    
    // MARK: - SessionsViewModel Tests
    
    func testSessionsViewModelInitialization() {
        let viewModel = container.makeSessionsViewModel()
        
        XCTAssertNotNil(viewModel.settings, "Settings should be injected")
        XCTAssertTrue(viewModel.sessions.isEmpty, "Sessions should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.selectedSession, "No session should be selected initially")
    }
    
    func testSessionsViewModelLoadSessions() async throws {
        let viewModel = container.makeSessionsViewModel()
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        await viewModel.loadSessions()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testSessionsViewModelCreateSession() async throws {
        let viewModel = container.makeSessionsViewModel()
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        let projectId = "test-project"
        let model = "gpt-4"
        let title = "Test Session"
        
        await viewModel.createSession(projectId: projectId, model: model, title: title)
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after creation")
    }
    
    func testSessionsViewModelFilterByProject() {
        let viewModel = container.makeSessionsViewModel()
        let projectId = "test-project-123"
        
        let session1 = APIClient.Session(
            id: "1",
            projectId: projectId,
            title: "Session 1",
            model: "gpt-4",
            systemPrompt: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isActive: true,
            totalTokens: 100,
            totalCost: 0.01,
            messageCount: 5
        )
        
        let session2 = APIClient.Session(
            id: "2",
            projectId: "other-project",
            title: "Session 2",
            model: "gpt-4",
            systemPrompt: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isActive: false,
            totalTokens: 200,
            totalCost: 0.02,
            messageCount: 10
        )
        
        viewModel.sessions = [session1, session2]
        viewModel.filterByProject(projectId)
        
        XCTAssertEqual(viewModel.filteredSessions.count, 1, "Should filter by project")
        XCTAssertEqual(viewModel.filteredSessions.first?.id, session1.id, "Should contain correct session")
    }
    
    // MARK: - ChatViewModel Tests
    
    func testChatViewModelInitialization() {
        let sessionId = "test-session"
        let projectId = "test-project"
        let viewModel = container.makeChatViewModel(sessionId: sessionId, projectId: projectId)
        
        XCTAssertEqual(viewModel.sessionId, sessionId, "Session ID should be set")
        XCTAssertEqual(viewModel.projectId, projectId, "Project ID should be set")
        XCTAssertNotNil(viewModel.apiClient, "API client should be injected")
        XCTAssertTrue(viewModel.messages.isEmpty, "Messages should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
    }
    
    func testChatViewModelSendMessage() async throws {
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "project")
        let mockAPI = MockAPIClient()
        container.injectMock(APIClientProtocol.self, mock: mockAPI)
        
        let message = "Test message"
        viewModel.inputText = message
        
        await viewModel.sendMessage()
        
        XCTAssertTrue(viewModel.inputText.isEmpty, "Input should be cleared after sending")
        XCTAssertFalse(viewModel.messages.isEmpty, "Should have added message")
        XCTAssertEqual(viewModel.messages.first?.content, message, "Message content should match")
    }
    
    func testChatViewModelStreamingResponse() async throws {
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "project")
        
        // Test streaming state management
        XCTAssertFalse(viewModel.isStreaming, "Should not be streaming initially")
        
        viewModel.isStreaming = true
        XCTAssertTrue(viewModel.isStreaming, "Should be streaming when set")
        
        viewModel.stopStreaming()
        XCTAssertFalse(viewModel.isStreaming, "Should stop streaming")
    }
    
    // MARK: - SettingsViewModel Tests
    
    func testSettingsViewModelInitialization() {
        let viewModel = container.makeSettingsViewModel()
        
        XCTAssertNotNil(viewModel.settings, "Settings should be injected")
        XCTAssertFalse(viewModel.apiKey.isEmpty, "API key should have default value")
        XCTAssertFalse(viewModel.baseURL.isEmpty, "Base URL should have default value")
    }
    
    func testSettingsViewModelSaveSettings() {
        let viewModel = container.makeSettingsViewModel()
        
        let newAPIKey = "new-test-key"
        let newBaseURL = "https://new.api.com"
        
        viewModel.apiKey = newAPIKey
        viewModel.baseURL = newBaseURL
        
        viewModel.saveSettings()
        
        XCTAssertEqual(viewModel.settings.apiKey, newAPIKey, "API key should be saved")
        XCTAssertEqual(viewModel.settings.baseURL, newBaseURL, "Base URL should be saved")
    }
    
    func testSettingsViewModelValidation() {
        let viewModel = container.makeSettingsViewModel()
        
        // Test empty API key
        viewModel.apiKey = ""
        XCTAssertFalse(viewModel.isValidConfiguration, "Should be invalid with empty API key")
        
        // Test valid configuration
        viewModel.apiKey = "valid-key"
        viewModel.baseURL = "https://api.example.com"
        XCTAssertTrue(viewModel.isValidConfiguration, "Should be valid with proper values")
        
        // Test invalid URL
        viewModel.baseURL = "not-a-url"
        XCTAssertFalse(viewModel.isValidConfiguration, "Should be invalid with bad URL")
    }
    
    // MARK: - MCPViewModel Tests
    
    func testMCPViewModelInitialization() {
        let viewModel = container.makeMCPViewModel()
        
        XCTAssertNotNil(viewModel.apiClient, "API client should be injected")
        XCTAssertTrue(viewModel.servers.isEmpty, "Servers should be empty initially")
        XCTAssertTrue(viewModel.availableTools.isEmpty, "Tools should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
    }
    
    func testMCPViewModelLoadServers() async throws {
        let viewModel = container.makeMCPViewModel()
        
        await viewModel.loadServers()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testMCPViewModelToggleServer() {
        let viewModel = container.makeMCPViewModel()
        
        let server = MCPServer(
            id: "test-server",
            name: "Test Server",
            description: "Test MCP Server",
            isEnabled: false,
            tools: []
        )
        
        viewModel.servers = [server]
        viewModel.toggleServer(server)
        
        XCTAssertTrue(viewModel.servers.first?.isEnabled ?? false, "Server should be toggled")
    }
    
    // MARK: - MonitoringViewModel Tests
    
    func testMonitoringViewModelInitialization() {
        let viewModel = container.makeMonitoringViewModel()
        
        XCTAssertTrue(viewModel.metrics.isEmpty, "Metrics should be empty initially")
        XCTAssertTrue(viewModel.logs.isEmpty, "Logs should be empty initially")
        XCTAssertFalse(viewModel.isMonitoring, "Should not be monitoring initially")
    }
    
    func testMonitoringViewModelStartMonitoring() {
        let viewModel = container.makeMonitoringViewModel()
        
        viewModel.startMonitoring()
        
        XCTAssertTrue(viewModel.isMonitoring, "Should be monitoring after start")
    }
    
    func testMonitoringViewModelStopMonitoring() {
        let viewModel = container.makeMonitoringViewModel()
        
        viewModel.startMonitoring()
        viewModel.stopMonitoring()
        
        XCTAssertFalse(viewModel.isMonitoring, "Should not be monitoring after stop")
    }
    
    func testMonitoringViewModelAddMetric() {
        let viewModel = container.makeMonitoringViewModel()
        
        let metric = PerformanceMetric(
            name: "API Response",
            value: 250.0,
            unit: "ms",
            timestamp: Date()
        )
        
        viewModel.addMetric(metric)
        
        XCTAssertEqual(viewModel.metrics.count, 1, "Should have added metric")
        XCTAssertEqual(viewModel.metrics.first?.name, metric.name, "Metric should match")
    }
    
    // MARK: - Performance Tests
    
    func testViewModelCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = container.makeHomeViewModel()
                _ = container.makeProjectsViewModel()
                _ = container.makeSessionsViewModel()
                _ = container.makeSettingsViewModel()
            }
        }
    }
    
    func testViewModelStateUpdatePerformance() {
        let viewModel = container.makeSettingsViewModel()
        
        measure {
            for i in 0..<1000 {
                viewModel.apiKey = "key-\(i)"
                viewModel.saveSettings()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testViewModelMemoryManagement() {
        weak var weakViewModel: HomeViewModel?
        
        autoreleasepool {
            let viewModel = container.makeHomeViewModel()
            weakViewModel = viewModel
            XCTAssertNotNil(weakViewModel, "ViewModel should exist in scope")
        }
        
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated")
    }
    
    func testCancellableCleanup() {
        let viewModel = container.makeHomeViewModel()
        var cancellables = Set<AnyCancellable>()
        
        viewModel.$isLoading
            .sink { _ in }
            .store(in: &cancellables)
        
        XCTAssertEqual(cancellables.count, 1, "Should have one subscription")
        
        cancellables.removeAll()
        XCTAssertEqual(cancellables.count, 0, "Should cleanup subscriptions")
    }
}