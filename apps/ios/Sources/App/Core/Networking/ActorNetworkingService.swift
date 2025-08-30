import Foundation
import OSLog
import Combine

// MARK: - Actor-based Networking Service with Swift Concurrency

/// Thread-safe networking actor with advanced concurrency patterns
actor NetworkingActor {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "NetworkingActor")
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    
    // Task management with cancellation support
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var taskGroups: [String: [UUID]] = [:]
    
    // Request queue for rate limiting
    private var requestQueue: AsyncStream<RequestOperation>?
    private var requestQueueContinuation: AsyncStream<RequestOperation>.Continuation?
    
    // Metrics tracking
    private var metrics = NetworkMetrics()
    
    // MARK: - Initialization
    
    init(configuration: URLSessionConfiguration = .default, retryPolicy: RetryPolicy = .default) {
        self.retryPolicy = retryPolicy
        
        // Enhanced configuration
        var config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.multipathServiceType = .handover
        config.httpMaximumConnectionsPerHost = 6
        
        // HTTP/3 support
        if #available(iOS 15.0, *) {
            config.requiresDNSSECValidation = true
        }
        
        self.session = URLSession(configuration: config)
        
        // Initialize request queue
        setupRequestQueue()
        
        logger.info("🚀 NetworkingActor initialized")
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: - Request Queue Setup
    
    private func setupRequestQueue() {
        let (stream, continuation) = AsyncStream<RequestOperation>.makeStream(
            bufferingPolicy: .bufferingNewest(100)
        )
        
        self.requestQueue = stream
        self.requestQueueContinuation = continuation
        
        // Start processing queue
        Task {
            await processRequestQueue()
        }
    }
    
    private func processRequestQueue() async {
        guard let requestQueue = requestQueue else { return }
        
        for await operation in requestQueue {
            await executeOperation(operation)
        }
    }
    
    private func executeOperation(_ operation: RequestOperation) async {
        do {
            let response = try await performRequest(operation.request, attempt: 1)
            operation.continuation.resume(returning: response)
        } catch {
            operation.continuation.resume(throwing: error)
        }
    }
    
    // MARK: - Public API
    
    /// Perform a network request with automatic retry and cancellation support
    func request<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        priority: TaskPriority = .medium,
        group: String? = nil
    ) async throws -> T {
        let taskId = UUID()
        
        // Track metrics
        metrics.requestStarted()
        defer { metrics.requestCompleted() }
        
        // Create cancellable task with proper type
        let task = Task<T, Error>(priority: priority) { [weak self] in
            guard let self = self else { 
                throw NetworkError.unknown
            }
            
            do {
                let (data, _) = try await self.performRequest(request, attempt: 1)
                let decoded = try JSONDecoder().decode(T.self, from: data)
                
                await self.removeTask(taskId, from: group)
                return decoded
                
            } catch {
                await self.removeTask(taskId, from: group)
                await self.recordFailedRequest(error: error)
                throw error
            }
        }
        
        // Create a wrapper task for tracking
        let trackingTask = Task<Void, Never> {
            _ = try? await task.value
        }
        
        // Track task
        addTask(taskId, task: trackingTask, to: group)
        
        // Wait for task completion and return result
        return try await task.value
    }
    
    /// Perform multiple requests concurrently
    func batchRequests<T: Decodable>(
        _ requests: [URLRequest],
        as type: T.Type,
        maxConcurrency: Int = 5
    ) async throws -> [Result<T, Error>] {
        try await withThrowingTaskGroup(of: Result<T, Error>.self) { group in
            // Limit concurrency
            for request in requests.prefix(maxConcurrency) {
                group.addTask { [weak self] in
                    do {
                        guard let self = self else {
                            return .failure(NetworkError.actorDeallocated)
                        }
                        let result = try await self.request(request, as: type)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var results: [Result<T, Error>] = []
            var nextIndex = maxConcurrency
            
            // Process results and add new tasks
            for try await result in group {
                results.append(result)
                
                if nextIndex < requests.count {
                    let request = requests[nextIndex]
                    group.addTask { [weak self] in
                        do {
                            guard let self = self else {
                                return .failure(NetworkError.actorDeallocated)
                            }
                            let result = try await self.request(request, as: type)
                            return .success(result)
                        } catch {
                            return .failure(error)
                        }
                    }
                    nextIndex += 1
                }
            }
            
            return results
        }
    }
    
    /// Stream data with AsyncSequence
    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200..<300).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: NetworkError.invalidResponse)
                        return
                    }
                    
                    for try await byte in bytes {
                        continuation.yield(Data([byte]))
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Cancel all tasks in a group
    func cancelGroup(_ group: String) async {
        guard let taskIds = taskGroups[group] else { return }
        
        for taskId in taskIds {
            activeTasks[taskId]?.cancel()
            activeTasks[taskId] = nil
        }
        
        taskGroups[group] = nil
        logger.info("❌ Cancelled \(taskIds.count) tasks in group: \(group)")
    }
    
    /// Cancel all active tasks
    func cancelAll() async {
        let count = activeTasks.count
        
        for task in activeTasks.values {
            task.cancel()
        }
        
        activeTasks.removeAll()
        taskGroups.removeAll()
        
        logger.info("❌ Cancelled all \(count) active tasks")
    }
    
    /// Get current metrics
    func getMetrics() -> NetworkMetrics {
        metrics
    }
    
    // MARK: - Private Methods
    
    private func performRequest(
        _ request: URLRequest,
        attempt: Int
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
                   let delay = TimeInterval(retryAfter),
                   attempt < retryPolicy.maxAttempts {
                    
                    logger.warning("⏳ Rate limited, retrying after \(delay)s")
                    try await Task.sleep(for: .seconds(delay))
                    return try await performRequest(request, attempt: attempt + 1)
                }
                throw NetworkError.rateLimited
            }
            
            // Handle server errors with retry
            if (500...599).contains(httpResponse.statusCode) {
                if retryPolicy.shouldRetry(for: NetworkError.serverError(httpResponse.statusCode), attempt: attempt) {
                    let delay = retryPolicy.delay(for: attempt)
                    logger.warning("🔄 Server error, retrying after \(delay)s")
                    try await Task.sleep(for: .seconds(delay))
                    return try await performRequest(request, attempt: attempt + 1)
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            // Handle client errors
            if !(200..<300).contains(httpResponse.statusCode) {
                throw NetworkError.httpError(httpResponse.statusCode, data)
            }
            
            metrics.bytesReceived(data.count)
            return (data, httpResponse)
            
        } catch {
            // Retry on network errors
            if retryPolicy.shouldRetry(for: error, attempt: attempt) {
                let delay = retryPolicy.delay(for: attempt)
                logger.warning("🔄 Network error, retrying after \(delay)s: \(error)")
                try await Task.sleep(for: .seconds(delay))
                return try await performRequest(request, attempt: attempt + 1)
            }
            
            throw error
        }
    }
    
    private func addTask(_ id: UUID, task: Task<Void, Never>, to group: String?) {
        activeTasks[id] = task
        
        if let group = group {
            var tasks = taskGroups[group] ?? []
            tasks.append(id)
            taskGroups[group] = tasks
        }
    }
    
    private func removeTask(_ id: UUID, from group: String?) {
        activeTasks[id] = nil
        
        if let group = group {
            taskGroups[group]?.removeAll { $0 == id }
        }
    }
    
    private func recordFailedRequest(error: Error) {
        metrics.requestFailed(error: error)
    }
}

