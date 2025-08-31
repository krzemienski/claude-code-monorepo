"""
Security utilities for password hashing and API key management
"""

import secrets
import string
from datetime import datetime, timedelta
from typing import Optional

from passlib.context import CryptContext
import bcrypt

from app.core.logging import setup_logging

logger = setup_logging()

# Password hashing context
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12  # Configurable work factor
)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain password against a hashed password
    
    Args:
        plain_password: Plain text password
        hashed_password: Bcrypt hashed password
        
    Returns:
        True if password matches, False otherwise
    """
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception as e:
        logger.error(f"Password verification error: {str(e)}")
        return False


def get_password_hash(password: str) -> str:
    """
    Hash a password using bcrypt
    
    Args:
        password: Plain text password
        
    Returns:
        Bcrypt hashed password
    """
    return pwd_context.hash(password)


def create_api_key(prefix: str = "ck", length: int = 32) -> str:
    """
    Generate a secure API key
    
    Args:
        prefix: Prefix for the API key (e.g., "ck" for Claude Code)
        length: Length of the random part
        
    Returns:
        API key in format: prefix_randomstring
    """
    # Use URL-safe characters for the API key
    alphabet = string.ascii_letters + string.digits + "-_"
    random_part = ''.join(secrets.choice(alphabet) for _ in range(length))
    return f"{prefix}_{random_part}"


def verify_api_key(api_key: str, stored_hash: str) -> bool:
    """
    Verify an API key against its stored hash
    
    Args:
        api_key: Plain API key
        stored_hash: Hashed API key from database
        
    Returns:
        True if API key is valid
    """
    try:
        # For API keys, we can use the same bcrypt verification
        return pwd_context.verify(api_key, stored_hash)
    except Exception as e:
        logger.error(f"API key verification error: {str(e)}")
        return False


def hash_api_key(api_key: str) -> str:
    """
    Hash an API key for storage
    
    Args:
        api_key: Plain API key
        
    Returns:
        Hashed API key
    """
    return pwd_context.hash(api_key)


def generate_secure_token(length: int = 32) -> str:
    """
    Generate a cryptographically secure random token
    
    Args:
        length: Token length
        
    Returns:
        Secure random token
    """
    return secrets.token_urlsafe(length)


def generate_verification_code(length: int = 6) -> str:
    """
    Generate a numeric verification code (for 2FA or email verification)
    
    Args:
        length: Code length
        
    Returns:
        Numeric verification code
    """
    return ''.join(secrets.choice(string.digits) for _ in range(length))


def is_password_strong(password: str) -> tuple[bool, list[str]]:
    """
    Check if a password meets security requirements
    
    Args:
        password: Password to check
        
    Returns:
        Tuple of (is_strong, list_of_issues)
    """
    issues = []
    
    # Minimum length
    if len(password) < 8:
        issues.append("Password must be at least 8 characters long")
    
    # Maximum length (bcrypt limitation)
    if len(password) > 72:
        issues.append("Password must not exceed 72 characters")
    
    # Character requirements
    if not any(c.isupper() for c in password):
        issues.append("Password must contain at least one uppercase letter")
    
    if not any(c.islower() for c in password):
        issues.append("Password must contain at least one lowercase letter")
    
    if not any(c.isdigit() for c in password):
        issues.append("Password must contain at least one number")
    
    special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    if not any(c in special_chars for c in password):
        issues.append("Password must contain at least one special character")
    
    # Common patterns to avoid
    common_patterns = [
        "password", "123456", "qwerty", "admin", "letmein",
        "welcome", "monkey", "dragon", "master", "abc123"
    ]
    
    password_lower = password.lower()
    for pattern in common_patterns:
        if pattern in password_lower:
            issues.append(f"Password contains common pattern: {pattern}")
            break
    
    return len(issues) == 0, issues


def validate_email(email: str) -> bool:
    """
    Basic email validation
    
    Args:
        email: Email address to validate
        
    Returns:
        True if email appears valid
    """
    import re
    
    # Basic email regex pattern
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def sanitize_username(username: str) -> str:
    """
    Sanitize a username for safe storage and display
    
    Args:
        username: Raw username input
        
    Returns:
        Sanitized username
    """
    # Remove leading/trailing whitespace
    username = username.strip()
    
    # Replace multiple spaces with single space
    import re
    username = re.sub(r'\s+', ' ', username)
    
    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', '"', "'", '&', '/', '\\', '\0']
    for char in dangerous_chars:
        username = username.replace(char, '')
    
    # Limit length
    max_length = 100
    if len(username) > max_length:
        username = username[:max_length]
    
    return username