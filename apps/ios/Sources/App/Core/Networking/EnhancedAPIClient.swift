import Foundation
import OSLog

// MARK: - Enhanced API Client with Retry and Cancellation
@MainActor
final class EnhancedAPIClient: APIClientProtocol {
    let baseURL: URL
    let apiKey: String?
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "EnhancedAPIClient")
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private var activeTasks: Set<URLSessionTask> = []
    private let taskQueue = DispatchQueue(label: "com.claudecode.apiclient.tasks", attributes: .concurrent)
    
    // Performance metrics tracking
    private var metrics = APIMetrics()
    
    // MARK: - Initialization
    init?(settings: AppSettings, retryPolicy: RetryPolicy = .default) {
        guard let url = settings.baseURLValidated else {
            Logger(subsystem: "com.claudecode.ios", category: "EnhancedAPIClient")
                .error("Invalid base URL from settings")
            return nil
        }
        self.baseURL = url
        self.apiKey = settings.apiKeyPlaintext.isEmpty ? nil : settings.apiKeyPlaintext
        self.retryPolicy = retryPolicy
        
        // Configure URLSession with optimal settings
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024, // 10 MB
            diskCapacity: 50 * 1024 * 1024,   // 50 MB
            diskPath: "com.claudecode.apiclient.cache"
        )
        configuration.httpMaximumConnectionsPerHost = 6
        
        self.session = URLSession(configuration: configuration)
        
        logger.info("EnhancedAPIClient initialized with baseURL: \(url.absoluteString)")
    }
    
    deinit {
        // Clean up without calling MainActor methods
        session.invalidateAndCancel()
    }
    
    // MARK: - Request Building
    private func buildRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        logger.debug("Creating \(method) request to: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            logger.debug("Request body size: \(body.count) bytes")
        }
        
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            logger.debug("Added authorization header")
        }
        
        // Add request ID for tracking
        let requestId = UUID().uuidString
        request.setValue(requestId, forHTTPHeaderField: "X-Request-ID")
        
        return request
    }
    
    // MARK: - Request Execution with Retry
    private func executeRequest(_ request: URLRequest, attempt: Int = 1) async throws -> (Data, HTTPURLResponse) {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Executing request (attempt \(attempt)): \(request.url?.absoluteString ?? "unknown")")
        
        do {
            // Create cancellable task
            let task = session.dataTask(with: request)
            
            // Track active task with weak reference to prevent retain cycle
            _ = await MainActor.run { [weak self] in
                self?.activeTasks.insert(task)
            }
            
            defer {
                Task { @MainActor [weak self] in
                    self?.activeTasks.remove(task)
                }
            }
            
            // Execute request
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw URLError(.badServerResponse)
            }
            
            logger.info("Response status: \(httpResponse.statusCode), data size: \(data.count) bytes")
            
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
                   let delay = TimeInterval(retryAfter) {
                    logger.warning("Rate limited, retry after \(delay) seconds")
                    
                    if attempt < retryPolicy.maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        return try await executeRequest(request, attempt: attempt + 1)
                    }
                }
            }
            
            // Check for server errors that might be transient
            if (500...599).contains(httpResponse.statusCode) {
                let error = APIClient.APIError(
                    status: httpResponse.statusCode,
                    body: String(data: data, encoding: .utf8)
                )
                
                if retryPolicy.shouldRetry(for: error, attempt: attempt) {
                    let delay = retryPolicy.delay(for: attempt)
                    logger.warning("Server error, retrying after \(delay) seconds")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await executeRequest(request, attempt: attempt + 1)
                }
                
                throw error
            }
            
            // Check for client errors
            if !(200..<300).contains(httpResponse.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "No body"
                logger.error("HTTP error \(httpResponse.statusCode): \(bodyString)")
                throw APIClient.APIError(status: httpResponse.statusCode, body: bodyString)
            }
            
            return (data, httpResponse)
            
        } catch {
            // Check if error is retryable
            if retryPolicy.shouldRetry(for: error, attempt: attempt) {
                let delay = retryPolicy.delay(for: attempt)
                logger.warning("Request failed, retrying after \(delay) seconds: \(error.localizedDescription)")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeRequest(request, attempt: attempt + 1)
            }
            
            logger.error("Request failed after \(attempt) attempts: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Cancellation Support
    func cancelAllRequests() {
        logger.info("Cancelling \(self.activeTasks.count) active requests")
        self.activeTasks.forEach { $0.cancel() }
        self.activeTasks.removeAll()
    }
    
    // MARK: - Generic JSON Helpers
    private func getJSON<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let request = buildRequest(path: path, method: "GET")
        let (data, _) = try await executeRequest(request)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("JSON decoding failed: \(error)")
            throw error
        }
    }
    
    private func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        let payload = try JSONEncoder().encode(body)
        let request = buildRequest(path: path, method: "POST", body: payload)
        let (data, _) = try await executeRequest(request)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("JSON decoding failed: \(error)")
            throw error
        }
    }
    
    private func delete(_ path: String) async throws {
        let request = buildRequest(path: path, method: "DELETE")
        _ = try await executeRequest(request)
    }
    
    // MARK: - API Endpoints Implementation
    func health() async throws -> APIClient.HealthResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/health", duration: duration)
        }
        return try await getJSON("/health", as: APIClient.HealthResponse.self)
    }
    
    func listProjects() async throws -> [APIClient.Project] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/projects", duration: duration)
        }
        return try await getJSON("/v1/projects", as: [APIClient.Project].self)
    }
    
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project {
        let body = APIClient.NewProjectBody(name: name, description: description, path: path)
        return try await postJSON("/v1/projects", body: body, as: APIClient.Project.self)
    }
    
    func getProject(id: String) async throws -> APIClient.Project {
        try await getJSON("/v1/projects/\(id)", as: APIClient.Project.self)
    }
    
    func listSessions(projectId: String? = nil) async throws -> [APIClient.Session] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions", duration: duration)
        }
        let path = projectId.map { "/v1/sessions?project_id=\($0)" } ?? "/v1/sessions"
        return try await getJSON(path, as: [APIClient.Session].self)
    }
    
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session {
        let body = APIClient.NewSessionBody(
            project_id: projectId,
            model: model,
            title: title,
            system_prompt: systemPrompt
        )
        return try await postJSON("/v1/sessions", body: body, as: APIClient.Session.self)
    }
    
    func modelCapabilities() async throws -> [APIClient.ModelCapability] {
        let envelope = try await getJSON("/v1/models/capabilities", as: APIClient.CapabilitiesEnvelope.self)
        return envelope.models
    }
    
    func sessionStats() async throws -> APIClient.SessionStats {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.recordRequest(endpoint: "/sessions/stats", duration: duration)
        }
        return try await getJSON("/v1/sessions/stats", as: APIClient.SessionStats.self)
    }
    
    func deleteCompletion(id: String) async throws {
        try await delete("/v1/chat/completions/\(id)")
    }
    
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool = true) async throws -> APIClient.DebugResponse {
        let body = APIClient.DebugRequest(sessionId: sessionId, prompt: prompt, includeContext: includeContext)
        return try await postJSON("/v1/chat/completions/debug", body: body, as: APIClient.DebugResponse.self)
    }
    
    func updateSessionTools(sessionId: String, tools: [String], priority: Int? = nil) async throws -> APIClient.SessionToolsResponse {
        let body = APIClient.SessionToolsRequest(tools: tools, priority: priority)
        return try await postJSON("/v1/sessions/\(sessionId)/tools", body: body, as: APIClient.SessionToolsResponse.self)
    }
    
    // MARK: - Performance Metrics
    
    func getMetrics() -> APIMetrics {
        return metrics
    }
    
    func resetMetrics() {
        metrics = APIMetrics()
    }
}

// MARK: - API Metrics

struct APIMetrics {
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
        
        // Calculate average (keep only last 100 samples to prevent memory bloat)
        if times.count > 100 {
            times = Array(times.suffix(100))
            responseTimes[endpoint] = times
        }
        
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