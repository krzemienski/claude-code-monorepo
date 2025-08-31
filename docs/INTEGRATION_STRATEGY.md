# iOS-Backend Integration Strategy

## Executive Summary

This document outlines the comprehensive strategy for integrating the iOS application with the FastAPI backend, addressing authentication, real-time communication, data synchronization, and testing approaches.

## Integration Architecture

### Communication Layers

```
┌─────────────────────────────────────┐
│         iOS Application             │
├─────────────────────────────────────┤
│     Network Abstraction Layer       │
├──────────────┬──────────────────────┤
│   REST API   │   WebSocket          │
├──────────────┼──────────────────────┤
│   URLSession │  URLSessionWebSocket │
└──────────────┴──────────────────────┘
              ↓↓↓
         [Internet/Network]
              ↓↓↓
┌─────────────────────────────────────┐
│       FastAPI Backend               │
├──────────────┬──────────────────────┤
│   REST       │   WebSocket          │
├──────────────┼──────────────────────┤
│  Endpoints   │   Real-time          │
└──────────────┴──────────────────────┘
```

## Authentication Integration

### JWT RS256 Implementation

**Current State:**
- Backend implements JWT RS256 with RBAC
- Documentation incorrectly states "NO AUTH"
- iOS has AuthenticationManager ready for JWT

**Integration Steps:**

1. **Token Management**
```swift
// iOS Implementation Required
class JWTTokenManager {
    func storeToken(_ token: String) -> KeychainResult
    func retrieveToken() -> String?
    func refreshToken() async throws -> Token
    func validateToken(_ token: String) -> Bool
}
```

2. **Authentication Flow**
```
1. User Login → POST /auth/login
2. Receive JWT Token + Refresh Token
3. Store in iOS Keychain
4. Add to Authorization header for all requests
5. Handle 401 responses with token refresh
6. Logout clears tokens
```

3. **Security Requirements**
- Store tokens in iOS Keychain (not UserDefaults)
- Implement biometric authentication for sensitive operations
- Certificate pinning for production
- Token expiry handling with automatic refresh

## API Integration Points

### 1. Session Management

**Endpoints:**
- `GET /api/sessions` - List all sessions
- `POST /api/sessions` - Create new session
- `GET /api/sessions/{id}` - Get session details
- `PUT /api/sessions/{id}` - Update session
- `DELETE /api/sessions/{id}` - Delete session
- `POST /api/sessions/{id}/messages` - Add message
- `GET /api/sessions/{id}/messages` - Get messages
- `WebSocket /ws/sessions/{id}` - Real-time updates

**iOS Implementation:**
```swift
protocol SessionServiceProtocol {
    func fetchSessions() async throws -> [Session]
    func createSession(_ session: Session) async throws -> Session
    func updateSession(_ session: Session) async throws -> Session
    func deleteSession(id: String) async throws
    func connectWebSocket(sessionId: String) async throws
}
```

### 2. MCP Server Communication

**Endpoints:**
- `GET /api/mcp-servers` - List servers
- `POST /api/mcp-servers` - Register server
- `GET /api/mcp-servers/{id}` - Server details
- `PUT /api/mcp-servers/{id}` - Update server
- `DELETE /api/mcp-servers/{id}` - Remove server
- `POST /api/mcp-servers/{id}/execute` - Execute command
- `GET /api/mcp-servers/{id}/status` - Server status
- `WebSocket /ws/mcp/{id}` - Real-time server communication

**iOS Models Required:**
```swift
struct MCPServer: Codable {
    let id: String
    let name: String
    let url: String
    let status: ServerStatus
    let capabilities: [String]
}

struct MCPCommand: Codable {
    let serverId: String
    let command: String
    let parameters: [String: Any]
}
```

### 3. Tool Operations

**Endpoints:**
- `GET /api/tools` - List available tools
- `POST /api/tools/execute` - Execute tool
- `GET /api/tools/{id}/status` - Execution status
- `POST /api/tools/batch` - Batch execution
- `WebSocket /ws/tools/stream` - Streaming results

**Implementation Priority:**
1. Basic tool listing and selection
2. Single tool execution with progress
3. Batch operations
4. Real-time streaming results

### 4. Command Processing

