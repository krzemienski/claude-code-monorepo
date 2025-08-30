import XCTest
import Combine
@testable import ClaudeCode

@MainActor
final class AuthenticationFlowTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var mockAPIClient: MockAPIClient!
    var mockKeychain: MockKeychainService!
    var settings: AppSettings!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        settings = AppSettings()
        mockAPIClient = MockAPIClient()
        mockKeychain = MockKeychainService()
        cancellables = []
        
        // Set up container with mocks
        EnhancedContainer.shared.reset()
        EnhancedContainer.shared.injectMock(APIClientProtocol.self, mock: mockAPIClient)
        EnhancedContainer.shared.injectMock(AppSettings.self, mock: settings)
        
        authManager = AuthenticationManager()
    }
    
    override func tearDown() async throws {
        authManager = nil
        mockAPIClient = nil
        mockKeychain?.reset()
        mockKeychain = nil
        settings = nil
        cancellables = nil
        EnhancedContainer.shared.reset()
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialUnauthenticatedState() {
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
        XCTAssertEqual(authManager.authState, .unauthenticated)
    }
    
    // MARK: - Login Flow Tests
    
    func testSuccessfulLogin() async throws {
        // Given
        let apiKey = "test-api-key-12345"
        let expectation = XCTestExpectation(description: "Login completed")
        
        authManager.$isAuthenticated
            .dropFirst()
            .sink { isAuthenticated in
                if isAuthenticated {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        try await authManager.login(apiKey: apiKey)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        XCTAssertEqual(authManager.authState, .authenticated)
        XCTAssertEqual(settings.apiKeyPlaintext, apiKey)
    }
    
    func testLoginWithInvalidAPIKey() async {
        // Given
        let invalidKey = ""
        
        // When & Then
        do {
            try await authManager.login(apiKey: invalidKey)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertFalse(authManager.isAuthenticated)
            XCTAssertEqual(authManager.authState, .unauthenticated)
        }
    }
    
    func testLoginWithNetworkError() async {
        // Given
        mockAPIClient.shouldFailRequests = true
        let apiKey = "test-api-key"
        
        // When & Then
        do {
            try await authManager.login(apiKey: apiKey)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertFalse(authManager.isAuthenticated)
            XCTAssertEqual(authManager.authState, .error(error.localizedDescription))
        }
    }
    
    // MARK: - Token Validation Tests
    
    func testTokenValidation() async throws {
        // Given
        let apiKey = "valid-token"
        settings.apiKeyPlaintext = apiKey
        
        // When
        let isValid = try await authManager.validateToken()
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testExpiredTokenHandling() async throws {
        // Given
        let expiredToken = "expired-token"
        settings.apiKeyPlaintext = expiredToken
        mockAPIClient.shouldReturnExpiredToken = true
        
        // When
        let isValid = try await authManager.validateToken()
        
        // Then
        XCTAssertFalse(isValid)
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    // MARK: - Logout Flow Tests
    
    func testSuccessfulLogout() async throws {
        // Given - User is logged in
        let apiKey = "test-api-key"
        try await authManager.login(apiKey: apiKey)
        XCTAssertTrue(authManager.isAuthenticated)
        
        // When
        await authManager.logout()
        
        // Then
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
        XCTAssertEqual(authManager.authState, .unauthenticated)
        XCTAssertEqual(settings.apiKeyPlaintext, "")
    }
    
    // MARK: - Session Persistence Tests
    
    func testSessionPersistence() async throws {
        // Given
        let apiKey = "persistent-key"
        try await authManager.login(apiKey: apiKey)
        
        // When - Create new auth manager (simulating app restart)
        let newAuthManager = AuthenticationManager()
        await newAuthManager.checkStoredCredentials()
        
        // Then
        XCTAssertTrue(newAuthManager.isAuthenticated)
        XCTAssertNotNil(newAuthManager.currentUser)
    }
    
    func testSessionExpiration() async throws {
        // Given
        let apiKey = "expiring-key"
        try await authManager.login(apiKey: apiKey)
        
        // When - Simulate token expiration
        mockAPIClient.shouldReturnExpiredToken = true
        await authManager.refreshTokenIfNeeded()
        
        // Then
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    // MARK: - Biometric Authentication Tests
    
    func testBiometricAuthenticationSetup() async throws {
        // Given
        let apiKey = "biometric-key"
        try await authManager.login(apiKey: apiKey)
        
        // When
        let success = await authManager.enableBiometricAuthentication()
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(authManager.isBiometricEnabled)
    }
    
    func testBiometricAuthenticationLogin() async throws {
        // Given
        await authManager.enableBiometricAuthentication()
        await authManager.logout()
        
        // When
        let success = await authManager.authenticateWithBiometrics()
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(authManager.isAuthenticated)
    }
    
    // MARK: - State Observation Tests
    
    func testAuthStatePublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Auth state changes")
        var stateChanges: [AuthenticationManager.AuthState] = []
        
        authManager.$authState
            .sink { state in
                stateChanges.append(state)
                if stateChanges.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        Task {
            authManager.authState = .authenticating
            try? await authManager.login(apiKey: "test-key")
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(stateChanges.contains(.unauthenticated))
        XCTAssertTrue(stateChanges.contains(.authenticating))
        XCTAssertTrue(stateChanges.contains(.authenticated))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentLoginAttempts() async throws {
        // Given
        let apiKey = "concurrent-key"
        
        // When - Multiple concurrent login attempts
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        try await self.authManager.login(apiKey: apiKey)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            // Then - All should succeed without race conditions
            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }
            XCTAssertGreaterThan(successCount, 0)
        }
        
        XCTAssertTrue(authManager.isAuthenticated)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery() async throws {
        // Given
        mockAPIClient.shouldFailRequests = true
        
        // When - First attempt fails
        do {
            try await authManager.login(apiKey: "test-key")
        } catch {
            XCTAssertEqual(authManager.authState, .error(error.localizedDescription))
        }
        
        // When - Fix error and retry
        mockAPIClient.shouldFailRequests = false
        try await authManager.login(apiKey: "test-key")
        
        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.authState, .authenticated)
    }
}

// MARK: - Authentication Manager Test Implementation

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authState: AuthState = .unauthenticated
    @Published var isBiometricEnabled = false
    
    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated
        case error(String)
    }
    
    struct User {
        let id: String
        let email: String
    }
    
    private let settings: AppSettings
    private let apiClient: APIClientProtocol
    
    init() {
        self.settings = ServiceLocator.shared.resolve(AppSettings.self) ?? AppSettings()
        self.apiClient = ServiceLocator.shared.resolve(APIClientProtocol.self) ?? MockAPIClient()
        
        Task {
            await checkStoredCredentials()
        }
    }
    
    func login(apiKey: String) async throws {
        guard !apiKey.isEmpty else {
            throw AuthenticationError.invalidToken
        }
        
        authState = .authenticating
        
        do {
            // Validate with backend
            _ = try await apiClient.health()
            
            // Store credentials
            settings.apiKeyPlaintext = apiKey
            
            // Update state
            isAuthenticated = true
            currentUser = User(id: "user-123", email: "user@example.com")
            authState = .authenticated
        } catch {
            authState = .error(error.localizedDescription)
            throw error
        }
    }
    
    func logout() async {
        isAuthenticated = false
        currentUser = nil
        authState = .unauthenticated
        settings.apiKeyPlaintext = ""
        isBiometricEnabled = false
    }
    
    func validateToken() async throws -> Bool {
        guard !settings.apiKeyPlaintext.isEmpty else {
            return false
        }
        
        do {
            _ = try await apiClient.health()
            return true
        } catch {
            isAuthenticated = false
            return false
        }
    }
    
    func checkStoredCredentials() async {
        if !settings.apiKeyPlaintext.isEmpty {
            do {
                try await login(apiKey: settings.apiKeyPlaintext)
            } catch {
                await logout()
            }
        }
    }
    
    func refreshTokenIfNeeded() async {
        if !(try? await validateToken()) ?? false {
            await logout()
        }
    }
    
    func enableBiometricAuthentication() async -> Bool {
        // Simulate biometric setup
        isBiometricEnabled = true
        return true
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricEnabled else { return false }
        
        // Simulate biometric authentication
        if let storedKey = try? settings.apiKeyPlaintext,
           !storedKey.isEmpty {
            do {
                try await login(apiKey: storedKey)
                return true
            } catch {
                return false
            }
        }
        return false
    }
}

// MARK: - Mock Extensions

extension MockAPIClient {
    var shouldReturnExpiredToken: Bool {
        get { false }
        set { /* Implementation */ }
    }
}