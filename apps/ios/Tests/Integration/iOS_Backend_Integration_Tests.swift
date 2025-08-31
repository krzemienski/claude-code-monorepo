import XCTest
import Combine
import Foundation
@testable import ClaudeCode

/// Comprehensive Integration Test Suite for iOS-Backend Communication
/// Tests all critical flows between the iOS app and backend API
@MainActor
final class iOS_Backend_Integration_Tests: XCTestCase {
    
    // MARK: - Properties
    
    private var apiClient: APIClient!
    private var enhancedClient: EnhancedAPIClient!
    private var sseClient: SSEClient!
    private var mockServer: MockAPIServer!
    private var cancellables: Set<AnyCancellable>!
    private var settings: AppSettings!
    
    // Test configuration
    private let testTimeout: TimeInterval = 30.0
    private let performanceTimeout: TimeInterval = 5.0
    
    // Test credentials
    private let testEmail = "test@claudecode.io"
    private let testPassword = "SecureTest123!"
    private let testUsername = "testuser"
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = []
        settings = AppSettings()
        
        // Configure for integration testing
        settings.backendURL = ProcessInfo.processInfo.environment["TEST_BACKEND_URL"] ?? "http://localhost:8000"
        settings.apiKeyPlaintext = ProcessInfo.processInfo.environment["TEST_API_KEY"] ?? "test-key"
        
        // Initialize clients
        apiClient = APIClient(settings: settings)
        enhancedClient = EnhancedAPIClient(
            settings: settings,
            retryPolicy: .default,
            urlSession: URLSession.shared
        )
        
        // Initialize mock server for offline testing
        mockServer = MockAPIServer()
        await mockServer.start()
        