**Endpoints:**
- `POST /api/commands/execute` - Execute command
- `GET /api/commands/history` - Command history
- `GET /api/commands/{id}/result` - Get results
- `POST /api/commands/validate` - Validate command
- `WebSocket /ws/commands/stream` - Stream execution

## WebSocket Integration

### Connection Management

```swift
class WebSocketManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession.shared
    
    func connect(to url: URL, token: String) async throws {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        await startReceiving()
    }
    
    private func startReceiving() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            handleMessage(message)
            await startReceiving() // Continue receiving
        } catch {
            handleDisconnection(error)
        }
    }
}
```

### Message Protocol

```json
{
  "type": "session.update" | "mcp.response" | "tool.output" | "command.result",
  "id": "unique-message-id",
  "timestamp": "2025-01-15T10:00:00Z",
  "data": {
    // Type-specific payload
  }
}
```

## Data Synchronization Strategy

### Offline-First Architecture

1. **Local Storage**
   - Core Data for persistent storage
   - In-memory cache for active sessions
   - Queue for pending operations

2. **Sync Protocol**
   ```
   1. Check network availability
   2. Process local queue
   3. Fetch remote changes
   4. Resolve conflicts (last-write-wins)
   5. Update local state
   6. Notify UI of changes
   ```

3. **Conflict Resolution**
   - Timestamp-based resolution
   - User preference for conflicts
   - Automatic retry with exponential backoff

### State Management

```swift
@MainActor
class SyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var pendingOperations: [Operation] = []
    
    func sync() async {
        syncStatus = .syncing
        
        // Process queue
        for operation in pendingOperations {
            await processOperation(operation)
        }
        
        // Fetch updates
        await fetchRemoteChanges()
        
        syncStatus = .completed
    }
}
```

## Error Handling Strategy

### Network Errors

```swift
enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(Int, String)
    case authenticationRequired
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noConnection: return "No network connection"
        case .timeout: return "Request timed out"
        case .serverError(let code, let message): 
            return "Server error \(code): \(message)"
        case .authenticationRequired: return "Authentication required"
        case .invalidResponse: return "Invalid server response"
        }
    }
}
```

### Retry Logic

```swift
class RetryManager {
    func execute<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.timeout
    }
}
```

## Testing Strategy

### 1. Unit Tests

**Backend Mocking:**
```swift
class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let response = mockResponses[endpoint.path] as? T else {
            throw NetworkError.invalidResponse
        }
        return response
    }
}
```

**Test Coverage Targets:**
- Network layer: 90%
- Data models: 95%
- Business logic: 85%
- UI ViewModels: 80%

### 2. Integration Tests

**Test Scenarios:**
1. Authentication flow (login → token → refresh → logout)
2. Session CRUD operations
3. WebSocket connection and messaging
4. MCP server communication
5. Tool execution pipeline
6. Command processing
7. Error recovery scenarios
8. Offline/online transitions

**Test Implementation:**
```swift
class IntegrationTests: XCTestCase {
    var apiClient: APIClient!
    var testServer: TestServer!
    
    override func setUp() async throws {
        testServer = try await TestServer.start()
        apiClient = APIClient(baseURL: testServer.url)
    }
    
    func testFullAuthenticationFlow() async throws {
        // 1. Login
        let credentials = LoginCredentials(email: "test@example.com", password: "test123")
        let token = try await apiClient.login(credentials)
        XCTAssertNotNil(token)
        
        // 2. Use token for API call
        let sessions = try await apiClient.fetchSessions(token: token)
        XCTAssertNotNil(sessions)
        
        // 3. Refresh token
        let newToken = try await apiClient.refreshToken(token)
        XCTAssertNotEqual(token, newToken)
        
        // 4. Logout
        try await apiClient.logout(token: newToken)
    }
}
```

### 3. Contract Tests

**Shared Contract Definition:**
```yaml
# contracts/session-api.yaml
endpoints:
  - path: /api/sessions
    method: GET
    response:
      status: 200
      schema:
        type: array
        items:
          $ref: '#/components/schemas/Session'
```

**iOS Contract Test:**
```swift
class ContractTests: XCTestCase {
    func testSessionContract() async throws {
        let contract = try Contract.load("session-api.yaml")
        let response = try await apiClient.get("/api/sessions")
        
        XCTAssertTrue(contract.validate(response))
    }
}
```

