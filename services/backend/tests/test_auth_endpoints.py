"""
Test suite for authentication API endpoints.
Covers login, logout, token refresh, and API key validation.
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timedelta
import jwt
from unittest.mock import patch, AsyncMock

from app.main import app
from app.models import User, Session
from app.core.security import create_access_token, hash_password, verify_password
from app.core.config import settings


@pytest.mark.asyncio
class TestAuthEndpoints:
    """Test authentication-related API endpoints."""
    
    async def test_login_success(self, client: AsyncClient, db_session: AsyncSession):
        """Test successful login with valid credentials."""
        # Create test user
        password = "SecurePassword123!"
        hashed = hash_password(password)
        user = User(
            email="test@example.com",
            password_hash=hashed,
            api_key="test-api-key-12345"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Attempt login
        response = await client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": password}
        )
        
        # Verify response
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == "test@example.com"
        
        # Verify token is valid
        decoded = jwt.decode(
            data["access_token"],
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        assert decoded["sub"] == str(user.id)
    
    async def test_login_invalid_email(self, client: AsyncClient):
        """Test login with non-existent email."""
        response = await client.post(
            "/api/auth/login",
            json={"email": "nonexistent@example.com", "password": "password"}
        )
        
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid credentials"
    
    async def test_login_invalid_password(self, client: AsyncClient, db_session: AsyncSession):
        """Test login with incorrect password."""
        # Create test user
        user = User(
            email="test@example.com",
            password_hash=hash_password("correct_password"),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Attempt login with wrong password
        response = await client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": "wrong_password"}
        )
        
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid credentials"
    
    async def test_login_creates_session(self, client: AsyncClient, db_session: AsyncSession):
        """Test that login creates a new session record."""
        # Create test user
        password = "TestPassword123!"
        user = User(
            email="test@example.com",
            password_hash=hash_password(password),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Login
        response = await client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": password}
        )
        
        assert response.status_code == 200
        
        # Check session was created
        session = await db_session.query(Session).filter_by(user_id=user.id).first()
        assert session is not None
        assert session.is_active == True
        assert session.token == response.json()["access_token"]
    
    async def test_refresh_token_success(self, client: AsyncClient, db_session: AsyncSession):
        """Test token refresh with valid refresh token."""
        # Create user and session
        user = User(
            email="test@example.com",
            password_hash=hash_password("password"),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Create refresh token
        refresh_token = create_access_token(
            data={"sub": str(user.id), "type": "refresh"},
            expires_delta=timedelta(days=7)
        )
        
        # Request new token
        response = await client.post(
            "/api/auth/refresh",
            headers={"Authorization": f"Bearer {refresh_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        
        # Verify new token is different
        assert data["access_token"] != refresh_token
        assert data["refresh_token"] != refresh_token
    
    async def test_refresh_token_expired(self, client: AsyncClient):
        """Test token refresh with expired refresh token."""
        # Create expired token
        expired_token = create_access_token(
            data={"sub": "user-123", "type": "refresh"},
            expires_delta=timedelta(seconds=-1)
        )
        
        response = await client.post(
            "/api/auth/refresh",
            headers={"Authorization": f"Bearer {expired_token}"}
        )
        
        assert response.status_code == 401
        assert "Token has expired" in response.json()["detail"]
    
    async def test_refresh_token_invalid_type(self, client: AsyncClient):
        """Test token refresh with access token instead of refresh token."""
        # Create access token (not refresh)
        access_token = create_access_token(
            data={"sub": "user-123", "type": "access"},
            expires_delta=timedelta(minutes=30)
        )
        
        response = await client.post(
            "/api/auth/refresh",
            headers={"Authorization": f"Bearer {access_token}"}
        )
        
        assert response.status_code == 401
        assert "Invalid token type" in response.json()["detail"]
    
    async def test_logout_success(self, client: AsyncClient, db_session: AsyncSession):
        """Test successful logout."""
        # Create user and active session
        user = User(
            email="test@example.com",
            password_hash=hash_password("password"),
            api_key="test-api-key"
        )
        db_session.add(user)
        
        token = create_access_token(data={"sub": str(user.id)})
        session = Session(
            user_id=user.id,
            token=token,
            is_active=True
        )
        db_session.add(session)
        await db_session.commit()
        
        # Logout
        response = await client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        assert response.json()["message"] == "Successfully logged out"
        
        # Verify session is deactivated
        await db_session.refresh(session)
        assert session.is_active == False
    
    async def test_logout_without_token(self, client: AsyncClient):
        """Test logout without authentication token."""
        response = await client.post("/api/auth/logout")
        
        assert response.status_code == 401
        assert "Not authenticated" in response.json()["detail"]
    
    async def test_validate_api_key_success(self, client: AsyncClient, db_session: AsyncSession):
        """Test API key validation with valid key."""
        # Create user with API key
        api_key = "valid-api-key-12345"
        user = User(
            email="test@example.com",
            password_hash=hash_password("password"),
            api_key=api_key
        )
        db_session.add(user)
        await db_session.commit()
        
        # Validate API key
        response = await client.get(
            "/api/auth/validate",
            headers={"X-API-Key": api_key}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] == True
        assert data["user"]["email"] == "test@example.com"
    
    async def test_validate_api_key_invalid(self, client: AsyncClient):
        """Test API key validation with invalid key."""
        response = await client.get(
            "/api/auth/validate",
            headers={"X-API-Key": "invalid-key"}
        )
        
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid API key"
    
    async def test_validate_api_key_missing(self, client: AsyncClient):
        """Test API key validation without key."""
        response = await client.get("/api/auth/validate")
        
        assert response.status_code == 400
        assert response.json()["detail"] == "API key required"
    
    @pytest.mark.parametrize("invalid_email", [
        "notanemail",
        "@example.com",
        "user@",
        "user@.com",
        "",
        None
    ])
    async def test_login_invalid_email_format(self, client: AsyncClient, invalid_email):
        """Test login with various invalid email formats."""
        response = await client.post(
            "/api/auth/login",
            json={"email": invalid_email, "password": "password"}
        )
        
        assert response.status_code in [400, 422]
    
    @pytest.mark.parametrize("weak_password", [
        "short",
        "12345678",
        "password",
        "",
        None
    ])
    async def test_register_weak_password(self, client: AsyncClient, weak_password):
        """Test registration with weak passwords."""
        response = await client.post(
            "/api/auth/register",
            json={"email": "test@example.com", "password": weak_password}
        )
        
        assert response.status_code in [400, 422]
        if response.status_code == 400:
            assert "Password requirements" in response.json()["detail"]
    
    async def test_concurrent_logins(self, client: AsyncClient, db_session: AsyncSession):
        """Test handling of concurrent login attempts."""
        # Create test user
        password = "TestPassword123!"
        user = User(
            email="test@example.com",
            password_hash=hash_password(password),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Attempt multiple concurrent logins
        import asyncio
        
        async def login():
            return await client.post(
                "/api/auth/login",
                json={"email": "test@example.com", "password": password}
            )
        
        responses = await asyncio.gather(*[login() for _ in range(5)])
        
        # All should succeed
        for response in responses:
            assert response.status_code == 200
            assert "access_token" in response.json()
        
        # Check that multiple sessions were created
        sessions = await db_session.query(Session).filter_by(user_id=user.id).all()
        assert len(sessions) == 5
    
    async def test_rate_limiting(self, client: AsyncClient):
        """Test rate limiting on authentication endpoints."""
        # Attempt many rapid login attempts
        responses = []
        for i in range(20):
            response = await client.post(
                "/api/auth/login",
                json={"email": f"user{i}@example.com", "password": "password"}
            )
            responses.append(response)
        
        # Should hit rate limit
        rate_limited = any(r.status_code == 429 for r in responses[-10:])
        assert rate_limited, "Rate limiting should trigger after multiple attempts"
    
    @patch('app.core.email.send_email', new_callable=AsyncMock)
    async def test_password_reset_request(self, mock_send_email, client: AsyncClient, db_session: AsyncSession):
        """Test password reset request flow."""
        # Create user
        user = User(
            email="test@example.com",
            password_hash=hash_password("old_password"),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Request password reset
        response = await client.post(
            "/api/auth/reset-password",
            json={"email": "test@example.com"}
        )
        
        assert response.status_code == 200
        assert response.json()["message"] == "Password reset email sent"
        
        # Verify email was sent
        mock_send_email.assert_called_once()
        call_args = mock_send_email.call_args
        assert call_args[0][0] == "test@example.com"
        assert "reset" in call_args[0][1].lower()
    
    async def test_token_introspection(self, client: AsyncClient, db_session: AsyncSession):
        """Test token introspection endpoint."""
        # Create user and token
        user = User(
            email="test@example.com",
            password_hash=hash_password("password"),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        token = create_access_token(data={"sub": str(user.id)})
        
        # Introspect token
        response = await client.post(
            "/api/auth/introspect",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["active"] == True
        assert data["sub"] == str(user.id)
        assert "exp" in data
        assert "iat" in data