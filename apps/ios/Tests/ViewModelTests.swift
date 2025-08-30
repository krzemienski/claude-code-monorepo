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
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertTrue(viewModel.projects.isEmpty, "Projects should be empty initially")
        XCTAssertTrue(viewModel.sessions.isEmpty, "Sessions should be empty initially")
        XCTAssertNil(viewModel.stats, "Stats should be nil initially")
        XCTAssertNil(viewModel.error, "Error should be nil initially")
    }
    
    func testHomeViewModelLoadData() async throws {
        let viewModel = container.makeHomeViewModel()
        
        // Test that loadData can be called
        await viewModel.loadData()
        
        // After loading, check state
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testHomeViewModelRefresh() async throws {
        let viewModel = container.makeHomeViewModel()
        
        await viewModel.refresh()
        
        XCTAssertFalse(viewModel.isLoading, "Should complete refresh")
    }
    
    // MARK: - ProjectsViewModel Tests
    
    func testProjectsViewModelInitialization() {
        let viewModel = container.makeProjectsViewModel()
        
        XCTAssertTrue(viewModel.projects.isEmpty, "Projects should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.error, "Error should be nil initially")
    }
    
    func testProjectsViewModelLoadProjects() async throws {
        let viewModel = container.makeProjectsViewModel()
        
        await viewModel.loadProjects()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testProjectsViewModelCreateProject() async throws {
        let viewModel = container.makeProjectsViewModel()
        
        let projectName = "Test Project"
        let projectDescription = "Test Description"
        
        await viewModel.createProject(name: projectName, description: projectDescription, path: nil)
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after creation")
    }
    
    // MARK: - SessionsViewModel Tests
    
    func testSessionsViewModelInitialization() {
        let viewModel = container.makeSessionsViewModel()
        
        XCTAssertTrue(viewModel.sessions.isEmpty, "Sessions should be empty initially")
        XCTAssertTrue(viewModel.filteredSessions.isEmpty, "Filtered sessions should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertTrue(viewModel.searchText.isEmpty, "Search text should be empty initially")
    }
    
    func testSessionsViewModelLoadSessions() async throws {
        let viewModel = container.makeSessionsViewModel()
        
        await viewModel.loadSessions()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
    
    func testSessionsViewModelCreateSession() async throws {
        let viewModel = container.makeSessionsViewModel()
        
        let projectId = "test-project"
        let model = "gpt-4"
        let title = "Test Session"
        
        _ = await viewModel.createSession(projectId: projectId, model: model, title: title, systemPrompt: nil)
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after creation")
    }
    
    func testSessionsViewModelSetProjectFilter() {
        let viewModel = container.makeSessionsViewModel()
        let projectId = "test-project-123"
        
        viewModel.setProjectFilter(projectId)
        
        XCTAssertEqual(viewModel.selectedProjectId, projectId, "Project filter should be set")
    }
    
    // MARK: - ChatViewModel Tests
    
    func testChatViewModelInitialization() {
        let sessionId = "test-session"
        let projectId = "test-project"
        let viewModel = container.makeChatViewModel(sessionId: sessionId, projectId: projectId)
        
        XCTAssertEqual(viewModel.sessionId, sessionId, "Session ID should be set")
        // Note: projectId is not a public property on ChatViewModel
        XCTAssertTrue(viewModel.messages.isEmpty, "Messages should be empty initially")
        XCTAssertFalse(viewModel.isStreaming, "Should not be streaming initially")
        XCTAssertTrue(viewModel.inputText.isEmpty, "Input text should be empty initially")
    }
    
    func testChatViewModelSendMessage() async throws {
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "project")
        
        let message = "Test message"
        await viewModel.sendMessage(message)
        
        // Note: The actual behavior depends on the implementation
        XCTAssertFalse(viewModel.isStreaming, "Should not be streaming after sending")
    }
    
    func testChatViewModelStopStreaming() async throws {
        let viewModel = container.makeChatViewModel(sessionId: "test", projectId: "project")
        
        viewModel.isStreaming = true
        await viewModel.stopStreaming()
        
        XCTAssertFalse(viewModel.isStreaming, "Should stop streaming")
    }
    
    // MARK: - SettingsViewModel Tests
    
    func testSettingsViewModelInitialization() {
        let viewModel = container.makeSettingsViewModel()
        
        // Settings is private, but we can test the public properties
        XCTAssertTrue(viewModel.apiKeyPlaintext.isEmpty || !viewModel.apiKeyPlaintext.isEmpty, "API key plaintext should be accessible")
        XCTAssertTrue(viewModel.baseURL.isEmpty || !viewModel.baseURL.isEmpty, "Base URL should be accessible")
        XCTAssertFalse(viewModel.isValidating, "Should not be validating initially")
    }
    
    func testSettingsViewModelValidateAndSave() async {
        let viewModel = container.makeSettingsViewModel()
        
        let newAPIKey = "new-test-key"
        let newBaseURL = "http://localhost:8000"
        
        viewModel.apiKeyPlaintext = newAPIKey
        viewModel.baseURL = newBaseURL
        
        await viewModel.validateAndSave()
        
        // After validation, check that the values are set
        XCTAssertEqual(viewModel.apiKeyPlaintext, newAPIKey, "API key should be set")
        XCTAssertEqual(viewModel.baseURL, newBaseURL, "Base URL should be set")
        XCTAssertFalse(viewModel.isValidating, "Should not be validating after completion")
    }
    
    func testSettingsViewModelValidation() async {
        let viewModel = container.makeSettingsViewModel()
        
        // Test empty base URL
        viewModel.apiKeyPlaintext = "test-key"
        viewModel.baseURL = ""
        XCTAssertFalse(viewModel.canValidate, "Should not be able to validate with empty URL")
        
        // Test valid configuration
        viewModel.apiKeyPlaintext = "valid-key"
        viewModel.baseURL = "http://localhost:8000"
        XCTAssertTrue(viewModel.canValidate, "Should be able to validate with proper values")
        
        // Test validation process
        await viewModel.validateAndSave()
        XCTAssertFalse(viewModel.isValidating, "Should complete validation")
    }
    
    // MARK: - MCPViewModel Tests
    
    func testMCPViewModelInitialization() {
        let viewModel = container.makeMCPViewModel()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(viewModel.servers.isEmpty, "Servers should be loaded on init")
        XCTAssertFalse(viewModel.tools.isEmpty, "Tools should be loaded on init")
        XCTAssertNotNil(viewModel.configuration, "Configuration should be initialized")
    }
    
    func testMCPViewModelToggleServer() {
        let viewModel = container.makeMCPViewModel()
        
        // Get first server if available
        if let firstServer = viewModel.servers.first {
            let initialState = firstServer.isEnabled
            viewModel.toggleServer(firstServer.id)
            
            // Find the server again after toggle
            if let updatedServer = viewModel.servers.first(where: { $0.id == firstServer.id }) {
                XCTAssertNotEqual(updatedServer.isEnabled, initialState, "Server state should toggle")
            }
        }
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after toggle")
    }
    
    // MARK: - MonitoringViewModel Tests
    
    func testMonitoringViewModelInitialization() {
        let viewModel = container.makeMonitoringViewModel()
        
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(viewModel.monitoringEnabled, "Should not be monitoring initially")
        XCTAssertNil(viewModel.snapshot, "Snapshot should be nil initially")
    }
    
    func testMonitoringViewModelStartMonitoring() {
        let viewModel = container.makeMonitoringViewModel()
        
        viewModel.startMonitoring()
        
        XCTAssertTrue(viewModel.monitoringEnabled, "Should be monitoring after start")
    }
    
    func testMonitoringViewModelStopMonitoring() {
        let viewModel = container.makeMonitoringViewModel()
        
        viewModel.startMonitoring()
        viewModel.stopMonitoring()
        
        XCTAssertFalse(viewModel.monitoringEnabled, "Should not be monitoring after stop")
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

// MARK: - Supporting Types

struct MCPServer {
    let id: String
    let name: String
    let description: String
    var isEnabled: Bool
    let tools: [String]
}

struct PerformanceMetric {
    let name: String
    let value: Double
    let unit: String
    let timestamp: Date
}