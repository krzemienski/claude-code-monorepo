import Foundation
import OSLog

// MARK: - Actor-based API Client with Advanced Networking

/// API client that leverages NetworkingActor for thread-safe, high-performance networking
@MainActor
final class ActorAPIClient: APIClientProtocol {
    
    // MARK: - Properties
    
    let baseURL: URL
    let apiKey: String?
    private let networkingActor: NetworkingActor
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ActorAPIClient")
    
    // Performance tracking
    private var metrics = ActorAPIMetrics()
    
    // MARK: - Initialization
    
    init?(settings: AppSettings, networkingActor: NetworkingActor? = nil) {
        guard let url = URL(string: settings.baseURL) else {
            return nil
        }
        
        self.baseURL = url
        self.apiKey = settings.apiKeyPlaintext.isEmpty ? nil : settings.apiKeyPlaintext
        self.networkingActor = networkingActor ?? NetworkingActor(retryPolicy: .default)
        
        logger.info("🚀 ActorAPIClient initialized with base URL: \(url)")
    }
    
    // MARK: - APIClientProtocol Implementation
    
    func health() async throws -> APIClient.HealthResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/health", duration: duration)
        }
        
        let request = try buildRequest(path: "/health", method: "GET")
        
        return try await networkingActor.request(
            request,
            as: APIClient.HealthResponse.self,
            priority: .high,
            group: "health"
        )
    }
    
    func listProjects() async throws -> [APIClient.Project] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/projects", duration: duration)
        }
        
        let request = try buildRequest(path: "/projects", method: "GET")
        
        return try await networkingActor.request(
            request,
            as: [APIClient.Project].self,
            priority: .medium,
            group: "projects"
        )
    }
    
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/projects", duration: duration)
        }
        
        let body = [
            "name": name,
            "description": description,
            "path": path ?? ""
        ]
        
        let request = try buildRequest(
            path: "/projects",
            method: "POST",
            body: body
        )
        
        return try await networkingActor.request(
            request,
            as: APIClient.Project.self,
            priority: .high,
            group: "projects"
        )
    }
    
    func getProject(id: String) async throws -> APIClient.Project {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/projects/\(id)", duration: duration)
        }
        
        let request = try buildRequest(path: "/projects/\(id)", method: "GET")
        
        return try await networkingActor.request(
            request,
            as: APIClient.Project.self,
            priority: .medium,
            group: "projects"
        )
    }
    
    func listSessions(projectId: String? = nil) async throws -> [APIClient.Session] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions", duration: duration)
        }
        
        var path = "/sessions"
        if let projectId = projectId {
            path += "?project_id=\(projectId)"
        }
        
        let request = try buildRequest(path: path, method: "GET")
        
        return try await networkingActor.request(
            request,
            as: [APIClient.Session].self,
            priority: .medium,
            group: "sessions"
        )
    }
    
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions", duration: duration)
        }
        
        var body: [String: Any] = [
            "project_id": projectId,
            "model": model
        ]
        
        if let title = title {
            body["title"] = title
        }
        
        if let systemPrompt = systemPrompt {
            body["system_prompt"] = systemPrompt
        }
        
        let request = try buildRequest(
            path: "/sessions",
            method: "POST",
            body: body
        )
        
        return try await networkingActor.request(
            request,
            as: APIClient.Session.self,
            priority: .high,
            group: "sessions"
        )
    }
    
    func modelCapabilities() async throws -> [APIClient.ModelCapability] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/models/capabilities", duration: duration)
        }
        
        let request = try buildRequest(path: "/models/capabilities", method: "GET")
        
        return try await networkingActor.request(
            request,
            as: [APIClient.ModelCapability].self,
            priority: .low,
            group: "models"
        )
    }
    
    func sessionStats() async throws -> APIClient.SessionStats {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions/stats", duration: duration)
        }
        
        let request = try buildRequest(path: "/sessions/stats", method: "GET")
        
        return try await networkingActor.request(
            request,
            as: APIClient.SessionStats.self,
            priority: .low,
            group: "stats"
        )
    }
    
    func deleteCompletion(id: String) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/completions/\(id)", duration: duration)
        }
        
        let request = try buildRequest(path: "/completions/\(id)", method: "DELETE")
        
        _ = try await networkingActor.request(
            request,
            as: EmptyResponse.self,
            priority: .medium,
            group: "completions"
        )
    }
    
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool) async throws -> APIClient.DebugResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/debug/completion", duration: duration)
        }
        
        let body: [String: Any] = [
            "session_id": sessionId,
            "prompt": prompt,
            "include_context": includeContext
        ]
        
        let request = try buildRequest(
            path: "/debug/completion",
            method: "POST",
            body: body
        )
        
        return try await networkingActor.request(
            request,
            as: APIClient.DebugResponse.self,
            priority: .low,
            group: "debug"
        )
    }
    
    func updateSessionTools(sessionId: String, tools: [String], priority: Int?) async throws -> APIClient.SessionToolsResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions/\(sessionId)/tools", duration: duration)
        }
        
        var body: [String: Any] = [
            "tools": tools
        ]
        
        if let priority = priority {
            body["priority"] = priority
        }
        
        let request = try buildRequest(
            path: "/sessions/\(sessionId)/tools",
            method: "PUT",
            body: body
        )
        
        return try await networkingActor.request(
            request,
            as: APIClient.SessionToolsResponse.self,
            priority: .medium,
            group: "sessions"
        )
    }
    
    func cancelAllRequests() {
        Task {
            await networkingActor.cancelAll()
        }
        logger.info("❌ Cancelled all requests")
    }
    
    // MARK: - Batch Operations
    
    /// Perform multiple API requests in parallel with controlled concurrency
    func batchRequests<T: Decodable>(
        requests: [(path: String, method: String, body: [String: Any]?)],
        as type: T.Type,
        maxConcurrency: Int = 3
    ) async throws -> [Result<T, Error>] {
        let urlRequests = try requests.map { request in
            try buildRequest(
                path: request.path,
                method: request.method,
                body: request.body
            )
        }
        
        return try await networkingActor.batchRequests(
            urlRequests,
            as: type,
            maxConcurrency: maxConcurrency
        )
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add API key if available
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Add common headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    // MARK: - Metrics
    
    func getMetrics() -> ActorAPIMetrics {
        return metrics
    }
    
    func resetMetrics() {
        metrics = ActorAPIMetrics()
    }
}

