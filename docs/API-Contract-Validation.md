# API Contract Validation Guide - Claude Code iOS

## Overview

This document provides comprehensive validation criteria for the API contract between the iOS client and backend services. It ensures consistency, reliability, and proper error handling across all endpoints.

## API Contract Specifications

### 1. Chat Completions API

#### Non-Streaming Request Validation
```json
// Request Schema
{
  "model": "string (required, must be valid model ID)",
  "project_id": "string (required, UUID format)",
  "messages": [
    {
      "role": "string (required, enum: user|assistant|system)",
      "content": "string (required, non-empty)"
    }
  ],
  "stream": "boolean (default: false)",
  "system_prompt": "string (optional)",
  "mcp": {
    "enabled_servers": ["string array (optional)"],
    "enabled_tools": ["string array (optional)"],
    "priority": ["string array (optional)"],
    "audit_log": "boolean (optional)"
  }
}
```

#### Non-Streaming Response Validation
```json
// Response Schema (200 OK)
{
  "id": "string (required, completion ID)",
  "object": "chat.completion",
  "created": "integer (required, unix timestamp)",
  "model": "string (required, model ID)",
  "choices": [
    {
      "index": "integer (required)",
      "message": {
        "role": "assistant",
        "content": "string (required)"
      },
      "finish_reason": "string (enum: stop|length|tool_calls)"
    }
  ],
  "usage": {
    "input_tokens": "integer (required)",
    "output_tokens": "integer (required)",
    "total_tokens": "integer (required)",
    "total_cost": "number (required)"
  },
  "session_id": "string (required)",
  "project_id": "string (required)"
}
```

#### SSE Streaming Validation
```typescript
// Event Stream Format
interface SSEEvent {
  data: ChatCompletionChunk | "[DONE]"
}

interface ChatCompletionChunk {
  id?: string                     // Present in first chunk
  object: "chat.completion.chunk"
  created?: number                 // Present in first chunk
  model?: string                   // Present in first chunk
  choices: [{
    index: number
    delta: {
      role?: "assistant"          // Present in first chunk
      content?: string             // Incremental content
      tool_calls?: ToolCall[]      // Tool invocations
    }
    finish_reason?: "stop" | "length" | "tool_calls"
  }]
}
```

### 2. Session Management API

#### Create Session Validation
```json
// Request
POST /v1/sessions
{
  "project_id": "string (required, must exist)",
  "model": "string (required, valid model ID)",
  "title": "string (optional, max 255 chars)",
  "system_prompt": "string (optional, max 4000 chars)"
}

// Response (201 Created)
{
  "id": "string (session UUID)",
  "project_id": "string",
  "model": "string",
  "title": "string",
  "system_prompt": "string",
  "created_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp",
  "is_active": true,
  "total_tokens": 0,
  "total_cost": 0.0,
  "message_count": 0
}
```

#### Session Status Validation
```json
// Request
GET /v1/chat/completions/{session_id}/status

// Response (200 OK)
{
  "session_id": "string",
  "project_id": "string",
  "model": "string",
  "is_running": "boolean",
  "created_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "total_tokens": "integer",
  "total_cost": "number",
  "message_count": "integer"
}
```

### 3. Project Management API

#### Project Schema Validation
```json
{
  "id": "string (UUID)",
  "name": "string (required, 1-255 chars)",
  "description": "string (required, max 1000 chars)",
  "path": "string (optional, valid filesystem path)",
  "created_at": "ISO-8601",
  "updated_at": "ISO-8601"
}
```

### 4. Model Capabilities API

#### Capabilities Response Validation
```json
{
  "data": [
    {
      "id": "string (model ID)",
      "name": "string (display name)",
      "description": "string",
      "max_tokens": "integer (>0)",
      "supports_streaming": "boolean",
      "supports_tools": "boolean",
      "pricing": {
        "input": "number (per 1K tokens)",
        "output": "number (per 1K tokens)"
      }
    }
  ]
}
```

## Validation Rules

### Request Validation

