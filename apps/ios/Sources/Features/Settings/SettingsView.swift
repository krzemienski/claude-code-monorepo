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
                    .dynamicTypeSize()
                    .accessibilityElement(
                        label: "Server base URL",
                        hint: "Enter the URL of your Claude Code server",
                        value: settings.baseURL
                    )

                HStack(spacing: Theme.Spacing.adaptive(Theme.Spacing.sm)) {
                    if showKey {
                        TextField("API Key", text: $settings.apiKeyPlaintext)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .apiKey)
                            .dynamicTypeSize()
                    } else {
                        SecureField("API Key", text: $settings.apiKeyPlaintext)
                            .focused($focusedField, equals: .apiKey)
                            .dynamicTypeSize()
                    }
                    Button(showKey ? "Hide" : "Show") { 
                        showKey.toggle() 
                    }
                    .buttonStyle(.bordered)
                    .dynamicTypeSize()
                    .accessibilityElement(
                        label: showKey ? "Hide API key" : "Show API key",
                        hint: showKey ? "Hide the API key for security" : "Show the API key to verify it",
                        traits: .isButton
                    )
                }
                .accessibilityElement(
                    label: "API Key",
                    hint: "Enter your API key for authentication",
                    value: showKey ? settings.apiKeyPlaintext : "Hidden"
                )

                Toggle("Streaming by default", isOn: $settings.streamingDefault)
                    .dynamicTypeSize()
                    .accessibilityElement(
                        label: "Streaming by default",
                        hint: "Enable streaming responses for faster feedback",
                        value: settings.streamingDefault ? "Enabled" : "Disabled"
                    )

                Stepper(value: $settings.sseBufferKiB, in: 16...512, step: 16) {
                    Text("SSE buffer: \(settings.sseBufferKiB) KiB")
                        .dynamicTypeSize()
                }
                .accessibilityElement(
                    label: "SSE buffer size",
                    hint: "Adjust the server-sent events buffer size in kilobytes",
                    value: "\(settings.sseBufferKiB) kilobytes"
                )
            }

            Section("Actions") {
                AdaptiveStack {
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
                                .dynamicTypeSize()
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
                        .dynamicTypeSize()
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
                        .dynamicTypeSize()
                        .accessibilityElement(
                            label: "Error message",
                            traits: .isStaticText,
                            value: errorMsg
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
