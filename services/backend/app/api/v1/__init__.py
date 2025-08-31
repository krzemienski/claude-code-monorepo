"""
API v1 router aggregation
"""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    # auth removed - no authentication required
    chat,
    models,
    projects,
    sessions,
    mcp,
    analytics,
    debug,
    files,
    environment,
    missing_endpoints,  # Import the new endpoints module
    monitoring  # Import monitoring endpoints
)

api_router = APIRouter()

# Include all endpoint routers
# Authentication removed - all endpoints are public
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(models.router, prefix="/models", tags=["models"])
api_router.include_router(projects.router, prefix="/projects", tags=["projects"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])

# Add the missing endpoints (messages and tools are under sessions, profile is standalone)
api_router.include_router(missing_endpoints.messages_router, tags=["sessions", "messages"])
api_router.include_router(missing_endpoints.tools_router, tags=["sessions", "tools"])
api_router.include_router(missing_endpoints.profile_router, tags=["profile", "user"])

api_router.include_router(mcp.router, prefix="/mcp", tags=["mcp"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(debug.router, prefix="/debug", tags=["debug"])
api_router.include_router(files.router, prefix="/files", tags=["files"])
api_router.include_router(environment.router, prefix="/environment", tags=["environment"])
api_router.include_router(monitoring.router, prefix="/monitoring", tags=["monitoring", "metrics"])