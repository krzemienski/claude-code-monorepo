import SwiftUI

struct NewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = AppSettings()

    let projectId: String
    @State private var capabilities: [APIClient.ModelCapability] = []
    @State private var selectedModelId: String = ""
    @State private var title: String = ""
    @State private var systemPrompt: String = ""
    @State private var isLoading = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            Form {
                if capabilities.isEmpty && isLoading { ProgressView() }

                Picker("Model", selection: $selectedModelId) {
                    ForEach(capabilities) { m in Text(m.name).tag(m.id) }
                }

                TextField("Title (optional)", text: $title)
                TextEditor(text: $systemPrompt).frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))

                Toggle("Streaming by default", isOn: $settings.streamingDefault)
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Start") { Task { await start() } }.disabled(selectedModelId.isEmpty) }
            }
            .task { await load() }
            .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
                Button("OK", role: .cancel) { err = nil }
            } message: { e in Text(e) }
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do { capabilities = try await client.modelCapabilities(); if let first = capabilities.first { selectedModelId = first.id } }
        catch { err = "\(error)" }
    }

    private func start() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do {
            _ = try await client.createSession(projectId: projectId, model: selectedModelId, title: title.isEmpty ? nil : title, systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt)
            dismiss()
        } catch { err = "\(error)" }
    }
}
