import Foundation
import LocalAuthentication
import Combine

// MARK: - NO AUTHENTICATION IMPLEMENTATION
// This file is maintained for backward compatibility only.
// The application now operates without authentication.
// All methods return success/default values immediately.

// MARK: - Authentication State (Deprecated)
public enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(user: AuthenticatedUser)
    case failed(error: AuthenticationError)
    case sessionExpired
}

// MARK: - Authentication Error (Deprecated)
public enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case biometricNotAvailable
    case biometricAuthenticationFailed
    case keychainError(String)
    case networkError(String)
    case sessionExpired
    case unknown(String)
    
    public var errorDescription: String? {
        return "Authentication is not required"
    }
}

// MARK: - Authenticated User (Deprecated)
public struct AuthenticatedUser {
    public let id: String = "default-user"
    public let apiKey: String = "" // No API key needed
    public let baseURL: String = "http://localhost:8000"
    public let authenticatedAt: Date = Date()
    public let biometricEnabled: Bool = false
    
    public init(id: String, apiKey: String, baseURL: String, authenticatedAt: Date, biometricEnabled: Bool) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.authenticatedAt = authenticatedAt
        self.biometricEnabled = biometricEnabled
    }
}

// MARK: - Authentication Manager
@MainActor
public class AuthenticationManager: ObservableObject {
    // MARK: - Properties
    @Published public var state: AuthenticationState = .unauthenticated
    @Published public var isBiometricAvailable: Bool = false
    @Published public var biometricType: LABiometryType = .none
    
    private let keychain: KeychainService
    private let laContext = LAContext()
    private var sessionTimer: Timer?
    private let sessionTimeout: TimeInterval = 3600 // 1 hour
    
    // Keychain keys
    private let apiKeyKey = "claude_code_api_key"
    private let baseURLKey = "claude_code_base_url"
    private let userIDKey = "claude_code_user_id"
    private let biometricEnabledKey = "claude_code_biometric_enabled"
    
    // MARK: - Singleton
    public static let shared = AuthenticationManager()
    
    // MARK: - Initialization
    private init() {
        self.keychain = KeychainService(
            service: "com.yourorg.claudecodeabs",
            account: "claudecode"
        )
        
        checkBiometricAvailability()
        restoreSessionIfValid()
    }
    
    // MARK: - Public Methods
    
    /// Authenticate with API key and base URL
    public func authenticate(apiKey: String, baseURL: String) async throws {
        state = .authenticating
        
        do {
            // Validate credentials with backend
            let isValid = try await validateCredentials(apiKey: apiKey, baseURL: baseURL)
            
            guard isValid else {
                state = .failed(error: .invalidCredentials)
                throw AuthenticationError.invalidCredentials
            }
            
            // Store in keychain
            let apiKeyService = KeychainService(service: "com.yourorg.claudecodeabs", account: apiKeyKey)
            try apiKeyService.set(apiKey)
            let baseURLService = KeychainService(service: "com.yourorg.claudecodeabs", account: baseURLKey)
            try baseURLService.set(baseURL)
            
            // Generate user ID (could be from API response)
            let userID = UUID().uuidString
            let userIDService = KeychainService(service: "com.yourorg.claudecodeabs", account: userIDKey)
            try userIDService.set(userID)
            
            // Create authenticated user
            let user = AuthenticatedUser(
                id: userID,
                apiKey: apiKey,
                baseURL: baseURL,
                authenticatedAt: Date(),
                biometricEnabled: false
            )
            
            state = .authenticated(user: user)
            startSessionTimer()
            
        } catch {
            let authError = error as? AuthenticationError ?? .unknown(error.localizedDescription)
            state = .failed(error: authError)
            throw authError
        }
    }
    