#### Headers
```http
Content-Type: application/json (required for POST/PUT)
Authorization: Bearer <token> (required if auth enabled)
X-Request-ID: <uuid> (optional, for tracing)
```

#### Common Validations
1. **UUID Format**: All IDs must be valid UUID v4
2. **Timestamps**: ISO-8601 format in UTC
3. **String Length**: Enforce max lengths
4. **Enums**: Validate against allowed values
5. **Required Fields**: Check presence and non-null

### Response Validation

#### Success Responses
- **200 OK**: Standard success
- **201 Created**: Resource created
- **204 No Content**: Successful deletion

#### Error Response Format
```json
{
  "error": {
    "code": "string (error code)",
    "message": "string (human-readable)",
    "status": "integer (HTTP status)",
    "details": {
      "field": "string (optional, field name)",
      "reason": "string (optional, validation reason)"
    }
  }
}
```

## Error Handling Patterns

### Client-Side Error Handling

```swift
// iOS Error Handling Pattern
enum APIError: Error {
    case invalidRequest(field: String, reason: String)
    case unauthorized(message: String)
    case notFound(resource: String)
    case conflict(message: String)
    case rateLimited(retryAfter: Int)
    case serverError(message: String)
    case networkError(Error)
}

func handleAPIResponse(_ response: HTTPURLResponse, data: Data) throws {
    switch response.statusCode {
    case 200...299:
        return // Success
    case 400:
        throw parseValidationError(data)
    case 401:
        throw APIError.unauthorized(message: parseError(data))
    case 404:
        throw APIError.notFound(resource: parseResource(data))
    case 409:
        throw APIError.conflict(message: parseError(data))
    case 429:
        throw APIError.rateLimited(retryAfter: parseRetryAfter(response))
    case 500...599:
        throw APIError.serverError(message: parseError(data))
    default:
        throw APIError.networkError(URLError(.unknown))
    }
}
```

### Rate Limiting

#### Response Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1672531200
Retry-After: 60 (seconds)
```

#### Client Implementation
```swift
struct RateLimitInfo {
    let limit: Int
    let remaining: Int
    let resetTime: Date
    let retryAfter: TimeInterval?
    
    init(from response: HTTPURLResponse) {
        self.limit = Int(response.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "0") ?? 0
        self.remaining = Int(response.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "0") ?? 0
        let resetTimestamp = Int(response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "0") ?? 0
        self.resetTime = Date(timeIntervalSince1970: TimeInterval(resetTimestamp))
        self.retryAfter = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "0") ?? nil
    }
}
```

## SSE Stream Handling

### Connection Management
```swift
class SSEConnection {
    // Connection States
    enum State {
        case connecting
        case connected
        case disconnected(Error?)
    }
    
    // Retry Strategy
    struct RetryPolicy {
        let maxAttempts: Int = 3
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        
        func delay(for attempt: Int) -> TimeInterval {
            min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
        }
    }
    
    // Heartbeat Detection
    let heartbeatInterval: TimeInterval = 30.0
    var lastEventTime: Date = Date()
    
    func checkHeartbeat() {
        if Date().timeIntervalSince(lastEventTime) > heartbeatInterval * 2 {
            reconnect()
        }
    }
}
```

### Event Parsing
```swift
enum SSEParseError: Error {
    case invalidFormat
    case missingData
    case invalidJSON
}

