import SwiftUI

struct ProjectsListView: View {
    @StateObject private var settings = AppSettings()
    @State private var projects: [APIClient.Project] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var err: String?
    @State private var showCreate = false

    var body: some View {
        List {
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            ForEach(filtered(projects)) { p in
                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.body)
                        Text(p.path ?? "—").font(.caption).foregroundStyle(Theme.mutedFg)
                    }
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Projects")
        .toolbar { Button { showCreate = true } label: { Label("New", systemImage: "plus") } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            CreateProjectSheet { name, desc, path in
                Task { await create(name: name, desc: desc, path: path); showCreate = false }
            }
        }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func filtered(_ items: [APIClient.Project]) -> [APIClient.Project] {
        guard !search.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(search) || ($0.path ?? "").localizedCaseInsensitiveContains(search) }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do { projects = try await client.listProjects() } catch { err = "\(error)" }
    }

    private func create(name: String, desc: String, path: String?) async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do { _ = try await client.createProject(name: name, description: desc, path: path); await load() }
        catch { err = "\(error)" }
    }
}

private struct CreateProjectSheet: View {
    var onCreate: (String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var desc = ""
    @State private var path: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                TextField("Path (optional)", text: $path)
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { onCreate(name, desc, path.isEmpty ? nil : path) } .disabled(name.isEmpty) }
            }
        }
    }
}
