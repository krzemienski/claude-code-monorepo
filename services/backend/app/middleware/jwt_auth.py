"""
JWT Authentication Middleware for FastAPI
"""

import time
from typing import Optional, Callable
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from app.auth.jwt_handler import jwt_handler
from app.core.logging import setup_logging

logger = setup_logging()


class JWTAuthMiddleware(BaseHTTPMiddleware):
    """
    JWT Authentication Middleware
    
    Validates JWT tokens for protected endpoints
    """
    
    def __init__(
        self,
        app: ASGIApp,
        exclude_paths: list[str] = None,
        exclude_prefixes: list[str] = None,
        optional_paths: list[str] = None
    ):
        """
        Initialize JWT middleware
        
        Args:
            app: FastAPI application
            exclude_paths: Exact paths to exclude from authentication
            exclude_prefixes: Path prefixes to exclude from authentication
            optional_paths: Paths where authentication is optional
        """
        super().__init__(app)
        
        # Default excluded paths (public endpoints)
        self.exclude_paths = exclude_paths or [
            "/",
            "/health",
            "/docs",
            "/redoc",
            "/openapi.json",
            "/v1/auth/login",
            "/v1/auth/register",
            "/v1/auth/refresh",
            "/v1/auth/verify-token"
        ]
        
        # Path prefixes to exclude
        self.exclude_prefixes = exclude_prefixes or [
            "/static",
            "/public"
        ]
        
        # Optional authentication paths
        self.optional_paths = optional_paths or [
            "/v1/models"  # Public endpoint but can use auth for rate limiting
        ]
    
    async def dispatch(self, request: Request, call_next):
        """
        Process requests and validate JWT tokens
        """
        # Skip authentication for excluded paths
        if self._should_skip_auth(request.url.path):
            return await call_next(request)
        
        # Check if path has optional authentication
        is_optional = request.url.path in self.optional_paths
        
        # Extract token from Authorization header
        auth_header = request.headers.get("Authorization")
        
        if not auth_header and not is_optional:
            return self._unauthorized_response("Authorization header missing")
        
        if auth_header:
            # Validate Bearer token format
            if not auth_header.startswith("Bearer "):
                return self._unauthorized_response("Invalid authorization header format")
            
            token = auth_header[7:]  # Remove "Bearer " prefix
            
            # Verify token
            payload = jwt_handler.verify_token(token, token_type="access")
            
            if not payload and not is_optional:
                return self._unauthorized_response("Invalid or expired token")
            
            if payload:
                # Add user information to request state
                request.state.user_id = payload.get("sub")
                request.state.user_email = payload.get("email")
                request.state.user_roles = payload.get("roles", [])
                request.state.user_permissions = payload.get("permissions", [])
                request.state.authenticated = True
                
                # Log authenticated request
                logger.debug(f"Authenticated request from user {request.state.user_email} to {request.url.path}")
            else:
                request.state.authenticated = False
        else:
            request.state.authenticated = False
        
        # Process request
        response = await call_next(request)
        
        # Add security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        
        return response
    
    def _should_skip_auth(self, path: str) -> bool:
        """
        Check if path should skip authentication
        
        Args:
            path: Request path
            
        Returns:
            True if authentication should be skipped
        """
        # Check exact path matches
        if path in self.exclude_paths:
            return True
        
        # Check prefix matches
        for prefix in self.exclude_prefixes:
            if path.startswith(prefix):
                return True
        
        return False
    
    def _unauthorized_response(self, detail: str) -> JSONResponse:
        """
        Create unauthorized response
        
        Args:
            detail: Error detail message
            
        Returns:
            JSON response with 401 status
        """
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={
                "error": {
                    "message": detail,
                    "type": "authentication_error",
                    "code": 401
                }
            },
            headers={"WWW-Authenticate": "Bearer"}
        )


class RoleBasedAccessMiddleware(BaseHTTPMiddleware):
    """
    Role-Based Access Control Middleware
    
    Enforces role requirements for specific endpoints
    """
    
    def __init__(
        self,
        app: ASGIApp,
        role_requirements: dict[str, list[str]] = None
    ):
        """
        Initialize RBAC middleware
        
        Args:
            app: FastAPI application
            role_requirements: Mapping of paths to required roles
        """
        super().__init__(app)
        
        # Default role requirements
        self.role_requirements = role_requirements or {
            "/v1/admin": ["admin"],
            "/v1/analytics": ["admin", "analyst"],
            "/v1/debug": ["admin", "developer"]
        }
    
    async def dispatch(self, request: Request, call_next):
        """
        Check role-based access control
        """
        # Check if user is authenticated
        if not hasattr(request.state, "authenticated") or not request.state.authenticated:
            return await call_next(request)
        
        # Check role requirements for path
        user_roles = getattr(request.state, "user_roles", [])
        
        for path_prefix, required_roles in self.role_requirements.items():
            if request.url.path.startswith(path_prefix):
                # Check if user has at least one required role
                if not any(role in user_roles for role in required_roles):
                    logger.warning(
                        f"Access denied for user {request.state.user_email} to {request.url.path}. "
                        f"Required roles: {required_roles}, User roles: {user_roles}"
                    )
                    return JSONResponse(
                        status_code=status.HTTP_403_FORBIDDEN,
                        content={
                            "error": {
                                "message": f"Insufficient permissions. Required roles: {required_roles}",
                                "type": "authorization_error",
                                "code": 403
                            }
                        }
                    )
        
        return await call_next(request)


class APIKeyAuthMiddleware(BaseHTTPMiddleware):
    """
    API Key Authentication Middleware
    
    Alternative authentication using API keys
    """
    
    def __init__(
        self,
        app: ASGIApp,
        header_name: str = "X-API-Key"
    ):
        """
        Initialize API key middleware
        
        Args:
            app: FastAPI application
            header_name: Header name for API key
        """
        super().__init__(app)
        self.header_name = header_name
    
    async def dispatch(self, request: Request, call_next):
        """
        Process API key authentication
        """
        # Skip if already authenticated via JWT
        if hasattr(request.state, "authenticated") and request.state.authenticated:
            return await call_next(request)
        
        # Check for API key
        api_key = request.headers.get(self.header_name)
        
        if api_key:
            # Here you would validate the API key against the database
            # For now, we'll just set a flag
            request.state.api_key = api_key
            request.state.auth_method = "api_key"
            
            logger.debug(f"API key authentication attempt for {request.url.path}")
        
        return await call_next(request)