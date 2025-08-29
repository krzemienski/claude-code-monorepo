import SwiftUI

struct SessionsView: View {
    @StateObject private var settings = AppSettings()
    @State private var sessions: [APIClient.Session] = []
    @State private var search = ""
    @State private var scope: Scope = .active
    @State private var isLoading = false
    @State private var err: String?

    enum Scope: String, CaseIterable, Identifiable { case active, all
        var id: String { rawValue }
        var title: String { self == .active ? "Active" : "All" }
    }

    var body: some View {
        List {
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            ForEach(filtered(sessions)) { s in
                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(s.title ?? s.id).font(.body)
                            if s.isActive {
                                Text("LIVE").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.accent).clipShape(Capsule()).foregroundStyle(Theme.accentFg)
                            }
                            Spacer(); Text(s.model).font(.caption).foregroundStyle(Theme.mutedFg)
                        }
                        HStack(spacing: 8) {
                            Text("msgs \(s.messageCount ?? 0)").font(.caption).foregroundStyle(Theme.mutedFg)
                            if let t = s.totalTokens { Text("tok \(t)").font(.caption).foregroundStyle(Theme.mutedFg) }
                            if let c = s.totalCost   { Text(String(format: "$%.3f", c)).font(.caption).foregroundStyle(Theme.mutedFg) }
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if s.isActive {
                        Button(role: .destructive) { Task { await stop(id: s.id) } } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                    }
                }
            }
        }
        .searchable(text: $search)
        .toolbar {
            Picker("Scope", selection: $scope) { ForEach(Scope.allCases) { sc in Text(sc.title).tag(sc) } }.pickerStyle(.segmented)
        }
        .navigationTitle("Sessions")
        .task { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func filtered(_ items: [APIClient.Session]) -> [APIClient.Session] {
        var base = items
        if scope == .active { base = base.filter { $0.isActive } }
        guard !search.isEmpty else { return base }
        return base.filter { s in
            (s.title ?? s.id).localizedCaseInsensitiveContains(search)
            || s.model.localizedCaseInsensitiveContains(search)
            || s.projectId.localizedCaseInsensitiveContains(search)
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do { sessions = try await client.listSessions(projectId: nil) } catch { err = "\(error)" }
    }

    private func stop(id: String) async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do { try await client.delete("/v1/chat/completions/\(id)"); await load() } catch { err = "\(error)" }
    }
}
