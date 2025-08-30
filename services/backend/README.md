# Claude Code Backend - Public API

A fully public, OpenAI-compatible API backend with no authentication required. All endpoints are accessible without API keys or tokens.

## Features

- ✅ **No Authentication Required** - All endpoints are public
- ✅ **OpenAI-Compatible** - Drop-in replacement for OpenAI API
- ✅ **Environment Reporting** - Real-time host system information
- ✅ **Chat Completions** - Claude-powered chat API
- ✅ **Session Management** - Chat session lifecycle control
- ✅ **Project Management** - Organize work into projects
- ✅ **File Management** - Full file system operations
- ✅ **MCP Integration** - Model Context Protocol support
- ✅ **Streaming Support** - SSE streaming for chat responses

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Set Environment Variables (Optional)

```bash
export ANTHROPIC_API_KEY="your-api-key"  # Required for chat completions
export PORT=8000
export DATABASE_URL="sqlite+aiosqlite:///./claude_code.db"
```

### 3. Start the Server

```bash
./start_backend.sh
```

Or manually:

```bash
python -m app.main
```

### 4. Test the API

```bash
python test_public_api.py
```

### 5. View Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- API Docs: See [API_DOCUMENTATION.md](API_DOCUMENTATION.md)

## Key Endpoints

### Environment Information (NEW!)

Get real-time host environment data:

```bash
curl http://localhost:8000/v1/environment
```

Returns:
- System info (OS, platform, architecture)
- CPU and memory usage
- Python environment and packages
- Disk usage statistics
- Process information

### Chat Completions

OpenAI-compatible chat endpoint:

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Models

List available Claude models:

```bash
curl http://localhost:8000/v1/models
```

## Project Structure

```
services/backend/
├── app/
│   ├── api/
│   │   ├── deps.py          # Mock authentication (always succeeds)
│   │   └── v1/
│   │       └── endpoints/
│   │           ├── chat.py       # Chat completions
│   │           ├── environment.py # Host environment reporting
│   │           ├── models.py     # Model listing
│   │           ├── projects.py   # Project management
│   │           ├── sessions.py   # Session management
│   │           ├── mcp.py        # MCP integration
│   │           └── files.py      # File operations
│   ├── core/
│   │   └── config.py        # Configuration
│   ├── db/
│   │   └── session.py       # Database management
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   └── main.py             # FastAPI application
├── requirements.txt         # Python dependencies
├── test_public_api.py      # API test suite
├── start_backend.sh        # Startup script
└── API_DOCUMENTATION.md    # Detailed API docs
```

## Security Notice

⚠️ **WARNING**: This API has no authentication and all endpoints are publicly accessible. Only use in development or trusted environments.

## OpenAI Compatibility

This API follows OpenAI's API format, making it compatible with existing OpenAI client libraries. Simply change the base URL to `http://localhost:8000/v1`.

## Development

### Run Tests

```bash
python test_public_api.py
```

### Database Migrations

```bash
alembic upgrade head
```

### Code Formatting

```bash
black app/
isort app/
flake8 app/
```

## License

MIT