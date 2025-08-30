import XCTest
import Combine
@testable import ClaudeCode

@MainActor
final class APIIntegrationTests: XCTestCase {
    
    var apiClient: EnhancedAPIClient!
    var mockURLSession: URLSessionMock!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockURLSession = URLSessionMock()
        cancellables = []
        
        let settings = AppSettings()
        settings.apiKeyPlaintext = "test-api-key"
        settings.backendURL = "http://localhost:8000"
        
        apiClient = EnhancedAPIClient(
            settings: settings,
            retryPolicy: .default,
            urlSession: mockURLSession
        )
    }
    
    override func tearDown() async throws {
        apiClient = nil
        mockURLSession = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Health Check Tests
    
    func testHealthEndpoint() async throws {
        // Given
        let expectedResponse = """
        {
            "ok": true,
            "version": "1.0.0",
            "active_sessions": 5
        }
        """.data(using: .utf8)!
        
        mockURLSession.data = expectedResponse
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let health = try await apiClient.health()
        
        // Then
        XCTAssertTrue(health.ok)
        XCTAssertEqual(health.version, "1.0.0")
        XCTAssertEqual(health.active_sessions, 5)
    }
    
    func testHealthEndpointFailure() async {
        // Given
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        // When & Then
        do {
            _ = try await apiClient.health()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Projects API Tests
    
    func testListProjects() async throws {
        // Given
        let expectedResponse = """
        [
            {
                "id": "proj-1",
                "name": "Project 1",
                "description": "First project",
                "path": "/path/to/project1",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": "proj-2",
                "name": "Project 2",
                "description": "Second project",
                "path": "/path/to/project2",
                "created_at": "2024-01-02T00:00:00Z",
                "updated_at": "2024-01-02T00:00:00Z"
            }
        ]
        """.data(using: .utf8)!
        
        mockURLSession.data = expectedResponse
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/projects")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let projects = try await apiClient.listProjects()
        
        // Then
        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects[0].id, "proj-1")
        XCTAssertEqual(projects[0].name, "Project 1")
        XCTAssertEqual(projects[1].id, "proj-2")
        XCTAssertEqual(projects[1].name, "Project 2")
    }
    
    func testCreateProject() async throws {
        // Given
        let expectedResponse = """
        {
            "id": "new-proj",
            "name": "New Project",
            "description": "A new project",
            "path": "/new/path",
            "created_at": "2024-01-03T00:00:00Z",
            "updated_at": "2024-01-03T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        mockURLSession.data = expectedResponse
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/projects")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let project = try await apiClient.createProject(
            name: "New Project",
            description: "A new project",
            path: "/new/path"
        )
        
        // Then
        XCTAssertEqual(project.id, "new-proj")
        XCTAssertEqual(project.name, "New Project")
        XCTAssertEqual(project.description, "A new project")
    }
    
    // MARK: - Sessions API Tests
    
    func testListSessions() async throws {
        // Given
        let expectedResponse = """
        [
            {
                "id": "session-1",
                "project_id": "proj-1",
                "title": "Chat Session 1",
                "model": "gpt-4",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z",
                "is_active": true,
                "total_tokens": 1500,
                "total_cost": 0.05,
                "message_count": 10
            }
        ]
        """.data(using: .utf8)!
        
        mockURLSession.data = expectedResponse
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/sessions")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let sessions = try await apiClient.listSessions(projectId: "proj-1")
        
        // Then
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "session-1")
        XCTAssertEqual(sessions[0].projectId, "proj-1")
        XCTAssertTrue(sessions[0].isActive)
        XCTAssertEqual(sessions[0].totalTokens, 1500)
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticationHeaders() async throws {
        // Given
        let expectedResponse = """
        {"ok": true, "version": "1.0.0", "active_sessions": 0}
        """.data(using: .utf8)!
        
        mockURLSession.data = expectedResponse
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        _ = try await apiClient.health()
        
        // Then
        XCTAssertNotNil(mockURLSession.lastRequest)
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-api-key"
        )
    }
    
    // MARK: - Retry Policy Tests
    
    func testRetryOnTemporaryFailure() async throws {
        // Given
        var attemptCount = 0
        mockURLSession.requestHandler = { _ in
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.timedOut)
            }
            return (
                """
                {"ok": true, "version": "1.0.0", "active_sessions": 0}
                """.data(using: .utf8)!,
                HTTPURLResponse(
                    url: URL(string: "http://localhost:8000/health")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
        
        // When
        let health = try await apiClient.health()
        
        // Then
        XCTAssertTrue(health.ok)
        XCTAssertEqual(attemptCount, 3, "Should retry twice before succeeding")
    }
    
    // MARK: - Cancellation Tests
    
    func testRequestCancellation() async {
        // Given
        let expectation = XCTestExpectation(description: "Request cancelled")
        
        mockURLSession.requestHandler = { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            throw URLError(.cancelled)
        }
        
        // When
        let task = Task {
            do {
                _ = try await apiClient.health()
                XCTFail("Should have been cancelled")
            } catch {
                if error is CancellationError {
                    expectation.fulfill()
                }
            }
        }
        
        // Cancel after short delay
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            task.cancel()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testAPIPerformance() {
        measure {
            let expectation = self.expectation(description: "Performance test")
            
            Task {
                mockURLSession.data = """
                {"ok": true, "version": "1.0.0", "active_sessions": 0}
                """.data(using: .utf8)!
                
                mockURLSession.response = HTTPURLResponse(
                    url: URL(string: "http://localhost:8000/health")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
                
                _ = try? await apiClient.health()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Enhanced URLSession Mock
// Note: URLSessionMock properties are defined in TestHelpers/URLSessionMock.swift