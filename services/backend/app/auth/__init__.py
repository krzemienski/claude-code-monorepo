"""
Authentication module for Claude Code Backend
"""

from .jwt_handler import JWTHandler, jwt_handler
from .dependencies import (
    get_current_user,
    get_current_active_user,
    require_admin,
    get_optional_user
)
from .security import (
    verify_password,
    get_password_hash,
    create_api_key,
    verify_api_key
)

__all__ = [
    "JWTHandler",
    "jwt_handler",
    "get_current_user",
    "get_current_active_user",
    "require_admin",
    "get_optional_user",
    "verify_password",
    "get_password_hash",
    "create_api_key",
    "verify_api_key"
]