import Foundation
import KeychainAccess
@testable import ClaudeCode

// MARK: - URLSession Protocol for Testing
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - Keychain Protocol for Testing
protocol KeychainProtocol {
    func get(_ key: String) throws -> String?
    func set(_ value: String, key: String) throws
    func remove(_ key: String) throws
    func removeAll() throws
}

// MARK: - URLSession Extension
extension URLSession: URLSessionProtocol {
    // URLSession already conforms to this interface
}

// MARK: - Keychain Extension
extension Keychain: KeychainProtocol {
    // Keychain already has these methods with matching signatures
}