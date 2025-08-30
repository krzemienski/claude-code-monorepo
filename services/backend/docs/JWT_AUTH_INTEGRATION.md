# JWT Authentication Integration Guide

## Overview

The Claude Code Backend API now implements a comprehensive JWT-based authentication system using RS256 algorithm for enhanced security. This guide provides complete integration instructions for iOS and other clients.

## Authentication Flow

### 1. User Registration

**Endpoint:** `POST /v1/auth/register`

```json
{
  "email": "user@example.com",
  "password": "SecureP@ssw0rd123",
  "username": "johndoe"  // optional
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "johndoe",
    "roles": ["user"],
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z",
    "api_key": "ck_xxxxx"  // Only returned on registration
  }
}
```

### 2. User Login

**Endpoint:** `POST /v1/auth/login`

OAuth2 compatible endpoint using form data:

```swift
// iOS Swift Example
let parameters = [
    "username": "user@example.com",  // or username
    "password": "SecureP@ssw0rd123"
]

AF.request(
    "\(baseURL)/v1/auth/login",
    method: .post,
    parameters: parameters,
    encoder: URLEncodedFormParameterEncoder.default
)
```

### 3. Token Refresh

**Endpoint:** `POST /v1/auth/refresh`

```json
{
  "refresh_token": "eyJhbGciOiJSUzI1NiIs..."
}
```

### 4. Using Authenticated Endpoints

Include the access token in the Authorization header:

```
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

## iOS Integration

### Swift Implementation

```swift
// AuthenticationManager.swift
import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private var accessToken: String?
    private var refreshToken: String?
    private let baseURL = "https://api.claudecode.com"
    
    // MARK: - Registration
    func register(email: String, password: String, username: String?) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/v1/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "password": password,
            "username": username
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw AuthError.registrationFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // Store tokens securely
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        saveTokensToKeychain()
        
        self.isAuthenticated = true
        self.currentUser = authResponse.user
        
        return authResponse
    }
    
    // MARK: - Login
    func login(username: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = "username=\(username)&password=\(password)"
        request.httpBody = parameters.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidCredentials
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // Store tokens
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        saveTokensToKeychain()
        
        self.isAuthenticated = true
        self.currentUser = authResponse.user
        
        // Schedule token refresh
        scheduleTokenRefresh()
        
        return authResponse
    }
    
    // MARK: - Token Refresh
    func refreshAccessToken() async throws {
        guard let refreshToken = self.refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        let url = URL(string: "\(baseURL)/v1/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh failed, logout user
            self.logout()
            throw AuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        saveTokensToKeychain()
        
        // Reschedule refresh
        scheduleTokenRefresh()
    }
    
    // MARK: - Authenticated Requests
    func authenticatedRequest(to url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Token Management
    private func scheduleTokenRefresh() {
        // Refresh token 1 minute before expiry (14 minutes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 840) { [weak self] in
            Task {
                try? await self?.refreshAccessToken()
            }
        }
    }
    
    private func saveTokensToKeychain() {
        // Use iOS Keychain to securely store tokens
        KeychainHelper.save(accessToken, forKey: "access_token")
        KeychainHelper.save(refreshToken, forKey: "refresh_token")
    }
    
    private func loadTokensFromKeychain() {
        self.accessToken = KeychainHelper.load(forKey: "access_token")
        self.refreshToken = KeychainHelper.load(forKey: "refresh_token")
    }
    
    func logout() {
        // Clear tokens
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
        self.currentUser = nil
        
        // Clear keychain
        KeychainHelper.delete(forKey: "access_token")
        KeychainHelper.delete(forKey: "refresh_token")
        
        // Call logout endpoint if needed
        Task {
            try? await callLogoutEndpoint()
        }
    }
}

// MARK: - Models
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct User: Codable {
    let id: String
    let email: String
    let username: String?
    let roles: [String]
    let isActive: Bool
    let createdAt: Date
    let apiKey: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, username, roles
        case isActive = "is_active"
        case createdAt = "created_at"
        case apiKey = "api_key"
    }
}

enum AuthError: Error {
    case invalidCredentials
    case registrationFailed
    case tokenRefreshFailed
    case noRefreshToken
}
```

## Security Features

### 1. Token Security
- **RS256 Algorithm**: Asymmetric encryption for enhanced security
- **15-minute Access Token**: Short-lived for security
- **7-day Refresh Token**: Longer validity with rotation
- **Token Rotation**: New refresh token on each refresh

### 2. Password Requirements
- Minimum 8 characters
- Maximum 72 characters (bcrypt limitation)
- Must contain uppercase, lowercase, number, and special character
- No common patterns (password, 123456, etc.)

### 3. Account Security
- **Account Lockout**: After 5 failed login attempts (30 minutes)
- **Password History**: Track last password change
- **Session Management**: Redis-based session tracking
- **Rate Limiting**: Per-user rate limits on sensitive endpoints

### 4. RBAC (Role-Based Access Control)
- Default roles: `user`, `admin`, `moderator`
- Custom permissions per endpoint
- JWT contains roles and permissions

## API Key Authentication

Alternative to JWT for server-to-server communication:

```swift
var request = URLRequest(url: url)
request.setValue("ck_xxxxx", forHTTPHeaderField: "X-API-Key")
```

## CORS Configuration

The backend is configured to accept requests from:
- `http://localhost:3000` - Web development
- `capacitor://localhost` - iOS Capacitor
- `ionic://localhost` - Ionic framework
- `app://localhost` - Desktop apps

In production, update the `CORS_ORIGINS` environment variable.

## Error Handling

### Authentication Errors

| Status Code | Error | Description |
|------------|-------|-------------|
| 401 | Unauthorized | Invalid or missing token |
| 403 | Forbidden | Insufficient permissions |
| 409 | Conflict | User already exists |
| 422 | Unprocessable Entity | Validation error (weak password, invalid email) |
| 423 | Locked | Account locked due to failed attempts |
| 429 | Too Many Requests | Rate limit exceeded |

### Error Response Format

```json
{
  "error": {
    "message": "Detailed error message",
    "type": "error_type",
    "code": 401
  }
}
```

## Best Practices

1. **Token Storage**: Use iOS Keychain for secure token storage
2. **Token Refresh**: Implement automatic refresh before expiry
3. **Error Recovery**: Handle token expiry gracefully
4. **Network Security**: Always use HTTPS in production
5. **Logout**: Clear tokens and call logout endpoint
6. **Rate Limiting**: Implement client-side rate limiting
7. **Session Management**: Track active sessions

## Environment Variables

```bash
# JWT Configuration
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
ALGORITHM=RS256

# Redis for Session Management
REDIS_URL=redis://localhost:6379

# CORS Origins
CORS_ORIGINS=capacitor://localhost,ionic://localhost
```

## Testing

Use the provided test suite:

```bash
pytest tests/test_auth.py -v
```

## Migration from No-Auth

For existing clients without authentication:

1. Implement registration/login flow
2. Store tokens securely
3. Add Authorization header to all requests
4. Handle 401 responses with token refresh
5. Implement logout functionality

## Support

For issues or questions about authentication integration:
- Check the API documentation at `/docs`
- Review test examples in `tests/test_auth.py`
- Contact the backend team for assistance