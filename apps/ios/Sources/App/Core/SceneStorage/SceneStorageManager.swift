import SwiftUI

/// SceneStorage keys for app-wide state restoration
/// Implements proper view restoration as identified in the audit
public enum SceneStorageKeys {
    // Navigation state
    static let selectedTab = "selectedTab"
    static let selectedProject = "selectedProject"
    static let selectedSession = "selectedSession"
    static let navigationPath = "navigationPath"
    
    // View state
    static let sidebarVisible = "sidebarVisible"
    static let toolPanelVisible = "toolPanelVisible"
    static let diagnosticsTab = "diagnosticsTab"
    static let analyticsTimeRange = "analyticsTimeRange"
    
    // User preferences
    static let chatInputDraft = "chatInputDraft"
    static let filterText = "filterText"
    static let sortOrder = "sortOrder"
    static let viewMode = "viewMode"
    
    // Scroll positions
    static let messageListScrollPosition = "messageListScrollPosition"
    static let projectListScrollPosition = "projectListScrollPosition"
}

/// Protocol for views that support state restoration
public protocol RestorationSupporting {
    associatedtype RestorationState: Codable
    
    func saveRestorationState() -> RestorationState
    func restoreFromState(_ state: RestorationState)
}

/// Generic restoration state wrapper
public struct ViewRestorationState<T: Codable>: Codable {
    public let timestamp: Date
    public let version: Int
    public let data: T
    
    public init(data: T, version: Int = 1) {
        self.timestamp = Date()
        self.version = version
        self.data = data
    }
}

/// Scene storage property wrapper with type safety
@propertyWrapper
public struct TypedSceneStorage<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    @SceneStorage private var jsonString: String
    
    public init(wrappedValue defaultValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = defaultValue
        self._jsonString = SceneStorage(wrappedValue: "", key)
    }
    
    public var wrappedValue: Value {
        get {
            guard !jsonString.isEmpty,
                  let data = jsonString.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue),
               let string = String(data: encoded, encoding: .utf8) {
                jsonString = string
            }
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.jsonString = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            }
        )
    }
}

/// Navigation state for restoration
public struct NavigationRestorationState: Codable {
    public let selectedTab: String?
    public let navigationPath: [String]
    public let timestamp: Date
    
    public init(
        selectedTab: String? = nil,
        navigationPath: [String] = [],
        timestamp: Date = Date()
    ) {
        self.selectedTab = selectedTab
        self.navigationPath = navigationPath
        self.timestamp = timestamp
    }
}

/// Chat view restoration state
public struct ChatRestorationState: Codable {
    public let sessionId: String?
    public let projectId: String
    public let inputDraft: String
    public let scrollPosition: String?
    public let toolPanelVisible: Bool
    
    public init(
        sessionId: String? = nil,
        projectId: String,
        inputDraft: String = "",
        scrollPosition: String? = nil,
        toolPanelVisible: Bool = false
    ) {
        self.sessionId = sessionId
        self.projectId = projectId
        self.inputDraft = inputDraft
        self.scrollPosition = scrollPosition
        self.toolPanelVisible = toolPanelVisible
    }
}

/// Settings view restoration state
public struct SettingsRestorationState: Codable {
    public let selectedSection: String?
    public let expandedSections: Set<String>
    public let searchText: String
    
    public init(
        selectedSection: String? = nil,
        expandedSections: Set<String> = [],
        searchText: String = ""
    ) {
        self.selectedSection = selectedSection
        self.expandedSections = expandedSections
        self.searchText = searchText
    }
}

/// View modifier for automatic state restoration
public struct StateRestorationModifier: ViewModifier {
    let key: String
    let saveInterval: TimeInterval
    
    @State private var saveTimer: Timer?
    
    public init(key: String, saveInterval: TimeInterval = 5.0) {
        self.key = key
        self.saveInterval = saveInterval
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                startAutoSave()
            }
            .onDisappear {
                stopAutoSave()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                saveState()
            }
    }
    
    private func startAutoSave() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { _ in
            saveState()
        }
    }
    
    private func stopAutoSave() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    private func saveState() {
        // Trigger save through notification
        NotificationCenter.default.post(name: .saveRestorationState, object: key)
    }
}

extension Notification.Name {
    static let saveRestorationState = Notification.Name("saveRestorationState")
    static let restoreState = Notification.Name("restoreState")
}

/// View extension for easy state restoration
public extension View {
    func restorationEnabled(key: String, saveInterval: TimeInterval = 5.0) -> some View {
        self.modifier(StateRestorationModifier(key: key, saveInterval: saveInterval))
    }
}

// MARK: - Usage Examples
/*
 struct ContentView: View {
     // Simple restoration
     @SceneStorage(SceneStorageKeys.selectedTab) var selectedTab = 0
     
     // Complex restoration with type safety
     @TypedSceneStorage(SceneStorageKeys.navigationPath) var navState = NavigationRestorationState()
     
     // Draft preservation
     @SceneStorage(SceneStorageKeys.chatInputDraft) var inputDraft = ""
     
     var body: some View {
         TabView(selection: $selectedTab) {
             // Content
         }
         .restorationEnabled(key: "ContentView")
         .onAppear {
             // Restore navigation if needed
             if !navState.navigationPath.isEmpty {
                 // Navigate to saved path
             }
         }
     }
 }
 */