import Foundation
import SwiftUI
import OSLog

// MARK: - Legacy Container (Redirects to EnhancedContainer)
// This provides backward compatibility while migrating to EnhancedContainer
@MainActor
final class Container: ObservableObject {
    static let shared = Container()
    
    private let enhancedContainer = EnhancedContainer.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "Container")
    
    // MARK: - Core Services (Delegate to EnhancedContainer)
    var settings: AppSettings {
        ServiceLocator.shared.resolve(AppSettings.self) ?? AppSettings()
    }
    
    var apiClient: APIClientProtocol {
        enhancedContainer.networkingService.apiClient
    }
    
    var sseClient: SSEClientProtocol {
        EnhancedSSEClient(retryPolicy: .default)
    }
    
    // MARK: - Actor-based Networking
    var networkingActor: NetworkingActor {
        NetworkingActor(retryPolicy: .default)
    }
    
    // MARK: - Service Protocols (Delegate to EnhancedContainer)
    var authenticationService: AuthenticationServiceProtocol {
        enhancedContainer.authenticationService
    }
    
    var cacheService: CacheServiceProtocol {
        enhancedContainer.cacheService
    }
    
    var analyticsService: AnalyticsServiceProtocol {
        enhancedContainer.analyticsService
    }
    
    // MARK: - Coordinators
    var appCoordinator: AppCoordinator {
        AppCoordinator(container: self)
    }
    
    // MARK: - Initialization
    private init() {
        logger.info("🚀 Container initialized - delegating to EnhancedContainer")
    }
    
    // MARK: - View Models Factory (Delegate to EnhancedContainer)
    func makeHomeViewModel() -> HomeViewModel {
        enhancedContainer.makeHomeViewModel()
    }
    
    func makeProjectsViewModel() -> ProjectsViewModel {
        enhancedContainer.makeProjectsViewModel()
    }
    
    func makeSessionsViewModel() -> SessionsViewModel {
        enhancedContainer.makeSessionsViewModel()
    }
    
    func makeChatViewModel(sessionId: String, projectId: String = "default") -> ChatViewModel {
        enhancedContainer.makeChatViewModel(sessionId: sessionId, projectId: projectId)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        enhancedContainer.makeSettingsViewModel()
    }
    
    func makeMCPViewModel() -> MCPViewModel {
        enhancedContainer.makeMCPViewModel()
    }
    
    func makeMonitoringViewModel() -> MonitoringViewModel {
        enhancedContainer.makeMonitoringViewModel()
    }
    
    // MARK: - Service Registration (Delegate to EnhancedContainer)
    func register<T>(service: T, for type: T.Type) {
        ServiceLocator.shared.register(type, instance: service)
        logger.debug("💉 Registered service for \(String(describing: type))")
    }
    
    // MARK: - Test Support
    private func createMockAPIClient() -> APIClientProtocol {
        // Return a mock client for testing/preview
        MockAPIClient()
    }
    
    // MARK: - Testing Support (Delegate to EnhancedContainer)
    func injectMock<T>(_ serviceType: T.Type, mock: T) {
        enhancedContainer.injectMock(serviceType, mock: mock)
    }
    
    func reset() {
        enhancedContainer.reset()
    }
}

// MARK: - Container Environment Key
struct ContainerEnvironmentKey: EnvironmentKey {
    @MainActor static let defaultValue = Container.shared
}

extension EnvironmentValues {
    var container: Container {
        get { self[ContainerEnvironmentKey.self] }
        set { self[ContainerEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions
extension View {
    @MainActor
    func withContainer(_ container: Container = .shared) -> some View {
        self.environment(\.container, container)
    }
}

// MARK: - Mock API Client for Testing
@MainActor
final class MockAPIClient: APIClientProtocol {
    let baseURL = URL(string: "https://mock.api.com") ?? URL(fileURLWithPath: "/")
    let apiKey: String? = nil
    
    func health() async throws -> APIClient.HealthResponse {
        // Return a mock healthy response matching the actual backend format
        struct MockHealthResponse: Decodable {
            let status: String = "healthy"
            let timestamp: String? = ISO8601DateFormatter().string(from: Date())
        }
        do {
            let mockData = try JSONEncoder().encode(["status": "healthy", "timestamp": ISO8601DateFormatter().string(from: Date())])
            return try JSONDecoder().decode(APIClient.HealthResponse.self, from: mockData)
        } catch {
            // Return a default health response if encoding/decoding fails
            return APIClient.HealthResponse(status: "healthy", timestamp: ISO8601DateFormatter().string(from: Date()))
        }
    }
    
    func listProjects() async throws -> [APIClient.Project] {
        [
            APIClient.Project(
                id: "1",
                name: "Test Project",
                description: "A test project",
                path: "/test",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
    }
    
    func createProject(name: String, description: String, path: String?) async throws -> APIClient.Project {
        APIClient.Project(
            id: UUID().uuidString,
            name: name,
            description: description,
            path: path,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func getProject(id: String) async throws -> APIClient.Project {
        APIClient.Project(
            id: id,
            name: "Test Project",
            description: "A test project",
            path: "/test",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func listSessions(projectId: String?) async throws -> [APIClient.Session] {
        [
            APIClient.Session(
                id: "1",
                projectId: projectId ?? "1",
                title: "Test Session",
                model: "gpt-4",
                systemPrompt: nil,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                isActive: true,
                totalTokens: 1000,
                totalCost: 0.05,
                messageCount: 10
            )
        ]
    }
    
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> APIClient.Session {
        APIClient.Session(
            id: UUID().uuidString,
            projectId: projectId,
            title: title,
            model: model,
            systemPrompt: systemPrompt,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isActive: true,
            totalTokens: 0,
            totalCost: 0.0,
            messageCount: 0
        )
    }
    
    func modelCapabilities() async throws -> [APIClient.ModelCapability] {
        [
            APIClient.ModelCapability(
                id: "gpt-4",
                name: "GPT-4",
                description: "Most capable model",
                maxTokens: 8192,
                supportsStreaming: true,
                supportsTools: true
            ),
            APIClient.ModelCapability(
                id: "gpt-3.5-turbo",
                name: "GPT-3.5 Turbo",
                description: "Fast and efficient",
                maxTokens: 4096,
                supportsStreaming: true,
                supportsTools: true
            )
        ]
    }
    
    func sessionStats() async throws -> APIClient.SessionStats {
        APIClient.SessionStats(
            activeSessions: 3,
            totalTokens: 50000,
            totalCost: 2.50,
            totalMessages: 250
        )
    }
    
    func deleteCompletion(id: String) async throws {
        // Mock implementation
    }
    
    func debugCompletion(sessionId: String, prompt: String, includeContext: Bool) async throws -> APIClient.DebugResponse {
        APIClient.DebugResponse(
            sessionId: sessionId,
            context: "Mock context",
            tokens: 100,
            modelState: "Ready"
        )
    }
    
    func updateSessionTools(sessionId: String, tools: [String], priority: Int?) async throws -> APIClient.SessionToolsResponse {
        APIClient.SessionToolsResponse(
            sessionId: sessionId,
            enabledTools: tools,
            message: "Tools updated"
        )
    }
    
    func cancelAllRequests() {
        // Mock implementation
    }
}