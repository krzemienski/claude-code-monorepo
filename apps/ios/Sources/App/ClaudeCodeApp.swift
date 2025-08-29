import SwiftUI

@main
struct ClaudeCodeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootTabView: View {
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
        }
    }
}