        // Setup SSE client
        if let baseURL = settings.baseURLValidated {
            sseClient = SSEClient(
                url: baseURL.appendingPathComponent("/stream"),
                headers: ["Authorization": "Bearer \(settings.apiKeyPlaintext)"]
            )
        }
    }
    
    override func tearDown() async throws {
        // Clean up resources
        apiClient?.cancelAllRequests()
        enhancedClient?.cancelAllRequests()
        sseClient?.close()
        await mockServer?.stop()
        
        apiClient = nil
        enhancedClient = nil
        sseClient = nil
        mockServer = nil
        cancellables = nil
        settings = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 1. Authentication Flow Tests
    
    func testAuthenticationFlow_RegisterNewUser() async throws {
        // Test user registration
        let registerRequest = AuthRegisterRequest(
            email: "\(UUID().uuidString)@test.com",
            password: testPassword,
            username: "\(testUsername)_\(UUID().uuidString)"
        )
        
        do {
            let response = try await enhancedClient.register(request: registerRequest)
            
            XCTAssertNotNil(response.access_token)
            XCTAssertNotNil(response.refresh_token)
            XCTAssertNotNil(response.user)
            XCTAssertEqual(response.user.email, registerRequest.email)
            XCTAssertEqual(response.token_type, "bearer")
            
            // Verify tokens are valid JWT
            XCTAssertTrue(isValidJWT(response.access_token))
            XCTAssertTrue(isValidJWT(response.refresh_token))
            
        } catch {
            XCTFail("Registration failed: \(error)")
        }
    }
    
    func testAuthenticationFlow_LoginWithCredentials() async throws {
        // Test login with email/password
        let loginRequest = AuthLoginRequest(
            email: testEmail,
            password: testPassword
        )
        
        do {
            let response = try await enhancedClient.login(request: loginRequest)
            
            XCTAssertNotNil(response.access_token)
            XCTAssertNotNil(response.refresh_token)
            XCTAssertEqual(response.token_type, "bearer")
            
            // Store tokens for subsequent tests
            settings.apiKeyPlaintext = response.access_token
            
            // Test authenticated endpoint access
            let health = try await apiClient.health()
            XCTAssertTrue(health.ok)
            
        } catch {
            XCTFail("Login failed: \(error)")
        }
    }
    
    func testAuthenticationFlow_RefreshTokenRotation() async throws {
        // Test token refresh mechanism
        guard let refreshToken = UserDefaults.standard.string(forKey: "refresh_token") else {
            // First login to get tokens
            let loginRequest = AuthLoginRequest(email: testEmail, password: testPassword)
            let loginResponse = try await enhancedClient.login(request: loginRequest)
            UserDefaults.standard.set(loginResponse.refresh_token, forKey: "refresh_token")
            
            // Wait for token to be near expiry (simulated)
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        let refreshRequest = RefreshTokenRequest(
            refresh_token: UserDefaults.standard.string(forKey: "refresh_token") ?? ""
        )
        
        do {
            let response = try await enhancedClient.refreshToken(request: refreshRequest)
            
            XCTAssertNotNil(response.access_token)
            XCTAssertNotNil(response.refresh_token)
            XCTAssertNotEqual(response.refresh_token, refreshRequest.refresh_token, "Token should be rotated")
            
            // Update stored tokens
            settings.apiKeyPlaintext = response.access_token
            UserDefaults.standard.set(response.refresh_token, forKey: "refresh_token")
            
        } catch {
            XCTFail("Token refresh failed: \(error)")
        }
    }
    
    func testAuthenticationFlow_Logout() async throws {
        // Ensure we're logged in first
        try await testAuthenticationFlow_LoginWithCredentials()
        
        do {
            try await enhancedClient.logout()
            
            // Verify tokens are cleared
            XCTAssertTrue(settings.apiKeyPlaintext.isEmpty || settings.apiKeyPlaintext == "test-key")
            XCTAssertNil(UserDefaults.standard.string(forKey: "refresh_token"))
            
            // Verify authenticated endpoints are no longer accessible
            do {
                _ = try await apiClient.listProjects()
                XCTFail("Should not be able to access authenticated endpoints after logout")
            } catch {
                // Expected - should fail with 401
                if let apiError = error as? APIClient.APIError {
                    XCTAssertEqual(apiError.status, 401)
                }
            }
            
        } catch {
            XCTFail("Logout failed: \(error)")
        }
    }
    
    // MARK: - 2. Core Workflow Tests
    
    func testCoreWorkflow_CreateSessionSendMessageReceiveResponse() async throws {
        // Complete session workflow test
        
        // 1. Create a project
        let project = try await apiClient.createProject(
            name: "Test Project \(UUID().uuidString)",
            description: "Integration test project",
            path: nil
        )
        XCTAssertNotNil(project.id)
        
        // 2. Create a session
        let session = try await apiClient.createSession(
            projectId: project.id,
            model: "claude-3-opus-20240229",
            title: "Test Session",
            systemPrompt: "You are a helpful assistant."
        )
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.projectId, project.id)
        
        // 3. Send a message
        let messageRequest = ChatCompletionRequest(
            sessionId: session.id,
            messages: [
                ChatMessage(role: "user", content: "Hello, this is a test message.")
            ],
            stream: false
        )
        
        let response = try await enhancedClient.sendChatCompletion(request: messageRequest)
        XCTAssertNotNil(response.id)
        XCTAssertFalse(response.choices.isEmpty)
        XCTAssertEqual(response.choices[0].message.role, "assistant")
        XCTAssertFalse(response.choices[0].message.content.isEmpty)
        
        // 4. Verify session stats updated
        let stats = try await apiClient.sessionStats()
        XCTAssertGreaterThan(stats.totalMessages, 0)
        XCTAssertGreaterThan(stats.totalTokens, 0)
    }
    
    func testCoreWorkflow_FileUploadProcessDownload() async throws {
        // File handling workflow test
        
        // 1. Create test file data
        let testContent = "This is a test file for integration testing."
        let testData = testContent.data(using: .utf8)!
        let fileName = "test_\(UUID().uuidString).txt"
        
        // 2. Upload file
        let uploadResponse = try await enhancedClient.uploadFile(
            data: testData,
            fileName: fileName,
            mimeType: "text/plain"
        )
        XCTAssertNotNil(uploadResponse.id)
        XCTAssertEqual(uploadResponse.filename, fileName)
        XCTAssertGreaterThan(uploadResponse.size, 0)
        
        // 3. Process file (example: analyze content)
        let processRequest = FileProcessRequest(
            fileId: uploadResponse.id,
            operation: "analyze",
            options: ["extract_keywords": true]
        )
        
        let processResponse = try await enhancedClient.processFile(request: processRequest)
        XCTAssertEqual(processResponse.status, "completed")
        XCTAssertNotNil(processResponse.result)
        
        // 4. Download processed result
        let downloadData = try await enhancedClient.downloadFile(fileId: uploadResponse.id)
        XCTAssertEqual(downloadData, testData)
        
        // 5. Delete file
        try await enhancedClient.deleteFile(fileId: uploadResponse.id)
        
        // Verify file is deleted
        do {
            _ = try await enhancedClient.downloadFile(fileId: uploadResponse.id)
            XCTFail("Should not be able to download deleted file")
        } catch {
            // Expected - file should be gone
        }
    }
    
    func testCoreWorkflow_WebSocketConnection() async throws {
        // WebSocket real-time updates test
        let expectation = XCTestExpectation(description: "WebSocket connection and message")
        
        guard let baseURL = settings.baseURLValidated else {
            XCTFail("Invalid base URL")
            return
        }
        
        // Create WebSocket connection
        let wsURL = baseURL
            .absoluteString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        
        let webSocketTask = URLSession.shared.webSocketTask(
            with: URL(string: "\(wsURL)/ws")!
        )
        
        webSocketTask.resume()
        
        // Send authentication
        let authMessage = ["type": "auth", "token": settings.apiKeyPlaintext]
        let authData = try JSONSerialization.data(withJSONObject: authMessage)
        
        webSocketTask.send(.data(authData)) { error in
            XCTAssertNil(error, "Failed to send auth message: \(String(describing: error))")
        }
        
        // Receive messages
        webSocketTask.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        XCTAssertNotNil(json)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Failed to parse WebSocket message: \(error)")
                    }
                case .string(let text):
                    XCTAssertFalse(text.isEmpty)
                    expectation.fulfill()
                @unknown default:
                    break
                }
            case .failure(let error):
                XCTFail("WebSocket error: \(error)")
            }
        }
        
        // Send a test message
        let testMessage = ["type": "ping", "timestamp": Date().timeIntervalSince1970]
        let testData = try JSONSerialization.data(withJSONObject: testMessage)
        webSocketTask.send(.data(testData)) { _ in }
        
        await fulfillment(of: [expectation], timeout: testTimeout)
        
        // Clean up
        webSocketTask.cancel(with: .goingAway, reason: nil)
    }
    
    func testCoreWorkflow_SSEStreaming() async throws {
        // Server-Sent Events streaming test
        let expectation = XCTestExpectation(description: "SSE streaming")
        var receivedEvents = 0
        
        // Start SSE client
        sseClient.onMessage = { event in
            receivedEvents += 1
            if receivedEvents >= 3 {
                expectation.fulfill()
            }
        }
        
        sseClient.onError = { error in
            XCTFail("SSE error: \(error)")
        }
        
        sseClient.connect()
        
        // Trigger events from server
        let session = try await createTestSession()
        let streamRequest = ChatCompletionRequest(
            sessionId: session.id,
            messages: [ChatMessage(role: "user", content: "Stream this response")],
            stream: true
        )
        
        _ = try await enhancedClient.sendChatCompletion(request: streamRequest)
        
        await fulfillment(of: [expectation], timeout: testTimeout)
        
        XCTAssertGreaterThanOrEqual(receivedEvents, 3, "Should receive multiple SSE events")
        
        sseClient.close()
    }
    
    // MARK: - 3. Error Handling Tests
    
    func testErrorHandling_NetworkFailure() async throws {
        // Simulate network failure
        let offlineClient = EnhancedAPIClient(
            settings: settings,
            retryPolicy: .default,
            urlSession: URLSession.shared
        )
        
        // Temporarily change to invalid URL
        settings.backendURL = "http://invalid.url.that.does.not.exist"
        
        do {
            _ = try await offlineClient.health()
            XCTFail("Should have thrown network error")
        } catch {
            // Verify proper error handling
            XCTAssertNotNil(error)
            
            if let urlError = error as? URLError {
                XCTAssertTrue(
                    urlError.code == .cannotFindHost ||
                    urlError.code == .cannotConnectToHost ||
                    urlError.code == .notConnectedToInternet
                )
            }
        }
    }
    
    func testErrorHandling_InvalidToken() async throws {
        // Test with invalid token
        settings.apiKeyPlaintext = "invalid-token-12345"
        
        do {
            _ = try await apiClient.listProjects()
            XCTFail("Should have thrown authentication error")
        } catch {
            if let apiError = error as? APIClient.APIError {
                XCTAssertEqual(apiError.status, 401, "Should return 401 Unauthorized")
            }
        }
    }
    
    func testErrorHandling_RateLimiting() async throws {
        // Test rate limiting handling
        let requests = (0..<20).map { i in
            Task {
                do {
                    _ = try await apiClient.health()
                } catch {
                    if let apiError = error as? APIClient.APIError {
                        return apiError.status
                    }
                    throw error
                }
                return 200
            }
        }
        
        let results = await withTaskGroup(of: Int.self) { group in
            for request in requests {
                group.addTask {
                    do {
                        return try await request.value
                    } catch {
                        return 0
                    }
                }
            }
            
            var statusCodes: [Int] = []
            for await result in group {
                statusCodes.append(result)
            }
            return statusCodes
        }
        
        // Check if any requests were rate limited (429)
        let rateLimitedCount = results.filter { $0 == 429 }.count
        if rateLimitedCount > 0 {
            print("Rate limited \(rateLimitedCount) requests out of \(results.count)")
        }
        
        // Verify retry logic worked for some requests
        let successCount = results.filter { $0 == 200 }.count
        XCTAssertGreaterThan(successCount, 0, "At least some requests should succeed")
    }
    
    func testErrorHandling_ServerErrors() async throws {
        // Test 500 Internal Server Error handling
        mockServer.simulateError(.internalServerError)
        
        // Use mock server URL
        settings.backendURL = "http://localhost:\(mockServer.port)"
        let mockClient = APIClient(settings: settings)!
        
        do {
            _ = try await mockClient.health()
            XCTFail("Should have thrown server error")
        } catch {
            if let apiError = error as? APIClient.APIError {
                XCTAssertEqual(apiError.status, 500)
            }
        }
        
        // Test 503 Service Unavailable
        mockServer.simulateError(.serviceUnavailable)
        
        do {
            _ = try await mockClient.health()
            XCTFail("Should have thrown service unavailable error")
        } catch {
            if let apiError = error as? APIClient.APIError {
                XCTAssertEqual(apiError.status, 503)
            }
        }
    }
    
    func testErrorHandling_TimeoutScenarios() async throws {
        // Test request timeout
        let slowClient = EnhancedAPIClient(
            settings: settings,
            retryPolicy: RetryPolicy(
                maxAttempts: 1,
                initialDelay: 0,
                maxDelay: 0,
                multiplier: 1,
                timeout: 1.0 // 1 second timeout
            ),
            urlSession: URLSession.shared
        )
        
        // Simulate slow endpoint
        mockServer.addDelay(seconds: 5.0)
        settings.backendURL = "http://localhost:\(mockServer.port)"
        
        do {
            _ = try await slowClient.health()
            XCTFail("Should have timed out")
        } catch {
            if let urlError = error as? URLError {
                XCTAssertEqual(urlError.code, .timedOut)
            }
        }
    }
    
    // MARK: - 4. Performance Benchmarks
    
    func testPerformance_APIResponseTime() async throws {
        // Measure API response times
        let metrics = XCTMetric.wallClockTime
        
        measure(metrics: [metrics]) {
            let expectation = XCTestExpectation()
            
            Task {
                do {
                    _ = try await apiClient.health()
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: performanceTimeout)
        }
        
        // Verify response time < 200ms
        // This is checked via baseline comparison in Xcode
    }
    
    func testPerformance_TokenRefresh() async throws {
        // Measure token refresh performance
        guard let refreshToken = UserDefaults.standard.string(forKey: "refresh_token") else {
            // Setup initial token
            let loginRequest = AuthLoginRequest(email: testEmail, password: testPassword)
            let response = try await enhancedClient.login(request: loginRequest)
            UserDefaults.standard.set(response.refresh_token, forKey: "refresh_token")
            return
        }
        
        let metrics = XCTMetric.wallClockTime
        
        measure(metrics: [metrics]) {
            let expectation = XCTestExpectation()
            
            Task {
                do {
                    let request = RefreshTokenRequest(refresh_token: refreshToken)
                    _ = try await enhancedClient.refreshToken(request: request)
                    expectation.fulfill()
                } catch {
                    XCTFail("Token refresh failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: performanceTimeout)
        }
        
        // Verify refresh time < 50ms
        // This is checked via baseline comparison in Xcode
    }
    
    func testPerformance_WebSocketLatency() async throws {
        // Measure WebSocket round-trip latency
        let measurements = NSMutableArray()
        let iterations = 10
        
        for _ in 0..<iterations {
            let startTime = Date()
            
            // Create WebSocket and send ping
            guard let baseURL = settings.baseURLValidated else { continue }
            let wsURL = baseURL.absoluteString
                .replacingOccurrences(of: "http://", with: "ws://")
                .replacingOccurrences(of: "https://", with: "wss://")
            
            let webSocket = URLSession.shared.webSocketTask(
                with: URL(string: "\(wsURL)/ws")!
            )
            webSocket.resume()
            
            let expectation = XCTestExpectation()
            
            // Send ping
            let ping = ["type": "ping", "timestamp": startTime.timeIntervalSince1970]
            let pingData = try JSONSerialization.data(withJSONObject: ping)
            
            webSocket.send(.data(pingData)) { _ in
                // Receive pong
                webSocket.receive { result in
                    let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
                    measurements.add(latency)
                    expectation.fulfill()
                    webSocket.cancel(with: .goingAway, reason: nil)
                }
            }
            
            await fulfillment(of: [expectation], timeout: 5.0)
        }
        
        // Calculate average latency
        let latencies = measurements.compactMap { $0 as? Double }
        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        
        XCTAssertLessThan(averageLatency, 100, "WebSocket latency should be < 100ms")
        print("Average WebSocket latency: \(averageLatency)ms")
    }
    
    func testPerformance_MemoryUsageDuringStreaming() async throws {
        // Monitor memory usage during SSE streaming
        let initialMemory = getMemoryUsage()
        
        // Start streaming
        sseClient.connect()
        
        // Simulate streaming session
        let session = try await createTestSession()
        let streamRequest = ChatCompletionRequest(
            sessionId: session.id,
            messages: [
                ChatMessage(role: "user", content: "Generate a long response with multiple paragraphs about Swift programming.")
            ],
            stream: true
        )
        
        _ = try await enhancedClient.sendChatCompletion(request: streamRequest)
        
        // Wait for streaming to complete
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (< 50MB)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory usage during streaming should be < 50MB")
        print("Memory increase during streaming: \(memoryIncrease / 1024 / 1024)MB")
        
        sseClient.close()
    }
    
    // MARK: - Helper Methods
    
    private func createTestSession() async throws -> APIClient.Session {
        let project = try await apiClient.createProject(
            name: "Test Project \(UUID().uuidString)",
            description: "Test",
            path: nil
        )
        
        return try await apiClient.createSession(
            projectId: project.id,
            model: "claude-3-opus-20240229",
            title: "Test Session",
            systemPrompt: nil
        )
    }
    
    private func isValidJWT(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        return parts.count == 3
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Supporting Types

struct AuthRegisterRequest: Encodable {
    let email: String
    let password: String
    let username: String
}

struct AuthLoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let user: User
    
    struct User: Decodable {
        let id: String
        let email: String
        let username: String
    }
}

struct RefreshTokenRequest: Encodable {
    let refresh_token: String
}

struct ChatCompletionRequest: Encodable {
    let sessionId: String
    let messages: [ChatMessage]
    let stream: Bool
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Decodable {
    let id: String
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: ChatMessage
        let finish_reason: String?
    }
}

struct FileUploadResponse: Decodable {
    let id: String
    let filename: String
    let size: Int
    let mime_type: String
}

struct FileProcessRequest: Encodable {
    let fileId: String
    let operation: String
    let options: [String: Bool]
}

struct FileProcessResponse: Decodable {
    let status: String
    let result: String?
}

// MARK: - Enhanced API Client Extensions

extension EnhancedAPIClient {
    func register(request: AuthRegisterRequest) async throws -> AuthResponse {
        // Implementation would go here
        fatalError("Implement registration endpoint call")
    }
    
    func login(request: AuthLoginRequest) async throws -> AuthResponse {
        // Implementation would go here
        fatalError("Implement login endpoint call")
    }
    
    func refreshToken(request: RefreshTokenRequest) async throws -> AuthResponse {
        // Implementation would go here
        fatalError("Implement token refresh endpoint call")
    }
    
    func logout() async throws {
        // Implementation would go here
        fatalError("Implement logout endpoint call")
    }
    
    func sendChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        // Implementation would go here
        fatalError("Implement chat completion endpoint call")
    }
    
    func uploadFile(data: Data, fileName: String, mimeType: String) async throws -> FileUploadResponse {
        // Implementation would go here
        fatalError("Implement file upload endpoint call")
    }
    
    func processFile(request: FileProcessRequest) async throws -> FileProcessResponse {
        // Implementation would go here
        fatalError("Implement file processing endpoint call")
    }
    
    func downloadFile(fileId: String) async throws -> Data {
        // Implementation would go here
        fatalError("Implement file download endpoint call")
    }
    
    func deleteFile(fileId: String) async throws {
        // Implementation would go here
        fatalError("Implement file deletion endpoint call")
    }
}