### 4. End-to-End Tests

**UI Test Flow:**
```swift
class E2ETests: XCUITestCase {
    func testCompleteUserJourney() {
        let app = XCUIApplication()
        app.launch()
        
        // Login
        app.textFields["email"].tap()
        app.textFields["email"].typeText("user@example.com")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("password123")
        app.buttons["Login"].tap()
        
        // Create session
        app.buttons["New Session"].tap()
        app.textFields["session-name"].typeText("Test Session")
        app.buttons["Create"].tap()
        
        // Send message
        app.textFields["message-input"].tap()
        app.textFields["message-input"].typeText("Test message")
        app.buttons["Send"].tap()
        
        // Verify message appears
        XCTAssertTrue(app.staticTexts["Test message"].exists)
    }
}
```

## Performance Monitoring

### Metrics to Track

1. **API Response Times**
   - Target: < 200ms for REST endpoints
   - Target: < 50ms for WebSocket messages

2. **App Performance**
   - Launch time: < 2 seconds
   - Screen transitions: < 300ms
   - Memory usage: < 150MB baseline

3. **Network Usage**
   - Minimize redundant requests
   - Implement response caching
   - Use compression for large payloads

### Implementation:
```swift
class PerformanceMonitor {
    static func track(operation: String, block: () async throws -> Void) async throws {
        let start = CFAbsoluteTimeGetCurrent()
        
        try await block()
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        Analytics.log(event: "performance", parameters: [
            "operation": operation,
            "duration": duration,
            "timestamp": Date()
        ])
        
        if duration > 1.0 {
            Logger.warning("Slow operation: \(operation) took \(duration)s")
        }
    }
}
```

## Security Considerations

### 1. Data Protection
- Encrypt sensitive data at rest
- Use SSL/TLS for all network communication
- Implement certificate pinning
- Sanitize user inputs

### 2. Authentication Security
- Biometric authentication for app access
- Secure token storage in Keychain
- Token rotation strategy
- Session timeout handling

### 3. API Security
- Rate limiting implementation
- Request signing for critical operations
- Input validation on both client and server
- SQL injection prevention

## Migration Plan

### Phase 1: Foundation (Week 3)
1. Implement JWT authentication
2. Create network abstraction layer
3. Set up basic REST communication
4. Establish error handling

### Phase 2: Core Features (Week 4)
1. Session management integration
2. WebSocket connection setup
3. Basic MCP server communication
4. Tool execution framework

### Phase 3: Advanced Features (Week 5)
1. Offline synchronization
2. Real-time updates
3. Batch operations
4. Performance optimization

### Phase 4: Testing & Validation (Week 6)
1. Complete integration test suite
2. End-to-end testing
3. Performance testing
4. Security audit

## Success Metrics

### Technical Metrics
- ✅ 100% API endpoint coverage
- ✅ < 200ms average response time
- ✅ 99.9% uptime for WebSocket connections
- ✅ 80% test coverage minimum
- ✅ Zero critical security vulnerabilities

### User Experience Metrics
- ✅ < 2 second app launch time
- ✅ Smooth 60 FPS UI performance
- ✅ Offline capability for core features
- ✅ Real-time synchronization < 100ms

## Risk Mitigation

### Technical Risks
1. **WebSocket Instability**
   - Mitigation: Implement reconnection logic with exponential backoff
   
2. **Token Expiry During Operation**
   - Mitigation: Preemptive token refresh before critical operations

3. **Large Data Synchronization**
   - Mitigation: Implement pagination and incremental sync

4. **Network Latency**
   - Mitigation: Local caching and optimistic UI updates

### Process Risks
1. **Integration Complexity**
   - Mitigation: Incremental integration with feature flags

2. **Testing Coverage**
   - Mitigation: Automated testing pipeline from day one

3. **Performance Degradation**
   - Mitigation: Continuous performance monitoring

## Conclusion

This integration strategy provides a comprehensive roadmap for connecting the iOS application with the FastAPI backend. By following this phased approach with emphasis on testing, security, and performance, we can ensure a robust and scalable integration that delivers excellent user experience while maintaining system reliability.