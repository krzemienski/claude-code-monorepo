import XCTest
@testable import ClaudeCode

final class AuthenticationTests: XCTestCase {
    
    // Note: AuthenticationManager is a singleton with private init,
    // so we'll test it using its public interface
    
    @MainActor
    func testAuthenticationFlow() async throws {
        let authManager = AuthenticationManager.shared
        
        // Test initial state
        if case .unauthenticated = authManager.state {
            XCTAssertTrue(true, "Initial state should be unauthenticated")
        } else {
            XCTFail("Expected unauthenticated state initially")
        }
        
        // Test biometric availability check
        XCTAssertNotNil(authManager.biometricType)
    }
    
    @MainActor
    func testAPIKeyValidation() async {
        let authManager = AuthenticationManager.shared
        
        // Test that invalid API key throws error
        do {
            try await authManager.authenticate(apiKey: "", baseURL: "https://api.example.com")
            XCTFail("Should not authenticate with empty API key")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    @MainActor
    func testSignOut() async {
        let authManager = AuthenticationManager.shared
        
        // Test sign out functionality
        authManager.signOut()
        
        if case .unauthenticated = authManager.state {
            XCTAssertTrue(true, "State should be unauthenticated after sign out")
        } else {
            XCTFail("Expected unauthenticated state after sign out")
        }
    }
    
    // MARK: - Mock Keychain Tests
    
    func testKeychainOperations() throws {
        let keychain = KeychainMock()
        
        // Test save
        try keychain.set("test-value", key: "test-key")
        
        // Test retrieve
        let retrieved = try keychain.get("test-key")
        XCTAssertEqual(retrieved, "test-value")
        
        // Test remove
        try keychain.remove("test-key")
        let afterRemove = try keychain.get("test-key")
        XCTAssertNil(afterRemove)
        
        // Test removeAll
        try keychain.set("value1", key: "key1")
        try keychain.set("value2", key: "key2")
        try keychain.removeAll()
        
        let afterRemoveAll1 = try keychain.get("key1")
        let afterRemoveAll2 = try keychain.get("key2")
        XCTAssertNil(afterRemoveAll1)
        XCTAssertNil(afterRemoveAll2)
    }
    
    // MARK: - Authentication Error Tests
    
    func testAuthenticationErrorMessages() {
        let errors: [AuthenticationError] = [
            .invalidCredentials,
            .biometricNotAvailable,
            .biometricAuthenticationFailed,
            .keychainError("Test error"),
            .networkError("Connection failed"),
            .sessionExpired,
            .unknown("Unknown error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
        }
    }
    
    // MARK: - Authenticated User Tests
    
    func testAuthenticatedUserCreation() {
        let user = AuthenticatedUser(
            id: "user-123",
            apiKey: "api-key-456",
            baseURL: "https://api.example.com",
            authenticatedAt: Date(),
            biometricEnabled: false
        )
        
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.apiKey, "api-key-456")
        XCTAssertEqual(user.baseURL, "https://api.example.com")
        XCTAssertFalse(user.biometricEnabled)
    }
}

// MARK: - Mock Helpers

class KeychainMock: KeychainProtocol {
    var savedItems: [String: String] = [:]
    var shouldThrowError = false
    
    func get(_ key: String) throws -> String? {
        if shouldThrowError {
            throw KeychainService.KeychainError.noData
        }
        return savedItems[key]
    }
    
    func set(_ value: String, key: String) throws {
        if shouldThrowError {
            throw KeychainService.KeychainError.unexpectedData
        }
        savedItems[key] = value
    }
    
    func remove(_ key: String) throws {
        if shouldThrowError {
            throw KeychainService.KeychainError.unhandledError(status: -1)
        }
        savedItems.removeValue(forKey: key)
    }
    
    func removeAll() throws {
        if shouldThrowError {
            throw KeychainService.KeychainError.unhandledError(status: -1)
        }
        savedItems.removeAll()
    }
}

// Mock URLSession for authentication tests
class AuthURLSessionMock: URLSessionProtocol {
    var mockResponse: Any?
    var shouldFail = false
    var mockError: Error?
    var statusCode = 200
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldFail {
            throw mockError ?? URLError(.badServerResponse)
        }
        
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let data: Data
        if let response = mockResponse {
            data = try JSONSerialization.data(withJSONObject: response)
        } else {
            data = Data()
        }
        
        return (data, httpResponse)
    }
}

// Local test response type
struct TestEmptyResponse: Codable {}