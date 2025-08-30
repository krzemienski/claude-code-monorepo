import SwiftUI

struct SessionsView: View {
    @StateObject private var settings = AppSettings()
    @State private var sessions: [APIClient.Session] = []
    @State private var search = ""
    @State private var scope: Scope = .active
    @State private var isLoading = false
    @State private var err: String?
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    enum Scope: String, CaseIterable, Identifiable { case active, all
        var id: String { rawValue }
        var title: String { self == .active ? "Active" : "All" }
    }

    var body: some View {
        List {
            if isLoading { 
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(
                        label: "Loading sessions",
                        traits: .updatesFrequently
                    )
            }
            ForEach(filtered(sessions)) { s in
                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.adaptive(Theme.Spacing.xs)) {
                        HStack {
                            Text(s.title ?? s.id)
                                .font(.body)
                                .dynamicTypeSize()
                            if s.isActive {
                                Text("LIVE")
                                    .font(.caption2)
                                    .dynamicTypeSize()
                                    .padding(.horizontal, Theme.Spacing.adaptive(Theme.Spacing.xs))
                                    .padding(.vertical, 2)
                                    .background(Theme.accent)
                                    .clipShape(Capsule())
                                    .foregroundStyle(Theme.accentFg)
                                    .accessibilityElement(
                                        label: "Live session",
                                        traits: .isStaticText
                                    )
                            }
                            Spacer()
                            Text(s.model)
                                .font(.caption)
                                .foregroundStyle(Theme.mutedFg)
                                .dynamicTypeSize()
                        }
                        HStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
                            Text("msgs \(s.messageCount ?? 0)")
                                .font(.caption)
                                .foregroundStyle(Theme.mutedFg)
                                .dynamicTypeSize()
                            if let t = s.totalTokens { 
                                Text("tok \(t)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mutedFg)
                                    .dynamicTypeSize()
                            }
                            if let c = s.totalCost { 
                                Text(String(format: "$%.3f", c))
                                    .font(.caption)
                                    .foregroundStyle(Theme.mutedFg)
                                    .dynamicTypeSize()
                            }
                        }
                    }
                }
                .accessibleNavigationLink(
                    label: "Session \(s.title ?? s.id)",
                    hint: "Model: \(s.model), \(s.messageCount ?? 0) messages, \(s.isActive ? "Active" : "Inactive")"
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if s.isActive {
                        Button(role: .destructive) { Task { await stop(id: s.id) } } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                        .accessibilityElement(
                            label: "Stop session",
                            hint: "Stop the active session \(s.title ?? s.id)",
                            traits: .isButton
                        )
                    }
                }
            }
        }
        .searchable(text: $search, prompt: Text("Search sessions"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { sc in
                        Text(sc.title)
                            .tag(sc)
                            .dynamicTypeSize()
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityElement(
                    label: "Session scope filter",
                    hint: "Filter between active and all sessions",
                    value: scope.title
                )
            }
        }
        .navigationTitle("Sessions")
        .accessibilityElement(
            label: "Sessions view",
            traits: .isHeader
        )
        .task { await load() }
        .refreshable { await load() }
        .accessibilityAction(named: "Refresh") {
            Task { await load() }
        }
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
