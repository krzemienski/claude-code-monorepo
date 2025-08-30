import SwiftUI

struct HomeView: View {
    @StateObject private var settings = AppSettings()
    @State private var projects: [APIClient.Project] = []
    @State private var sessions: [APIClient.Session] = []
    @State private var stats: APIClient.SessionStats?
    @State private var isLoading = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: ProjectsListView()) { pill("Projects", system: "folder") }
                        NavigationLink(destination: SessionsView()) { pill("Sessions", system: "bubble.left.and.bubble.right") }
                        NavigationLink(destination: MonitoringView()) { pill("Monitor", system: "gauge") }
                    }.padding(.horizontal)

                    sectionCard("Recent Projects") {
                        if isLoading { ProgressView() }
                        else if projects.isEmpty { Text("No projects").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(projects.prefix(3)) { p in
                                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(p.name).font(.headline)
                                            Text(p.path ?? "—").font(.caption).foregroundStyle(Theme.mutedFg)
                                        }
                                        Spacer(); Image(systemName: "chevron.right")
                                    }.padding(.vertical, 6)
                                }
                                Divider().background(Theme.border)
                            }
                        }
                    }

                    sectionCard("Active Sessions") {
                        if isLoading { ProgressView() }
                        else if sessions.isEmpty { Text("No active sessions").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(sessions.prefix(3)) { s in
                                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(s.title ?? s.id).font(.subheadline)
                                            Text("model \(s.model) • msgs \(s.messageCount ?? 0)")
                                                .font(.caption).foregroundStyle(Theme.mutedFg)
                                        }
                                        Spacer(); Image(systemName: "chevron.right")
                                    }.padding(.vertical, 6)
                                }
                                Divider().background(Theme.border)
                            }
                        }
                    }

                    sectionCard("Usage Highlights") {
                        if let st = stats {
                            HStack {
                                metric("Tokens", "\(st.totalTokens)")
                                metric("Sessions", "\(st.activeSessions)")
                                metric("Cost", String(format: "$%.2f", st.totalCost))
                                metric("Msgs", "\(st.totalMessages)")
                            }
                        } else if isLoading { ProgressView() }
                        else { Text("No stats").foregroundStyle(Theme.mutedFg) }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Claude Code")
            .toolbar { NavigationLink(destination: SettingsView()) { Image(systemName: "gear") } }
            .task { await load() }
            .refreshable { await load() }
            .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
                Button("OK", role: .cancel) { err = nil }
            } message: { err in Text(err) }
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true
        do {
            async let ps = client.listProjects()
            async let ss = client.listSessions()
            async let st = client.sessionStats()
            projects = try await ps
            sessions = try await ss.filter { $0.isActive }
            stats = try await st
        } catch { err = "\(error)" }
        isLoading = false
    }

    private func pill(_ title: String, system: String) -> some View {
        Label(title, systemImage: system)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Theme.foreground)
            content()
        }
        .padding()
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.headline).foregroundStyle(Theme.primary)
            Text(label).font(.caption).foregroundStyle(Theme.mutedFg)
        }.frame(maxWidth: .infinity)
    }
}
