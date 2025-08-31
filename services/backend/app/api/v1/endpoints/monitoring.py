"""
Monitoring and metrics endpoints
Provides health checks, metrics, and system status
"""

from typing import Dict, Any, Optional
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.responses import PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from prometheus_client import generate_latest

from app.db.session import get_db
from app.models.session import Session, SessionStatus
from app.models.message import Message
from app.core.logging import setup_logging
from app.middleware.performance_monitoring import (
    registry,
    get_monitoring_health,
    active_sessions_gauge,
    ConnectionTracker,
    DatabaseMetrics
)
from app.services.websocket_manager import websocket_manager

logger = setup_logging()

router = APIRouter()


@router.get("/health", response_model=Dict[str, Any])
async def health_check(
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Comprehensive health check endpoint
    Returns system health and basic metrics
    """
    try:
        # Check database connectivity
        await db.execute(select(1))
        db_status = "healthy"
        db_error = None
    except Exception as e:
        db_status = "unhealthy"
        db_error = str(e)
        logger.error(f"Database health check failed: {e}")
    
    # Get monitoring health
    monitoring_status = await get_monitoring_health()
    
    # Get WebSocket statistics
    ws_stats = websocket_manager.get_connection_stats()
    
    # Count active sessions
    active_sessions = await db.scalar(
        select(func.count()).select_from(Session).where(
            Session.status == SessionStatus.ACTIVE
        )
    )
    
    # Update gauge
    active_sessions_gauge.set(active_sessions or 0)
    
    return {
        "status": "healthy" if db_status == "healthy" else "degraded",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "components": {
            "database": {
                "status": db_status,
                "error": db_error
            },
            "monitoring": monitoring_status,
            "websocket": {
                "status": "healthy",
                "stats": ws_stats
            }
        },
        "metrics": {
            "active_sessions": active_sessions,
            "websocket_connections": ws_stats["active_connections"]
        }
    }


@router.get("/metrics", response_class=PlainTextResponse)
async def prometheus_metrics() -> str:
    """
    Prometheus metrics endpoint
    Returns metrics in Prometheus text format
    """
    try:
        # Generate metrics
        metrics = generate_latest(registry)
        return metrics.decode('utf-8')
    except Exception as e:
        logger.error(f"Failed to generate metrics: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate metrics")


@router.get("/status", response_model=Dict[str, Any])
async def system_status(
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Detailed system status endpoint
    Returns comprehensive system metrics and status
    """
    # Get session statistics
    total_sessions = await db.scalar(
        select(func.count()).select_from(Session)
    )
    
    active_sessions = await db.scalar(
        select(func.count()).select_from(Session).where(
            Session.status == SessionStatus.ACTIVE
        )
    )
    
    # Get message statistics for last 24 hours
    yesterday = datetime.utcnow() - timedelta(days=1)
    recent_messages = await db.scalar(
        select(func.count()).select_from(Message).where(
            Message.created_at > yesterday
        )
    )
    
    # Get token usage statistics
    token_stats = await db.execute(
        select(
            func.sum(Message.token_count).label("total_tokens"),
            func.avg(Message.token_count).label("avg_tokens")
        ).select_from(Message).where(
            Message.created_at > yesterday
        )
    )
    token_result = token_stats.first()
    
    # Get WebSocket stats
    ws_stats = websocket_manager.get_connection_stats()
    
    # Get monitoring health
    monitoring_health = await get_monitoring_health()
    
    return {
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat(),
        "sessions": {
            "total": total_sessions or 0,
            "active": active_sessions or 0,
            "inactive": (total_sessions or 0) - (active_sessions or 0)
        },
        "messages": {
            "last_24h": recent_messages or 0,
            "tokens": {
                "total_24h": token_result.total_tokens or 0,
                "average": round(token_result.avg_tokens or 0, 2)
            }
        },
        "connections": {
            "websocket": ws_stats,
            "sse": {
                "active": monitoring_health["metrics"].get("sse_connections", 0)
            }
        },
        "system": {
            "cpu_percent": monitoring_health["metrics"]["cpu_percent"],
            "memory_percent": monitoring_health["metrics"]["memory_percent"]
        }
    }


@router.get("/dashboard", response_model=Dict[str, Any])
async def monitoring_dashboard(
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Dashboard configuration and current metrics
    Returns data formatted for monitoring dashboard display
    """
    # Get current metrics
    status = await system_status(db)
    
    # Dashboard configuration
    dashboard_config = {
        "refresh_interval": 10,  # seconds
        "metrics_endpoint": "/v1/monitoring/metrics",
        "health_endpoint": "/v1/monitoring/health",
        "panels": [
            {
                "id": "sessions",
                "title": "Active Sessions",
                "type": "gauge",
                "metric": "active_sessions",
                "thresholds": {
                    "green": 0,
                    "yellow": 50,
                    "red": 100
                }
            },
            {
                "id": "websockets",
                "title": "WebSocket Connections",
                "type": "gauge",
                "metric": "websocket_connections"
            },
            {
                "id": "requests",
                "title": "Requests/sec",
                "type": "graph",
                "metric": "http_requests_total",
                "aggregation": "rate"
            },
            {
                "id": "latency",
                "title": "Request Latency",
                "type": "histogram",
                "metric": "http_request_duration_seconds",
                "unit": "seconds"
            },
            {
                "id": "tokens",
                "title": "Token Usage",
                "type": "counter",
                "metric": "token_usage_total"
            },
            {
                "id": "errors",
                "title": "Error Rate",
                "type": "graph",
                "metric": "api_errors_total",
                "aggregation": "rate"
            },
            {
                "id": "cpu",
                "title": "CPU Usage",
                "type": "gauge",
                "metric": "system_cpu_percent",
                "unit": "percent",
                "thresholds": {
                    "green": 0,
                    "yellow": 60,
                    "red": 80
                }
            },
            {
                "id": "memory",
                "title": "Memory Usage",
                "type": "gauge",
                "metric": "system_memory_percent",
                "unit": "percent",
                "thresholds": {
                    "green": 0,
                    "yellow": 70,
                    "red": 90
                }
            }
        ],
        "alerts": [
            {
                "name": "High CPU Usage",
                "condition": "system_cpu_percent > 80",
                "severity": "warning"
            },
            {
                "name": "High Memory Usage",
                "condition": "system_memory_percent > 90",
                "severity": "critical"
            },
            {
                "name": "High Error Rate",
                "condition": "rate(api_errors_total) > 0.1",
                "severity": "warning"
            },
            {
                "name": "WebSocket Disconnections",
                "condition": "rate(websocket_disconnections) > 5",
                "severity": "info"
            }
        ]
    }
    
    return {
        "config": dashboard_config,
        "current_metrics": status,
        "timestamp": datetime.utcnow().isoformat()
    }


@router.post("/test-metrics")
async def test_metrics_collection() -> Dict[str, Any]:
    """
    Test endpoint to verify metrics collection
    Generates sample metrics for testing
    """
    from app.middleware.performance_monitoring import (
        TokenUsageTracker,
        track_endpoint_error,
        track_custom_metric
    )
    
    # Track some test metrics
    TokenUsageTracker.track_usage("claude-3-opus", 100, 150)
    track_endpoint_error("/test", "test_error")
    track_custom_metric("test_metric", 42.0, {"label": "test"})
    
    # Update connection counters
    ConnectionTracker.add_sse_connection()
    ConnectionTracker.remove_sse_connection()
    
    return {
        "status": "success",
        "message": "Test metrics generated",
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/alerts", response_model=Dict[str, Any])
async def get_active_alerts(
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Get active monitoring alerts
    """
    alerts = []
    
    # Check system metrics
    monitoring_health = await get_monitoring_health()
    
    # CPU alert
    cpu_percent = monitoring_health["metrics"]["cpu_percent"]
    if cpu_percent > 80:
        alerts.append({
            "id": "cpu_high",
            "severity": "critical" if cpu_percent > 90 else "warning",
            "message": f"High CPU usage: {cpu_percent}%",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    # Memory alert
    memory_percent = monitoring_health["metrics"]["memory_percent"]
    if memory_percent > 80:
        alerts.append({
            "id": "memory_high",
            "severity": "critical" if memory_percent > 90 else "warning",
            "message": f"High memory usage: {memory_percent}%",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    # Session alert
    active_sessions = await db.scalar(
        select(func.count()).select_from(Session).where(
            Session.status == SessionStatus.ACTIVE
        )
    )
    if active_sessions > 100:
        alerts.append({
            "id": "sessions_high",
            "severity": "info",
            "message": f"High number of active sessions: {active_sessions}",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    return {
        "alerts": alerts,
        "total": len(alerts),
        "timestamp": datetime.utcnow().isoformat()
    }