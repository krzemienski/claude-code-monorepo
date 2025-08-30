import Foundation
@testable import ClaudeCode

/// Mock API Client for testing
@MainActor
class MockAPIClient: APIClientProtocol {
    
    // Required protocol properties
    var baseURL: URL = URL(string: "http://localhost:8000")!
    var apiKey: String? = "test-api-key"
    
    // Track API calls for verification
    var calledEndpoints: [String] = []
    var requestBodies: [Data] = []
    var requestHeaders: [[String: String]] = []
    
    // Configure responses
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    var mockDelay: TimeInterval = 0
    
    // MARK: - Mock Configuration
    
    func setMockResponse<T: Encodable>(for endpoint: String, response: T) {
        mockResponses[endpoint] = response
    }
    
    func setMockError(for endpoint: String, error: Error) {
        mockErrors[endpoint] = error
    }
    
    // MARK: - APIClientProtocol Implementation
    
    func getJSON<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        recordCall(endpoint: endpoint, headers: headers)
        
        if let error = mockErrors[endpoint] {
            throw error
        }
        
        if let response = mockResponses[endpoint] {
            if let typedResponse = response as? T {
                return typedResponse
            }
            
            // Convert to JSON and decode
            let data = try JSONSerialization.data(withJSONObject: response)
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        throw APIError.noData
    }
    
    func postJSON<T: Decodable, U: Encodable>(
        _ endpoint: String,
        body: U,
        headers: [String: String]? = nil
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        recordCall(endpoint: endpoint, body: bodyData, headers: headers)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if let error = mockErrors[endpoint] {
            throw error
        }
        
        if let response = mockResponses[endpoint] {
            if let typedResponse = response as? T {
                return typedResponse
            }
            
            let data = try JSONSerialization.data(withJSONObject: response)
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        throw APIError.noData
    }
    
    func deleteJSON(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws {
        recordCall(endpoint: endpoint, headers: headers)
        
        if let error = mockErrors[endpoint] {
            throw error
        }
    }
    
    // MARK: - Verification Helpers
    
    func verifyEndpointCalled(_ endpoint: String) -> Bool {
        calledEndpoints.contains(endpoint)
    }
    
    func verifyEndpointCalledTimes(_ endpoint: String, times: Int) -> Bool {
        calledEndpoints.filter { $0 == endpoint }.count == times
    }
    
    func reset() {
        calledEndpoints.removeAll()
        requestBodies.removeAll()
        requestHeaders.removeAll()
        mockResponses.removeAll()
        mockErrors.removeAll()
        mockDelay = 0
    }
    
    // MARK: - Private
    
    private func recordCall(
        endpoint: String,
        body: Data? = nil,
        headers: [String: String]?
    ) {
        calledEndpoints.append(endpoint)
        if let body = body {
            requestBodies.append(body)
        }
        requestHeaders.append(headers ?? [:])
    }
    
    // MARK: - Required APIClientProtocol Methods
    
    func health() async throws -> APIClient.HealthResponse {
        calledEndpoints.append("health")
        if let error = mockErrors["health"] {
            throw error
        }
        return mockResponses["health"] as? APIClient.HealthResponse ?? APIClient.HealthResponse(ok: true, version: "1.0.0", active_sessions: 0)
    }
    
    func listProjects() async throws -> [APIClient.Project] {
        calledEndpoints.append("listProjects")
        if let error = mockErrors["listProjects"] {
            throw error
        }
        return mockResponses["listProjects"] as? [APIClient.Project] ?? []
    }
    
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project {
        calledEndpoints.append("createProject")
        if let error = mockErrors["createProject"] {
            throw error
        }
        return mockResponses["createProject"] as? APIClient.Project ?? APIClient.Project(
            id: UUID().uuidString,
            name: name,
            description: description,
            path: path ?? "/test",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func getProject(id: String) async throws -> APIClient.Project {
        calledEndpoints.append("getProject")
        if let error = mockErrors["getProject"] {
            throw error
        }
        return mockResponses["getProject"] as? APIClient.Project ?? APIClient.Project(
            id: id,
            name: "Test Project",
            description: "Test",
            path: "/test",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func listSessions(projectId: String?) async throws -> [APIClient.Session] {
        calledEndpoints.append("listSessions")
        if let error = mockErrors["listSessions"] {
            throw error
        }
        return mockResponses["listSessions"] as? [APIClient.Session] ?? []
    }
    
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session {
        calledEndpoints.append("createSession")
        if let error = mockErrors["createSession"] {
            throw error
        }
        return mockResponses["createSession"] as? APIClient.Session ?? APIClient.Session(
            id: UUID().uuidString,
            projectId: projectId,
            title: title ?? "Test Session",
            model: model,
            systemPrompt: systemPrompt,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isActive: true,
            totalTokens: 0,
            totalCost: 0,
            messageCount: 0
        )
    }
    
    func modelCapabilities() async throws -> [APIClient.ModelCapability] {
        calledEndpoints.append("modelCapabilities")
        if let error = mockErrors["modelCapabilities"] {
            throw error
        }
        return mockResponses["modelCapabilities"] as? [APIClient.ModelCapability] ?? []
    }
    
    func sessionStats() async throws -> APIClient.SessionStats {
        calledEndpoints.append("sessionStats")
        if let error = mockErrors["sessionStats"] {
            throw error
        }
        return mockResponses["sessionStats"] as? APIClient.SessionStats ?? APIClient.SessionStats(
            activeSessions: 0,
            totalTokens: 0,
            totalCost: 0,
            totalMessages: 0
        )
    }
    
    func deleteCompletion(id: String) async throws {
        calledEndpoints.append("deleteCompletion")
        if let error = mockErrors["deleteCompletion"] {
            throw error
        }
    }
    
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool) async throws -> APIClient.DebugResponse {
        calledEndpoints.append("debugCompletion")
        if let error = mockErrors["debugCompletion"] {
            throw error
        }
        return mockResponses["debugCompletion"] as? APIClient.DebugResponse ?? APIClient.DebugResponse(
            sessionId: sessionId,
            context: includeContext ? "test context" : "",
            tokens: 100
        )
    }
    
    func updateSessionTools(sessionId: String, tools: [String], priority: Int?) async throws -> APIClient.SessionToolsResponse {
        calledEndpoints.append("updateSessionTools")
        if let error = mockErrors["updateSessionTools"] {
            throw error
        }
        return mockResponses["updateSessionTools"] as? APIClient.SessionToolsResponse ?? APIClient.SessionToolsResponse(
            sessionId: sessionId,
            enabledTools: tools,
            message: "Tools updated"
        )
    }
    
    func cancelAllRequests() {
        calledEndpoints.append("cancelAllRequests")
    }
}

// Mock API Error
enum APIError: Error {
    case noData
    case invalidResponse
    case networkError
    case unauthorized
    case serverError(Int)
}