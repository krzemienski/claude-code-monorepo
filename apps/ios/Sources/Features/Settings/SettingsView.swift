import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @State private var validating = false
    @State private var healthText: String = "Not validated"
    @State private var showKey = false
    @State private var errorMsg: String?
    
    // Environment values for adaptive layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case baseURL, apiKey
    }

    var body: some View {
        Form {
            Section("Server") {
                TextField("Base URL", text: $settings.baseURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .baseURL)
                    .accessibilityElement(
                        label: "Server base URL",
                        value: settings.baseURL,
                        hint: "Enter the URL of your Claude Code server"
                    )

                HStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
                    if showKey {
                        TextField("API Key", text: $settings.apiKeyPlaintext)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .apiKey)
                    } else {
                        SecureField("API Key", text: $settings.apiKeyPlaintext)
                            .focused($focusedField, equals: .apiKey)
                    }
                    Button(showKey ? "Hide" : "Show") { 
                        showKey.toggle() 
                    }
                    .buttonStyle(.bordered)
                    .accessibilityElement(
                        label: showKey ? "Hide API key" : "Show API key",
                        hint: showKey ? "Hide the API key for security" : "Show the API key to verify it",
                        traits: .isButton
                    )
                }
                .accessibilityElement(
                    label: "API Key",
                    value: showKey ? settings.apiKeyPlaintext : "Hidden",
                    hint: "Enter your API key for authentication"
                )

                Toggle("Streaming by default", isOn: $settings.streamingDefault)
                    .applyDynamicTypeSize()
                    .accessibilityElement(
                        label: "Streaming by default",
                        value: settings.streamingDefault ? "Enabled" : "Disabled",
                        hint: "Enable streaming responses for faster feedback"
                    )

                Stepper(value: $settings.sseBufferKiB, in: 16...512, step: 16) {
                    Text("SSE buffer: \(settings.sseBufferKiB) KiB")
                        .applyDynamicTypeSize()
                }
                .accessibilityElement(
                    label: "SSE buffer size",
                    value: "\(settings.sseBufferKiB) kilobytes",
                    hint: "Adjust the server-sent events buffer size in kilobytes"
                )
            }

            Section("Actions") {
                HStack {
                    Button {
                        Task { await validateAndSave() }
                    } label: {
                        if validating { 
                            ProgressView()
                                .accessibilityElement(
                                    label: "Validating",
                                    traits: .updatesFrequently
                                )
                        } else { 
                            Text("Validate")
                                .applyDynamicTypeSize()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityElement(
                        label: "Validate settings",
                        hint: "Test connection to the server with current settings",
                        traits: .isButton
                    )

                    if horizontalSizeClass == .regular {
                        Spacer()
                    }
                    
                    Text(healthText)
                        .foregroundStyle(errorMsg == nil ? Theme.accent : Theme.destructive)
                        .font(.footnote)
                        .applyDynamicTypeSize()
                        .accessibilityElement(
                            label: "Server status",
                            value: healthText
                        )
                }
            }

            if let errorMsg {
                Section("Error") {
                    Text(errorMsg)
                        .foregroundStyle(Theme.destructive)
                        .font(.footnote)
                        .applyDynamicTypeSize()
                        .accessibilityElement(
                            label: "Error message",
                            value: errorMsg,
                            traits: .isStaticText
                        )
                }
            }
        }
        .navigationTitle("Settings")
        .accessibilityElement(
            label: "Settings",
            traits: .isHeader
        )
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
