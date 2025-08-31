"""
Performance monitoring middleware with Prometheus metrics
Tracks endpoint timing, token usage, and system health
"""

import time
import asyncio
from typing import Dict, Any, Optional
from datetime import datetime
import psutil
from contextlib import asynccontextmanager

from fastapi import Request, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CollectorRegistry
from prometheus_client.exposition import make_asgi_app
import redis.asyncio as redis

from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

# Create custom registry for metrics
registry = CollectorRegistry()

# Define metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status'],
    registry=registry
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    registry=registry,
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
)

active_sessions_gauge = Gauge(
    'active_sessions',
    'Number of active chat sessions',
    registry=registry
)

websocket_connections_gauge = Gauge(
    'websocket_connections',
    'Number of active WebSocket connections',
    registry=registry
)

sse_connections_gauge = Gauge(
    'sse_connections',
    'Number of active SSE connections',
    registry=registry
)

token_usage_counter = Counter(
    'token_usage_total',
    'Total token usage',
    ['model', 'type'],  # type: prompt/completion/total
    registry=registry
)

api_errors_counter = Counter(
    'api_errors_total',
    'Total API errors',
    ['endpoint', 'error_type'],
    registry=registry
)

system_memory_gauge = Gauge(
    'system_memory_bytes',
    'System memory usage in bytes',
    ['type'],  # type: available/used/percent
    registry=registry
)

system_cpu_gauge = Gauge(
    'system_cpu_percent',
    'System CPU usage percentage',
    registry=registry
)

redis_connections_gauge = Gauge(
    'redis_connections',
    'Number of Redis connections',
    registry=registry
)

database_connections_gauge = Gauge(
    'database_connections',
    'Number of database connections',
    ['state'],  # state: active/idle/total
    registry=registry
)


class PerformanceMonitoringMiddleware:
    """
    Middleware for comprehensive performance monitoring
    """
    
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.monitoring_task: Optional[asyncio.Task] = None
        
    async def __call__(self, request: Request, call_next):
        """Process request and collect metrics"""
        start_time = time.time()
        
        # Extract endpoint info
        endpoint = request.url.path
        method = request.method
        
        # Track request
        try:
            response = await call_next(request)
            status_code = response.status_code
            
            # Record metrics
            duration = time.time() - start_time
            http_requests_total.labels(
                method=method,
                endpoint=endpoint,
                status=status_code
            ).inc()
            
            http_request_duration_seconds.labels(
                method=method,
                endpoint=endpoint
            ).observe(duration)
            
            # Add performance headers
            response.headers["X-Process-Time"] = f"{duration:.3f}"
            response.headers["X-Server-Timestamp"] = str(int(time.time()))
            
            # Track errors
            if status_code >= 400:
                error_type = "client_error" if status_code < 500 else "server_error"
                api_errors_counter.labels(
                    endpoint=endpoint,
                    error_type=error_type
                ).inc()
            
            return response
            
        except Exception as e:
            # Track exception
            duration = time.time() - start_time
            api_errors_counter.labels(
                endpoint=endpoint,
                error_type="exception"
            ).inc()
            
            logger.error(f"Request processing error: {e}")
            raise
    
    async def start_monitoring(self):
        """Start background monitoring tasks"""
        if not self.monitoring_task or self.monitoring_task.done():
            self.monitoring_task = asyncio.create_task(self._monitor_system())
            logger.info("Started performance monitoring background task")
    
    async def stop_monitoring(self):
        """Stop background monitoring tasks"""
        if self.monitoring_task and not self.monitoring_task.done():
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
            logger.info("Stopped performance monitoring background task")
    
    async def _monitor_system(self):
        """Background task to monitor system metrics"""
        while True:
            try:
                # System memory metrics
                memory = psutil.virtual_memory()
                system_memory_gauge.labels(type='available').set(memory.available)
                system_memory_gauge.labels(type='used').set(memory.used)
                system_memory_gauge.labels(type='percent').set(memory.percent)
                
                # CPU metrics
                cpu_percent = psutil.cpu_percent(interval=1)
                system_cpu_gauge.set(cpu_percent)
                
                # Redis connection metrics (if available)
                if self.redis_client:
                    try:
                        info = await self.redis_client.info()
                        redis_connections_gauge.set(
                            info.get('connected_clients', 0)
                        )
                    except Exception as e:
                        logger.warning(f"Failed to get Redis metrics: {e}")
                
                # Sleep for 10 seconds before next collection
                await asyncio.sleep(10)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in monitoring task: {e}")
                await asyncio.sleep(10)


