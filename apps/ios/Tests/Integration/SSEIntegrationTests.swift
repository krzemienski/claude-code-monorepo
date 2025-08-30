import XCTest
import Combine
import LDSwiftEventSource
@testable import ClaudeCode

@MainActor
final class SSEIntegrationTests: XCTestCase {
    
    var sseClient: EnhancedSSEClient!
    var mockEventSource: MockEventSource!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
        sseClient = EnhancedSSEClient(retryPolicy: .default)
        mockEventSource = MockEventSource()
    }
    
    override func tearDown() async throws {
        await sseClient.disconnect()
        sseClient = nil
        mockEventSource = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Connection Tests
    
    func testSuccessfulConnection() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let headers = ["Authorization": "Bearer test-token"]
        let expectation = XCTestExpectation(description: "Connected successfully")
        
        // When
        let stream = sseClient.connect(to: url, headers: headers)
        
        // Monitor connection state
        Task {
            for await event in stream {
                if case .connected = event {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        // Simulate connection
        await sseClient.simulateConnection()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(sseClient.isConnected)
    }
    
    func testConnectionFailure() async {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let expectation = XCTestExpectation(description: "Connection failed")
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        // Monitor for error
        Task {
            for await event in stream {
                if case .error(let error) = event {
                    XCTAssertNotNil(error)
                    expectation.fulfill()
                    break
                }
            }
        }
        
        // Simulate connection failure
        await sseClient.simulateError(URLError(.notConnectedToInternet))
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(sseClient.isConnected)
    }
    
    // MARK: - Message Handling Tests
    
    func testMessageReception() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let expectation = XCTestExpectation(description: "Received message")
        var receivedMessages: [String] = []
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .message(let message) = event {
                    receivedMessages.append(message.data ?? "")
                    if receivedMessages.count >= 3 {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate messages
        await sseClient.simulateConnection()
        await sseClient.simulateMessage(data: "Message 1", eventType: "message")
        await sseClient.simulateMessage(data: "Message 2", eventType: "message")
        await sseClient.simulateMessage(data: "Message 3", eventType: "message")
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedMessages.count, 3)
        XCTAssertEqual(receivedMessages[0], "Message 1")
        XCTAssertEqual(receivedMessages[1], "Message 2")
        XCTAssertEqual(receivedMessages[2], "Message 3")
    }
    
    func testEventTypeFiltering() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let expectation = XCTestExpectation(description: "Received specific event")
        var receivedEvents: [(type: String?, data: String?)] = []
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .message(let message) = event {
                    receivedEvents.append((type: message.event, data: message.data))
                    if receivedEvents.count >= 3 {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate different event types
        await sseClient.simulateConnection()
        await sseClient.simulateMessage(data: "Chat message", eventType: "chat")
        await sseClient.simulateMessage(data: "Status update", eventType: "status")
        await sseClient.simulateMessage(data: "Error occurred", eventType: "error")
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedEvents[0].type, "chat")
        XCTAssertEqual(receivedEvents[1].type, "status")
        XCTAssertEqual(receivedEvents[2].type, "error")
    }
    
    // MARK: - Reconnection Tests
    
    func testAutomaticReconnection() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let expectation = XCTestExpectation(description: "Reconnected after disconnect")
        var connectionCount = 0
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .connected = event {
                    connectionCount += 1
                    if connectionCount == 2 {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate connection, disconnect, and reconnection
        await sseClient.simulateConnection()
        await sseClient.simulateDisconnection()
        try await Task.sleep(nanoseconds: 100_000_000) // Wait for retry
        await sseClient.simulateConnection()
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertEqual(connectionCount, 2)
    }
    
    func testRetryWithBackoff() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        var retryAttempts = 0
        let expectation = XCTestExpectation(description: "Retried with backoff")
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .error = event {
                    retryAttempts += 1
                    if retryAttempts >= 3 {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate multiple failures
        for _ in 0..<3 {
            await sseClient.simulateError(URLError(.timedOut))
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(retryAttempts, 3)
    }
    
    // MARK: - Heartbeat Tests
    
    func testHeartbeatHandling() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let expectation = XCTestExpectation(description: "Received heartbeats")
        var heartbeatCount = 0
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .message(let message) = event,
                   message.event == "heartbeat" {
                    heartbeatCount += 1
                    if heartbeatCount >= 3 {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate heartbeats
        await sseClient.simulateConnection()
        for i in 1...3 {
            await sseClient.simulateMessage(data: "ping-\(i)", eventType: "heartbeat")
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(heartbeatCount, 3)
    }
    
    // MARK: - Performance Tests
    
    func testHighVolumeMessageHandling() async throws {
        // Given
        let url = URL(string: "http://localhost:8000/stream")!
        let messageCount = 1000
        let expectation = XCTestExpectation(description: "Handled high volume")
        var receivedCount = 0
        
        // When
        let stream = sseClient.connect(to: url, headers: [:])
        
        Task {
            for await event in stream {
                if case .message = event {
                    receivedCount += 1
                    if receivedCount >= messageCount {
                        expectation.fulfill()
                        break
                    }
                }
            }
        }
        
        // Simulate high volume
        await sseClient.simulateConnection()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<messageCount {
                group.addTask {
                    await self.sseClient.simulateMessage(
                        data: "Message \(i)",
                        eventType: "message"
                    )
                }
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(receivedCount, messageCount)
    }
    
    // MARK: - Memory Management Tests
    
    func testNoMemoryLeaks() async {
        // Given
        weak var weakClient: EnhancedSSEClient?
        
        autoreleasepool {
            let client = EnhancedSSEClient(retryPolicy: .default)
            weakClient = client
            
            // Connect and send messages
            let url = URL(string: "http://localhost:8000/stream")!
            _ = client.connect(to: url, headers: [:])
            
            Task {
                await client.simulateConnection()
                for i in 0..<100 {
                    await client.simulateMessage(data: "Message \(i)", eventType: "test")
                }
                await client.disconnect()
            }
        }
        
        // Then
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(weakClient, "SSE client should be deallocated")
    }
}

// MARK: - Mock Event Source

class MockEventSource {
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?
    var onMessage: ((String, MessageEvent) -> Void)?
    var onComment: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    func start() {
        // Simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onOpened?()
        }
    }
    
    func stop() {
        onClosed?()
    }
    
    func simulateMessage(data: String, event: String? = nil, id: String? = nil) {
        let messageEvent = MessageEvent(
            data: data,
            event: event,
            id: id,
            retry: nil,
            origin: nil,
            lastEventId: nil
        )
        onMessage?(event ?? "message", messageEvent)
    }
    
    func simulateError(_ error: Error) {
        onError?(error)
    }
}

// MARK: - SSE Client Test Extensions

extension EnhancedSSEClient {
    func simulateConnection() async {
        // Simulate successful connection for testing
    }
    
    func simulateDisconnection() async {
        // Simulate disconnection for testing
    }
    
    func simulateMessage(data: String, eventType: String) async {
        // Simulate incoming message for testing
    }
    
    func simulateError(_ error: Error) async {
        // Simulate error for testing
    }
}