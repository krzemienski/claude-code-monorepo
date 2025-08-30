#!/bin/bash
set -e

echo "Starting Claude Code API Backend..."
echo "================================="
echo "Port: ${PORT:-8000}"
echo "Workspace: /workspace"
echo "================================="

# For now, go directly to the fallback test server
# TODO: Fix claude-code-api package installation
echo "Starting development test server..."
    cat > /tmp/test_server.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import json
import asyncio
from datetime import datetime

app = FastAPI(title="Claude Code API", version="0.1.0")

# Configure CORS for iOS Simulator access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# Health check
@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

# Models endpoint
@app.get("/v1/models")
async def get_models():
    return {
        "object": "list",
        "data": [
            {
                "id": "claude-3-5-sonnet-20241022",
                "object": "model",
                "created": 1729555200,
                "owned_by": "anthropic"
            },
            {
                "id": "claude-3-5-haiku-20241022",
                "object": "model",
                "created": 1729555200,
                "owned_by": "anthropic"
            }
        ]
    }

# Chat completions endpoint (with SSE streaming support)
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: Optional[bool] = False
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = 4096

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    if request.stream:
        async def generate():
            # Simulate streaming response
            chunks = [
                "Hello! ",
                "This is ",
                "a test ",
                "streaming ",
                "response ",
                "from the ",
                "backend API."
            ]
            
            for i, chunk in enumerate(chunks):
                data = {
                    "id": f"chatcmpl-test-{i}",
                    "object": "chat.completion.chunk",
                    "created": int(datetime.utcnow().timestamp()),
                    "model": request.model,
                    "choices": [{
                        "index": 0,
                        "delta": {"content": chunk},
                        "finish_reason": None
                    }]
                }
                yield f"data: {json.dumps(data)}\n\n"
                await asyncio.sleep(0.1)
            
            # Send final message
            final_data = {
                "id": f"chatcmpl-test-final",
                "object": "chat.completion.chunk",
                "created": int(datetime.utcnow().timestamp()),
                "model": request.model,
                "choices": [{
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop"
                }]
            }
            yield f"data: {json.dumps(final_data)}\n\n"
            yield "data: [DONE]\n\n"
        
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        # Non-streaming response
        return {
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "created": int(datetime.utcnow().timestamp()),
            "model": request.model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "This is a test response from the backend API."
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }

# Projects endpoints
@app.get("/v1/projects")
async def list_projects():
    return {
        "projects": [
            {
                "id": "proj_001",
                "name": "Sample Project",
                "path": "/workspace/sample-project",
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }
        ]
    }

@app.post("/v1/projects")
async def create_project(project: Dict[str, Any]):
    return {
        "id": "proj_new",
        "name": project.get("name", "New Project"),
        "path": project.get("path", "/workspace/new-project"),
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat()
    }

# Sessions endpoints
@app.get("/v1/sessions")
async def list_sessions():
    return {
        "sessions": [
            {
                "id": "sess_001",
                "project_id": "proj_001",
                "status": "active",
                "created_at": datetime.utcnow().isoformat()
            }
        ]
    }

@app.post("/v1/sessions")
async def create_session(session: Dict[str, Any]):
    return {
        "id": "sess_new",
        "project_id": session.get("project_id", "proj_001"),
        "status": "active",
        "created_at": datetime.utcnow().isoformat()
    }

# MCP endpoints
@app.get("/v1/mcp/servers")
async def list_mcp_servers():
    return {
        "servers": [
            {
                "id": "mcp_filesystem",
                "name": "Filesystem",
                "description": "File operations",
                "status": "available"
            },
            {
                "id": "mcp_bash",
                "name": "Bash",
                "description": "Command execution",
                "status": "available"
            }
        ]
    }

@app.get("/v1/mcp/servers/{server_id}/tools")
async def get_mcp_tools(server_id: str):
    tools = {
        "mcp_filesystem": [
            {"name": "read_file", "description": "Read file contents"},
            {"name": "write_file", "description": "Write file contents"},
            {"name": "list_directory", "description": "List directory contents"}
        ],
        "mcp_bash": [
            {"name": "execute", "description": "Execute bash command"},
            {"name": "check_status", "description": "Check command status"}
        ]
    }
    
    return {
        "server_id": server_id,
        "tools": tools.get(server_id, [])
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
    
    # Install uvicorn if not present
    pip install --quiet uvicorn fastapi python-multipart 2>/dev/null || true
    
    echo "Starting test server..."
    exec python -m uvicorn test_server:app --host 0.0.0.0 --port ${PORT:-8000} --reload --app-dir /tmp