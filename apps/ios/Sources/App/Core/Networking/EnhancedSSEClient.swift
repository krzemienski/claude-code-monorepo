import Foundation
import os.log

// MARK: - Enhanced SSE Client with Auto-Reconnection
final class EnhancedSSEClient: NSObject, URLSessionDataDelegate, SSEClientProtocol {
    // MARK: - Types
    private let queue = DispatchQueue(label: "com.claudecode.sse", attributes: .concurrent)
    
    struct Event {
        let raw: String
        let id: String?
        let event: String?
        let retry: TimeInterval?
    }
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(Error)
    }
    
    // MARK: - Properties
    private var url: URL?
    private var headers: [String: String] = [:]
    private var body: Data?
    
    private var buffer = Data()
    private var task: URLSessionDataTask?
    private var session: URLSession?
    
    private let logger = Logger(subsystem: "com.claudecode", category: "EnhancedSSE")
    private var connectionState: ConnectionState = .disconnected
    
    // Reconnection properties
    private let retryPolicy: RetryPolicy
    private var reconnectAttempts = 0
    private var reconnectTimer: DispatchWorkItem?
    private var lastEventId: String?
    private var shouldReconnect = true
    
    // Callbacks (made nonisolated for external access)
    var onEvent: ((SSEClient.Event) -> Void)?
    var onDone: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onMessage: ((String) -> Void)?
    var onComplete: (() -> Void)?
    
    // Additional callbacks for enhanced functionality
    var onConnectionStateChange: ((ConnectionState) -> Void)?
    var onReconnecting: ((Int) -> Void)?
    
    // MARK: - Initialization
    init(retryPolicy: RetryPolicy = .default) {
        self.retryPolicy = retryPolicy
        super.init()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Interface (SSEClientProtocol)
    func connect(url: URL?, body: Data? = nil, headers: [String: String] = [:]) {
        queue.async(flags: .barrier) { [weak self] in
            self?.connectSync(url: url, body: body, headers: headers)
        }
    }
    
    func stop() {
        queue.async(flags: .barrier) { [weak self] in
            self?.stopSync()
        }
    }
    
    // MARK: - Actor-Isolated Implementation
    private func connectSync(url: URL?, body: Data?, headers: [String: String]) {
        guard let url = url else {
            logger.error("SSE URL is nil")
            handleError(URLError(.badURL))
            return
        }
        
        self.url = url
        self.body = body
        self.headers = headers
        self.shouldReconnect = true
        
        performConnection()
    }
    
    private func stopSync() {
        logger.info("Stopping SSE connection")
        shouldReconnect = false
        reconnectTimer?.cancel()
        reconnectTimer = nil
        disconnect()
        updateConnectionState(.disconnected)
    }
    
    private func performConnection() {
        guard let url = url else { return }
        
        updateConnectionState(.connecting)
        logger.info("Connecting to SSE: \(url.absoluteString)")
        
        // Clean up previous connection
        disconnect()
        
        // Create new session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        configuration.allowsConstrainedNetworkAccess = true
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = body != nil ? "POST" : "GET"
        request.httpBody = body
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add custom headers
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add last event ID for resumption
        if let lastEventId = lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
            logger.debug("Resuming from event ID: \(lastEventId)")
        }
        
        // Start the connection
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    private func disconnect() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer.removeAll()
    }
    
    private func cleanup() {
        shouldReconnect = false
        reconnectTimer?.cancel()
        disconnect()
    }
    
    // MARK: - Reconnection Logic
    private func scheduleReconnection() {
        guard shouldReconnect else { return }
        
        reconnectAttempts += 1
        let delay = retryPolicy.delay(for: reconnectAttempts)
        
        updateConnectionState(.reconnecting(attempt: reconnectAttempts))
        onReconnecting?(reconnectAttempts)
        
        logger.info("Scheduling reconnection attempt \(self.reconnectAttempts) after \(delay) seconds")
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.queue.async(flags: .barrier) { [weak self] in
                guard let self = self, self.shouldReconnect else { return }
                self.performConnection()
            }
        }
        reconnectTimer = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    // MARK: - State Management
    private func updateConnectionState(_ newState: ConnectionState) {
        connectionState = newState
        onConnectionStateChange?(newState)
        
        switch newState {
        case .connected:
            reconnectAttempts = 0
            logger.info("SSE connected successfully")
        case .failed(let error):
            logger.error("SSE connection failed: \(error.localizedDescription)")
        case .reconnecting(let attempt):
            logger.info("SSE reconnecting (attempt \(attempt))")
        default:
            break
        }
    }
    
    private func handleError(_ error: Error) {
        updateConnectionState(.failed(error))
        onError?(error)
        
        // Check if we should retry
        if shouldReconnect && retryPolicy.shouldRetry(for: error, attempt: reconnectAttempts + 1) {
            scheduleReconnection()
        }
    }
    
    // MARK: - Event Processing
    private func processBuffer() {
        let newlineData = Data("\n\n".utf8)
        
        while let range = buffer.range(of: newlineData) {
            let eventData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.upperBound)
            
            if !eventData.isEmpty {
                processEvent(eventData)
            }
        }
    }
    
    private func processEvent(_ eventData: Data) {
        guard let eventString = String(data: eventData, encoding: .utf8) else { return }
        
        var eventId: String?
        var eventType: String?
        var eventDataString = ""
        
        // Parse event fields
        let lines = eventString.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                lastEventId = eventId
            } else if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !eventDataString.isEmpty {
                    eventDataString += "\n"
                }
                eventDataString += data
            } else if line.hasPrefix("retry:") {
                // Retry interval could be used for reconnection logic in the future
                _ = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Handle special [DONE] message
        if eventDataString == "[DONE]" {
            logger.debug("SSE received [DONE]")
            onDone?()
            onComplete?()
            shouldReconnect = false
            disconnect()
            updateConnectionState(.disconnected)
            return
        }
        
        // Dispatch event
        if !eventDataString.isEmpty {
            // Convert to legacy event type for compatibility
            let legacyEvent = SSEClient.Event(raw: eventDataString)
            onEvent?(legacyEvent)
            onMessage?(eventDataString)
            
            logger.debug("SSE event received: \(eventType ?? "message")")
        }
    }
    
    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            self?.handleResponse(response)
            completionHandler(.allow)
        }
    }
    
    private func handleResponse(_ response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("SSE response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                updateConnectionState(.connected)
                reconnectAttempts = 0
            } else {
                let error = URLError(.badServerResponse, userInfo: [
                    "statusCode": httpResponse.statusCode
                ])
                handleError(error)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async(flags: .barrier) { [weak self] in
            self?.handleData(data)
        }
    }
    
    private func handleData(_ data: Data) {
        buffer.append(data)
        processBuffer()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async(flags: .barrier) { [weak self] in
            self?.handleCompletion(error: error)
        }
    }
    
    private func handleCompletion(error: Error?) {
        if let error = error {
            logger.error("SSE connection error: \(error.localizedDescription)")
            
            // Check if it's a cancellation
            if (error as NSError).code == NSURLErrorCancelled && !shouldReconnect {
                updateConnectionState(.disconnected)
                return
            }
            
            handleError(error)
        } else {
            // Normal completion
            logger.info("SSE connection completed normally")
            onComplete?()
            
            if shouldReconnect {
                scheduleReconnection()
            } else {
                updateConnectionState(.disconnected)
            }
        }
    }
}