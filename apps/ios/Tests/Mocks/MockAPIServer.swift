import Foundation
import Network
import OSLog

/// Mock API Server for offline integration testing
/// Simulates backend responses for testing without a real server
@MainActor
public class MockAPIServer {
    
    // MARK: - Properties
    
    private var listener: NWListener?
    private var connections: Set<NWConnection> = []
    private let queue = DispatchQueue(label: "com.claudecode.mock.server")
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MockServer")
    
    public private(set) var port: Int = 0
    private var isRunning = false
    private var delay: TimeInterval = 0
    private var currentError: ServerError?
    
    // Response templates
    private var responseTemplates: [String: MockResponse] = [:]
    
    // Statistics
    private var requestCount = 0
    private var errorCount = 0
    
    // MARK: - Server Errors
    
    public enum ServerError {
        case internalServerError
        case serviceUnavailable
        case badGateway
        case timeout
        case unauthorized
        case forbidden
        case notFound
        case badRequest
        case tooManyRequests
        
        var statusCode: Int {
            switch self {
            case .badRequest: return 400
            case .unauthorized: return 401
            case .forbidden: return 403
            case .notFound: return 404
            case .tooManyRequests: return 429
            case .internalServerError: return 500
            case .badGateway: return 502
            case .serviceUnavailable: return 503
            case .timeout: return 504
            }
        }
        
        var message: String {
            switch self {
            case .badRequest: return "Bad Request"
            case .unauthorized: return "Unauthorized"
            case .forbidden: return "Forbidden"
            case .notFound: return "Not Found"
            case .tooManyRequests: return "Too Many Requests"
            case .internalServerError: return "Internal Server Error"
            case .badGateway: return "Bad Gateway"
            case .serviceUnavailable: return "Service Unavailable"
            case .timeout: return "Gateway Timeout"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultResponses()
    }
    
    // MARK: - Server Control
    
    public func start(on port: Int = 0) async throws {
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let actualPort = port == 0 ? NWEndpoint.Port.any : NWEndpoint.Port(rawValue: UInt16(port))!
        
        listener = try NWListener(using: parameters, on: actualPort)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener?.port {
                    self?.port = Int(port.rawValue)
                    self?.logger.info("Mock server listening on port: \(port)")
                }
            case .failed(let error):
                self?.logger.error("Server failed: \(error)")
            default:
                break
            }
        }
        
        listener?.start(queue: queue)
        isRunning = true
        
        // Wait for server to be ready
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    public func stop() async {
        guard isRunning else { return }
        
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        listener?.cancel()
        listener = nil
        
        isRunning = false
        port = 0
        
        logger.info("Mock server stopped. Requests: \(requestCount), Errors: \(errorCount)")
    }
    
    // MARK: - Request Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connections.insert(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveRequest(from: connection)
            case .failed, .cancelled:
                self?.connections.remove(connection)
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                self.processRequest(data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
                self.connections.remove(connection)
            } else if error == nil {
                self.receiveRequest(from: connection)
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        requestCount += 1
        
        guard let request = String(data: data, encoding: .utf8) else {
            sendErrorResponse(.badRequest, to: connection)
            return
        }
        
        logger.debug("Received request: \(request.prefix(200))")
        
        // Apply delay if configured
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
        
        // Check for simulated error
        if let error = currentError {
            sendErrorResponse(error, to: connection)
            return
        }
        
        // Parse HTTP request
        let lines = request.split(separator: "\r\n")
        guard let firstLine = lines.first else {
            sendErrorResponse(.badRequest, to: connection)
            return
        }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendErrorResponse(.badRequest, to: connection)
            return
        }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        // Extract headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                headers[String(headerParts[0]).trimmingCharacters(in: .whitespaces)] = 
                    String(headerParts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Extract body if present
        var body: Data?
        if let bodyStart = request.range(of: "\r\n\r\n") {
            let bodyData = data[data.index(data.startIndex, offsetBy: bodyStart.upperBound.utf16Offset(in: request))...]
            if !bodyData.isEmpty {
                body = bodyData
            }
        }
        
        // Route request
        handleRoute(method: method, path: path, headers: headers, body: body, connection: connection)
    }
    
