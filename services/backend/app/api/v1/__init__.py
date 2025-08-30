"""
API v1 router aggregation
"""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth,
    chat,
    models,
    projects,
    sessions,
    mcp,
    analytics,
    debug,
    files,
    environment
)

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(auth.router, tags=["authentication"])  # Auth endpoints first
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(models.router, prefix="/models", tags=["models"])
api_router.include_router(projects.router, prefix="/projects", tags=["projects"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(mcp.router, prefix="/mcp", tags=["mcp"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(debug.router, prefix="/debug", tags=["debug"])
api_router.include_router(files.router, prefix="/files", tags=["files"])
api_router.include_router(environment.router, prefix="/environment", tags=["environment"])