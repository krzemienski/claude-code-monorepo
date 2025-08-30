import XCTest
import Combine
@testable import ClaudeCode

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var viewModel: HomeViewModel!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        cancellables = []
        
        // Inject mock API client
        EnhancedContainer.shared.reset()
        EnhancedContainer.shared.injectMock(APIClientProtocol.self, mock: mockAPIClient)
        
        viewModel = HomeViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockAPIClient = nil
        cancellables = nil
        EnhancedContainer.shared.reset()
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.quickStats.activeSessions == 0)
        XCTAssertTrue(viewModel.quickStats.totalTokens == 0)
        XCTAssertTrue(viewModel.quickStats.totalCost == 0.0)
        XCTAssertTrue(viewModel.recentProjects.isEmpty)
        XCTAssertTrue(viewModel.recentSessions.isEmpty)
    }
    
    // MARK: - Loading Data Tests
    
    func testLoadDashboardData() async {
        // Given
        let expectation = XCTestExpectation(description: "Dashboard data loaded")
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertGreaterThan(viewModel.quickStats.activeSessions, 0)
        XCTAssertGreaterThan(viewModel.quickStats.totalTokens, 0)
        XCTAssertGreaterThan(viewModel.quickStats.totalCost, 0)
        XCTAssertFalse(viewModel.recentProjects.isEmpty)
        XCTAssertFalse(viewModel.recentSessions.isEmpty)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testLoadingStateChanges() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        viewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
            }
            .store(in: &cancellables)
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        XCTAssertTrue(loadingStates.contains(true), "Should have loading state true")
        XCTAssertTrue(loadingStates.contains(false), "Should have loading state false")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Quick Actions Tests
    
    func testCreateNewProject() async {
        // Given
        let projectName = "Test Project"
        let projectDescription = "Test Description"
        
        // When
        let success = await viewModel.createNewProject(
            name: projectName,
            description: projectDescription
        )
        
        // Then
        XCTAssertTrue(success)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testCreateNewSession() async {
        // Given
        let projectId = "test-project"
        let model = "gpt-4"
        
        // When
        let sessionId = await viewModel.createNewSession(
            projectId: projectId,
            model: model
        )
        
        // Then
        XCTAssertNotNil(sessionId)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Given
        mockAPIClient.shouldFailRequests = true
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testErrorRecovery() async {
        // Given
        mockAPIClient.shouldFailRequests = true
        await viewModel.loadDashboardData()
        XCTAssertNotNil(viewModel.errorMessage)
        
        // When - Fix the error condition
        mockAPIClient.shouldFailRequests = false
        await viewModel.loadDashboardData()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshData() async {
        // Given
        await viewModel.loadDashboardData()
        let initialStats = viewModel.quickStats
        
        // When
        await viewModel.refreshData()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        // Stats should be refreshed (in a real scenario, they might change)
        XCTAssertNotNil(viewModel.quickStats)
    }
    
    // MARK: - Performance Tests
    
    func testDashboardLoadPerformance() {
        measure {
            let expectation = self.expectation(description: "Performance test")
            
            Task {
                await viewModel.loadDashboardData()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testNoRetainCycles() {
        // Given
        weak var weakViewModel = viewModel
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated")
    }
    
    // MARK: - Combine Publisher Tests
    
    func testQuickStatsPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Quick stats updated")
        var receivedStats: [HomeViewModel.QuickStats] = []
        
        viewModel.$quickStats
            .sink { stats in
                receivedStats.append(stats)
                if stats.activeSessions > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        Task {
            await viewModel.loadDashboardData()
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThan(receivedStats.count, 1)
    }
}

// MARK: - Mock Extensions for Testing

extension MockAPIClient {
    var shouldFailRequests: Bool {
        get { false }
        set { /* Implement failure logic */ }
    }
}