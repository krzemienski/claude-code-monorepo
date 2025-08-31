import XCTest
import Combine
@testable import ClaudeCode

/// Tests for SSE/WebSocket connections without authentication
@MainActor
final class SSENoAuthTests: XCTestCase {
    
    var sseClient: SSEClient!
    var enhancedSSEClient: EnhancedSSEClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        sseClient = SSEClient()
        enhancedSSEClient = EnhancedSSEClient(
            baseURL: URL(string: "http://localhost:8000")!,
            sessionId: "test-session"
        )
        cancellables = []
    }
    
    override func tearDown() async throws {
        sseClient?.stop()
        enhancedSSEClient?.disconnect()
        sseClient = nil
        enhancedSSEClient = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic SSE Tests
    
    func testSSEConnectionInitialization() {
        XCTAssertNotNil(sseClient, "SSE client should be initialized")
        
        // Verify no auth headers are set by default
        let headers = sseClient.headers
        XCTAssertTrue(headers.isEmpty || !headers.keys.contains("Authorization"))
    }
    
    func testSSEConnectWithoutAuth() async {
        let expectation = XCTestExpectation(description: "SSE connects")
        
        sseClient.onEvent = { event in
            XCTAssertFalse(event.raw.isEmpty)
            expectation.fulfill()
        }
        
        // Connect without any auth headers
        let url = URL(string: "http://localhost:8000/v1/sessions/test/stream")!
        sseClient.connect(url: url, headers: [:])
        
        // Simulate receiving data
        let testData = "data: {\"type\":\"message\",\"content\":\"Test\"}\n\n".data(using: .utf8)!
        sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: testData)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testSSEMessageParsing() async {
        let expectation = XCTestExpectation(description: "Messages parsed")
        var receivedMessages: [String] = []
        
        sseClient.onMessage = { message in
            receivedMessages.append(message)
            if receivedMessages.count == 3 {
                expectation.fulfill()
            }
        }
        
        // Send multiple messages
        let messages = [
            "data: {\"content\":\"First message\"}\n\n",
            "data: {\"content\":\"Second message\"}\n\n",
            "data: {\"content\":\"Third message\"}\n\n"
        ]
        
        for message in messages {
            if let data = message.data(using: .utf8) {
                sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: data)
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedMessages.count, 3)
    }
    
    func testSSEDoneSignal() async {
        let expectation = XCTestExpectation(description: "Done received")
        
        sseClient.onDone = {
            expectation.fulfill()
        }
        
        // Send DONE signal
        let doneData = "data: [DONE]\n\n".data(using: .utf8)!
        sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: doneData)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testSSEErrorHandling() async {
        let expectation = XCTestExpectation(description: "Error handled")
        
        sseClient.onError = { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        
        // Simulate error
        let error = URLError(.notConnectedToInternet)
        sseClient.urlSession(URLSession.shared, task: URLSessionTask(), didCompleteWithError: error)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Enhanced SSE Client Tests
    
    func testEnhancedSSEConnectionWithoutAuth() async {
        XCTAssertNotNil(enhancedSSEClient)
        
        // Subscribe to message stream
        let expectation = XCTestExpectation(description: "Enhanced SSE receives messages")
        
        enhancedSSEClient.messagePublisher
            .sink { completion in
                if case .failure(let error) = completion {
                    XCTFail("Should not fail: \(error)")
                }
            } receiveValue: { message in
                XCTAssertFalse(message.content.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Connect without auth
        enhancedSSEClient.connect()
        
        // Simulate message
        let messageData = """
        {
            "id": "msg-1",
            "role": "assistant",
            "content": "Hello from enhanced SSE",
            "timestamp": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        enhancedSSEClient.handleStreamData(messageData)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testEnhancedSSEReconnection() async {
        let expectation = XCTestExpectation(description: "Reconnection works")
        
        enhancedSSEClient.connectionStatePublisher
            .dropFirst() // Skip initial state
            .sink { state in
                if state == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Disconnect and reconnect
        enhancedSSEClient.disconnect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.enhancedSSEClient.connect()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testEnhancedSSEToolExecution() async {
        let expectation = XCTestExpectation(description: "Tool execution received")
        
        enhancedSSEClient.toolExecutionPublisher
            .sink { toolExecution in
                XCTAssertEqual(toolExecution.toolName, "test_tool")
                XCTAssertEqual(toolExecution.status, "completed")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate tool execution message
        let toolData = """
        {
            "type": "tool_execution",
            "data": {
                "id": "tool-1",
                "tool_name": "test_tool",
                "tool_type": "utility",
                "status": "completed",
                "created_at": "2024-01-01T00:00:00Z"
            }
        }
        """.data(using: .utf8)!
        
        enhancedSSEClient.handleStreamData(toolData)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Stream Event Types
    
    func testStreamEventTypes() async {
        var receivedEvents: [String] = []
        let expectation = XCTestExpectation(description: "All event types received")
        
        enhancedSSEClient.messagePublisher
            .sink { _ in } receiveValue: { message in
                receivedEvents.append("message")
                if receivedEvents.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Test different event types
        let events = [
            """
            {"type": "message", "data": {"content": "Regular message"}}
            """,
            """
            {"type": "error", "data": {"message": "Error occurred"}}
            """,
            """
            {"type": "status", "data": {"status": "processing"}}
            """
        ]
        
        for event in events {
            if let data = event.data(using: .utf8) {
                enhancedSSEClient.handleStreamData(data)
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Connection State Tests
    
    func testConnectionStates() async {
        var states: [EnhancedSSEClient.ConnectionState] = []
        let expectation = XCTestExpectation(description: "State transitions")
        
        enhancedSSEClient.connectionStatePublisher
            .sink { state in
                states.append(state)
                if states.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger state changes
        enhancedSSEClient.connect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.enhancedSSEClient.disconnect()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.enhancedSSEClient.connect()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertTrue(states.contains(.disconnected))
        XCTAssertTrue(states.contains(.connecting))
    }
    
    // MARK: - Performance Tests
    
    func testSSEMessageThroughput() {
        measure {
            let expectation = self.expectation(description: "Throughput test")
            var messageCount = 0
            
            sseClient.onMessage = { _ in
                messageCount += 1
                if messageCount >= 1000 {
                    expectation.fulfill()
                }
            }
            
            // Send 1000 messages rapidly
            let messageData = "data: {\"content\":\"Test message\"}\n\n".data(using: .utf8)!
            for _ in 0..<1000 {
                sseClient.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: messageData)
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Memory Tests
    
    func testSSEMemoryManagement() async {
        weak var weakClient: SSEClient?
        
        autoreleasepool {
            let client = SSEClient()
            weakClient = client
            
            // Use the client
            client.connect(url: URL(string: "http://localhost:8000/test")!)
            
            // Send some data
            let data = "data: test\n\n".data(using: .utf8)!
            client.urlSession(URLSession.shared, dataTask: URLSessionDataTask(), didReceive: data)
            
            client.stop()
        }
        
        // Wait for deallocation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNil(weakClient, "SSE client should be deallocated")
    }
}

// MARK: - Mock Extensions for Enhanced SSE Client
extension EnhancedSSEClient {
    func handleStreamData(_ data: Data) {
        // This would normally be internal, but exposed for testing
        // Parse and handle the data as if it came from the stream
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = jsonObject["type"] as? String else {
            return
        }
        
        switch type {
        case "message":
            if let messageData = jsonObject["data"] as? [String: Any],
               let content = messageData["content"] as? String {
                let message = StreamMessage(
                    id: UUID().uuidString,
                    role: "assistant",
                    content: content,
                    timestamp: Date()
                )
                messageSubject.send(message)
            }
            
        case "tool_execution":
            if let toolData = jsonObject["data"] as? [String: Any],
               let toolName = toolData["tool_name"] as? String,
               let status = toolData["status"] as? String {
                let toolExecution = ToolExecution(
                    id: UUID().uuidString,
                    toolName: toolName,
                    toolType: toolData["tool_type"] as? String ?? "unknown",
                    inputParams: nil,
                    output: nil,
                    status: status,
                    errorMessage: nil,
                    executionTimeMs: nil,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    completedAt: nil
                )
                toolExecutionSubject.send(toolExecution)
            }
            
        default:
            break
        }
    }
}