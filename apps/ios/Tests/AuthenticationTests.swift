import XCTest
@testable import ClaudeCode

final class AuthenticationTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var mockSession: AuthURLSessionMock!
    var mockKeychain: KeychainMock!
    
    override func setUp() {
        super.setUp()
        mockSession = AuthURLSessionMock()
        mockKeychain = KeychainMock()
        authManager = AuthenticationManager(
            session: mockSession,
            keychain: mockKeychain
        )
    }
    
    override func tearDown() {
        authManager = nil
        mockSession = nil
        mockKeychain = nil
        super.tearDown()
    }
    
    // MARK: - Login Tests
    
    func testLoginSuccess() async throws {
        // Given
        let email = "test@example.com"
        let password = "securePassword123"
        let expectedToken = "jwt-token-12345"
        let expectedAPIKey = "api-key-67890"
        
        mockSession.mockResponse = AuthResponse(
            token: expectedToken,
            apiKey: expectedAPIKey,
            user: User(id: "user-1", email: email)
        )
        
        // When
        let result = try await authManager.login(email: email, password: password)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockKeychain.savedItems["auth_token"], expectedToken)
        XCTAssertEqual(mockKeychain.savedItems["api_key"], expectedAPIKey)
        XCTAssertEqual(authManager.currentUser?.email, email)
        XCTAssertTrue(authManager.isAuthenticated)
    }
    
    func testLoginFailureInvalidCredentials() async {
        // Given
        let email = "test@example.com"
        let password = "wrongPassword"
        mockSession.shouldFail = true
        mockSession.mockError = APIError.unauthorized
        
        // When/Then
        do {
            _ = try await authManager.login(email: email, password: password)
            XCTFail("Expected login to fail")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
            XCTAssertNil(mockKeychain.savedItems["auth_token"])
            XCTAssertFalse(authManager.isAuthenticated)
        }
    }
    
    func testLoginNetworkError() async {
        // Given
        mockSession.shouldFail = true
        mockSession.mockError = URLError(.notConnectedToInternet)
        
        // When/Then
        do {
            _ = try await authManager.login(email: "test@example.com", password: "pass")
            XCTFail("Expected network error")
        } catch {
            XCTAssertTrue(error is URLError)
            XCTAssertFalse(authManager.isAuthenticated)
        }
    }
    
    // MARK: - Token Refresh Tests
    
    func testTokenRefreshSuccess() async throws {
        // Given
        mockKeychain.savedItems["refresh_token"] = "old-refresh-token"
        let newToken = "new-jwt-token"
        mockSession.mockResponse = TokenRefreshResponse(
            token: newToken,
            refreshToken: "new-refresh-token"
        )
        
        // When
        let result = try await authManager.refreshToken()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockKeychain.savedItems["auth_token"], newToken)
    }
    
    func testTokenRefreshFailureTriggersLogout() async throws {
        // Given
        mockKeychain.savedItems["auth_token"] = "expired-token"
        mockKeychain.savedItems["refresh_token"] = "invalid-refresh"
        mockSession.shouldFail = true
        mockSession.mockError = APIError.unauthorized
        
        // When
        let result = try? await authManager.refreshToken()
        
        // Then
        XCTAssertNil(result)
        XCTAssertNil(mockKeychain.savedItems["auth_token"])
        XCTAssertNil(mockKeychain.savedItems["refresh_token"])
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsAllData() async {
        // Given
        mockKeychain.savedItems["auth_token"] = "token"
        mockKeychain.savedItems["api_key"] = "key"
        mockKeychain.savedItems["refresh_token"] = "refresh"
        authManager.currentUser = User(id: "1", email: "test@example.com")
        
        // When
        await authManager.logout()
        
        // Then
        XCTAssertNil(mockKeychain.savedItems["auth_token"])
        XCTAssertNil(mockKeychain.savedItems["api_key"])
        XCTAssertNil(mockKeychain.savedItems["refresh_token"])
        XCTAssertNil(authManager.currentUser)
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    // MARK: - API Key Tests
    
    func testValidateAPIKeySuccess() async throws {
        // Given
        let apiKey = "valid-api-key"
        mockKeychain.savedItems["api_key"] = apiKey
        mockSession.mockResponse = ValidationResponse(valid: true)
        
        // When
        let isValid = try await authManager.validateAPIKey()
        
        // Then
        XCTAssertTrue(isValid)
        XCTAssertEqual(mockSession.lastRequest?.allHTTPHeaderFields?["X-API-Key"], apiKey)
    }
    
    func testValidateAPIKeyFailure() async throws {
        // Given
        mockKeychain.savedItems["api_key"] = "invalid-key"
        mockSession.mockResponse = ValidationResponse(valid: false)
        
        // When
        let isValid = try await authManager.validateAPIKey()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Session Management Tests
    
    func testAutoRefreshOnUnauthorized() async throws {
        // Given
        mockKeychain.savedItems["refresh_token"] = "valid-refresh"
        
        // First request fails with 401
        mockSession.responses = [
            .failure(APIError.unauthorized),
            .success(TokenRefreshResponse(token: "new-token", refreshToken: "new-refresh")),
            .success(["data": "success"])
        ]
        
        // When
        let result = try await authManager.makeAuthenticatedRequest(endpoint: "/api/data")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(mockSession.requestCount, 3) // Original + refresh + retry
        XCTAssertEqual(mockKeychain.savedItems["auth_token"], "new-token")
    }
    
    // MARK: - Performance Tests
    
    func testLoginPerformance() {
        measure {
            let expectation = expectation(description: "Login performance")
            
            Task {
                _ = try? await authManager.login(email: "test@example.com", password: "password")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Classes

class AuthURLSessionMock: URLSessionProtocol {
    var mockResponse: Any?
    var mockError: Error?
    var shouldFail = false
    var lastRequest: URLRequest?
    var requestCount = 0
    var responses: [Result<Any, Error>] = []
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        requestCount += 1
        
        if !responses.isEmpty {
            let response = responses.removeFirst()
            switch response {
            case .success(let data):
                let encoded = try JSONEncoder().encode(data as! Encodable)
                return (encoded, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            case .failure(let error):
                throw error
            }
        }
        
        if shouldFail {
            throw mockError ?? URLError(.badServerResponse)
        }
        
        guard let response = mockResponse else {
            throw URLError(.badServerResponse)
        }
        
        let data = try JSONEncoder().encode(response as! Encodable)
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, httpResponse)
    }
}

class KeychainMock: KeychainProtocol {
    var savedItems: [String: String] = [:]
    
    func save(_ value: String, for key: String) throws {
        savedItems[key] = value
    }
    
    func retrieve(for key: String) throws -> String? {
        return savedItems[key]
    }
    
    func delete(for key: String) throws {
        savedItems.removeValue(forKey: key)
    }
    
    func clear() throws {
        savedItems.removeAll()
    }
}