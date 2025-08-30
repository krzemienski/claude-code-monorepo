# Claude Code Backend API Documentation

## Overview

This is a fully public, OpenAI-compatible API with no authentication required. All endpoints are accessible without API keys or authentication tokens.

## Base URL

```
http://localhost:8000
```

## Quick Start

1. **Start the server:**
   ```bash
   cd services/backend
   ./start_backend.sh
   ```

2. **Test the API:**
   ```bash
   python test_public_api.py
   ```

3. **View interactive docs:**
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

## Endpoints

### Health & Status

#### GET /health
Health check endpoint
```bash
curl http://localhost:8000/health
```

#### GET /
API information and available endpoints
```bash
curl http://localhost:8000/
```

### Environment Information 🆕

#### GET /v1/environment
Get comprehensive host environment information including:
- System information (OS, platform, architecture)
- Memory and CPU usage
- Disk usage
- Python environment and packages
- Environment variables (filtered for security)

```bash
curl http://localhost:8000/v1/environment
```

Response includes:
- `system`: Platform details, Python version, hostname
- `memory`: Total, available, used memory
- `disk`: Disk usage statistics
- `process`: Current process information
- `cpu_count`: Number of CPU cores
- `cpu_percent`: Current CPU usage
- `python_packages`: Installed Python packages
- `working_directory`: Current working directory

#### GET /v1/environment/summary
Get a simplified environment summary
```bash
curl http://localhost:8000/v1/environment/summary
```

### Chat Completions (OpenAI-Compatible)

#### POST /v1/chat/completions
Create a chat completion (requires ANTHROPIC_API_KEY in environment)

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 100
  }'
```

Supports streaming:
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### Models

#### GET /v1/models
List available Claude models
```bash
curl http://localhost:8000/v1/models
```

#### GET /v1/models/{model_id}
Get specific model information
```bash
curl http://localhost:8000/v1/models/claude-3-opus-20240229
```

### Projects

#### POST /v1/projects
Create a new project
```bash
curl -X POST http://localhost:8000/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Project",
    "description": "Project description",
    "path": "/path/to/project"
  }'
```

#### GET /v1/projects
List all projects
```bash
curl http://localhost:8000/v1/projects
```

#### GET /v1/projects/{project_id}
Get specific project
```bash
curl http://localhost:8000/v1/projects/{project_id}
```

#### PATCH /v1/projects/{project_id}
Update project
```bash
curl -X PATCH http://localhost:8000/v1/projects/{project_id} \
  -H "Content-Type: application/json" \
  -d '{"description": "Updated description"}'
```

#### DELETE /v1/projects/{project_id}
Delete project
```bash
curl -X DELETE http://localhost:8000/v1/projects/{project_id}
```

### Sessions

#### POST /v1/sessions
Create a chat session
```bash
curl -X POST http://localhost:8000/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "name": "New Session",
    "model": "claude-3-opus-20240229"
  }'
```

#### GET /v1/sessions
List sessions
```bash
curl http://localhost:8000/v1/sessions
```

#### GET /v1/sessions/{session_id}
Get session details
```bash
curl http://localhost:8000/v1/sessions/{session_id}
```

#### GET /v1/sessions/{session_id}/stats
Get session statistics
```bash
curl http://localhost:8000/v1/sessions/{session_id}/stats
```

#### POST /v1/sessions/{session_id}/stop
Stop active streaming
```bash
curl -X POST http://localhost:8000/v1/sessions/{session_id}/stop
```

#### POST /v1/sessions/{session_id}/clear
Clear session history
```bash
curl -X POST http://localhost:8000/v1/sessions/{session_id}/clear
```

#### POST /v1/sessions/{session_id}/archive
Archive session
```bash
curl -X POST http://localhost:8000/v1/sessions/{session_id}/archive
```

#### DELETE /v1/sessions/{session_id}
Delete session
```bash
curl -X DELETE http://localhost:8000/v1/sessions/{session_id}
```

### MCP (Model Context Protocol)

#### GET /v1/mcp/servers
List MCP servers and their status
```bash
curl http://localhost:8000/v1/mcp/servers
```

#### POST /v1/mcp/servers/{server_name}/start
Start MCP server
```bash
curl -X POST http://localhost:8000/v1/mcp/servers/filesystem/start
```

#### POST /v1/mcp/servers/{server_name}/stop
Stop MCP server
```bash
curl -X POST http://localhost:8000/v1/mcp/servers/filesystem/stop
```

#### GET /v1/mcp/tools
List available MCP tools
```bash
curl http://localhost:8000/v1/mcp/tools
```

#### POST /v1/mcp/tools/call
Call an MCP tool
```bash
curl -X POST http://localhost:8000/v1/mcp/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "server": "filesystem",
    "tool": "read_file",
    "arguments": {"path": "/example.txt"}
  }'
