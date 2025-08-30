"""
Rate limiting middleware for API protection
"""

import time
import hashlib
from typing import Dict, Optional, Tuple
from collections import defaultdict
from datetime import datetime, timedelta

from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from app.core.config import settings
from app.services.cache import cache_manager


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware with sliding window algorithm
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.enabled = settings.RATE_LIMIT_ENABLED
        self.requests_limit = settings.RATE_LIMIT_REQUESTS
        self.period = settings.RATE_LIMIT_PERIOD
        
        # In-memory storage for rate limiting (fallback if Redis not available)
        self.requests: Dict[str, list] = defaultdict(list)
    
    async def dispatch(self, request: Request, call_next):
        """
        Process request with rate limiting
        """
        if not self.enabled:
            return await call_next(request)
        
        # Skip rate limiting for health checks and docs
        if request.url.path in ["/health", "/docs", "/redoc", "/openapi.json"]:
            return await call_next(request)
        
        # Get client identifier
        client_id = self.get_client_id(request)
        
        # Check rate limit
        allowed, remaining, reset_time = await self.check_rate_limit(client_id)
        
        if not allowed:
            return self.rate_limit_exceeded_response(remaining, reset_time)
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(self.requests_limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_time)
        
        return response
    
    def get_client_id(self, request: Request) -> str:
        """
        Get unique client identifier from request
        """
        # Priority: API key > Authorization header > IP address
        
        # Check for API key
        api_key = request.headers.get("x-api-key")
        if api_key:
            return f"api_key:{hashlib.sha256(api_key.encode()).hexdigest()[:16]}"
        
        # Check for Bearer token
        auth_header = request.headers.get("authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.replace("Bearer ", "")
            return f"token:{hashlib.sha256(token.encode()).hexdigest()[:16]}"
        
        # Fall back to IP address
        client_ip = request.client.host if request.client else "unknown"
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        
        return f"ip:{client_ip}"
    
    async def check_rate_limit(self, client_id: str) -> Tuple[bool, int, int]:
        """
        Check if client has exceeded rate limit
        Returns: (allowed, remaining_requests, reset_timestamp)
        """
        current_time = time.time()
        window_start = current_time - self.period
        
        if settings.redis_enabled:
            # Use Redis for distributed rate limiting
            return await self.check_redis_rate_limit(client_id, current_time, window_start)
        else:
            # Use in-memory storage
            return self.check_memory_rate_limit(client_id, current_time, window_start)
    
    async def check_redis_rate_limit(
        self,
        client_id: str,
        current_time: float,
        window_start: float
    ) -> Tuple[bool, int, int]:
        """
        Check rate limit using Redis
        """
        try:
            key = f"rate_limit:{client_id}"
            
            # Get current request timestamps
            timestamps = await cache_manager.get_list(key)
            
            # Filter out old timestamps
            valid_timestamps = [
                ts for ts in timestamps
                if float(ts) > window_start
            ]
            
            # Check if limit exceeded
            if len(valid_timestamps) >= self.requests_limit:
                oldest_timestamp = min(valid_timestamps)
                reset_time = int(float(oldest_timestamp) + self.period)
                return False, 0, reset_time
            
            # Add current timestamp
            valid_timestamps.append(str(current_time))
            
            # Update Redis
            await cache_manager.set_list(key, valid_timestamps, ttl=self.period)
            
            remaining = self.requests_limit - len(valid_timestamps)
            reset_time = int(current_time + self.period)
            
            return True, remaining, reset_time
            
        except Exception as e:
            # If Redis fails, allow the request but log the error
            logger.error(f"Redis rate limit check failed: {e}")
            return True, self.requests_limit, int(current_time + self.period)
    
    def check_memory_rate_limit(
        self,
        client_id: str,
        current_time: float,
        window_start: float
    ) -> Tuple[bool, int, int]:
        """
        Check rate limit using in-memory storage
        """
        # Clean old timestamps
        self.requests[client_id] = [
            ts for ts in self.requests[client_id]
            if ts > window_start
        ]
        
        # Check if limit exceeded
        if len(self.requests[client_id]) >= self.requests_limit:
            oldest_timestamp = min(self.requests[client_id])
            reset_time = int(oldest_timestamp + self.period)
            return False, 0, reset_time
        
        # Add current timestamp
        self.requests[client_id].append(current_time)
        
        remaining = self.requests_limit - len(self.requests[client_id])
        reset_time = int(current_time + self.period)
        
        return True, remaining, reset_time
    
    def rate_limit_exceeded_response(self, remaining: int, reset_time: int) -> JSONResponse:
        """
        Create rate limit exceeded response
        """
        return JSONResponse(
            status_code=429,
            content={
                "error": {
                    "message": "Rate limit exceeded. Please try again later.",
                    "type": "rate_limit_exceeded",
                    "code": 429
                }
            },
            headers={
                "X-RateLimit-Limit": str(self.requests_limit),
                "X-RateLimit-Remaining": str(remaining),
                "X-RateLimit-Reset": str(reset_time),
                "Retry-After": str(reset_time - int(time.time()))
            }
        )


class AdaptiveRateLimiter:
    """
    Adaptive rate limiter that adjusts limits based on system load
    """
    
    def __init__(self):
        self.base_limit = settings.RATE_LIMIT_REQUESTS
        self.min_limit = max(10, self.base_limit // 4)
        self.max_limit = self.base_limit * 2
        self.current_limit = self.base_limit
        self.load_history: list = []
        self.adjustment_interval = 60  # seconds
        self.last_adjustment = time.time()
    
    def update_load(self, cpu_percent: float, memory_percent: float, response_time: float):
        """
        Update system load metrics
        """
        load_score = (cpu_percent * 0.3 + memory_percent * 0.3 + min(response_time * 100, 100) * 0.4) / 100
        self.load_history.append((time.time(), load_score))
        
        # Keep only recent history
        cutoff = time.time() - self.adjustment_interval * 2
        self.load_history = [(t, s) for t, s in self.load_history if t > cutoff]
        
        # Adjust limits if needed
        if time.time() - self.last_adjustment > self.adjustment_interval:
            self.adjust_limits()
    
    def adjust_limits(self):
        """
        Adjust rate limits based on system load
        """
        if not self.load_history:
            return
        
        # Calculate average load
        avg_load = sum(score for _, score in self.load_history) / len(self.load_history)
        
        # Adjust limit based on load
        if avg_load > 0.8:
            # High load - reduce limit
            self.current_limit = max(self.min_limit, int(self.current_limit * 0.9))
        elif avg_load < 0.3:
            # Low load - increase limit
            self.current_limit = min(self.max_limit, int(self.current_limit * 1.1))
        else:
            # Moderate load - gradually return to base
            if self.current_limit < self.base_limit:
                self.current_limit = min(self.base_limit, int(self.current_limit * 1.05))
            elif self.current_limit > self.base_limit:
                self.current_limit = max(self.base_limit, int(self.current_limit * 0.95))
        
        self.last_adjustment = time.time()
        logger.info(f"Adjusted rate limit to {self.current_limit} (load: {avg_load:.2f})")
    
    def get_current_limit(self) -> int:
        """
        Get current rate limit
        """
        return self.current_limit


# Import logger
import logging
logger = logging.getLogger(__name__)