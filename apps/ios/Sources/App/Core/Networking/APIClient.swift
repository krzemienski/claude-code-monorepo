import Foundation
import OSLog

public struct APIClient: APIClientProtocol {
    public let baseURL: URL
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "APIClient")

    @MainActor
    public init?(settings: AppSettings) {
        guard let url = settings.baseURLValidated else { 
            Logger(subsystem: "com.claudecode.ios", category: "APIClient").error("Invalid base URL from settings")
            return nil 
        }
        self.baseURL = url
        logger.info("APIClient initialized with baseURL: \(url.absoluteString)")
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        logger.debug("Creating \(method) request to: \(url.absoluteString)")
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30 // 30 second timeout
        
        if let body { 
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            logger.debug("Request body size: \(body.count) bytes")
        }
        
        return req
    }

    private func data(for req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        logger.info("Sending request to: \(req.url?.absoluteString ?? "unknown")")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { 
                logger.error("Response is not HTTPURLResponse")
                throw URLError(.badServerResponse) 
            }
            
            logger.info("Response status: \(http.statusCode), data size: \(data.count) bytes")
            
            if !(200..<300).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "No body"
                logger.error("HTTP error \(http.statusCode): \(bodyString)")
            }
            
            return (data, http)
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            throw error
        }
    }

    // Generic JSON helpers
    public func getJSON<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let req = request(path: path, method: "GET")
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        let payload = try JSONEncoder().encode(body)
        let req = request(path: path, method: "POST", body: payload)
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func delete(_ path: String) async throws {
        let req = request(path: path, method: "DELETE")
        let (_, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: nil) }
    }

    public struct APIError: Error, CustomStringConvertible {
        public let status: Int
        public let body: String?
        public var description: String { "HTTP \(status) \(body ?? "")" }
    }

    // ---- Typed endpoints

    public struct HealthResponse: Decodable { 
        public let ok: Bool
        public let version: String?
        public let active_sessions: Int?
        
        // Custom decoder to handle both response formats
        public enum CodingKeys: String, CodingKey {
            case ok, status, version, active_sessions, timestamp
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try to decode 'ok' field first (old format)
            if let okValue = try? container.decode(Bool.self, forKey: .ok) {
                self.ok = okValue
                self.version = try? container.decode(String.self, forKey: .version)
                self.active_sessions = try? container.decode(Int.self, forKey: .active_sessions)
            } else {
                // Fall back to 'status' field (new format)
                let status = try container.decode(String.self, forKey: .status)
                self.ok = (status == "healthy")
                self.version = nil
                self.active_sessions = nil
            }
        }
    }
    public func health() async throws -> HealthResponse { try await getJSON("/health", as: HealthResponse.self) }

    public struct Project: Codable, Identifiable {
        public let id: String; public let name: String; public let description: String; public let path: String?
        public let createdAt: String; public let updatedAt: String
    }
    public func listProjects() async throws -> [Project] { try await getJSON("/v1/projects", as: [Project].self) }
    public struct NewProjectBody: Encodable { public let name: String; public let description: String; public let path: String? }
    public func createProject(name: String, description: String, path: String?) async throws -> Project {
        try await postJSON("/v1/projects", body: NewProjectBody(name: name, description: description, path: path), as: Project.self)
    }
    public func getProject(id: String) async throws -> Project { try await getJSON("/v1/projects/\(id)", as: Project.self) }

    public struct Session: Codable, Identifiable {
        public let id: String
        public let projectId: String
        public let title: String?
        public let model: String
        public let systemPrompt: String?
        public let createdAt: String
        public let updatedAt: String
        public var isActive: Bool
        public let totalTokens: Int?
        public let totalCost: Double?
        public let messageCount: Int?
        
        public enum CodingKeys: String, CodingKey {
            case id
            case projectId = "project_id"
            case title
            case model
            case systemPrompt = "system_prompt"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case isActive = "is_active"
            case totalTokens = "total_tokens"
            case totalCost = "total_cost"
            case messageCount = "message_count"
        }
    }
    public func listSessions(projectId: String? = nil) async throws -> [Session] {
        let path = projectId.map { "/v1/sessions?project_id=\($0)" } ?? "/v1/sessions"
        return try await getJSON(path, as: [Session].self)
    }
    public struct NewSessionBody: Encodable { public let project_id: String; public let model: String; public let title: String?; public let system_prompt: String? }
    public func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> Session {
        let body = NewSessionBody(project_id: projectId, model: model, title: title, system_prompt: systemPrompt)
        return try await postJSON("/v1/sessions", body: body, as: Session.self)
    }

    public struct ModelCapability: Decodable, Identifiable {
        public let id: String; public let name: String; public let description: String
        public let maxTokens: Int; public let supportsStreaming: Bool; public let supportsTools: Bool
    }
    public struct CapabilitiesEnvelope: Decodable { public let models: [ModelCapability] }
    public func modelCapabilities() async throws -> [ModelCapability] {
        try await getJSON("/v1/models/capabilities", as: CapabilitiesEnvelope.self).models
    }

    public struct SessionStats: Codable { public let activeSessions: Int; public let totalTokens: Int; public let totalCost: Double; public let totalMessages: Int }
    public func sessionStats() async throws -> SessionStats { try await getJSON("/v1/sessions/stats", as: SessionStats.self) }
    
    // MARK: - Message Management Endpoints
    public struct Message: Codable {
        public let id: String
        public let sessionId: String
        public let role: String
        public let content: String
        public let tokenCount: Int
        public let metadata: [String: Any]?
        public let createdAt: String
        
        public enum CodingKeys: String, CodingKey {
            case id
            case sessionId = "session_id"
            case role
            case content
            case tokenCount = "token_count"
            case metadata = "message_metadata"
            case createdAt = "created_at"
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            sessionId = try container.decode(String.self, forKey: .sessionId)
            role = try container.decode(String.self, forKey: .role)
            content = try container.decode(String.self, forKey: .content)
            tokenCount = try container.decodeIfPresent(Int.self, forKey: .tokenCount) ?? 0
            metadata = try container.decodeIfPresent([String: Any].self, forKey: .metadata)
            createdAt = try container.decode(String.self, forKey: .createdAt)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
            try container.encode(tokenCount, forKey: .tokenCount)
            try container.encode(createdAt, forKey: .createdAt)
        }
    }
    
    public struct MessageListResponse: Codable {
        public let messages: [Message]
        public let total: Int
        public let limit: Int
        public let offset: Int
        public let sessionId: String
        
        public enum CodingKeys: String, CodingKey {
            case messages, total, limit, offset
            case sessionId = "session_id"
        }
    }
    
    public func getSessionMessages(sessionId: String, limit: Int = 100, offset: Int = 0, role: String? = nil) async throws -> MessageListResponse {
        var path = "/v1/sessions/\(sessionId)/messages?limit=\(limit)&offset=\(offset)"
        if let role = role {
            path += "&role=\(role)"
        }
        return try await getJSON(path, as: MessageListResponse.self)
    }
    
    // Additional missing endpoints
    public func deleteCompletion(id: String) async throws {
        try await delete("/v1/chat/completions/\(id)")
    }
    
    public struct DebugRequest: Encodable {
        public let sessionId: String
        public let prompt: String
        public let includeContext: Bool
    }
    
    public struct DebugResponse: Decodable {
        public let sessionId: String
        public let context: String
        public let tokens: Int
        public let modelState: String
    }
    
    public func debugCompletion(sessionId: String, prompt: String, includeContext: Bool = true) async throws -> DebugResponse {
        let body = DebugRequest(sessionId: sessionId, prompt: prompt, includeContext: includeContext)
        return try await postJSON("/v1/chat/completions/debug", body: body, as: DebugResponse.self)
    }
    
    public struct SessionToolsRequest: Encodable {
        public let tools: [String]
        public let priority: Int?
    }
    
    public struct SessionToolsResponse: Decodable {
        public let sessionId: String
        public let enabledTools: [String]
        public let message: String
    }
    
    // MARK: - Tool Execution Endpoints
    public struct ToolExecution: Codable {
        public let id: String
        public let toolName: String
        public let toolType: String
        public let inputParams: [String: Any]?
        public let output: [String: Any]?
        public let status: String
        public let errorMessage: String?
        public let executionTimeMs: Int?
        public let createdAt: String
        public let completedAt: String?
        
        public enum CodingKeys: String, CodingKey {
            case id
            case toolName = "tool_name"
            case toolType = "tool_type"
            case inputParams = "input_params"
            case output
            case status
            case errorMessage = "error_message"
            case executionTimeMs = "execution_time_ms"
            case createdAt = "created_at"
            case completedAt = "completed_at"
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            toolName = try container.decode(String.self, forKey: .toolName)
            toolType = try container.decode(String.self, forKey: .toolType)
            inputParams = try container.decodeIfPresent([String: Any].self, forKey: .inputParams)
            output = try container.decodeIfPresent([String: Any].self, forKey: .output)
            status = try container.decode(String.self, forKey: .status)
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            executionTimeMs = try container.decodeIfPresent(Int.self, forKey: .executionTimeMs)
            createdAt = try container.decode(String.self, forKey: .createdAt)
            completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(toolName, forKey: .toolName)
            try container.encode(toolType, forKey: .toolType)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
            try container.encodeIfPresent(executionTimeMs, forKey: .executionTimeMs)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(completedAt, forKey: .completedAt)
        }
    }
    
    public struct ToolExecutionResponse: Codable {
        public let executions: [ToolExecution]
        public let total: Int
        public let sessionId: String
        
        public enum CodingKeys: String, CodingKey {
            case executions, total
            case sessionId = "session_id"
        }
    }
    
    public func getSessionTools(sessionId: String, toolType: String? = nil, status: String? = nil, limit: Int = 100) async throws -> ToolExecutionResponse {
        var path = "/v1/sessions/\(sessionId)/tools?limit=\(limit)"
        if let toolType = toolType {
            path += "&tool_type=\(toolType)"
        }
        if let status = status {
            path += "&status=\(status)"
        }
        return try await getJSON(path, as: ToolExecutionResponse.self)
    }
    
    public func updateSessionTools(sessionId: String, tools: [String], priority: Int? = nil) async throws -> SessionToolsResponse {
        let body = SessionToolsRequest(tools: tools, priority: priority)
        return try await postJSON("/v1/sessions/\(sessionId)/tools", body: body, as: SessionToolsResponse.self)
    }
    
    // MARK: - User Profile Endpoints
    public struct UserProfile: Codable {
        public let id: String
        public let email: String
        public let username: String?
        public let roles: [String]
        public let permissions: [String]
        public let preferences: [String: Any]?
        public let createdAt: String
        public let updatedAt: String
        public let lastLogin: String?
        public let isActive: Bool
        public let sessionCount: Int
        public let messageCount: Int
        public let tokenUsage: [String: Int]
        
        public enum CodingKeys: String, CodingKey {
            case id, email, username, roles, permissions, preferences
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case lastLogin = "last_login"
            case isActive = "is_active"
            case sessionCount = "session_count"
            case messageCount = "message_count"
            case tokenUsage = "token_usage"
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            email = try container.decode(String.self, forKey: .email)
            username = try container.decodeIfPresent(String.self, forKey: .username)
            roles = try container.decode([String].self, forKey: .roles)
            permissions = try container.decode([String].self, forKey: .permissions)
            preferences = try container.decodeIfPresent([String: Any].self, forKey: .preferences)
            createdAt = try container.decode(String.self, forKey: .createdAt)
            updatedAt = try container.decode(String.self, forKey: .updatedAt)
            lastLogin = try container.decodeIfPresent(String.self, forKey: .lastLogin)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            sessionCount = try container.decode(Int.self, forKey: .sessionCount)
            messageCount = try container.decode(Int.self, forKey: .messageCount)
            tokenUsage = try container.decode([String: Int].self, forKey: .tokenUsage)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(email, forKey: .email)
            try container.encodeIfPresent(username, forKey: .username)
            try container.encode(roles, forKey: .roles)
            try container.encode(permissions, forKey: .permissions)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(lastLogin, forKey: .lastLogin)
            try container.encode(isActive, forKey: .isActive)
            try container.encode(sessionCount, forKey: .sessionCount)
            try container.encode(messageCount, forKey: .messageCount)
            try container.encode(tokenUsage, forKey: .tokenUsage)
        }
    }
    
    public struct UserProfileUpdate: Encodable {
        public let username: String?
        public let preferences: [String: Any]?
    }
    
    public func getUserProfile() async throws -> UserProfile {
        let path = "/v1/user/profile"
        return try await getJSON(path, as: UserProfile.self)
    }
    
    public func updateUserProfile(username: String? = nil, preferences: [String: Any]? = nil) async throws -> UserProfile {
        let body = UserProfileUpdate(username: username, preferences: preferences)
        return try await postJSON("/v1/user/profile", body: body, as: UserProfile.self)
    }
    
    private struct EmptyBody: Encodable {}
    
    // MARK: - Request Cancellation
    public func cancelAllRequests() {
        // Cancel all ongoing URLSession tasks
        URLSession.shared.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}
