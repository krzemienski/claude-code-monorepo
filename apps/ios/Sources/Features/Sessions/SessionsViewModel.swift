import SwiftUI
import Combine
import Foundation
import os.log

// MARK: - Sessions View Model
@MainActor
final class SessionsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessions: [APIClient.Session] = []
    @Published var filteredSessions: [APIClient.Session] = []
    @Published var searchText: String = ""
    @Published var scopeFilter: SessionScope = .active
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var selectedProjectId: String?
    
    // MARK: - Session Scope
    enum SessionScope: String, CaseIterable, Identifiable {
        case active = "Active"
        case all = "All"
        case archived = "Archived"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
    
    // MARK: - Private Properties (using Property Wrappers)
    @Injected(APIClientProtocol.self) private var apiClient: APIClientProtocol
    @Injected(AppSettings.self) private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode", category: "SessionsViewModel")
    private var refreshTimer: Timer?
    
    // MARK: - Combine Publishers
    var sessionsPublisher: AnyPublisher<[APIClient.Session], Never> {
        $sessions.eraseToAnyPublisher()
    }
    
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    var hasSessions: Bool {
        !sessions.isEmpty
    }
    
    var hasError: Bool {
        error != nil
    }
    
    var errorMessage: String? {
        error?.localizedDescription
    }
    
    var activeSessions: [APIClient.Session] {
        sessions.filter { $0.isActive }
    }
    
    var sessionStats: SessionStats {
        SessionStats(
            total: sessions.count,
            active: activeSessions.count,
            totalTokens: sessions.compactMap { $0.totalTokens }.reduce(0, +),
            totalCost: sessions.compactMap { $0.totalCost }.reduce(0, +)
        )
    }
    
    struct SessionStats {
        let total: Int
        let active: Int
        let totalTokens: Int
        let totalCost: Double
    }
    
    // MARK: - Initialization
    init(projectId: String? = nil) {
        // Dependencies are automatically injected via property wrappers
        self.selectedProjectId = projectId
        setupSubscriptions()
        startAutoRefresh()
    }
    
    deinit {
        Task { @MainActor in
            stopAutoRefresh()
        }
    }
    
    // MARK: - Setup Methods
    private func setupSubscriptions() {
        // Filter sessions based on search and scope
        Publishers.CombineLatest3($searchText, $sessions, $scopeFilter)
            .map { [weak self] searchText, sessions, scope in
                self?.filterSessions(sessions, searchText: searchText, scope: scope) ?? []
            }
            .assign(to: &$filteredSessions)
    }
    
    private func filterSessions(_ sessions: [APIClient.Session], searchText: String, scope: SessionScope) -> [APIClient.Session] {
        var filtered = sessions
        
        // Apply scope filter
        switch scope {
        case .active:
            filtered = filtered.filter { $0.isActive }
        case .archived:
            filtered = filtered.filter { !$0.isActive }
        case .all:
            break // No filtering
        }
        
        // Apply project filter if set
        if let projectId = selectedProjectId {
            filtered = filtered.filter { $0.projectId == projectId }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                (session.title ?? session.id).localizedCaseInsensitiveContains(searchText) ||
                session.model.localizedCaseInsensitiveContains(searchText) ||
                session.projectId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by last activity (most recent first)
        filtered.sort { $0.updatedAt > $1.updatedAt }
        
        return filtered
    }
    
    // MARK: - Public Methods
    func loadSessions() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let loadedSessions = try await apiClient.listSessions(projectId: selectedProjectId)
            
            await MainActor.run {
                self.sessions = loadedSessions
                self.logger.info("Loaded \(loadedSessions.count) sessions")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to load sessions: \(error)")
            }
        }
        
        isLoading = false
    }
    
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async -> APIClient.Session? {
        isLoading = true
        error = nil
        
        do {
            let session = try await apiClient.createSession(
                projectId: projectId,
                model: model,
                title: title,
                systemPrompt: systemPrompt
            )
            
            // Reload sessions to ensure consistency
            await loadSessions()
            
            logger.info("Created session: \(session.id)")
            return session
            
        } catch {
            self.error = error
            logger.error("Failed to create session: \(error)")
            return nil
        }
    }
    
    func stopSession(_ sessionId: String) async {
        error = nil
        
        do {
            // Call API to stop session
            try await apiClient.deleteCompletion(id: sessionId)
            
            // Update local state
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[index].isActive = false
            }
            
            // Reload to ensure consistency
            await loadSessions()
            
            logger.info("Stopped session: \(sessionId)")
            
        } catch {
            self.error = error
            logger.error("Failed to stop session: \(error)")
        }
    }
    
    func deleteSession(_ sessionId: String) async {
        error = nil
        
        // Optimistically remove from list
        await MainActor.run {
            self.sessions.removeAll { $0.id == sessionId }
        }
        
        // Note: API endpoint for deletion may need to be implemented
        logger.info("Session deletion requested for: \(sessionId)")
        
        // Reload to ensure consistency
        await loadSessions()
    }
    
    func refresh() async {
        await loadSessions()
    }
    
    func clearError() {
        error = nil
    }
    
    func setProjectFilter(_ projectId: String?) {
        selectedProjectId = projectId
    }
    
    // MARK: - Auto Refresh
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { await self?.loadSessions() }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}