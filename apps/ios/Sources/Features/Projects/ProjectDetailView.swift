import SwiftUI

struct ProjectDetailView: View {
    @StateObject private var settings = AppSettings()
    let projectId: String

    @State private var project: APIClient.Project?
    @State private var sessions: [APIClient.Session] = []
    @State private var isLoading = false
    @State private var err: String?
    @State private var showNewSession = false

    var body: some View {
        List {
            if let p = project {
                Section("Info") {
                    LabeledContent("Name", value: p.name)
                    LabeledContent("Path", value: p.path ?? "—")
                    LabeledContent("Updated", value: p.updatedAt)
                }
            } else if isLoading {
                ProgressView()
            }

            Section("Sessions") {
                if sessions.isEmpty { Text("No sessions").foregroundStyle(Theme.mutedFg) }
                ForEach(sessions) { s in
                    NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                        VStack(alignment: .leading) {
                            Text(s.title ?? s.id).font(.body)
                            Text("model \(s.model) • msgs \(s.messageCount ?? 0)")
                                .font(.caption).foregroundStyle(Theme.mutedFg)
                        }
                    }
                }
            }
        }
        .navigationTitle("Project")
        .toolbar { Button { showNewSession = true } label: { Label("New Session", systemImage: "plus") } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showNewSession) { NewSessionView(projectId: projectId) }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do {
            async let p = client.getProject(id: projectId)
            async let ss = client.listSessions(projectId: projectId)
            project = try await p; sessions = try await ss
        } catch { err = "\(error)" }
    }
}