// MARK: - Supporting Types

struct RequestOperation {
    let request: URLRequest
    let continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case rateLimited
    case serverError(Int)
    case httpError(Int, Data)
    case actorDeallocated
    case timeout
    case noConnection
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited:
            return "Rate limited by server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .httpError(let code, _):
            return "HTTP error: \(code)"
        case .actorDeallocated:
            return "Network actor was deallocated"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No network connection"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

// MARK: - Network Metrics

struct NetworkMetrics {
    private(set) var totalRequests: Int = 0
    private(set) var successfulRequests: Int = 0
    private(set) var failedRequests: Int = 0
    private(set) var totalBytesReceived: Int = 0
    private(set) var totalBytesSent: Int = 0
    private(set) var averageResponseTime: TimeInterval = 0
    private var responseTimeSum: TimeInterval = 0
    private var requestCount: Int = 0
    
    mutating func requestStarted() {
        totalRequests += 1
    }
    
    mutating func requestCompleted(responseTime: TimeInterval = 0) {
        successfulRequests += 1
        responseTimeSum += responseTime
        requestCount += 1
        averageResponseTime = responseTimeSum / Double(requestCount)
    }
    
    mutating func requestFailed(error: Error) {
        failedRequests += 1
    }
    
    mutating func bytesReceived(_ bytes: Int) {
        totalBytesReceived += bytes
    }
    
    mutating func bytesSent(_ bytes: Int) {
        totalBytesSent += bytes
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
}

// MARK: - Async Request Builder

@resultBuilder
enum AsyncRequestBuilder {
    static func buildBlock(_ request: URLRequest) -> URLRequest {
        request
    }
    
    static func buildOptional(_ request: URLRequest?) -> URLRequest? {
        request
    }
    
    static func buildEither(first request: URLRequest) -> URLRequest {
        request
    }
    
    static func buildEither(second request: URLRequest) -> URLRequest {
        request
    }
}

// MARK: - Request Extensions

extension URLRequest {
    /// Build a request using result builder syntax
    static func build(
        url: URL,
        @AsyncRequestBuilder builder: () -> URLRequest
    ) -> URLRequest {
        builder()
    }
    
    /// Add authorization header
    func authorized(with token: String) -> URLRequest {
        var request = self
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    /// Add JSON body
    func withJSON<T: Encodable>(_ body: T) throws -> URLRequest {
        var request = self
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    /// Set timeout
    func withTimeout(_ timeout: TimeInterval) -> URLRequest {
        var request = self
        request.timeoutInterval = timeout
        return request
    }
}