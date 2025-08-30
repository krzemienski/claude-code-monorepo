import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @State private var validating = false
    @State private var healthText: String = "Not validated"
    @State private var showKey = false
    @State private var errorMsg: String?

    var body: some View {
        Form {
            Section("Server") {
                TextField("Base URL", text: $settings.baseURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    if showKey {
                        TextField("API Key", text: $settings.apiKeyPlaintext)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("API Key", text: $settings.apiKeyPlaintext)
                    }
                    Button(showKey ? "Hide" : "Show") { showKey.toggle() }
                        .buttonStyle(.bordered)
                }

                Toggle("Streaming by default", isOn: $settings.streamingDefault)

                Stepper(value: $settings.sseBufferKiB, in: 16...512, step: 16) {
                    Text("SSE buffer: \(settings.sseBufferKiB) KiB")
                }
            }

            Section("Actions") {
                HStack {
                    Button {
                        Task { await validateAndSave() }
                    } label: {
                        if validating { ProgressView() } else { Text("Validate") }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                    Text(healthText)
                        .foregroundStyle(errorMsg == nil ? Theme.accent : Theme.destructive)
                        .font(.footnote)
                }
            }

            if let errorMsg {
                Section("Error") {
                    Text(errorMsg).foregroundStyle(Theme.destructive).font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func validateAndSave() async {
        errorMsg = nil
        guard let client = APIClient(settings: settings) else {
            errorMsg = "Invalid Base URL"
            return
        }
        do {
            validating = true
            let health = try await client.health()
            try settings.saveAPIKey()
            healthText = health.ok ? "OK • v\(health.version ?? "?") • sessions \(health.active_sessions ?? 0)" : "Unhealthy"
        } catch {
            errorMsg = "\(error)"; healthText = "Unhealthy"
        }
        validating = false
    }
}