    private func handleRoute(method: String, path: String, headers: [String: String], body: Data?, connection: NWConnection) {
        // Check for custom response template
        let routeKey = "\(method) \(path)"
        if let template = responseTemplates[routeKey] {
            sendResponse(template, to: connection)
            return
        }
        
        // Default routing
        switch (method, path) {
        case ("GET", "/health"):
            sendHealthResponse(to: connection)
            
        case ("POST", "/v1/auth/register"):
            sendAuthResponse(isRegistration: true, to: connection)
            
        case ("POST", "/v1/auth/login"):
            sendAuthResponse(isRegistration: false, to: connection)
            
        case ("POST", "/v1/auth/refresh"):
            sendTokenRefreshResponse(to: connection)
            
        case ("POST", "/v1/auth/logout"):
            sendLogoutResponse(to: connection)
            
        case ("GET", "/v1/projects"):
            sendProjectsListResponse(to: connection)
            
        case ("POST", "/v1/projects"):
            sendCreateProjectResponse(body: body, to: connection)
            
        case ("GET", let p) where p.starts(with: "/v1/projects/"):
            sendProjectDetailsResponse(projectId: String(p.dropFirst(13)), to: connection)
            
        case ("GET", "/v1/sessions"):
            sendSessionsListResponse(to: connection)
            
        case ("POST", "/v1/sessions"):
            sendCreateSessionResponse(body: body, to: connection)
            
        case ("POST", "/v1/chat/completions"):
            sendChatCompletionResponse(body: body, to: connection)
            
        case ("POST", "/v1/files/upload"):
            sendFileUploadResponse(to: connection)
            
        case ("GET", let p) where p.starts(with: "/v1/files/"):
            sendFileDownloadResponse(to: connection)
            
        case ("DELETE", let p) where p.starts(with: "/v1/files/"):
            sendDeleteResponse(to: connection)
            
        case ("GET", "/v1/models/capabilities"):
            sendModelCapabilitiesResponse(to: connection)
            
        case ("GET", "/v1/sessions/stats"):
            sendSessionStatsResponse(to: connection)
            
        case ("GET", "/ws"):
            handleWebSocketUpgrade(headers: headers, connection: connection)
            
        case ("GET", "/stream"):
            handleSSEConnection(connection: connection)
            
        default:
            sendErrorResponse(.notFound, to: connection)
        }
    }
    
    // MARK: - Response Handlers
    
