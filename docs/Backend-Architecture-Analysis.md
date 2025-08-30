# Backend Architecture Analysis - Claude Code iOS

## Executive Summary

The Claude Code iOS backend is built on a FastAPI-based architecture providing OpenAI-compatible APIs with SSE streaming support. The system is containerized using Docker and follows a microservices approach with clear separation between API endpoints, session management, and MCP tool orchestration.

## Architecture Overview

### Technology Stack
- **Framework**: FastAPI (Python 3.11)
- **Container**: Docker with multi-stage builds
- **API Protocol**: RESTful + Server-Sent Events (SSE)
- **External Dependencies**: 
  - Anthropic Claude API
  - Claude Code CLI (@anthropic-ai/claude-code)
  - MCP (Model Context Protocol) servers

### System Components

```
┌─────────────────────────────────────────────────────────┐
│                     iOS Client                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  APIClient.swift  │  SSEClient.swift  │ Keychain │   │
│  └──────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS/WSS
                         ▼
┌─────────────────────────────────────────────────────────┐
│                 Claude Code API Backend                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │          FastAPI Application (Port 8000)         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────┐ │   │
│  │  │ Chat Engine  │  │ Session Mgr  │  │ Models │ │   │
│  │  └──────────────┘  └──────────────┘  └────────┘ │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────┐ │   │
│  │  │   Projects   │  │  MCP Router  │  │ Health │ │   │
│  │  └──────────────┘  └──────────────┘  └────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              External Services                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Anthropic API│  │ MCP Servers  │  │  Workspace   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## API Specification

### 1. Core Endpoints

#### Chat Completions
- **Endpoint**: `POST /v1/chat/completions`
- **Protocol**: RESTful (non-streaming) or SSE (streaming)
- **Features**:
  - OpenAI-compatible request/response format
  - Real-time streaming with SSE
  - Session persistence
  - MCP tool integration
  - Usage tracking and cost calculation

#### Session Management
- **Create**: `POST /v1/sessions`
- **List**: `GET /v1/sessions`
- **Detail**: `GET /v1/sessions/{session_id}`
- **Delete**: `DELETE /v1/sessions/{session_id}`
- **Stats**: `GET /v1/sessions/stats`

#### Project Management
- **List**: `GET /v1/projects`
- **Create**: `POST /v1/projects`
- **Detail**: `GET /v1/projects/{project_id}`
- **Delete**: `DELETE /v1/projects/{project_id}`

#### Model Management
- **List**: `GET /v1/models`
- **Capabilities**: `GET /v1/models/capabilities`
- **Detail**: `GET /v1/models/{model_id}`

### 2. MCP Integration

#### Server Discovery
```http
GET /v1/mcp/servers?scope=user|project&project_id=...
```

#### Tool Listing
```http
GET /v1/mcp/servers/{server_id}/tools?project_id=...
```

#### Session Tool Configuration
```http
POST /v1/sessions/{session_id}/tools
{
  "enabled_servers": ["fs-local", "bash"],
  "enabled_tools": ["fs.read", "fs.write", "bash.run"],
  "priority": ["fs.read", "bash.run"],
  "audit_log": true
}
```

## Infrastructure Configuration

### Docker Setup

#### docker-compose.yml
```yaml
services:
  api:
    build:
      context: ../../
      dockerfile: deploy/docker/Dockerfile.api
      args:
        BACKEND_REF: main
    environment:
      ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}"
      PORT: "${PORT:-8000}"
    volumes:
      - ../../files/workspace:/workspace
    ports:
      - "${PORT:-8000}:8000"
    restart: unless-stopped
    init: true
    tty: true
```

#### Dockerfile (Multi-stage Build)
1. **Base Layer**: Python 3.11 slim with essential packages
2. **Dependencies**: Node.js 20.x for Claude Code CLI
3. **Application**: Clone and install claude-code-api from GitHub
4. **Security**: Non-root user (appuser), minimal attack surface
5. **Runtime**: uvicorn ASGI server

### Environment Variables
```env
# Required
ANTHROPIC_API_KEY=sk-your-anthropic-api-key

