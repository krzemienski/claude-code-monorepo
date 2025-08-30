import Foundation

// MARK: - API Client Protocol
@MainActor
protocol APIClientProtocol {
    var baseURL: URL { get }
    var apiKey: String? { get }
    
    // Health check
    func health() async throws -> APIClient.HealthResponse
    
    // Projects
    func listProjects() async throws -> [APIClient.Project]
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project
    func getProject(id: String) async throws -> APIClient.Project
    
    // Sessions
    func listSessions(projectId: String?) async throws -> [APIClient.Session]
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session
    
    // Model capabilities
    func modelCapabilities() async throws -> [APIClient.ModelCapability]
    
    // Session stats
    func sessionStats() async throws -> APIClient.SessionStats
    
    // Completions
    func deleteCompletion(id: String) async throws
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool) async throws -> APIClient.DebugResponse
    
    // Session tools
    func updateSessionTools(sessionId: String, tools: [String], priority: Int?) async throws -> APIClient.SessionToolsResponse
    
    // Cancellable request support
    func cancelAllRequests()
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, from data: Data) async throws -> (Data, URLResponse)
}

// MARK: - SSE Client Protocol
protocol SSEClientProtocol {
    func connect(url: URL?, body: Data?, headers: [String: String])
    func stop()
    
    var onEvent: ((SSEClient.Event) -> Void)? { get set }
    var onDone: (() -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    var onMessage: ((String) -> Void)? { get set }
    var onComplete: (() -> Void)? { get set }
}

// MARK: - Retry Policy
struct RetryPolicy {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitterRange: ClosedRange<Double>
    
    static var `default`: RetryPolicy {
        RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.5,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitterRange: 0.8...1.2
        )
    }
    
    static var aggressive: RetryPolicy {
        RetryPolicy(
            maxAttempts: 5,
            initialDelay: 0.25,
            maxDelay: 60.0,
            multiplier: 1.5,
            jitterRange: 0.9...1.1
        )
    }
    
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt - 1))
        let clampedDelay = min(exponentialDelay, maxDelay)
        let jitter = Double.random(in: jitterRange)
        
        return clampedDelay * jitter
    }
    
    func shouldRetry(for error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        // Check for retryable errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                return false
            }
        }
        
        // Check for retryable HTTP status codes
        if let apiError = error as? APIClient.APIError {
            switch apiError.status {
            case 408, 429, 500, 502, 503, 504:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}