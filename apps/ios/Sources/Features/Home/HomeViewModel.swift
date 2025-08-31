import SwiftUI
import Combine
import Foundation
import OSLog

// MARK: - Home View Model with Property Wrapper DI
@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var projects: [APIClient.Project] = []
    @Published var sessions: [APIClient.Session] = []
    @Published var stats: APIClient.SessionStats?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var refreshInterval: TimeInterval = 30.0
    @Published var lastRefreshTime: Date?
    
    // MARK: - Connection Status
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
        
        var isHealthy: Bool {
            if case .connected = self { return true }
            return false
        }
    }
    
    // MARK: - Dependencies (using Property Wrappers)
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    @Injected(AppSettings.self) private var settings: AppSettings
    @OptionalInjected(AnalyticsServiceProtocol.self) private var analyticsService: AnalyticsServiceProtocol?
    @OptionalInjected(CacheServiceProtocol.self) private var cacheService: CacheServiceProtocol?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "HomeViewModel")
    private weak var refreshTimer: Timer?
    private let refreshSubject = PassthroughSubject<Void, Never>()
    
    // Performance tracking
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Combine Publishers
    var projectsPublisher: AnyPublisher<[APIClient.Project], Never> {
        $projects.eraseToAnyPublisher()
    }
    
    var sessionsPublisher: AnyPublisher<[APIClient.Session], Never> {
        $sessions.eraseToAnyPublisher()
    }
    
    var statsPublisher: AnyPublisher<APIClient.SessionStats?, Never> {
        $stats.eraseToAnyPublisher()
    }
    
    var connectionPublisher: AnyPublisher<ConnectionStatus, Never> {
        $connectionStatus.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    var recentProjects: [APIClient.Project] {
        Array(projects.prefix(5))
    }
    
    var activeSessions: [APIClient.Session] {
        Array(sessions.filter { $0.isActive }.prefix(5))
    }
    
    var hasData: Bool {
        !projects.isEmpty || !sessions.isEmpty
    }
    
    var statusMessage: String {
        switch connectionStatus {
        case .connected:
            if let lastRefresh = lastRefreshTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Updated \(formatter.localizedString(for: lastRefresh, relativeTo: Date()))"
            }
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    // MARK: - Initialization
    init(
        autoRefresh: Bool = true
    ) {
        // Dependencies are automatically injected via property wrappers
        
        setupSubscriptions()
        
        if autoRefresh {
            startAutoRefresh()
        }
        
        // Track screen view
        analyticsService?.screen(name: "Home", properties: nil)
        
        // Initial load with cached data
        Task { 
            await loadCachedData()
            await loadData()
        }
    }
    
    // MARK: - Cache Management
    private func loadCachedData() async {
        // Try to load cached data for immediate display
        if let cachedProjects = await cacheService?.retrieve([APIClient.Project].self, forKey: "home.projects") {
            self.projects = cachedProjects
        }
        
        if let cachedSessions = await cacheService?.retrieve([APIClient.Session].self, forKey: "home.sessions") {
            self.sessions = cachedSessions
        }
        
        if let cachedStats = await cacheService?.retrieve(APIClient.SessionStats.self, forKey: "home.stats") {
            self.stats = cachedStats
        }
    }
    
    private func cacheData() async {
        // Cache current data for offline/quick loading
        await cacheService?.cache(projects, forKey: "home.projects")
        await cacheService?.cache(sessions, forKey: "home.sessions")
        if let stats = stats {
            await cacheService?.cache(stats, forKey: "home.stats")
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    private func setupSubscriptions() {
        // Auto-refresh subscription
        refreshSubject
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                Task { await self?.loadData() }
            }
            .store(in: &cancellables)
        
        // Monitor connection status for auto-retry
        $connectionStatus
            .removeDuplicates { old, new in
                switch (old, new) {
                case (.connected, .connected), (.disconnected, .disconnected):
                    return true
                default:
                    return false
                }
            }
            .sink { [weak self] status in
                if case .error = status {
                    // Auto-retry after error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self?.refreshSubject.send()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods with Performance Tracking
    func loadData() async {
        guard !isLoading else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        isLoading = true
        connectionStatus = .connecting
        error = nil
        
        // Track performance
        performanceMetrics.recordRequestStart()
        
        do {
            // Check health first
            let health = try await apiClient.health()
            guard health.ok else {
                throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend is not healthy"])
            }
            
            // Load data in parallel with performance tracking
            async let projectsTask = apiClient.listProjects()
            async let sessionsTask = apiClient.listSessions(projectId: nil)
            async let statsTask = apiClient.sessionStats()
            
            let (loadedProjects, loadedSessions, loadedStats) = try await (projectsTask, sessionsTask, statsTask)
            
            // Calculate load time
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            performanceMetrics.recordRequestComplete(duration: loadTime)
            
            // Update state on main thread with weak self to prevent retain cycle
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.projects = loadedProjects
                self.sessions = loadedSessions
                self.stats = loadedStats
                self.connectionStatus = .connected
                self.lastRefreshTime = Date()
                self.error = nil
            }
            
            // Cache the data
            await cacheData()
            
            // Track analytics
            analyticsService?.track(event: "home_data_loaded", properties: [
                "projects_count": loadedProjects.count,
                "sessions_count": loadedSessions.count,
                "load_time": loadTime
            ])
            
            logger.info("Data loaded successfully: \(loadedProjects.count) projects, \(loadedSessions.count) sessions in \(String(format: "%.2f", loadTime))s")
            
        } catch {
            performanceMetrics.recordRequestFailed()
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.error = error
                self.connectionStatus = .error(error.localizedDescription)
            }
            
            // Track error
            analyticsService?.track(event: "home_data_error", properties: [
                "error": error.localizedDescription
            ])
            
            logger.error("Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    func startAutoRefresh(interval: TimeInterval? = nil) {
        stopAutoRefresh()
        
        if let interval = interval {
            refreshInterval = interval
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshSubject.send()
        }
        refreshTimer = timer
        
        logger.info("Started auto-refresh with interval: \(self.refreshInterval)s")
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        logger.info("Stopped auto-refresh")
    }
    
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project {
        connectionStatus = .connecting
        
        do {
            let project = try await apiClient.createProject(name: name, description: description, path: path)
            
            // Refresh projects list
            await loadData()
            
            logger.info("Created project: \(project.id)")
            return project
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
            logger.error("Failed to create project: \(error)")
            throw error
        }
    }
    
    func createSession(for projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session {
        connectionStatus = .connecting
        
        do {
            let session = try await apiClient.createSession(
                projectId: projectId,
                model: model,
                title: title,
                systemPrompt: systemPrompt
            )
            
            // Refresh sessions list
            await loadData()
            
            logger.info("Created session: \(session.id)")
            return session
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
            logger.error("Failed to create session: \(error)")
            throw error
        }
    }
    
    func deleteProject(_ projectId: String) async throws {
        // Note: This endpoint doesn't exist in the current API, but showing the pattern
        connectionStatus = .connecting
        
        do {
            // try await apiClient.deleteProject(id: projectId)
            
            // Remove from local list immediately for better UX
            await MainActor.run { [weak self] in
                self?.projects.removeAll { $0.id == projectId }
            }
            
            // Refresh to ensure consistency
            await loadData()
            
            logger.info("Deleted project: \(projectId)")
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
            logger.error("Failed to delete project: \(error)")
            throw error
        }
    }
    
    // MARK: - Statistics Methods
    func calculateTrends() -> TrendData {
        guard let stats = stats else {
            return TrendData(tokenTrend: .neutral, costTrend: .neutral, sessionTrend: .neutral)
        }
        
        // This would normally compare with historical data
        // For now, showing placeholder logic
        return TrendData(
            tokenTrend: stats.totalTokens > 10000 ? .up : .down,
            costTrend: stats.totalCost > 10.0 ? .up : .down,
            sessionTrend: stats.activeSessions > 5 ? .up : .neutral
        )
    }
    
    struct TrendData {
        enum Trend {
            case up, down, neutral
            
            var icon: String {
                switch self {
                case .up: return "arrow.up.circle.fill"
                case .down: return "arrow.down.circle.fill"
                case .neutral: return "minus.circle.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .up: return .green
                case .down: return .red
                case .neutral: return .gray
                }
            }
        }
        
        let tokenTrend: Trend
        let costTrend: Trend
        let sessionTrend: Trend
    }
    
    // MARK: - Error Recovery
    func clearError() {
        error = nil
        if case .error = connectionStatus {
            connectionStatus = .disconnected
        }
    }
    
    func retryConnection() async {
        clearError()
        await loadData()
    }
    
    // MARK: - Performance Metrics
    func getPerformanceMetrics() -> PerformanceMetrics {
        return performanceMetrics
    }
}

// MARK: - Performance Metrics
struct PerformanceMetrics {
    private(set) var totalRequests: Int = 0
    private(set) var successfulRequests: Int = 0
    private(set) var failedRequests: Int = 0
    private(set) var averageResponseTime: TimeInterval = 0
    private var responseTimeSum: TimeInterval = 0
    private var requestCount: Int = 0
    
    mutating func recordRequestStart() {
        totalRequests += 1
    }
    
    mutating func recordRequestComplete(duration: TimeInterval) {
        successfulRequests += 1
        responseTimeSum += duration
        requestCount += 1
        averageResponseTime = responseTimeSum / Double(requestCount)
    }
    
    mutating func recordRequestFailed() {
        failedRequests += 1
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
}