class TokenUsageTracker:
    """Track and report token usage metrics"""
    
    @staticmethod
    def track_usage(model: str, prompt_tokens: int, completion_tokens: int):
        """Track token usage for a model"""
        token_usage_counter.labels(model=model, type='prompt').inc(prompt_tokens)
        token_usage_counter.labels(model=model, type='completion').inc(completion_tokens)
        token_usage_counter.labels(model=model, type='total').inc(
            prompt_tokens + completion_tokens
        )
    
    @staticmethod
    def track_session_tokens(session_id: str, tokens: int):
        """Track tokens for a specific session"""
        # This could be expanded to track per-session metrics
        logger.debug(f"Session {session_id} used {tokens} tokens")


class ConnectionTracker:
    """Track WebSocket and SSE connections"""
    
    @staticmethod
    def add_websocket_connection():
        """Increment WebSocket connection count"""
        websocket_connections_gauge.inc()
    
    @staticmethod
    def remove_websocket_connection():
        """Decrement WebSocket connection count"""
        websocket_connections_gauge.dec()
    
    @staticmethod
    def add_sse_connection():
        """Increment SSE connection count"""
        sse_connections_gauge.inc()
    
    @staticmethod
    def remove_sse_connection():
        """Decrement SSE connection count"""
        sse_connections_gauge.dec()
    
    @staticmethod
    def update_active_sessions(count: int):
        """Update active sessions count"""
        active_sessions_gauge.set(count)


class DatabaseMetrics:
    """Track database connection metrics"""
    
    @staticmethod
    async def update_pool_metrics(pool):
        """Update database connection pool metrics"""
        try:
            # Get pool statistics
            size = pool.size if hasattr(pool, 'size') else 0
            checked_in = pool.checked_in_connections if hasattr(pool, 'checked_in_connections') else 0
            checked_out = pool.checked_out_connections if hasattr(pool, 'checked_out_connections') else 0
            
            database_connections_gauge.labels(state='total').set(size)
            database_connections_gauge.labels(state='idle').set(checked_in)
            database_connections_gauge.labels(state='active').set(checked_out)
            
        except Exception as e:
            logger.warning(f"Failed to update database metrics: {e}")


# Create Prometheus metrics endpoint
metrics_app = make_asgi_app(registry=registry)


# Export middleware instance
monitoring_middleware = PerformanceMonitoringMiddleware()


@asynccontextmanager
async def monitoring_lifespan():
    """Lifespan manager for monitoring"""
    # Start monitoring
    await monitoring_middleware.start_monitoring()
    yield
    # Stop monitoring
    await monitoring_middleware.stop_monitoring()


# Utility functions for manual metric updates
def track_endpoint_error(endpoint: str, error_type: str):
    """Manually track an endpoint error"""
    api_errors_counter.labels(endpoint=endpoint, error_type=error_type).inc()


def track_custom_metric(name: str, value: float, labels: Dict[str, str] = None):
    """Track a custom metric (for extension)"""
    logger.info(f"Custom metric: {name}={value}, labels={labels}")


# Health check endpoint for monitoring
async def get_monitoring_health() -> Dict[str, Any]:
    """Get monitoring system health status"""
    try:
        memory = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=0.1)
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "metrics": {
                "memory_percent": memory.percent,
                "cpu_percent": cpu_percent,
                "active_sessions": active_sessions_gauge._value.get(),
                "websocket_connections": websocket_connections_gauge._value.get(),
                "sse_connections": sse_connections_gauge._value.get()
            }
        }
    except Exception as e:
        logger.error(f"Failed to get monitoring health: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }