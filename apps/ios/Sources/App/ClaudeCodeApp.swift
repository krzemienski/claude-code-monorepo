import SwiftUI
import OSLog

@main
struct ClaudeCodeApp: App {
    init() {
        // Initialize the dependency container first
        _ = EnhancedContainer.shared
        _ = Container.shared
        
        // Setup logging
        #if DEBUG
        DebugLogger.setup()
        #endif
        
        Logger.app.logLifecycle("App launched")
    }
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .performanceOverlay() // ⚡ Performance monitoring
                .onAppear {
                    Logger.app.logLifecycle("Main window appeared")
                    setupCyberpunkTheme()
                }
        }
    }
}

// 🎨 Cyberpunk Theme Setup
func setupCyberpunkTheme() {
    // Configure global appearance
    UINavigationBar.appearance().barTintColor = UIColor(CyberpunkTheme.Colors.darkBg)
    UINavigationBar.appearance().titleTextAttributes = [
        .foregroundColor: UIColor(CyberpunkTheme.Colors.neonCyan)
    ]
    UITabBar.appearance().barTintColor = UIColor(CyberpunkTheme.Colors.darkBgSecondary)
    UITabBar.appearance().tintColor = UIColor(CyberpunkTheme.Colors.neonCyan)
    UITabBar.appearance().unselectedItemTintColor = UIColor(CyberpunkTheme.Colors.neonCyan.opacity(0.5))
}

struct RootTabView: View {
    @StateObject private var settings = AppSettings()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            ProjectsListView()
                .tabItem { Label("Projects", systemImage: "folder") }

            SessionsView()
                .tabItem { Label("Sessions", systemImage: "bubble.left.and.bubble.right") }

            EnhancedAnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                
            MonitoringView()
                .tabItem { Label("Monitor", systemImage: "gauge") }
            
            #if DEBUG
            BackendTestView()
                .tabItem { Label("Test", systemImage: "network") }
            #endif
        }
        .environmentObject(settings)
        .onAppear {
            // Log initial settings
            Logger.app.info("Backend URL: \(settings.baseURL)")
            Logger.app.info("Streaming enabled: \(settings.streamingDefault)")
        }
    }
}
