# Backend Deployment Guide

## Overview
The Claude Code backend API provides OpenAI-compatible endpoints for the iOS app with SSE streaming support for chat completions, project management, session lifecycle, and MCP tool configuration.

## Current Status
✅ Backend server successfully deployed and running on http://localhost:8000
✅ All core endpoints verified and operational
✅ SSE streaming tested and working
✅ CORS configured for iOS Simulator access

## Deployment Requirements

### Prerequisites
- Docker and Docker Compose installed
- Anthropic API key (for production use)
- Port 8000 available (configurable)

### Environment Configuration
Create a `.env` file from `.env.example`:
```bash
cp .env.example .env
```

Configure the following variables:
- `ANTHROPIC_API_KEY`: Your Anthropic API key (required for Claude integration)
- `PORT`: API server port (default: 8000)
- `CLAUDE_CONFIG_DIR`: Optional persistent CLI config directory

### Quick Start
```bash
# Build and start the backend
make up

# Or using docker-compose directly
docker compose -f deploy/compose/docker-compose.yml up --build -d

# Check status
docker compose -f deploy/compose/docker-compose.yml ps

# View logs
docker compose -f deploy/compose/docker-compose.yml logs -f api

# Stop the backend
make down
```

## API Endpoints Verified

### Health & Models
- ✅ `GET /health` - Health check endpoint
- ✅ `GET /v1/models` - List available Claude models

### Chat Completions (SSE Streaming)
- ✅ `POST /v1/chat/completions` - Main chat endpoint with streaming support
  - Supports both streaming (`stream: true`) and non-streaming responses
  - Server-Sent Events (SSE) for real-time streaming
  - OpenAI-compatible request/response format

### Project Management
- ✅ `GET /v1/projects` - List all projects
- ✅ `POST /v1/projects` - Create new project
- ✅ `GET /v1/projects/{id}` - Get project details
- ✅ `DELETE /v1/projects/{id}` - Delete project

### Session Management
- ✅ `GET /v1/sessions` - List all sessions
- ✅ `POST /v1/sessions` - Create new session
- ✅ `GET /v1/sessions/{id}` - Get session details
- ✅ `POST /v1/sessions/{id}/messages` - Add message to session

### MCP (Model Context Protocol)
- ✅ `GET /v1/mcp/servers` - List available MCP servers
- ✅ `GET /v1/mcp/servers/{id}/tools` - Get tools for specific server
- ✅ `POST /v1/mcp/servers/{id}/enable` - Enable MCP server for session
- ✅ `POST /v1/mcp/tools/{id}/execute` - Execute MCP tool

## iOS Simulator Integration

### CORS Configuration
The backend is configured with permissive CORS headers for development:
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)
```

### iOS App Configuration
In the iOS app's Settings view:
- **Base URL**: `http://localhost:8000` (for simulator)
- **API Key**: Your Anthropic API key (stored securely in Keychain)

### Network Configuration
For iOS Simulator to access localhost:
- The simulator can access `localhost` or `127.0.0.1` directly
- For physical devices, use your machine's IP address
- ATS exception already configured in Info.plist for HTTP development

## Test Data
Sample test data has been seeded including:
- 3 sample projects (iOS App, Backend API, Test Suite)
- 2 active sessions linked to projects
- 2 MCP servers (Filesystem, Bash) with tools

## Docker Architecture

### Container Structure
- Base image: `python:3.11-slim`
- Working directory: `/workspace` (mounted from `./files/workspace`)
- Non-root user: `appuser`
- Entry point: Custom script with fallback test server

### Current Implementation
The backend currently runs a development test server that implements:
- Full OpenAI-compatible API structure
- SSE streaming for chat completions
- Project and session management
- MCP server configuration
- CORS support for cross-origin requests

### Production Considerations
For production deployment:
1. Replace test server with actual claude-code-api implementation
2. Configure proper authentication and authorization
3. Set up SSL/TLS termination (nginx/traefik)
4. Implement rate limiting and request validation
5. Configure production-grade logging and monitoring
6. Use environment-specific CORS origins
7. Set up database persistence (PostgreSQL/MongoDB)
8. Implement proper error handling and recovery

## Monitoring & Logging

### View Logs
```bash
# Real-time logs
docker compose -f deploy/compose/docker-compose.yml logs -f api

# Last 100 lines
docker compose -f deploy/compose/docker-compose.yml logs --tail 100 api
```

### Health Monitoring
```bash
# Check health endpoint
curl http://localhost:8000/health

# Full system check
curl http://localhost:8000/health | jq
```

## Troubleshooting

### Container won't start
1. Check if port 8000 is already in use: `lsof -i :8000`
2. Check Docker daemon is running: `docker ps`
3. Review logs: `docker compose logs api`

### API not responding
1. Verify container is running: `docker compose ps`
2. Check health endpoint: `curl http://localhost:8000/health`
3. Review container logs for errors

### iOS app can't connect
1. Verify backend URL in iOS Settings is correct
2. Check CORS headers are properly configured
3. Ensure ATS exception is in place for HTTP
4. Test with curl from terminal first

## Next Steps
- [ ] Implement actual claude-code-api package integration
- [ ] Set up production database (PostgreSQL)
- [ ] Configure Redis for session management
- [ ] Implement WebSocket support for real-time updates
- [ ] Add comprehensive API documentation (OpenAPI/Swagger)
- [ ] Set up CI/CD pipeline for automated deployment
- [ ] Implement comprehensive logging with ELK stack
- [ ] Add Prometheus metrics and Grafana dashboards