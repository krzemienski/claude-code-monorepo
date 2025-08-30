import SwiftUI

// MARK: - Navigation Path Item
enum NavigationDestination: Hashable {
    case home
    case projects
    case projectDetail(String)
    case sessions
    case sessionDetail(String)
    case chat(String)
    case settings
    case mcpSettings
    case monitoring
    case fileBrowser
}

// MARK: - App Coordinator
@MainActor
final class AppCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var selectedTab: Tab = .home
    @Published var presentedSheet: Sheet?
    @Published var presentedAlert: Alert?
    
    private weak var container: Container?
    
    // MARK: - Tab Definition
    enum Tab: String, CaseIterable {
        case home = "Home"
        case projects = "Projects"
        case sessions = "Sessions"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .projects: return "folder.fill"
            case .sessions: return "bubble.left.and.bubble.right.fill"
            case .settings: return "gear"
            }
        }
    }
    
    // MARK: - Sheet Types
    enum Sheet: Identifiable {
        case newProject
        case newSession(projectId: String)
        case editProject(String)
        case editSession(String)
        case mcpTools
        case debugConsole
        case about
        
        var id: String {
            switch self {
            case .newProject: return "newProject"
            case .newSession(let id): return "newSession-\(id)"
            case .editProject(let id): return "editProject-\(id)"
            case .editSession(let id): return "editSession-\(id)"
            case .mcpTools: return "mcpTools"
            case .debugConsole: return "debugConsole"
            case .about: return "about"
            }
        }
    }
    
    // MARK: - Alert Types
    struct Alert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryButton: AlertButton?
        let secondaryButton: AlertButton?
        
        struct AlertButton {
            let title: String
            let role: ButtonRole?
            let action: () -> Void
            
            enum ButtonRole {
                case destructive
                case cancel
            }
        }
    }
    
    // MARK: - Initialization
    init(container: Container) {
        self.container = container
    }
    
    // MARK: - Navigation Methods
    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func navigateToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }
    
    func switchTab(to tab: Tab) {
        selectedTab = tab
        navigateToRoot()
    }
    
    // MARK: - Sheet Presentation
    func presentSheet(_ sheet: Sheet) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    // MARK: - Alert Presentation
    func showAlert(title: String, message: String, primaryButton: Alert.AlertButton? = nil, secondaryButton: Alert.AlertButton? = nil) {
        presentedAlert = Alert(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }
    
    func showErrorAlert(_ error: Error) {
        showAlert(
            title: "Error",
            message: error.localizedDescription,
            primaryButton: Alert.AlertButton(title: "OK", role: nil) { [weak self] in
                self?.dismissAlert()
            }
        )
    }
    
    func showConfirmationAlert(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        onConfirm: @escaping () -> Void
    ) {
        showAlert(
            title: title,
            message: message,
            primaryButton: Alert.AlertButton(title: confirmTitle, role: .destructive, action: onConfirm),
            secondaryButton: Alert.AlertButton(title: "Cancel", role: .cancel) { [weak self] in
                self?.dismissAlert()
            }
        )
    }
    
    func dismissAlert() {
        presentedAlert = nil
    }
    
    // MARK: - Deep Linking
    func handleDeepLink(_ url: URL) {
        // Parse URL and navigate accordingly
        // Example: claudecode://project/123
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        switch components.host {
        case "project":
            if let projectId = components.path.split(separator: "/").first {
                switchTab(to: .projects)
                navigate(to: .projectDetail(String(projectId)))
            }
        case "session":
            if let sessionId = components.path.split(separator: "/").first {
                switchTab(to: .sessions)
                navigate(to: .sessionDetail(String(sessionId)))
            }
        case "chat":
            if let sessionId = components.path.split(separator: "/").first {
                navigate(to: .chat(String(sessionId)))
            }
        case "settings":
            switchTab(to: .settings)
        default:
            break
        }
    }
    
    // MARK: - State Restoration
    func saveNavigationState() -> Data? {
        // NavigationPath doesn't support direct encoding
        // Would need to track routes separately for persistence
        return nil
    }
    
    func restoreNavigationState(from data: Data) {
        // NavigationPath doesn't support direct decoding
        // Would need to track routes separately for restoration
    }
}

// MARK: - Coordinator View Modifier
struct CoordinatorViewModifier: ViewModifier {
    @ObservedObject var coordinator: AppCoordinator
    
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .sheet(item: $coordinator.presentedSheet) { sheet in
                sheetView(for: sheet)
            }
            .alert(item: $coordinator.presentedAlert) { alert in
                SwiftUI.Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: alertButton(alert.primaryButton),
                    secondaryButton: alertButton(alert.secondaryButton)
                )
            }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .home:
            HomeView()
        case .projects:
            EmptyView() // ProjectsView()
        case .projectDetail(let id):
            EmptyView() // ProjectDetailView(projectId: id)
        case .sessions:
            EmptyView() // SessionsView()
        case .sessionDetail(let id):
            EmptyView() // SessionDetailView(sessionId: id)
        case .chat(let id):
            ChatConsoleView(sessionId: id, projectId: "default")
        case .settings:
            EmptyView() // SettingsView()
        case .mcpSettings:
            MCPSettingsView()
        case .monitoring:
            EmptyView() // MonitoringView()
        case .fileBrowser:
            FileBrowserView()
        }
    }
    
    @ViewBuilder
    private func sheetView(for sheet: AppCoordinator.Sheet) -> some View {
        switch sheet {
        case .newProject:
            EmptyView() // NewProjectView()
        case .newSession(let projectId):
            EmptyView() // NewSessionView(projectId: projectId)
        case .editProject(let id):
            EmptyView() // EditProjectView(projectId: id)
        case .editSession(let id):
            EmptyView() // EditSessionView(sessionId: id)
        case .mcpTools:
            SessionToolPickerView(sessionId: "default")
        case .debugConsole:
            EmptyView() // DebugConsoleView()
        case .about:
            EmptyView() // AboutView()
        }
    }
    
    private func alertButton(_ button: AppCoordinator.Alert.AlertButton?) -> SwiftUI.Alert.Button {
        guard let button = button else {
            return .default(Text("OK"))
        }
        
        switch button.role {
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        case .none:
            return .default(Text(button.title), action: button.action)
        }
    }
}

extension View {
    func withCoordinator(_ coordinator: AppCoordinator) -> some View {
        modifier(CoordinatorViewModifier(coordinator: coordinator))
    }
}