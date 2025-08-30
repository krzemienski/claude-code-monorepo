import SwiftUI

struct ProjectsListView: View {
    @StateObject private var settings = AppSettings()
    @State private var projects: [APIClient.Project] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var err: String?
    @State private var showCreate = false
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        List {
            if isLoading { 
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(
                        label: "Loading projects",
                        traits: .updatesFrequently
                    )
            }
            ForEach(filtered(projects)) { p in
                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(p.name)
                            .font(.body)
                            .applyDynamicTypeSize()
                        Text(p.path ?? "—")
                            .font(.caption)
                            .foregroundStyle(Theme.mutedFg)
                            .applyDynamicTypeSize()
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .accessibleNavigationLink(
                    label: "Project \(p.name)",
                    hint: "Path: \(p.path ?? "No path specified")"
                )
            }
        }
        .searchable(text: $search, prompt: Text("Search projects"))
        .navigationTitle("Projects")
        .toolbar { 
            Button { showCreate = true } label: { 
                Label("New", systemImage: "plus") 
            }
            .accessibilityElement(
                label: "New project",
                hint: "Create a new project",
                traits: .isButton
            )
        }
        .accessibilityElement(
            label: "Projects list",
            traits: .isHeader
        )
        .task { await load() }
        .refreshable { await load() }
        .accessibilityAction(named: "Refresh") {
            Task { await load() }
        }
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
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var name = ""
    @State private var desc = ""
    @State private var path: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, description, path
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .applyDynamicTypeSize()
                        .accessibilityElement(
                            label: "Project name",
                            value: name,
                            hint: "Required. Enter the name for your new project"
                        )
                    
                    TextField("Description", text: $desc)
                        .focused($focusedField, equals: .description)
                        .applyDynamicTypeSize()
                        .accessibilityElement(
                            label: "Project description",
                            value: desc,
                            hint: "Optional. Describe your project"
                        )
                    
                    TextField("Path (optional)", text: $path)
                        .focused($focusedField, equals: .path)
                        .applyDynamicTypeSize()
                        .accessibilityElement(
                            label: "Project path",
                            value: path,
                            hint: "Optional. Specify the file system path for your project"
                        )
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button("Cancel") { dismiss() }
                        .accessibilityElement(
                            label: "Cancel",
                            value: "",
                            hint: "Dismiss without creating project",
                            traits: .isButton
                        )
                }
                ToolbarItem(placement: .confirmationAction) { 
                    Button("Create") { 
                        onCreate(name, desc, path.isEmpty ? nil : path) 
                    }
                    .disabled(name.isEmpty)
                    .accessibilityElement(
                        label: "Create project",
                        value: "",
                        hint: name.isEmpty ? "Enter a project name first" : "Create the new project",
                        traits: .isButton
                    )
                }
            }
        }
    }
}