# Optional
PORT=8000
CLAUDE_CONFIG_DIR=/Users/you/.claude
```

## Integration Patterns

### 1. iOS to Backend Communication

#### Standard Request Flow
```swift
1. AppSettings → validate credentials
2. APIClient → create authenticated request
3. URLSession → execute HTTP call
4. JSONDecoder → parse response
5. SwiftUI → update UI
```

#### SSE Streaming Flow
```swift
1. SSEClient → establish connection
2. URLSessionDataDelegate → receive chunks
3. Event parsing → extract data frames
4. Progressive UI updates → real-time display
5. [DONE] signal → completion handling
```

### 2. Authentication & Security

#### Token Management
- **Storage**: iOS Keychain for secure credential storage
- **Transport**: Bearer token in Authorization header
- **Validation**: Backend validates with Anthropic API
- **Rotation**: Support for token refresh (future)

#### Security Best Practices
- HTTPS enforced for production
- API keys never logged or exposed
- Request/response sanitization
- Rate limiting per session
- CORS configuration for web clients

### 3. Session Lifecycle

#### Session Creation
```
1. Client: POST /v1/sessions with project_id, model
2. Backend: Generate session_id, initialize state
3. Backend: Configure MCP tools if specified
4. Client: Store session_id for subsequent requests
```

#### Chat Interaction
```
1. Client: POST /v1/chat/completions with messages
2. Backend: Validate session, check quotas
3. Backend: Forward to Anthropic API
4. Backend: Stream response via SSE
5. Backend: Execute MCP tools as needed
6. Backend: Track usage and costs
7. Client: Display responses and tool events
```

#### Session Termination
```
1. Client: DELETE /v1/sessions/{session_id}
2. Backend: Cancel active operations
3. Backend: Persist session metrics
4. Backend: Clean up resources
```

## Error Handling

### Error Response Format
```json
{
  "error": {
    "code": "error_code",
    "message": "Human-readable description",
    "status": 400
  }
}
```

### Error Categories
- **400**: Bad Request - Validation errors
- **401**: Unauthorized - Invalid or missing API key
- **403**: Forbidden - Insufficient permissions
- **404**: Not Found - Resource doesn't exist
- **409**: Conflict - Operation already in progress
- **429**: Rate Limited - Too many requests
- **500**: Internal Error - Server-side failure
- **503**: Service Unavailable - Dependency failure

## Performance Considerations

### Optimization Strategies
1. **Connection Pooling**: Reuse HTTP connections
2. **Response Caching**: Cache model capabilities, project lists
3. **Stream Buffering**: Optimize SSE chunk sizes
4. **Async Operations**: Non-blocking I/O throughout
5. **Resource Limits**: Memory and CPU constraints in Docker

### Scalability Patterns
1. **Horizontal Scaling**: Multiple API containers behind load balancer
2. **Session Affinity**: Sticky sessions for SSE connections
3. **Database Backend**: PostgreSQL for persistent state (future)
4. **Queue System**: Redis/RabbitMQ for async tasks (future)
5. **CDN Integration**: Static asset caching (future)

## Monitoring & Logging

### Health Monitoring
```http
GET /health
{
  "ok": true,
  "version": "1.2.3",
  "active_sessions": 2,
  "uptime_seconds": 86400
}
```

### Logging Strategy
- **Application Logs**: Structured JSON via Python logging
- **Access Logs**: Uvicorn access logs with timing
- **Error Tracking**: Exception details with stack traces
- **Audit Trail**: MCP tool invocations with parameters
- **Performance Metrics**: Request latency, token usage

## Deployment Strategy

### Local Development
```bash
# Start backend
make up

# View logs
make logs

# Stop backend
make down
```

### Staging Environment
1. Build Docker image with specific branch
2. Deploy to staging server
3. Run integration tests
4. Validate with iOS TestFlight build

### Production Deployment
1. Tag release version
2. Build optimized Docker image
3. Deploy with rolling updates
4. Monitor health endpoints
5. Rollback if issues detected

## CI/CD Pipeline

### Build Pipeline
```yaml
1. Lint Python code (black, flake8)
2. Run unit tests (pytest)
3. Build Docker image
4. Push to registry
5. Deploy to staging
```

### Testing Strategy
- **Unit Tests**: FastAPI endpoints with mock dependencies
- **Integration Tests**: Full stack with real Anthropic API
- **Load Tests**: Concurrent SSE connections
- **Security Scans**: Dependency vulnerabilities

## Future Enhancements

### Phase 1 (Q1 2025)
- PostgreSQL integration for persistent storage
- Redis caching layer
- WebSocket support alongside SSE
- Enhanced MCP tool discovery

### Phase 2 (Q2 2025)
- Multi-model support (OpenAI, Google)
- File upload/download capabilities
- Collaborative sessions
- Advanced analytics dashboard

### Phase 3 (Q3 2025)
- Plugin system for custom tools
- Workflow automation
- Template library
- Enterprise SSO integration

## Recommendations

### Immediate Actions
1. **Add Request ID Tracking**: Correlate logs across services
2. **Implement Circuit Breakers**: Handle Anthropic API failures
3. **Add Prometheus Metrics**: Detailed performance monitoring
4. **Create API Documentation**: OpenAPI/Swagger spec
5. **Setup Rate Limiting**: Prevent abuse and control costs

### Best Practices
1. **Version API Endpoints**: Support backward compatibility
2. **Use Database Transactions**: Ensure data consistency
3. **Implement Retry Logic**: Handle transient failures
4. **Add Request Validation**: Comprehensive input checking
5. **Enable CORS Properly**: Support web clients securely

## Conclusion

The Claude Code iOS backend provides a robust foundation for AI-assisted development with:
- Clean API design following OpenAI conventions
- Real-time streaming capabilities via SSE
- Flexible MCP tool integration
- Containerized deployment for consistency
- Clear separation of concerns

The architecture supports both immediate needs and future scaling requirements while maintaining security and performance standards.