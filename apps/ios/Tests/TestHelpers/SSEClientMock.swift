import Foundation
@testable import ClaudeCode

// MARK: - SSE Event Mock
struct SSEEventMock {
    let data: String?
    let event: String?
    let id: String?
    let retry: TimeInterval?
    
    init(data: String? = nil, event: String? = nil, id: String? = nil, retry: TimeInterval? = nil) {
        self.data = data
        self.event = event
        self.id = id
        self.retry = retry
    }
}

// MARK: - SSE Client Mock
final class SSEClientMock: SSEClientProtocol {
    // Mock configuration
    var mockEvents: [SSEEventMock] = []
    var shouldDisconnect = false
    var shouldFail = false
    var mockError: Error?
    var reconnectAfter = 0
    var connectionAttempts = 0
    var delay: TimeInterval = 0
    
    // State tracking
    private(set) var isConnected = false
    private(set) var lastURL: URL?
    private(set) var lastHeaders: [String: String] = [:]
    private(set) var lastBody: Data?
    private(set) var disconnectCount = 0
    
    // Callbacks
    var onEvent: ((SSEClient.Event) -> Void)?
    var onDone: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onMessage: ((String) -> Void)?
    var onComplete: (() -> Void)?
    
    // Event stream
    private var eventTask: Task<Void, Never>?
    
    // MARK: - SSEClientProtocol Implementation
    func connect(url: URL?, body: Data? = nil, headers: [String: String] = [:]) {
        connectionAttempts += 1
        lastURL = url
        lastBody = body
        lastHeaders = headers
        
        // Check for immediate failure
        if shouldFail {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                self?.onError?(self?.mockError ?? URLError(.cannotConnectToHost))
            }
            return
        }
        
        // Check for disconnection scenario
        if shouldDisconnect && connectionAttempts < reconnectAfter {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                self?.onError?(URLError(.networkConnectionLost))
            }
            return
        }
        
        // Successful connection
        isConnected = true
        
        // Start event stream
        eventTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Simulate delay if configured
            if self.delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(self.delay * 1_000_000_000))
            }
            
            // Send mock events
            for event in self.mockEvents {
                guard !Task.isCancelled else { break }
                
                // Create SSE event
                if let data = event.data {
                    let sseEvent = SSEClient.Event(raw: data)
                    
                    await MainActor.run {
                        self.onEvent?(sseEvent)
                        self.onMessage?(data)
                    }
                }
                
                // Small delay between events
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Send completion
            if !Task.isCancelled {
                await MainActor.run {
                    self.onDone?()
                    self.onComplete?()
                }
            }
        }
    }
    
    func stop() {
        disconnectCount += 1
        isConnected = false
        eventTask?.cancel()
        eventTask = nil
    }
    
    // MARK: - Test Helpers
    func reset() {
        mockEvents = []
        shouldDisconnect = false
        shouldFail = false
        mockError = nil
        reconnectAfter = 0
        connectionAttempts = 0
        delay = 0
        isConnected = false
        lastURL = nil
        lastHeaders = [:]
        lastBody = nil
        disconnectCount = 0
        eventTask?.cancel()
        eventTask = nil
    }
    
    func sendEvent(_ event: SSEEventMock) {
        guard isConnected else { return }
        
        if let data = event.data {
            let sseEvent = SSEClient.Event(raw: data)
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(sseEvent)
                self?.onMessage?(data)
            }
        }
    }
    
    func sendDone() {
        guard isConnected else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.onDone?()
            self?.onComplete?()
        }
        stop()
    }
    
    func simulateError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(error)
        }
        stop()
    }
    
    func simulateReconnection() {
        stop()
        connectionAttempts = 0
        connect(url: lastURL, body: lastBody, headers: lastHeaders)
    }
}

// MARK: - Async Stream Support
extension SSEClientMock {
    func eventStream() -> AsyncStream<SSEClient.Event> {
        AsyncStream { continuation in
            self.onEvent = { event in
                continuation.yield(event)
            }
            
            self.onComplete = {
                continuation.finish()
            }
            
            self.onError = { _ in
                continuation.finish()
            }
        }
    }
}