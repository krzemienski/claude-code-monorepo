"""
Debug API endpoints
Provides diagnostic information, system health, and debugging utilities
"""

import os
import sys
import time
import psutil
import platform
import asyncio
from datetime import datetime
from typing import Dict, Any, List, Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, select, func

from app.db.session import get_db, engine
from app.core.config import settings
from app.services.cache import cache_manager
from app.services.mcp import MCPManager
# Authentication removed - all endpoints are public

router = APIRouter()


@router.get("/info")
async def get_debug_info(
    
):
    """
    Get comprehensive debug information about the system
    Admin access required
    """
    # System information
    system_info = {
        "platform": platform.platform(),
        "python_version": sys.version,
        "processor": platform.processor(),
        "architecture": platform.architecture(),
        "hostname": platform.node(),
        "cpu_count": psutil.cpu_count(),
        "memory": {
            "total": psutil.virtual_memory().total,
            "available": psutil.virtual_memory().available,
            "percent": psutil.virtual_memory().percent,
            "used": psutil.virtual_memory().used
        },
        "disk": {
            "total": psutil.disk_usage('/').total,
            "used": psutil.disk_usage('/').used,
            "free": psutil.disk_usage('/').free,
            "percent": psutil.disk_usage('/').percent
        }
    }
    
    # Process information
    process = psutil.Process()
    process_info = {
        "pid": process.pid,
        "cpu_percent": process.cpu_percent(),
        "memory_info": {
            "rss": process.memory_info().rss,
            "vms": process.memory_info().vms,
            "percent": process.memory_percent()
        },
        "num_threads": process.num_threads(),
        "create_time": datetime.fromtimestamp(process.create_time()).isoformat(),
        "status": process.status()
    }
    
    # Application configuration (sanitized)
    config_info = {
        "debug_mode": settings.DEBUG,
        "port": settings.PORT,
        "anthropic_model": settings.ANTHROPIC_MODEL,
        "database_url": settings.DATABASE_URL.split("@")[0] if "@" in settings.DATABASE_URL else "sqlite",
        "redis_enabled": settings.redis_enabled,
        "rate_limit_enabled": settings.RATE_LIMIT_ENABLED,
        "mcp_discovery_enabled": settings.MCP_DISCOVERY_ENABLED,
        "metrics_enabled": settings.METRICS_ENABLED,
        "workspace_dir": settings.WORKSPACE_DIR,
        "log_level": settings.LOG_LEVEL
    }
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "system": system_info,
        "process": process_info,
        "config": config_info,
        "uptime_seconds": time.time() - process.create_time()
    }


@router.get("/health/detailed")
async def get_detailed_health(
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed health status of all system components
    """
    health_status = {
        "timestamp": datetime.utcnow().isoformat(),
        "overall": "healthy",
        "components": {}
    }
    
    # Check database
    try:
        await db.execute(text("SELECT 1"))
        health_status["components"]["database"] = {
            "status": "healthy",
            "type": "postgresql" if "postgresql" in settings.DATABASE_URL else "sqlite"
        }
    except Exception as e:
        health_status["components"]["database"] = {
            "status": "unhealthy",
            "error": str(e)
        }
        health_status["overall"] = "degraded"
    
    # Check Redis if enabled
    if settings.redis_enabled:
        try:
            from app.services.cache import cache_manager
            await cache_manager.ping()
            health_status["components"]["redis"] = {"status": "healthy"}
        except Exception as e:
            health_status["components"]["redis"] = {
                "status": "unhealthy",
                "error": str(e)
            }
            health_status["overall"] = "degraded"
    
    # Check MCP servers
    try:
        mcp_manager = MCPManager()
        servers = await mcp_manager.list_servers()
        health_status["components"]["mcp"] = {
            "status": "healthy",
            "server_count": len(servers)
        }
    except Exception as e:
        health_status["components"]["mcp"] = {
            "status": "unhealthy",
            "error": str(e)
        }
    
    # Check Anthropic API
    try:
        from anthropic import AsyncAnthropic
        client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
        # Simple check - just verify the client can be created
        health_status["components"]["anthropic"] = {
            "status": "configured",
            "model": settings.ANTHROPIC_MODEL
        }
    except Exception as e:
        health_status["components"]["anthropic"] = {
            "status": "error",
            "error": str(e)
        }
        health_status["overall"] = "degraded"
    
    # Check filesystem
    try:
        workspace_exists = os.path.exists(settings.WORKSPACE_DIR)
        workspace_writable = os.access(settings.WORKSPACE_DIR, os.W_OK) if workspace_exists else False
        
        health_status["components"]["filesystem"] = {
            "status": "healthy" if workspace_exists and workspace_writable else "degraded",
            "workspace_exists": workspace_exists,
            "workspace_writable": workspace_writable
        }
    except Exception as e:
        health_status["components"]["filesystem"] = {
            "status": "error",
            "error": str(e)
        }
    
    return health_status


@router.get("/metrics")
async def get_metrics(
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get application metrics and performance statistics
    """
    # Database metrics
    db_metrics = {}
    try:
        # Get session count
        session_count = await db.scalar(
            select(func.count()).select_from(Session)
        )
        
        # Get message count
        message_count = await db.scalar(
            select(func.count()).select_from(Message)
        )
        
        # Get active sessions
        active_sessions = await db.scalar(
            select(func.count()).select_from(Session).where(
                Session.status == "active"
            )
        )
        
        db_metrics = {
            "total_sessions": session_count,
            "active_sessions": active_sessions,
            "total_messages": message_count
        }
    except:
        db_metrics = {"error": "Failed to fetch database metrics"}
    
    # System metrics
    system_metrics = {
        "cpu_percent": psutil.cpu_percent(interval=1),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_percent": psutil.disk_usage('/').percent,
        "network": {
            "bytes_sent": psutil.net_io_counters().bytes_sent,
            "bytes_recv": psutil.net_io_counters().bytes_recv
        }
    }
    
    # Process metrics
    process = psutil.Process()
    process_metrics = {
        "cpu_percent": process.cpu_percent(),
        "memory_mb": process.memory_info().rss / 1024 / 1024,
        "threads": process.num_threads(),
        "connections": len(process.connections())
    }
    
    # Cache metrics if Redis is enabled
    cache_metrics = {}
    if settings.redis_enabled:
        try:
            cache_metrics = await cache_manager.get_stats()
        except:
            cache_metrics = {"error": "Failed to fetch cache metrics"}
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "database": db_metrics,
        "system": system_metrics,
        "process": process_metrics,
        "cache": cache_metrics
    }


