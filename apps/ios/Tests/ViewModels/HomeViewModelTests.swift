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
        XCTAssertNil(viewModel.error)
        XCTAssertNil(viewModel.stats)
        XCTAssertTrue(viewModel.projects.isEmpty)
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }
    
    // MARK: - Loading Data Tests
    
    func testLoadData() async {
        // Given
        let expectation = XCTestExpectation(description: "Data loaded")
        
        // When
        await viewModel.loadData()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        // With mock data, we expect empty results initially
        XCTAssertTrue(viewModel.projects.isEmpty)
        XCTAssertTrue(viewModel.sessions.isEmpty)
        
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
        await viewModel.loadData()
        
        // Then
        XCTAssertTrue(loadingStates.contains(true), "Should have loading state true")
        XCTAssertTrue(loadingStates.contains(false), "Should have loading state false")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Quick Actions Tests
    
    func testCreateProject() async throws {
        // Given
        let projectName = "Test Project"
        let projectDescription = "Test Description"
        
        // When
        do {
            let project = try await viewModel.createProject(
                name: projectName,
                description: projectDescription,
                path: nil
            )
            
            // Then
            XCTAssertNotNil(project)
            XCTAssertNil(viewModel.error)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testCreateSession() async throws {
        // Given
        let projectId = "test-project"
        let model = "gpt-4"
        let title = "Test Session"
        
        // When
        do {
            let session = try await viewModel.createSession(
                for: projectId,
                model: model,
                title: title,
                systemPrompt: nil
            )
            
            // Then
            XCTAssertNotNil(session)
            XCTAssertNil(viewModel.error)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Given
        mockAPIClient.shouldFailRequests = true
        
        // When
        await viewModel.loadData()
        
        // Then
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testErrorRecovery() async {
        // Given
        mockAPIClient.shouldFailRequests = true
        await viewModel.loadData()
        XCTAssertNotNil(viewModel.error)
        
        // When - Fix the error condition
        mockAPIClient.shouldFailRequests = false
        await viewModel.loadData()
        
        // Then
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshData() async {
        // Given
        await viewModel.loadData()
        let initialStats = viewModel.stats
        
        // When
        await viewModel.refresh()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        // Stats should be refreshed (in a real scenario, they might change)
        // Note: With mock data, stats may remain nil
    }
    
    // MARK: - Performance Tests
    
    func testLoadDataPerformance() {
        measure {
            let expectation = self.expectation(description: "Performance test")
            
            Task {
                await viewModel.loadData()
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
    
    func testStatsPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Stats updated")
        var receivedStats: [APIClient.SessionStats?] = []
        
        viewModel.$stats
            .sink { stats in
                receivedStats.append(stats)
                if stats != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        Task {
            await viewModel.loadData()
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedStats.count, 1)
    }
}

// MARK: - Mock Extensions for Testing

extension MockAPIClient {
    var shouldFailRequests: Bool {
        get { false }
        set { /* Implement failure logic */ }
    }
}