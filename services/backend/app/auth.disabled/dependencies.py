"""
FastAPI dependencies for authentication and authorization
"""

from typing import Optional, Annotated
from datetime import datetime, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, APIKeyHeader
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.auth.jwt_handler import jwt_handler
from app.auth.security import verify_api_key
from app.core.logging import setup_logging
from app.core.redis_client import get_redis_client

logger = setup_logging()

# OAuth2 scheme for JWT bearer tokens
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/v1/auth/login",
    auto_error=False  # Don't auto-raise 401, let us handle it
)

# API Key header scheme
api_key_header = APIKeyHeader(
    name="X-API-Key",
    auto_error=False
)


async def get_current_user(
    token: Annotated[Optional[str], Depends(oauth2_scheme)],
    api_key: Annotated[Optional[str], Depends(api_key_header)],
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Get current user from JWT token or API key
    
    Supports both authentication methods:
    1. JWT Bearer token in Authorization header
    2. API key in X-API-Key header
    
    Args:
        token: JWT token from Authorization header
        api_key: API key from X-API-Key header
        db: Database session
        
    Returns:
        Authenticated user
        
    Raises:
        HTTPException: If authentication fails
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    user = None
    
    # Try JWT authentication first
    if token:
        payload = jwt_handler.verify_token(token, token_type="access")
        if not payload:
            raise credentials_exception
        
        user_id = payload.get("sub")
        if not user_id:
            raise credentials_exception
        
        # Get user from database
        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        
    # Try API key authentication if no JWT
    elif api_key:
        # Find user by API key
        result = await db.execute(
            select(User).where(User.api_key == api_key)
        )
        user = result.scalar_one_or_none()
        
        if user:
            # Log API key usage
            logger.info(f"API key authentication for user: {user.email}")
    
    if not user:
        raise credentials_exception
    
    return user


async def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)]
) -> User:
    """
    Get current active user
    
    Args:
        current_user: User from authentication
        
    Returns:
        Active user
        
    Raises:
        HTTPException: If user is inactive
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user


async def require_admin(
    current_user: Annotated[User, Depends(get_current_active_user)]
) -> User:
    """
    Require admin privileges
    
    Args:
        current_user: Active user
        
    Returns:
        Admin user
        
    Raises:
        HTTPException: If user is not admin
    """
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return current_user


async def get_optional_user(
    token: Annotated[Optional[str], Depends(oauth2_scheme)],
    api_key: Annotated[Optional[str], Depends(api_key_header)],
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """
    Get optional current user (for endpoints that work with or without auth)
    
    Args:
        token: Optional JWT token
        api_key: Optional API key
        db: Database session
        
    Returns:
        User if authenticated, None otherwise
    """
    try:
        if token or api_key:
            return await get_current_user(token, api_key, db)
    except HTTPException:
        pass
    
    return None


class RateLimitDependency:
    """
    Rate limiting dependency for authenticated users
    """
    
    def __init__(self, requests: int = 100, window: int = 60):
        """
        Initialize rate limiter
        
        Args:
            requests: Number of requests allowed
            window: Time window in seconds
        """
        self.requests = requests
        self.window = window
    
    async def __call__(
        self,
        user: User = Depends(get_current_active_user),
        redis = Depends(get_redis_client)
    ):
        """
        Check rate limit for user
        
        Args:
            user: Authenticated user
            redis: Redis client
            
        Raises:
            HTTPException: If rate limit exceeded
        """
        if not redis:
            # Skip rate limiting if Redis not available
            return
        
        key = f"rate_limit:user:{user.id}"
        
        try:
            # Increment counter
            count = await redis.incr(key)
            
            # Set expiry on first request
            if count == 1:
                await redis.expire(key, self.window)
            
            # Check limit
            if count > self.requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Rate limit exceeded. Max {self.requests} requests per {self.window} seconds."
                )
        except Exception as e:
            if isinstance(e, HTTPException):
                raise
            logger.error(f"Rate limiting error: {str(e)}")
            # Don't block on rate limit errors


# Pre-configured rate limiters
rate_limit_standard = RateLimitDependency(requests=100, window=60)
rate_limit_strict = RateLimitDependency(requests=10, window=60)
rate_limit_lenient = RateLimitDependency(requests=1000, window=60)


class RBACDependency:
    """
    Role-Based Access Control dependency
    """
    
    def __init__(self, required_roles: list[str] = None, required_permissions: list[str] = None):
        """
        Initialize RBAC checker
        
        Args:
            required_roles: List of required roles (user must have at least one)
            required_permissions: List of required permissions (user must have all)
        """
        self.required_roles = required_roles or []
        self.required_permissions = required_permissions or []
    
    async def __call__(
        self,
        token: Annotated[str, Depends(oauth2_scheme)],
        db: AsyncSession = Depends(get_db)
    ) -> User:
        """
        Check user roles and permissions
        
        Args:
            token: JWT token
            db: Database session
            
        Returns:
            Authorized user
            
        Raises:
            HTTPException: If authorization fails
        """
        # Decode token to get roles and permissions
        payload = jwt_handler.verify_token(token, token_type="access")
        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
        
        user_roles = payload.get("roles", [])
        user_permissions = payload.get("permissions", [])
        
        # Check roles (user must have at least one required role)
        if self.required_roles:
            if not any(role in user_roles for role in self.required_roles):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Required roles: {self.required_roles}"
                )
        
        # Check permissions (user must have all required permissions)
        if self.required_permissions:
            if not all(perm in user_permissions for perm in self.required_permissions):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Required permissions: {self.required_permissions}"
                )
        
        # Get user from database
        user_id = payload.get("sub")
        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return user


# Pre-configured RBAC checkers
require_user_role = RBACDependency(required_roles=["user"])
require_moderator_role = RBACDependency(required_roles=["moderator", "admin"])
require_write_permission = RBACDependency(required_permissions=["write"])
require_delete_permission = RBACDependency(required_permissions=["delete"])