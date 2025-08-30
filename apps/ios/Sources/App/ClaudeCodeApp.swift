import SwiftUI
import OSLog

@main
struct ClaudeCodeApp: App {
    init() {
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
                .onAppear {
                    Logger.app.logLifecycle("Main window appeared")
                }
        }
    }
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