func parseSSEEvent(_ line: String) throws -> SSEEvent {
    guard line.hasPrefix("data: ") else {
        throw SSEParseError.invalidFormat
    }
    
    let data = String(line.dropFirst(6))
    
    if data == "[DONE]" {
        return .done
    }
    
    guard let jsonData = data.data(using: .utf8) else {
        throw SSEParseError.missingData
    }
    
    do {
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData)
        return .chunk(chunk)
    } catch {
        throw SSEParseError.invalidJSON
    }
}
```

## MCP Tool Validation

### Tool Discovery Response
```json
{
  "server_id": "string",
  "tools": [
    {
      "name": "string (tool.name format)",
      "title": "string (display name)",
      "description": "string",
      "input_schema": {
        "type": "object",
        "properties": {},
        "required": []
      },
      "supports_stream": "boolean",
      "dangerous": "boolean"
    }
  ]
}
```

### Tool Invocation Event
```json
{
  "type": "tool_call",
  "id": "string (call ID)",
  "tool": {
    "server": "string",
    "name": "string",
    "arguments": {}
  },
  "timestamp": "ISO-8601",
  "duration_ms": "integer",
  "success": "boolean",
  "error": "string (optional)"
}
```

## Testing Strategies

### Contract Testing
```swift
// Contract Test Example
func testChatCompletionContract() async throws {
    // Arrange
    let request = ChatCompletionRequest(
        model: "claude-3-haiku",
        projectId: "test-project",
        messages: [Message(role: "user", content: "Hello")],
        stream: false
    )
    
    // Act
    let response = try await apiClient.createChatCompletion(request)
    
    // Assert - Contract Validation
    XCTAssertNotNil(response.id)
    XCTAssertEqual(response.object, "chat.completion")
    XCTAssertGreaterThan(response.created, 0)
    XCTAssertEqual(response.model, request.model)
    XCTAssertFalse(response.choices.isEmpty)
    XCTAssertNotNil(response.usage)
    XCTAssertGreaterThanOrEqual(response.usage.totalTokens, 0)
    XCTAssertGreaterThanOrEqual(response.usage.totalCost, 0)
}
```

### Mock Server Setup
```swift
class MockAPIServer {
    func setupChatCompletionEndpoint() {
        router.post("/v1/chat/completions") { request in
            // Validate request
            guard let body = try? request.content.decode(ChatCompletionRequest.self) else {
                return Response(status: .badRequest, body: errorResponse("invalid_request"))
            }
            
            // Validate required fields
            guard !body.model.isEmpty,
                  !body.projectId.isEmpty,
                  !body.messages.isEmpty else {
                return Response(status: .badRequest, body: errorResponse("missing_required_fields"))
            }
            
            // Return mock response
            if body.stream {
                return streamingResponse(for: body)
            } else {
                return nonStreamingResponse(for: body)
            }
        }
    }
}
```

## Monitoring & Validation Metrics

### Key Metrics to Track
1. **Request Success Rate**: Percentage of 2xx responses
2. **Average Response Time**: P50, P95, P99 latencies
3. **Error Rate by Type**: 4xx vs 5xx errors
4. **Token Usage**: Average tokens per request
5. **Stream Connection Duration**: Average SSE session length
6. **Tool Invocation Success**: MCP tool success rate

### Validation Dashboards
```yaml
# Prometheus Metrics
api_request_total{method="POST", endpoint="/v1/chat/completions", status="200"}
api_request_duration_seconds{method="POST", endpoint="/v1/chat/completions", quantile="0.95"}
api_validation_errors_total{field="model", reason="invalid"}
sse_connections_active
sse_events_sent_total{type="chunk"}
mcp_tool_invocations_total{server="fs-local", tool="fs.read", status="success"}
```

## Compliance Checklist

### API Compliance
- [ ] All endpoints return proper HTTP status codes
- [ ] Error responses follow standard format
- [ ] Required fields are validated
- [ ] String length limits enforced
- [ ] UUID format validation
- [ ] ISO-8601 timestamp format
- [ ] Enum value validation
- [ ] Rate limiting headers present
- [ ] CORS headers configured (if needed)

### SSE Compliance
- [ ] Proper Content-Type header (text/event-stream)
- [ ] Events prefixed with "data: "
- [ ] [DONE] signal sent on completion
- [ ] Heartbeat/keep-alive mechanism
- [ ] Graceful connection handling
- [ ] Retry mechanism on failure

### Security Compliance
- [ ] Authentication tokens validated
- [ ] Sensitive data not logged
- [ ] Input sanitization
- [ ] SQL injection prevention
- [ ] Rate limiting enforced
- [ ] HTTPS in production

## Conclusion

This validation guide ensures robust API contract enforcement between the iOS client and backend. Regular contract testing and monitoring help maintain reliability and catch breaking changes early in the development cycle.