    /// Authenticate with biometrics
    func authenticateWithBiometrics() async throws {
        guard isBiometricAvailable else {
            throw AuthenticationError.biometricNotAvailable
        }
        
        state = .authenticating
        
        do {
            // Perform biometric authentication
            let reason = "Authenticate to access Claude Code"
            let success = try await performBiometricAuthentication(reason: reason)
            
            guard success else {
                state = .failed(error: .biometricAuthenticationFailed)
                throw AuthenticationError.biometricAuthenticationFailed
            }
            
            // Retrieve stored credentials
            let apiKeyService = KeychainService(service: "com.yourorg.claudecodeabs", account: apiKeyKey)
            let baseURLService = KeychainService(service: "com.yourorg.claudecodeabs", account: baseURLKey)
            let userIDService = KeychainService(service: "com.yourorg.claudecodeabs", account: userIDKey)
            guard let apiKey = try apiKeyService.get(),
                  let baseURL = try baseURLService.get(),
                  let userID = try userIDService.get() else {
                state = .failed(error: .keychainError("Unable to retrieve stored credentials"))
                throw AuthenticationError.keychainError("Unable to retrieve stored credentials")
            }
            
            // Create authenticated user
            let user = AuthenticatedUser(
                id: userID,
                apiKey: apiKey,
                baseURL: baseURL,
                authenticatedAt: Date(),
                biometricEnabled: true
            )
            
            state = .authenticated(user: user)
            startSessionTimer()
            
        } catch {
            let authError = error as? AuthenticationError ?? .biometricAuthenticationFailed
            state = .failed(error: authError)
            throw authError
        }
    }
    
    /// Enable biometric authentication for future sessions
    func enableBiometricAuthentication() async throws {
        guard case .authenticated(let user) = state else {
            throw AuthenticationError.unknown("Must be authenticated to enable biometrics")
        }
        
        guard isBiometricAvailable else {
            throw AuthenticationError.biometricNotAvailable
        }
        
        // Verify with biometrics first
        let reason = "Enable biometric authentication for Claude Code"
        let success = try await performBiometricAuthentication(reason: reason)
        
        guard success else {
            throw AuthenticationError.biometricAuthenticationFailed
        }
        
        // Store preference
        let biometricService = KeychainService(service: "com.yourorg.claudecodeabs", account: biometricEnabledKey)
        try biometricService.set("true")
        
        // Update user state
        let updatedUser = AuthenticatedUser(
            id: user.id,
            apiKey: user.apiKey,
            baseURL: user.baseURL,
            authenticatedAt: user.authenticatedAt,
            biometricEnabled: true
        )
        
        state = .authenticated(user: updatedUser)
    }
    
    /// Sign out and clear credentials
    public func signOut() {
        // Clear keychain
        try? KeychainService(service: "com.yourorg.claudecodeabs", account: apiKeyKey).remove()
        try? KeychainService(service: "com.yourorg.claudecodeabs", account: baseURLKey).remove()
        try? KeychainService(service: "com.yourorg.claudecodeabs", account: userIDKey).remove()
        try? KeychainService(service: "com.yourorg.claudecodeabs", account: biometricEnabledKey).remove()
        
        // Reset state
        state = .unauthenticated
        
        // Cancel session timer
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    /// Refresh session to extend timeout
    func refreshSession() {
        guard case .authenticated = state else { return }
        startSessionTimer()
    }
    
    // MARK: - Private Methods
    
    private func checkBiometricAvailability() {
        var error: NSError?
        isBiometricAvailable = laContext.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        biometricType = laContext.biometryType
    }
    
    private func performBiometricAuthentication(reason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            laContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func validateCredentials(apiKey: String, baseURL: String) async throws -> Bool {
        // Create API client with provided credentials
        guard let healthURL = URL(string: "\(baseURL)/health") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: healthURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            throw AuthenticationError.networkError(error.localizedDescription)
        }
    }
    
    private func restoreSessionIfValid() {
        // Check if biometric is enabled and credentials exist
        let biometricService = KeychainService(service: "com.yourorg.claudecodeabs", account: biometricEnabledKey)
        let apiKeyService = KeychainService(service: "com.yourorg.claudecodeabs", account: apiKeyKey)
        let baseURLService = KeychainService(service: "com.yourorg.claudecodeabs", account: baseURLKey)
        guard let biometricEnabled = try? biometricService.get(),
              biometricEnabled == "true",
              let _ = try? apiKeyService.get(),
              let _ = try? baseURLService.get() else {
            return
        }
        
        // Session requires biometric authentication on app launch
        Task {
            try? await authenticateWithBiometrics()
        }
    }
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { _ in
            Task { @MainActor in
                self.handleSessionTimeout()
            }
        }
    }
    
    private func handleSessionTimeout() {
        state = .sessionExpired
        
        // If biometric is enabled, prompt for re-authentication
        let biometricService = KeychainService(service: "com.yourorg.claudecodeabs", account: biometricEnabledKey)
        if let biometricEnabled = try? biometricService.get(),
           biometricEnabled == "true" {
            Task {
                try? await authenticateWithBiometrics()
            }
        }
    }
}

// MARK: - Biometry Type Extension
extension LABiometryType {
    var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Not Available"
        @unknown default:
            return "Unknown"
        }
    }
}