    private func sendHealthResponse(to connection: NWConnection) {
        let response = """
        {
            "ok": true,
            "version": "1.0.0-mock",
            "active_sessions": 5,
            "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendAuthResponse(isRegistration: Bool, to connection: NWConnection) {
        let userId = UUID().uuidString
        let response = """
        {
            "access_token": "mock_access_\(UUID().uuidString)",
            "refresh_token": "mock_refresh_\(UUID().uuidString)",
            "token_type": "bearer",
            "expires_in": 3600,
            "user": {
                "id": "\(userId)",
                "email": "test@claudecode.io",
                "username": "testuser",
                "created_at": "\(ISO8601DateFormatter().string(from: Date()))"
            }
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendTokenRefreshResponse(to connection: NWConnection) {
        let response = """
        {
            "access_token": "mock_refreshed_access_\(UUID().uuidString)",
            "refresh_token": "mock_refreshed_refresh_\(UUID().uuidString)",
            "token_type": "bearer",
            "expires_in": 3600
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendLogoutResponse(to connection: NWConnection) {
        let response = """
        {
            "message": "Successfully logged out"
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendProjectsListResponse(to connection: NWConnection) {
        let response = """
        [
            {
                "id": "proj_1",
                "name": "Test Project 1",
                "description": "First test project",
                "path": "/path/to/project1",
                "createdAt": "2024-01-01T00:00:00Z",
                "updatedAt": "2024-01-01T00:00:00Z"
            },
            {
                "id": "proj_2",
                "name": "Test Project 2",
                "description": "Second test project",
                "path": "/path/to/project2",
                "createdAt": "2024-01-02T00:00:00Z",
                "updatedAt": "2024-01-02T00:00:00Z"
            }
        ]
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendCreateProjectResponse(body: Data?, to connection: NWConnection) {
        let projectId = UUID().uuidString
        let response = """
        {
            "id": "\(projectId)",
            "name": "New Test Project",
            "description": "Created via mock server",
            "path": "/path/to/new/project",
            "createdAt": "\(ISO8601DateFormatter().string(from: Date()))",
            "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendProjectDetailsResponse(projectId: String, to connection: NWConnection) {
        let response = """
        {
            "id": "\(projectId)",
            "name": "Test Project",
            "description": "Detailed project information",
            "path": "/path/to/project",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendSessionsListResponse(to connection: NWConnection) {
        let response = """
        [
            {
                "id": "session_1",
                "project_id": "proj_1",
                "title": "Test Session 1",
                "model": "claude-3-opus-20240229",
                "system_prompt": "You are a helpful assistant.",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z",
                "is_active": true,
                "total_tokens": 1000,
                "total_cost": 0.05,
                "message_count": 10
            }
        ]
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendCreateSessionResponse(body: Data?, to connection: NWConnection) {
        let sessionId = UUID().uuidString
        let response = """
        {
            "id": "\(sessionId)",
            "project_id": "proj_1",
            "title": "New Test Session",
            "model": "claude-3-opus-20240229",
            "system_prompt": "You are a helpful assistant.",
            "created_at": "\(ISO8601DateFormatter().string(from: Date()))",
            "updated_at": "\(ISO8601DateFormatter().string(from: Date()))",
            "is_active": true,
            "total_tokens": 0,
            "total_cost": 0.0,
            "message_count": 0
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendChatCompletionResponse(body: Data?, to connection: NWConnection) {
        let response = """
        {
            "id": "chatcmpl_\(UUID().uuidString)",
            "object": "chat.completion",
            "created": \(Int(Date().timeIntervalSince1970)),
            "model": "claude-3-opus-20240229",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "This is a mock response from the test server."
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendFileUploadResponse(to connection: NWConnection) {
        let fileId = UUID().uuidString
        let response = """
        {
            "id": "\(fileId)",
            "filename": "test_file.txt",
            "size": 1024,
            "mime_type": "text/plain",
            "uploaded_at": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendFileDownloadResponse(to connection: NWConnection) {
        let fileContent = "This is mock file content for testing."
        let response = "HTTP/1.1 200 OK\r\n" +
            "Content-Type: text/plain\r\n" +
            "Content-Length: \(fileContent.count)\r\n" +
            "\r\n" +
            fileContent
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendDeleteResponse(to connection: NWConnection) {
        let response = "HTTP/1.1 204 No Content\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendModelCapabilitiesResponse(to connection: NWConnection) {
        let response = """
        {
            "models": [
                {
                    "id": "claude-3-opus-20240229",
                    "name": "Claude 3 Opus",
                    "description": "Most capable model",
                    "maxTokens": 200000,
                    "supportsStreaming": true,
                    "supportsTools": true
                },
                {
                    "id": "claude-3-sonnet-20240229",
                    "name": "Claude 3 Sonnet",
                    "description": "Balanced model",
                    "maxTokens": 200000,
                    "supportsStreaming": true,
                    "supportsTools": true
                }
            ]
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    private func sendSessionStatsResponse(to connection: NWConnection) {
        let response = """
        {
            "activeSessions": 5,
            "totalTokens": 150000,
            "totalCost": 7.50,
            "totalMessages": 250
        }
        """
        sendJSONResponse(response, to: connection)
    }
    
    // MARK: - WebSocket Handling
    
    private func handleWebSocketUpgrade(headers: [String: String], connection: NWConnection) {
        // Simplified WebSocket handshake
        let acceptKey = "mock_websocket_accept_key"
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            // Start WebSocket communication
            self.handleWebSocketConnection(connection)
        })
    }
    
    private func handleWebSocketConnection(_ connection: NWConnection) {
        // Send periodic ping messages
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            let pingMessage = """
            {"type": "ping", "timestamp": \(Date().timeIntervalSince1970)}
            """
            
            // WebSocket frame (simplified)
            var frame = Data()
            frame.append(0x81) // FIN + text frame
            frame.append(UInt8(pingMessage.count)) // Payload length
            frame.append(pingMessage.data(using: .utf8)!)
            
            connection.send(content: frame, completion: .contentProcessed { _ in
                // Check if connection is still active
                if connection.state != .ready {
                    timer.invalidate()
                }
            })
        }
    }
    
    // MARK: - SSE Handling
    
    private func handleSSEConnection(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/event-stream\r
        Cache-Control: no-cache\r
        Connection: keep-alive\r
        \r
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            // Send periodic events
            self.sendSSEEvents(to: connection)
        })
    }
    
    private func sendSSEEvents(to connection: NWConnection) {
        var eventCount = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            eventCount += 1
            
            let event = """
            data: {"type": "update", "count": \(eventCount), "timestamp": \(Date().timeIntervalSince1970)}\n\n
            """
            
            connection.send(content: event.data(using: .utf8), completion: .contentProcessed { _ in
                // Stop after 10 events or if connection closed
                if eventCount >= 10 || connection.state != .ready {
                    timer.invalidate()
                    connection.cancel()
                }
            })
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendJSONResponse(_ json: String, statusCode: Int = 200, to connection: NWConnection) {
        let response = "HTTP/1.1 \(statusCode) OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(json.count)\r\n" +
            "\r\n" +
            json
        
        sendResponse(MockResponse(statusCode: statusCode, body: json, contentType: "application/json"), to: connection)
    }
    
    private func sendErrorResponse(_ error: ServerError, to connection: NWConnection) {
        errorCount += 1
        
        let errorBody = """
        {
            "error": {
                "code": \(error.statusCode),
                "message": "\(error.message)",
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
            }
        }
        """
        
        let response = "HTTP/1.1 \(error.statusCode) \(error.message)\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(errorBody.count)\r\n" +
            "\r\n" +
            errorBody
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendResponse(_ response: MockResponse, to connection: NWConnection) {
        let httpResponse = "HTTP/1.1 \(response.statusCode) OK\r\n" +
            "Content-Type: \(response.contentType)\r\n" +
            "Content-Length: \(response.body.count)\r\n" +
            response.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") +
            "\r\n\r\n" +
            response.body
        
        connection.send(content: httpResponse.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    // MARK: - Configuration Methods
    
    public func addDelay(seconds: TimeInterval) {
        delay = seconds
    }
    
    public func removeDelay() {
        delay = 0
    }
    
    public func simulateError(_ error: ServerError?) {
        currentError = error
    }
    
    public func clearError() {
        currentError = nil
    }
    
    public func setCustomResponse(for route: String, response: MockResponse) {
        responseTemplates[route] = response
    }
    
    public func clearCustomResponses() {
        responseTemplates.removeAll()
        setupDefaultResponses()
    }
    
    private func setupDefaultResponses() {
        // Set up any default custom responses if needed
    }
    
    // MARK: - Statistics
    
    public func getStatistics() -> (requests: Int, errors: Int) {
        return (requestCount, errorCount)
    }
    
    public func resetStatistics() {
        requestCount = 0
        errorCount = 0
    }
}

// MARK: - Supporting Types

public struct MockResponse {
    let statusCode: Int
    let body: String
    let contentType: String
    let headers: [String: String]
    
    public init(statusCode: Int = 200, 
                body: String, 
                contentType: String = "application/json",
                headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
        self.headers = headers
    }
}