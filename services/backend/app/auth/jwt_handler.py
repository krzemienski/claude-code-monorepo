"""
JWT token handler with RS256 algorithm support
"""

import os
import json
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from pathlib import Path

from jose import JWTError, jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()


class JWTHandler:
    """Handles JWT token generation, validation, and key management"""
    
    def __init__(self):
        self.algorithm = "RS256"
        self.access_token_expire_minutes = 15
        self.refresh_token_expire_days = 7
        self.issuer = "claude-code-backend"
        self.audience = ["claude-code-ios", "claude-code-web"]
        
        # Initialize keys
        self._init_keys()
    
    def _init_keys(self):
        """Initialize RSA keys for JWT signing"""
        key_dir = Path("/workspace/.keys")
        key_dir.mkdir(exist_ok=True, mode=0o700)
        
        private_key_path = key_dir / "jwt_private.pem"
        public_key_path = key_dir / "jwt_public.pem"
        
        if not private_key_path.exists():
            # Generate new RSA key pair
            private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=2048,
                backend=default_backend()
            )
            
            # Save private key
            private_pem = private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            private_key_path.write_bytes(private_pem)
            private_key_path.chmod(0o600)
            
            # Save public key
            public_key = private_key.public_key()
            public_pem = public_key.public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            )
            public_key_path.write_bytes(public_pem)
            public_key_path.chmod(0o644)
            
            logger.info("Generated new RSA key pair for JWT")
        
        # Load keys
        self.private_key = private_key_path.read_text()
        self.public_key = public_key_path.read_text()
    
    def create_access_token(
        self,
        user_id: str,
        email: str,
        roles: list[str] = None,
        permissions: list[str] = None,
        additional_claims: Dict[str, Any] = None
    ) -> str:
        """
        Create an access token for a user
        
        Args:
            user_id: User's unique identifier
            email: User's email address
            roles: List of user roles (e.g., ["user", "admin"])
            permissions: List of specific permissions
            additional_claims: Additional JWT claims
            
        Returns:
            Encoded JWT access token
        """
        expires_delta = timedelta(minutes=self.access_token_expire_minutes)
        expire = datetime.now(timezone.utc) + expires_delta
        
        to_encode = {
            "sub": user_id,
            "email": email,
            "type": "access",
            "iat": datetime.now(timezone.utc),
            "exp": expire,
            "iss": self.issuer,
            "aud": self.audience,
            "roles": roles or ["user"],
            "permissions": permissions or []
        }
        
        if additional_claims:
            to_encode.update(additional_claims)
        
        encoded_jwt = jwt.encode(
            to_encode,
            self.private_key,
            algorithm=self.algorithm
        )
        return encoded_jwt
    
    def create_refresh_token(
        self,
        user_id: str,
        email: str,
        token_family: Optional[str] = None
    ) -> tuple[str, str]:
        """
        Create a refresh token for a user
        
        Args:
            user_id: User's unique identifier
            email: User's email address
            token_family: Token family ID for rotation tracking
            
        Returns:
            Tuple of (refresh_token, token_family_id)
        """
        import uuid
        
        expires_delta = timedelta(days=self.refresh_token_expire_days)
        expire = datetime.now(timezone.utc) + expires_delta
        
        # Generate token family ID if not provided (for refresh token rotation)
        if not token_family:
            token_family = str(uuid.uuid4())
        
        token_id = str(uuid.uuid4())
        
        to_encode = {
            "sub": user_id,
            "email": email,
            "type": "refresh",
            "jti": token_id,  # JWT ID for tracking
            "family": token_family,  # Token family for rotation
            "iat": datetime.now(timezone.utc),
            "exp": expire,
            "iss": self.issuer,
            "aud": self.audience
        }
        
        encoded_jwt = jwt.encode(
            to_encode,
            self.private_key,
            algorithm=self.algorithm
        )
        return encoded_jwt, token_family
    
    def verify_token(
        self,
        token: str,
        token_type: str = "access",
        verify_exp: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Verify and decode a JWT token
        
        Args:
            token: JWT token to verify
            token_type: Expected token type ("access" or "refresh")
            verify_exp: Whether to verify expiration
            
        Returns:
            Decoded token payload if valid, None otherwise
        """
        try:
            payload = jwt.decode(
                token,
                self.public_key,
                algorithms=[self.algorithm],
                audience=self.audience,
                issuer=self.issuer,
                options={"verify_exp": verify_exp}
            )
            
            # Verify token type
            if payload.get("type") != token_type:
                logger.warning(f"Invalid token type: expected {token_type}, got {payload.get('type')}")
                return None
            
            return payload
            
        except JWTError as e:
            logger.warning(f"JWT verification failed: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error during JWT verification: {str(e)}")
            return None
    
    def refresh_access_token(
        self,
        refresh_token: str,
        redis_client=None
    ) -> Optional[tuple[str, str, str]]:
        """
        Generate new access and refresh tokens from a valid refresh token
        
        Args:
            refresh_token: Valid refresh token
            redis_client: Redis client for token family tracking
            
        Returns:
            Tuple of (new_access_token, new_refresh_token, token_family) if valid
        """
        payload = self.verify_token(refresh_token, token_type="refresh")
        if not payload:
            return None
        
        user_id = payload.get("sub")
        email = payload.get("email")
        token_family = payload.get("family")
        token_id = payload.get("jti")
        
        # Check if token has been revoked (requires Redis)
        if redis_client:
            import asyncio
            if asyncio.iscoroutinefunction(redis_client.get):
                # Async Redis client
                revoked = asyncio.run(redis_client.get(f"revoked_token:{token_id}"))
            else:
                # Sync Redis client
                revoked = redis_client.get(f"revoked_token:{token_id}")
            
            if revoked:
                logger.warning(f"Attempted to use revoked refresh token: {token_id}")
                # Revoke entire token family for security
                if redis_client:
                    self._revoke_token_family(redis_client, token_family)
                return None
        
        # Generate new tokens
        new_access_token = self.create_access_token(user_id, email)
        new_refresh_token, _ = self.create_refresh_token(user_id, email, token_family)
        
        # Mark old refresh token as used (if Redis available)
        if redis_client:
            self._mark_token_used(redis_client, token_id)
        
        return new_access_token, new_refresh_token, token_family
    
    def _revoke_token_family(self, redis_client, token_family: str):
        """Revoke an entire token family (for refresh token rotation security)"""
        try:
            import asyncio
            key = f"revoked_family:{token_family}"
            expire_time = self.refresh_token_expire_days * 24 * 3600
            
            if asyncio.iscoroutinefunction(redis_client.setex):
                asyncio.run(redis_client.setex(key, expire_time, "1"))
            else:
                redis_client.setex(key, expire_time, "1")
            
            logger.info(f"Revoked token family: {token_family}")
        except Exception as e:
            logger.error(f"Failed to revoke token family: {str(e)}")
    
    def _mark_token_used(self, redis_client, token_id: str):
        """Mark a refresh token as used"""
        try:
            import asyncio
            key = f"used_token:{token_id}"
            expire_time = self.refresh_token_expire_days * 24 * 3600
            
            if asyncio.iscoroutinefunction(redis_client.setex):
                asyncio.run(redis_client.setex(key, expire_time, "1"))
            else:
                redis_client.setex(key, expire_time, "1")
            
        except Exception as e:
            logger.error(f"Failed to mark token as used: {str(e)}")
    
    def get_public_key(self) -> str:
        """Get the public key for token verification (useful for microservices)"""
        return self.public_key
    
    def decode_token_unsafe(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Decode token without verification (USE WITH CAUTION)
        Useful for debugging or getting claims from expired tokens
        """
        try:
            return jwt.decode(
                token,
                options={"verify_signature": False, "verify_exp": False}
            )
        except Exception as e:
            logger.error(f"Failed to decode token: {str(e)}")
            return None


# Global JWT handler instance
jwt_handler = JWTHandler()