```

#### GET /v1/mcp/config
Get MCP configuration
```bash
curl http://localhost:8000/v1/mcp/config
```

### File Management

#### GET /v1/files/list
List files in directory
```bash
curl "http://localhost:8000/v1/files/list?path=/"
```

#### GET /v1/files/read
Read file contents
```bash
curl "http://localhost:8000/v1/files/read?path=example.txt"
```

#### POST /v1/files/write
Write file contents
```bash
curl -X POST "http://localhost:8000/v1/files/write" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "test.txt",
    "content": "Hello, World!",
    "encoding": "utf-8"
  }'
```

#### POST /v1/files/upload
Upload a file
```bash
curl -X POST "http://localhost:8000/v1/files/upload?path=/" \
  -F "file=@local_file.txt"
```

#### GET /v1/files/download
Download a file
```bash
curl "http://localhost:8000/v1/files/download?path=example.txt" -o downloaded.txt
```

#### DELETE /v1/files/delete
Delete file or directory
```bash
curl -X DELETE "http://localhost:8000/v1/files/delete?path=test.txt"
```

#### POST /v1/files/mkdir
Create directory
```bash
curl -X POST "http://localhost:8000/v1/files/mkdir" \
  -H "Content-Type: application/json" \
  -d '{"path": "new_directory"}'
```

#### POST /v1/files/move
Move or rename file/directory
```bash
curl -X POST "http://localhost:8000/v1/files/move" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "old_name.txt",
    "destination": "new_name.txt"
  }'
```

### Analytics

Analytics endpoints are available at `/v1/analytics/*` (implementation depends on analytics.py)

### Debug

Debug endpoints are available at `/v1/debug/*` (implementation depends on debug.py)

## Authentication

**NO AUTHENTICATION REQUIRED!** 

All endpoints are publicly accessible. The API uses a mock authentication system that always returns a default user with full permissions.

## Environment Variables

Optional configuration via environment variables:

- `ANTHROPIC_API_KEY`: Required for chat completions
- `PORT`: Server port (default: 8000)
- `DATABASE_URL`: Database connection string
- `WORKSPACE_DIR`: File management workspace directory
- `DEBUG`: Enable debug mode (default: false)

## Error Responses

All errors follow OpenAI's error format:

```json
{
  "error": {
    "message": "Error description",
    "type": "error_type",
    "code": 500
  }
}
```

## Rate Limiting

Rate limiting is configurable but not enforced by default in public mode.

## Testing

Run the comprehensive test suite:

```bash
python test_public_api.py
```

This will test all endpoints and verify they work without authentication.

## Security Notice

⚠️ **WARNING**: This API has no authentication and should only be used in development or trusted environments. All endpoints are publicly accessible.

## OpenAI Compatibility

This API is designed to be compatible with OpenAI's API format, allowing it to be used as a drop-in replacement for OpenAI API clients. Simply point your OpenAI client to `http://localhost:8000/v1` and it should work (note: uses Claude models instead of GPT models).