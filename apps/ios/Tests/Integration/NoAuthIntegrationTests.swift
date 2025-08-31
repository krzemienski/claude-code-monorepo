import XCTest
import Combine
@testable import ClaudeCode

/// Comprehensive integration tests for no-auth implementation
@MainActor
final class NoAuthIntegrationTests: XCTestCase {
    
    var apiClient: EnhancedAPIClient!
    var sseClient: SSEClient!
    var mockURLSession: URLSessionMock!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockURLSession = URLSessionMock()
        cancellables = []
        
        let settings = AppSettings()
        settings.backendURL = "http://localhost:8000"
        
        apiClient = EnhancedAPIClient(
            settings: settings,
            retryPolicy: .default,
            urlSession: mockURLSession
        )
        
        sseClient = SSEClient()
    }
    
    override func tearDown() async throws {
        apiClient = nil
        sseClient = nil
        mockURLSession = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - No Authentication Header Tests
    
    func testAllEndpointsHaveNoAuthHeaders() async throws {
        // Test endpoints that should work without authentication
        let endpoints = [
            ("/health", "GET"),
            ("/v1/projects", "GET"),
            ("/v1/sessions", "GET"),
            ("/v1/models/capabilities", "GET"),
            ("/v1/sessions/stats", "GET"),
            ("/v1/user/profile", "GET")
        ]
        
        for (path, method) in endpoints {
            mockURLSession.reset()
            mockURLSession.data = """
                {"ok": true, "data": []}
                """.data(using: .utf8)!
            
            mockURLSession.response = HTTPURLResponse(
                url: URL(string: "http://localhost:8000\(path)")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            
            // Make request based on endpoint
            switch path {
            case "/health":
                _ = try? await apiClient.health()
            case "/v1/projects":
                _ = try? await apiClient.listProjects()
            case "/v1/sessions":
                _ = try? await apiClient.listSessions()
            case "/v1/models/capabilities":
                _ = try? await apiClient.modelCapabilities()
            case "/v1/sessions/stats":
                _ = try? await apiClient.sessionStats()
            case "/v1/user/profile":
                _ = try? await apiClient.getUserProfile()
            default:
                break
            }
            
            // Verify no auth headers
            XCTAssertNotNil(mockURLSession.lastRequest, "Request should be made for \(path)")
            XCTAssertNil(
                mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "\(path) should not have Authorization header"
            )
            XCTAssertNil(
                mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"),
                "\(path) should not have X-API-Key header"
            )
            XCTAssertNil(
                mockURLSession.lastRequest?.value(forHTTPHeaderField: "Bearer"),
                "\(path) should not have Bearer token"
            )
        }
    }
    
    // MARK: - SSE/WebSocket Connection Tests
    
    func testSSEConnectionWithoutAuth() async throws {
        let expectation = XCTestExpectation(description: "SSE connects without auth")
        
        // Configure SSE client
        sseClient.onMessage = { message in
            XCTAssertFalse(message.isEmpty, "Should receive messages")
            expectation.fulfill()
        }
        
        sseClient.onError = { error in
            XCTFail("SSE should not error: \(error)")
        }
        
        // Connect without auth headers
        let url = URL(string: "http://localhost:8000/v1/sessions/test-session/stream")!
        sseClient.connect(url: url, headers: [:]) // Empty headers - no auth
        
        // Simulate SSE data
        let sseData = "data: {\"content\": \"Hello from SSE\"}\n\n".data(using: .utf8)!
        sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: sseData)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testSSEStreamingWithoutAuth() async throws {
        let expectation = XCTestExpectation(description: "SSE streams messages")
        var messageCount = 0
        
        sseClient.onMessage = { message in
            messageCount += 1
            if messageCount >= 3 {
                expectation.fulfill()
            }
        }
        
        // Stream multiple messages
        let messages = [
            "data: {\"content\": \"Message 1\"}\n\n",
            "data: {\"content\": \"Message 2\"}\n\n",
            "data: {\"content\": \"Message 3\"}\n\n"
        ]
        
        for message in messages {
            if let data = message.data(using: .utf8) {
                sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: data)
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(messageCount, 3, "Should receive all messages")
    }
    
    // MARK: - Project Management Tests
    
    func testProjectCRUDWithoutAuth() async throws {
        // Create project
        mockURLSession.data = """
        {
            "id": "proj-123",
            "name": "Test Project",
            "description": "Test Description",
            "path": "/test/path",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/projects")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        let project = try await apiClient.createProject(
            name: "Test Project",
            description: "Test Description",
            path: "/test/path"
        )
        
        XCTAssertEqual(project.id, "proj-123")
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        
        // List projects
        mockURLSession.reset()
        mockURLSession.data = """
        [{
            "id": "proj-123",
            "name": "Test Project",
            "description": "Test Description",
            "path": "/test/path",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }]
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/projects")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let projects = try await apiClient.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }
    
    // MARK: - Session Management Tests
    
    func testSessionCRUDWithoutAuth() async throws {
        // Create session
        mockURLSession.data = """
        {
            "id": "session-123",
            "project_id": "proj-123",
            "title": "Test Session",
            "model": "gpt-4",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "is_active": true,
            "total_tokens": 0,
            "total_cost": 0.0,
            "message_count": 0
        }
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/sessions")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        let session = try await apiClient.createSession(
            projectId: "proj-123",
            model: "gpt-4",
            title: "Test Session",
            systemPrompt: nil
        )
        
        XCTAssertEqual(session.id, "session-123")
        XCTAssertTrue(session.isActive)
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        
        // List sessions
        mockURLSession.reset()
        mockURLSession.data = """
        [{
            "id": "session-123",
            "project_id": "proj-123",
            "title": "Test Session",
            "model": "gpt-4",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "is_active": true,
            "total_tokens": 100,
            "total_cost": 0.01,
            "message_count": 5
        }]
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/sessions?project_id=proj-123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let sessions = try await apiClient.listSessions(projectId: "proj-123")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].totalTokens, 100)
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }
    
    // MARK: - Message Management Tests
    
    func testMessageOperationsWithoutAuth() async throws {
        // Get session messages
        mockURLSession.data = """
        {
            "messages": [
                {
                    "id": "msg-1",
                    "session_id": "session-123",
                    "role": "user",
                    "content": "Hello",
                    "token_count": 10,
                    "created_at": "2024-01-01T00:00:00Z"
                },
                {
                    "id": "msg-2",
                    "session_id": "session-123",
                    "role": "assistant",
                    "content": "Hi there!",
                    "token_count": 15,
                    "created_at": "2024-01-01T00:01:00Z"
                }
            ],
            "total": 2,
            "limit": 100,
            "offset": 0,
            "session_id": "session-123"
        }
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/sessions/session-123/messages")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let messageResponse = try await apiClient.getSessionMessages(sessionId: "session-123")
        XCTAssertEqual(messageResponse.messages.count, 2)
        XCTAssertEqual(messageResponse.messages[0].role, "user")
        XCTAssertEqual(messageResponse.messages[1].role, "assistant")
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }
    
    // MARK: - User Profile Tests (Mock/Default)
    
    func testUserProfileWithoutAuth() async throws {
        // Get default/mock user profile
        mockURLSession.data = """
        {
            "id": "default-user",
            "email": "user@localhost",
            "username": "Local User",
            "roles": ["user"],
            "permissions": ["read", "write"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "is_active": true,
            "session_count": 10,
            "message_count": 100,
            "token_usage": {"gpt-4": 1000, "gpt-3.5": 5000}
        }
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/user/profile")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let profile = try await apiClient.getUserProfile()
        XCTAssertEqual(profile.id, "default-user")
        XCTAssertEqual(profile.email, "user@localhost")
        XCTAssertTrue(profile.isActive)
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingWithoutAuth() async throws {
        // Test 404 error
        mockURLSession.error = nil
        mockURLSession.data = """
        {"error": "Not found"}
        """.data(using: .utf8)!
        
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "http://localhost:8000/v1/projects/nonexistent")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await apiClient.getProject(id: "nonexistent")
            XCTFail("Should throw error for 404")
        } catch {
            XCTAssertNotNil(error)
            // Verify no auth headers were sent even on error
            XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        }
        
        // Test network error
        mockURLSession.reset()
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        do {
            _ = try await apiClient.health()
            XCTFail("Should throw network error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithoutAuth() {
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
                
                // Make 100 requests
                for _ in 0..<100 {
                    _ = try? await apiClient.health()
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - URLSession Mock Extension
extension NoAuthIntegrationTests {
    class URLSessionMock: URLSession {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        var lastRequest: URLRequest?
        var requestHandler: ((URLRequest) async throws -> (Data, URLResponse))?
        
        override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            lastRequest = request
            
            if let handler = requestHandler {
                return try await handler(request)
            }
            
            if let error = error {
                throw error
            }
            
            guard let data = data, let response = response else {
                throw URLError(.badServerResponse)
            }
            
            return (data, response)
        }
        
        func reset() {
            data = nil
            response = nil
            error = nil
            lastRequest = nil
            requestHandler = nil
        }
    }
}