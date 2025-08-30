import SwiftUI

/// NavigationCoordinator - Modern navigation management with NavigationStack
@MainActor
public final class NavigationCoordinator: ObservableObject {
    // MARK: - Navigation Path
    @Published public var path = NavigationPath()
    
    // MARK: - Deep Link Support
    @Published public var pendingDeepLink: DeepLink?
    
    // MARK: - Sheet Presentations
    @Published public var activeSheet: SheetDestination?
    @Published public var activeFullScreenCover: FullScreenDestination?
    
    // MARK: - Tab Selection (for TabView)
    @Published public var selectedTab: Tab = .home
    
    // Singleton instance
    public static let shared = NavigationCoordinator()
    
    private init() {
        setupDeepLinkHandler()
    }
    
    // MARK: - Navigation Destinations
    public enum Destination: Hashable {
        case home
        case session(String)
        case settings
        case profile
        case project(String)
        case file(String)
        case analytics
        case diagnostics
        case about
    }
    
    public enum Tab: String, CaseIterable {
        case home = "Home"
        case sessions = "Sessions"
        case files = "Files"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .sessions: return "bubble.left.and.bubble.right"
            case .files: return "folder"
            case .settings: return "gearshape"
            }
        }
    }
    
    public enum SheetDestination: Identifiable {
        case newSession
        case quickSettings
        case search
        case profile
        
        public var id: String {
            switch self {
            case .newSession: return "newSession"
            case .quickSettings: return "quickSettings"
            case .search: return "search"
            case .profile: return "profile"
            }
        }
    }
    
    public enum FullScreenDestination: Identifiable {
        case onboarding
        case sessionDetail(String)
        case mediaViewer(URL)
        
        public var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .sessionDetail(let id): return "session_\(id)"
            case .mediaViewer: return "mediaViewer"
            }
        }
    }
    
    // MARK: - Navigation Methods
    public func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    public func navigateToRoot() {
        path.removeLast(path.count)
    }
    
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    public func pop(count: Int) {
        let popCount = min(count, path.count)
        if popCount > 0 {
            path.removeLast(popCount)
        }
    }
    
    public func replaceNavigationStack(with destinations: [Destination]) {
        path = NavigationPath()
        destinations.forEach { path.append($0) }
    }
    
    // MARK: - Sheet Management
    public func presentSheet(_ sheet: SheetDestination) {
        activeSheet = sheet
    }
    
    public func dismissSheet() {
        activeSheet = nil
    }
    
    public func presentFullScreen(_ destination: FullScreenDestination) {
        activeFullScreenCover = destination
    }
    
    public func dismissFullScreen() {
        activeFullScreenCover = nil
    }
    
    // MARK: - Tab Management
    public func selectTab(_ tab: Tab) {
        selectedTab = tab
    }
    
    // MARK: - Deep Link Handling
    private func setupDeepLinkHandler() {
        // Listen for deep links from NotificationCenter or URL schemes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeepLink(_:)),
            name: .deepLinkReceived,
            object: nil
        )
    }
    
    @objc private func handleDeepLink(_ notification: Notification) {
        guard let deepLink = notification.object as? DeepLink else { return }
        processDeepLink(deepLink)
    }
    
    public func processDeepLink(_ deepLink: DeepLink) {
        // Store for later processing if needed
        pendingDeepLink = deepLink
        
        // Navigate based on deep link
        switch deepLink.destination {
        case .session(let id):
            navigateToRoot()
            navigate(to: .session(id))
            
        case .settings(let section):
            navigateToRoot()
            navigate(to: .settings)
            // Additional logic for specific settings section
            
        case .newSession:
            presentSheet(.newSession)
            
        case .project(let id):
            navigateToRoot()
            navigate(to: .project(id))
        }
        
        // Clear pending deep link after processing
        pendingDeepLink = nil
    }
}

// MARK: - Deep Link Model
public struct DeepLink {
    public enum Destination {
        case session(String)
        case settings(String?)
        case newSession
        case project(String)
    }
    
    public let destination: Destination
    public let timestamp: Date
    
    public init(destination: Destination) {
        self.destination = destination
        self.timestamp = Date()
    }
}

// MARK: - Notification Extension
public extension Notification.Name {
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
}

// MARK: - Navigation View Modifier
public struct NavigationDestinationModifier: ViewModifier {
    @ObservedObject private var coordinator = NavigationCoordinator.shared
    
    public func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                switch destination {
                case .home:
                    HomeView()
                    
                case .session(let id):
                    ChatView(sessionId: id)
                    
                case .settings:
                    SettingsView()
                    
                case .profile:
                    ProfileView()
                    
                case .project(let id):
                    ProjectDetailView(projectId: id)
                    
                case .file(let path):
                    FileDetailView(filePath: path)
                    
                case .analytics:
                    AnalyticsView()
                    
                case .diagnostics:
                    DiagnosticsView()
                    
                case .about:
                    AboutView()
                }
            }
    }
}

// MARK: - Convenience View Extension
public extension View {
    func withNavigationDestinations() -> some View {
        self.modifier(NavigationDestinationModifier())
    }
}

// MARK: - NavigationStack Wrapper
public struct AppNavigationStack<Content: View>: View {
    @ObservedObject private var coordinator = NavigationCoordinator.shared
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            content
                .withNavigationDestinations()
        }
        .sheet(item: $coordinator.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $coordinator.activeFullScreenCover) { destination in
            fullScreenContent(for: destination)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: NavigationCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .newSession:
            NewSessionView()
            
        case .quickSettings:
            QuickSettingsView()
            
        case .search:
            SearchView()
            
        case .profile:
            ProfileView()
        }
    }
    
    @ViewBuilder
    private func fullScreenContent(for destination: NavigationCoordinator.FullScreenDestination) -> some View {
        switch destination {
        case .onboarding:
            OnboardingView()
            
        case .sessionDetail(let id):
            ChatView(sessionId: id)
                .navigationBarHidden(false)
            
        case .mediaViewer(let url):
            MediaViewerView(url: url)
        }
    }
}