import XCTest
@testable import ClaudeCode

final class NetworkingTests: XCTestCase {
    
    var apiClient: APIClient!
    var mockSession: URLSessionMock!
    var mockSSEClient: NetworkSSEClientMock!
    
    override func setUp() {
        super.setUp()
        mockSession = URLSessionMock()
        mockSSEClient = NetworkSSEClientMock()
        apiClient = APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: mockSession,
            sseClient: mockSSEClient
        )
    }
    
    override func tearDown() {
        apiClient = nil
        mockSession = nil
        mockSSEClient = nil
        super.tearDown()
    }
    
    // MARK: - Request Building Tests
    
    func testBuildGETRequest() throws {
        // Given
        let endpoint = "/api/users"
        let params = ["page": "1", "limit": "10"]
        
        // When
        let request = try apiClient.buildRequest(
            endpoint: endpoint,
            method: .get,
            params: params
        )
        
        // Then
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/users")
        XCTAssertTrue(request.url?.query?.contains("page=1") ?? false)
        XCTAssertTrue(request.url?.query?.contains("limit=10") ?? false)
    }
    
    func testBuildPOSTRequest() throws {
        // Given
        let endpoint = "/api/sessions"
        let body = ["name": "Test Session", "projectId": "123"]
        
        // When
        let request = try apiClient.buildRequest(
            endpoint: endpoint,
            method: .post,
            body: body
        )
        
        // Then
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        
        let bodyData = request.httpBody!
        let decodedBody = try JSONDecoder().decode([String: String].self, from: bodyData)
        XCTAssertEqual(decodedBody["name"], "Test Session")
    }
    
    func testAuthorizationHeader() throws {
        // Given
        apiClient.authToken = "bearer-token-123"
        
        // When
        let request = try apiClient.buildRequest(endpoint: "/api/protected", method: .get)
        
        // Then
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer bearer-token-123")
    }
    
    func testAPIKeyHeader() throws {
        // Given
        apiClient.apiKey = "api-key-456"
        
        // When
        let request = try apiClient.buildRequest(endpoint: "/api/data", method: .get)
        
        // Then
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "api-key-456")
    }
    
    // MARK: - Response Handling Tests
    
    func testHandleSuccessResponse() async throws {
        // Given
        struct TestResponse: Codable {
            let id: String
            let name: String
        }
        
        mockSession.mockResponse = TestResponse(id: "1", name: "Test")
        
        // When
        let response: TestResponse = try await apiClient.request(endpoint: "/api/test")
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertEqual(response.name, "Test")
    }
    
    func testHandle401Unauthorized() async {
        // Given
        mockSession.statusCode = 401
        mockSession.shouldFail = true
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/protected")
            XCTFail("Should throw unauthorized error")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
    }
    
    func testHandle404NotFound() async {
        // Given
        mockSession.statusCode = 404
        mockSession.shouldFail = true
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/missing")
            XCTFail("Should throw not found error")
        } catch {
            XCTAssertEqual(error as? APIError, .notFound)
        }
    }
    
    func testHandle500ServerError() async {
        // Given
        mockSession.statusCode = 500
        mockSession.shouldFail = true
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/error")
            XCTFail("Should throw server error")
        } catch {
            XCTAssertEqual(error as? APIError, .serverError)
        }
    }
    
    func testHandleRateLimiting() async {
        // Given
        mockSession.statusCode = 429
        mockSession.shouldFail = true
        mockSession.headers = ["Retry-After": "60"]
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/limited")
            XCTFail("Should throw rate limit error")
        } catch {
            guard case APIError.rateLimited(let retryAfter) = error else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(retryAfter, 60)
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryOnNetworkError() async throws {
        // Given - first two attempts fail, third succeeds
        mockSession.responses = [
            .failure(URLError(.networkConnectionLost)),
            .failure(URLError(.timedOut)),
            .success(["result": "success"])
        ]
        
        // When
        let response: [String: String] = try await apiClient.requestWithRetry(
            endpoint: "/api/data",
            maxRetries: 3
        )
        
        // Then
        XCTAssertEqual(response["result"], "success")
        XCTAssertEqual(mockSession.requestCount, 3)
    }
    
    func testNoRetryOnClientError() async {
        // Given - 400 error should not retry
        mockSession.statusCode = 400
        mockSession.shouldFail = true
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.requestWithRetry(
                endpoint: "/api/bad",
                maxRetries: 3
            )
            XCTFail("Should throw bad request error")
        } catch {
            XCTAssertEqual(mockSession.requestCount, 1) // No retries
        }
    }
    
    // MARK: - SSE Tests
    
    func testSSEConnection() async throws {
        // Given
        let url = URL(string: "https://api.example.com/sse")!
        mockSSEClient.mockEvents = [
            SSEEvent(data: "First event", event: "message"),
            SSEEvent(data: "Second event", event: "message")
        ]
        
        // When
        var receivedEvents: [String] = []
        let stream = apiClient.sseStream(url: url)
        
        for await event in stream {
            receivedEvents.append(event.data ?? "")
            if receivedEvents.count == 2 { break }
        }
        
        // Then
        XCTAssertEqual(receivedEvents, ["First event", "Second event"])
    }
    
    func testSSEReconnection() async throws {
        // Given
        mockSSEClient.shouldDisconnect = true
        mockSSEClient.reconnectAfter = 2
        
        // When
        let connected = await apiClient.connectSSE(url: URL(string: "https://api.example.com/sse")!)
        
        // Then
        XCTAssertTrue(connected)
        XCTAssertEqual(mockSSEClient.connectionAttempts, 2)
    }
    
    func testSSEErrorHandling() async {
        // Given
        mockSSEClient.shouldFail = true
        mockSSEClient.mockError = URLError(.notConnectedToInternet)
        
        // When
        let connected = await apiClient.connectSSE(url: URL(string: "https://api.example.com/sse")!)
        
        // Then
        XCTAssertFalse(connected)
    }
    
    // MARK: - Batch Request Tests
    
    func testBatchRequests() async throws {
        // Given
        mockSession.mockResponse = ["id": "batch-result"]
        let endpoints = ["/api/1", "/api/2", "/api/3"]
        
        // When
        let results: [[String: String]] = try await apiClient.batchRequest(endpoints: endpoints)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(mockSession.requestCount, 3)
    }
    
    func testParallelRequests() async throws {
        // Given
        mockSession.mockResponse = ["status": "ok"]
        
        // When
        async let request1: [String: String] = apiClient.request(endpoint: "/api/parallel1")
        async let request2: [String: String] = apiClient.request(endpoint: "/api/parallel2")
        
        let (result1, result2) = try await (request1, request2)
        
        // Then
        XCTAssertEqual(result1["status"], "ok")
        XCTAssertEqual(result2["status"], "ok")
    }
    
    // MARK: - Cancel and Timeout Tests
    
    func testRequestCancellation() async {
        // Given
        mockSession.delay = 5.0 // Long delay
        
        // When
        let task = Task {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/slow")
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        task.cancel()
        
        // Then
        let result = await task.result
        
        switch result {
        case .failure(let error):
            XCTAssertTrue(error is CancellationError)
        case .success:
            XCTFail("Should have been cancelled")
        }
    }
    
    func testRequestTimeout() async {
        // Given
        apiClient.timeoutInterval = 1.0
        mockSession.delay = 5.0
        
        // When/Then
        do {
            let _: [String: String] = try await apiClient.request(endpoint: "/api/timeout")
            XCTFail("Should timeout")
        } catch {
            XCTAssertTrue(error is URLError)
            if let urlError = error as? URLError {
                XCTAssertEqual(urlError.code, .timedOut)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testRequestPerformance() {
        measure {
            let expectation = expectation(description: "Request performance")
            
            Task {
                mockSession.mockResponse = ["test": "data"]
                let _: [String: String] = try? await apiClient.request(endpoint: "/api/perf")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testLargePayloadHandling() async throws {
        // Given - large JSON payload
        var largeData: [String: [String]] = [:]
        for i in 0..<1000 {
            largeData["key\(i)"] = Array(repeating: "value", count: 10)
        }
        mockSession.mockResponse = largeData
        
        // When
        let response: [String: [String]] = try await apiClient.request(endpoint: "/api/large")
        
        // Then
        XCTAssertEqual(response.count, 1000)
    }
}

// MARK: - SSE Client Mock

class NetworkSSEClientMock: SSEClientProtocol {
    var mockEvents: [SSEEvent] = []
    var shouldDisconnect = false
    var reconnectAfter = 0
    var connectionAttempts = 0
    var shouldFail = false
    var mockError: Error?
    
    func connect(to url: URL) async throws -> AsyncStream<SSEEvent> {
        connectionAttempts += 1
        
        if shouldFail {
            throw mockError ?? URLError(.cannotConnectToHost)
        }
        
        if shouldDisconnect && connectionAttempts < reconnectAfter {
            throw URLError(.networkConnectionLost)
        }
        
        return AsyncStream { continuation in
            for event in mockEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
    
    func disconnect() {
        // Mock disconnect
    }
}