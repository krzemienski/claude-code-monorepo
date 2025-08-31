import SwiftUI
import Combine

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @AppStorage("baseURL") public var baseURL: String = "http://localhost:8000"
    @AppStorage("streamingDefault") public var streamingDefault: Bool = true
    @AppStorage("sseBufferKiB") public var sseBufferKiB: Int = 64

    public init() {}

    public var baseURLValidated: URL? { URL(string: baseURL) }
}
