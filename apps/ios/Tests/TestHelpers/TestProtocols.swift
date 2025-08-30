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
    func get(_ key: String) throws -> String? {
        return try self.get(key)
    }
    
    func set(_ value: String, key: String) throws {
        try self.set(value, key: key)
    }
    
    func remove(_ key: String) throws {
        try self.remove(key)
    }
    
    func removeAll() throws {
        try self.removeAll()
    }
}