@router.get("/logs")
async def get_recent_logs(
    lines: int = Query(100, le=1000),
    level: Optional[str] = Query(None),
    
):
    """
    Get recent application logs
    Admin access required
    """
    log_file = "/workspace/logs/app.log"
    
    if not os.path.exists(log_file):
        return {"logs": [], "message": "Log file not found"}
    
    try:
        with open(log_file, 'r') as f:
            # Read last N lines
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:]
            
            # Filter by level if specified
            if level:
                recent_lines = [
                    line for line in recent_lines 
                    if level.upper() in line.upper()
                ]
            
            return {
                "logs": recent_lines,
                "count": len(recent_lines),
                "total_lines": len(all_lines)
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read logs: {str(e)}")


@router.get("/config")
async def get_configuration(
    
):
    """
    Get current application configuration (sanitized)
    Admin access required
    """
    # Sanitize sensitive information
    safe_config = {}
    
    for key, value in settings.dict().items():
        if any(sensitive in key.lower() for sensitive in ["key", "secret", "password", "token"]):
            # Mask sensitive values
            if value:
                safe_config[key] = "***REDACTED***"
            else:
                safe_config[key] = None
        else:
            safe_config[key] = value
    
    return {
        "config": safe_config,
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "version": settings.VERSION
    }


@router.post("/cache/clear")
async def clear_cache(
    
):
    """
    Clear application cache
    Admin access required
    """
    if not settings.redis_enabled:
        return {"message": "Cache not enabled", "cleared": False}
    
    try:
        cleared = await cache_manager.clear_all()
        return {
            "message": "Cache cleared successfully",
            "cleared": True,
            "keys_cleared": cleared
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to clear cache: {str(e)}")


@router.get("/environment")
async def get_environment_info():
    """
    Get environment variables and system information
    Public endpoint for debugging client connectivity
    """
    return {
        "api_version": settings.VERSION,
        "anthropic_model": settings.ANTHROPIC_MODEL,
        "cors_origins": settings.CORS_ORIGINS,
        "rate_limiting": settings.RATE_LIMIT_ENABLED,
        "mcp_enabled": settings.MCP_DISCOVERY_ENABLED,
        "workspace_dir": settings.WORKSPACE_DIR,
        "server_time": datetime.utcnow().isoformat(),
        "python_version": sys.version,
        "platform": platform.platform()
    }


@router.post("/test/error")
async def trigger_test_error(
    error_type: str = Query("generic"),
    
):
    """
    Trigger a test error for debugging error handling
    Admin access required
    """
    if error_type == "generic":
        raise HTTPException(status_code=500, detail="Test error triggered")
    elif error_type == "database":
        async with get_db() as db:
            await db.execute(text("SELECT * FROM non_existent_table"))
    elif error_type == "timeout":
        await asyncio.sleep(30)
        return {"message": "Should have timed out"}
    elif error_type == "memory":
        # Allocate large memory
        data = [0] * (10**8)
        return {"message": f"Allocated {len(data)} items"}
    else:
        raise ValueError(f"Unknown error type: {error_type}")


# Import required models
from app.models.session import Session
from app.models.message import Message