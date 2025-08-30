import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("baseURL") public var baseURL: String = "http://localhost:8000"
    @AppStorage("streamingDefault") public var streamingDefault: Bool = true
    @AppStorage("sseBufferKiB") public var sseBufferKiB: Int = 64

    @Published public var apiKeyPlaintext: String = ""
    private let keychain = KeychainService(service: "com.yourorg.claudecode", account: "apiKey")

    init() {
        if let stored = try? keychain.get() { self.apiKeyPlaintext = stored }
    }

    public func saveAPIKey() throws {
        try keychain.set(apiKeyPlaintext)
    }

    public var baseURLValidated: URL? { URL(string: baseURL) }
}
