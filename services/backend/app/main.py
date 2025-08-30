"""
Main FastAPI application for Claude Code Backend
"""

import os
import time
import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from app.core.config import settings
from app.core.logging import setup_logging
from app.core.rate_limit import RateLimitMiddleware
from app.core.redis_client import init_redis, close_redis
from app.api.v1 import api_router
from app.db.session import engine, Base
from app.services.mcp import MCPManager
from app.middleware.jwt_auth import JWTAuthMiddleware, RoleBasedAccessMiddleware

# Setup logging
logger = setup_logging()

# Initialize MCP manager
mcp_manager = MCPManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting Claude Code Backend API...")
    
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Initialize Redis for session management
    await init_redis()
    
    # Initialize MCP servers
    await mcp_manager.initialize()
    
    # Store in app state
    app.state.mcp_manager = mcp_manager
    
    yield
    
    # Shutdown
    logger.info("Shutting down Claude Code Backend API...")
    await mcp_manager.shutdown()
    await close_redis()
    await engine.dispose()


# Create FastAPI app
app = FastAPI(
    title="Claude Code Backend API",
    version="1.0.0",
    description="OpenAI-compatible API with Claude integration and MCP support",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# Add CORS middleware - configure for specific origins in production
allowed_origins = [
    "http://localhost:3000",  # Local development
    "http://localhost:8080",  # Alternative local port
    "capacitor://localhost",  # iOS app
    "ionic://localhost",  # Ionic framework
    "app://localhost",  # Electron/Desktop apps
]

# In production, use specific origins from settings
if settings.CORS_ORIGINS and settings.CORS_ORIGINS != ["*"]:
    allowed_origins = settings.CORS_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if not settings.DEBUG else ["*"],  # All origins in debug mode
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["X-Total-Count", "X-Request-ID", "X-Process-Time"],
)

# Add JWT authentication middleware
app.add_middleware(JWTAuthMiddleware)

# Add role-based access control middleware
app.add_middleware(RoleBasedAccessMiddleware)

# Add rate limiting middleware
app.add_middleware(RateLimitMiddleware)

# Add request ID middleware
@app.middleware("http")
async def add_request_id(request: Request, call_next):
    """Add unique request ID to each request"""
    request_id = request.headers.get("X-Request-ID", str(time.time()))
    request.state.request_id = request_id
    
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response

# Add response time middleware
@app.middleware("http")
async def add_response_time(request: Request, call_next):
    """Add response time header"""
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

# Include API routes
app.include_router(api_router, prefix="/v1")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": time.time()
    }

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "Claude Code Backend API",
        "version": "1.0.0",
        "documentation": "/docs",
        "openapi": "/openapi.json",
        "endpoints": {
            "chat": "/v1/chat/completions",
            "models": "/v1/models",
            "projects": "/v1/projects",
            "sessions": "/v1/sessions",
            "mcp": "/v1/mcp",
            "analytics": "/v1/analytics",
            "debug": "/v1/debug"
        }
    }

# Error handlers
@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    """Custom 404 handler"""
    return JSONResponse(
        status_code=404,
        content={
            "error": {
                "message": f"The requested URL {request.url.path} was not found.",
                "type": "not_found",
                "code": 404
            }
        }
    )

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    """Custom 500 handler"""
    logger.error(f"Internal server error: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": "An internal server error occurred.",
                "type": "internal_error",
                "code": 500
            }
        }
    )


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info"
    )