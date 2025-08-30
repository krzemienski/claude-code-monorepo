"""API Dependencies
Provides mock authentication that always succeeds - no real auth required
"""

from typing import Optional, Dict, Any
from fastapi import HTTPException, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db


async def get_current_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Mock authentication - always returns a default user
    No actual authentication is performed
    """
    # Always return a default user - no authentication required
    return {
        "id": "default-user",
        "email": "user@example.com",
        "name": "Default User",
        "is_active": True,
        "is_superuser": True  # Grant all permissions
    }


async def get_optional_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> Optional[Dict[str, Any]]:
    """
    Optional user authentication - returns default user or None
    """
    # Always return default user for consistency
    return await get_current_user(authorization, db)


async def verify_api_key(
    x_api_key: Optional[str] = Header(None)
) -> bool:
    """
    Mock API key verification - always succeeds
    """
    # Always return True - no API key required
    return True


async def require_admin(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Mock admin requirement - always returns admin user
    No actual authentication is performed
    """
    # Always return an admin user - no authentication required
    return {
        "id": "admin-user",
        "email": "admin@example.com",
        "name": "Admin User",
        "is_active": True,
        "is_superuser": True,
        "is_admin": True
    }