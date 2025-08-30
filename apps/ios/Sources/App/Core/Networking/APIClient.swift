import Foundation
import OSLog

struct APIClient: APIClientProtocol {
    let baseURL: URL
    let apiKey: String?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "APIClient")

    @MainActor
    init?(settings: AppSettings) {
        guard let url = settings.baseURLValidated else { 
            Logger(subsystem: "com.claudecode.ios", category: "APIClient").error("Invalid base URL from settings")
            return nil 
        }
        self.baseURL = url
        self.apiKey = settings.apiKeyPlaintext.isEmpty ? nil : settings.apiKeyPlaintext
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
        
        if let apiKey { 
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            logger.debug("Added authorization header")
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
    func getJSON<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let req = request(path: path, method: "GET")
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        let payload = try JSONEncoder().encode(body)
        let req = request(path: path, method: "POST", body: payload)
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        let req = request(path: path, method: "DELETE")
        let (_, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: nil) }
    }

    struct APIError: Error, CustomStringConvertible {
        let status: Int
        let body: String?
        var description: String { "HTTP \(status) \(body ?? "")" }
    }

    // ---- Typed endpoints

    struct HealthResponse: Decodable { 
        let ok: Bool
        let version: String?
        let active_sessions: Int?
        
        // Custom decoder to handle both response formats
        enum CodingKeys: String, CodingKey {
            case ok, status, version, active_sessions, timestamp
        }
        
        init(from decoder: Decoder) throws {
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
    func health() async throws -> HealthResponse { try await getJSON("/health", as: HealthResponse.self) }

    struct Project: Codable, Identifiable {
        let id: String; let name: String; let description: String; let path: String?
        let createdAt: String; let updatedAt: String
    }
    func listProjects() async throws -> [Project] { try await getJSON("/v1/projects", as: [Project].self) }
    struct NewProjectBody: Encodable { let name: String; let description: String; let path: String? }
    func createProject(name: String, description: String, path: String?) async throws -> Project {
        try await postJSON("/v1/projects", body: NewProjectBody(name: name, description: description, path: path), as: Project.self)
    }
    func getProject(id: String) async throws -> Project { try await getJSON("/v1/projects/\(id)", as: Project.self) }

    struct Session: Codable, Identifiable {
        let id: String; let projectId: String; let title: String?
        let model: String; let systemPrompt: String?
        let createdAt: String; let updatedAt: String
        var isActive: Bool; let totalTokens: Int?; let totalCost: Double?; let messageCount: Int?
    }
    func listSessions(projectId: String? = nil) async throws -> [Session] {
        let path = projectId.map { "/v1/sessions?project_id=\($0)" } ?? "/v1/sessions"
        return try await getJSON(path, as: [Session].self)
    }
    struct NewSessionBody: Encodable { let project_id: String; let model: String; let title: String?; let system_prompt: String? }
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> Session {
        let body = NewSessionBody(project_id: projectId, model: model, title: title, system_prompt: systemPrompt)
        return try await postJSON("/v1/sessions", body: body, as: Session.self)
    }

    struct ModelCapability: Decodable, Identifiable {
        let id: String; let name: String; let description: String
        let maxTokens: Int; let supportsStreaming: Bool; let supportsTools: Bool
    }
    struct CapabilitiesEnvelope: Decodable { let models: [ModelCapability] }
    func modelCapabilities() async throws -> [ModelCapability] {
        try await getJSON("/v1/models/capabilities", as: CapabilitiesEnvelope.self).models
    }

    struct SessionStats: Codable { let activeSessions: Int; let totalTokens: Int; let totalCost: Double; let totalMessages: Int }
    func sessionStats() async throws -> SessionStats { try await getJSON("/v1/sessions/stats", as: SessionStats.self) }
    
    // Additional missing endpoints
    func deleteCompletion(id: String) async throws {
        try await delete("/v1/chat/completions/\(id)")
    }
    
    struct DebugRequest: Encodable {
        let sessionId: String
        let prompt: String
        let includeContext: Bool
    }
    
    struct DebugResponse: Decodable {
        let sessionId: String
        let context: String
        let tokens: Int
        let modelState: String
    }
    
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool = true) async throws -> DebugResponse {
        let body = DebugRequest(sessionId: sessionId, prompt: prompt, includeContext: includeContext)
        return try await postJSON("/v1/chat/completions/debug", body: body, as: DebugResponse.self)
    }
    
    struct SessionToolsRequest: Encodable {
        let tools: [String]
        let priority: Int?
    }
    
    struct SessionToolsResponse: Decodable {
        let sessionId: String
        let enabledTools: [String]
        let message: String
    }
    
    func updateSessionTools(sessionId: String, tools: [String], priority: Int? = nil) async throws -> SessionToolsResponse {
        let body = SessionToolsRequest(tools: tools, priority: priority)
        return try await postJSON("/v1/sessions/\(sessionId)/tools", body: body, as: SessionToolsResponse.self)
    }
    
    // MARK: - Request Cancellation
    func cancelAllRequests() {
        // Cancel all ongoing URLSession tasks
        URLSession.shared.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}