// MARK: - Empty Response for DELETE operations

private struct EmptyResponse: Decodable {}

// MARK: - API Metrics

struct ActorAPIMetrics {
    private(set) var requestCounts: [String: Int] = [:]
    private(set) var averageResponseTimes: [String: TimeInterval] = [:]
    private var responseTimes: [String: [TimeInterval]] = [:]
    
    mutating func recordRequest(endpoint: String, duration: TimeInterval) {
        // Update count
        requestCounts[endpoint, default: 0] += 1
        
        // Update response times
        var times = responseTimes[endpoint, default: []]
        times.append(duration)
        responseTimes[endpoint] = times
        
        // Calculate average
        let average = times.reduce(0, +) / Double(times.count)
        averageResponseTimes[endpoint] = average
    }
    
    var totalRequests: Int {
        requestCounts.values.reduce(0, +)
    }
    
    var overallAverageResponseTime: TimeInterval {
        guard !averageResponseTimes.isEmpty else { return 0 }
        let sum = averageResponseTimes.values.reduce(0, +)
        return sum / Double(averageResponseTimes.count)
    }
    
    func slowestEndpoint() -> (endpoint: String, averageTime: TimeInterval)? {
        averageResponseTimes.max { $0.value < $1.value }
            .map { ($0.key, $0.value) }
    }
    
    func fastestEndpoint() -> (endpoint: String, averageTime: TimeInterval)? {
        averageResponseTimes.min { $0.value < $1.value }
            .map { ($0.key, $0.value) }
    }
}