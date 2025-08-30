"""
Comprehensive tests for JWT authentication system
"""

import pytest
import asyncio
from datetime import datetime, timedelta, timezone
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.auth import jwt_handler, get_password_hash, verify_password
from app.auth.security import is_password_strong, create_api_key, validate_email
from app.models.user import User
from app.db.session import get_db


@pytest.fixture
async def async_client():
    """Create async test client"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.fixture
async def test_user_data():
    """Test user data"""
    return {
        "email": "test@example.com",
        "password": "SecureP@ssw0rd123",
        "username": "testuser"
    }


@pytest.fixture
async def authenticated_client(async_client, test_user_data):
    """Create authenticated test client"""
    # Register user
    response = await async_client.post("/v1/auth/register", json=test_user_data)
    assert response.status_code == 201
    
    data = response.json()
    token = data["access_token"]
    
    # Set authorization header
    async_client.headers["Authorization"] = f"Bearer {token}"
    
    return async_client, data


class TestJWTHandler:
    """Test JWT handler functionality"""
    
    def test_create_access_token(self):
        """Test access token creation"""
        token = jwt_handler.create_access_token(
            user_id="test-user-id",
            email="test@example.com",
            roles=["user", "admin"],
            permissions=["read", "write"]
        )
        
        assert token is not None
        assert isinstance(token, str)
        
        # Verify token
        payload = jwt_handler.verify_token(token, token_type="access")
        assert payload is not None
        assert payload["sub"] == "test-user-id"
        assert payload["email"] == "test@example.com"
        assert "user" in payload["roles"]
        assert "admin" in payload["roles"]
        assert "read" in payload["permissions"]
        assert "write" in payload["permissions"]
    
    def test_create_refresh_token(self):
        """Test refresh token creation"""
        token, family = jwt_handler.create_refresh_token(
            user_id="test-user-id",
            email="test@example.com"
        )
        
        assert token is not None
        assert family is not None
        assert isinstance(token, str)
        assert isinstance(family, str)
        
        # Verify token
        payload = jwt_handler.verify_token(token, token_type="refresh")
        assert payload is not None
        assert payload["sub"] == "test-user-id"
        assert payload["email"] == "test@example.com"
        assert payload["family"] == family
    
    def test_verify_expired_token(self):
        """Test verification of expired token"""
        # Create token with past expiration
        token = jwt_handler.create_access_token(
            user_id="test-user-id",
            email="test@example.com"
        )
        
        # Manually create expired token
        import jose.jwt as jwt
        from datetime import datetime, timezone, timedelta
        
        expired_payload = {
            "sub": "test-user-id",
            "exp": datetime.now(timezone.utc) - timedelta(hours=1),
            "iat": datetime.now(timezone.utc) - timedelta(hours=2),
            "type": "access",
            "iss": jwt_handler.issuer,
            "aud": jwt_handler.audience
        }
        
        expired_token = jwt.encode(
            expired_payload,
            jwt_handler.private_key,
            algorithm=jwt_handler.algorithm
        )
        
        # Verify expired token fails
        payload = jwt_handler.verify_token(expired_token)
        assert payload is None
    
    def test_invalid_token_type(self):
        """Test token with wrong type"""
        refresh_token, _ = jwt_handler.create_refresh_token(
            user_id="test-user-id",
            email="test@example.com"
        )
        
        # Try to verify refresh token as access token
        payload = jwt_handler.verify_token(refresh_token, token_type="access")
        assert payload is None
    
    def test_decode_token_unsafe(self):
        """Test unsafe token decoding"""
        token = jwt_handler.create_access_token(
            user_id="test-user-id",
            email="test@example.com"
        )
        
        payload = jwt_handler.decode_token_unsafe(token)
        assert payload is not None
        assert payload["sub"] == "test-user-id"
        assert payload["email"] == "test@example.com"


class TestSecurity:
    """Test security utilities"""
    
    def test_password_hashing(self):
        """Test password hashing and verification"""
        password = "SecureP@ssw0rd123"
        
        # Hash password
        hashed = get_password_hash(password)
        assert hashed != password
        assert len(hashed) > 50  # Bcrypt hash length
        
        # Verify correct password
        assert verify_password(password, hashed) is True
        
        # Verify incorrect password
        assert verify_password("WrongPassword", hashed) is False
    
    def test_password_strength_validation(self):
        """Test password strength checker"""
        # Weak passwords
        weak_passwords = [
            ("short", False),  # Too short
            ("no-uppercase-123", False),  # No uppercase
            ("NO-LOWERCASE-123", False),  # No lowercase
            ("NoNumbers!", False),  # No numbers
            ("NoSpecialChars123", False),  # No special chars
            ("password123!", False),  # Common pattern
        ]
        
        for password, expected in weak_passwords:
            is_strong, issues = is_password_strong(password)
            assert is_strong == expected
            if not expected:
                assert len(issues) > 0
        
        # Strong password
        is_strong, issues = is_password_strong("SecureP@ssw0rd123")
        assert is_strong is True
        assert len(issues) == 0
    
    def test_api_key_generation(self):
        """Test API key generation"""
        api_key = create_api_key(prefix="test", length=32)
        
        assert api_key.startswith("test_")
        assert len(api_key) == 37  # prefix(4) + underscore(1) + random(32)
        
        # Test uniqueness
        api_key2 = create_api_key(prefix="test", length=32)
        assert api_key != api_key2
    
    def test_email_validation(self):
        """Test email validation"""
        valid_emails = [
            "user@example.com",
            "test.user@example.co.uk",
            "user+tag@example.org",
            "123@example.com"
        ]
        
        for email in valid_emails:
            assert validate_email(email) is True
        
        invalid_emails = [
            "not-an-email",
            "@example.com",
            "user@",
            "user @example.com",
            "user@.com"
        ]
        
        for email in invalid_emails:
            assert validate_email(email) is False


@pytest.mark.asyncio
class TestAuthEndpoints:
    """Test authentication API endpoints"""
    
    async def test_register_success(self, async_client, test_user_data):
        """Test successful user registration"""
        response = await async_client.post("/v1/auth/register", json=test_user_data)
        
        assert response.status_code == 201
        data = response.json()
        
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] == 900  # 15 minutes
        
        assert data["user"]["email"] == test_user_data["email"]
        assert data["user"]["username"] == test_user_data["username"]
        assert data["user"]["roles"] == ["user"]
        assert "api_key" in data["user"]  # API key returned on registration
    
    async def test_register_duplicate_email(self, async_client, test_user_data):
        """Test registration with duplicate email"""
        # First registration
        response = await async_client.post("/v1/auth/register", json=test_user_data)
        assert response.status_code == 201
        
        # Duplicate registration
        response = await async_client.post("/v1/auth/register", json=test_user_data)
        assert response.status_code == 409
        assert "already exists" in response.json()["detail"]
    
    async def test_register_weak_password(self, async_client):
        """Test registration with weak password"""
        data = {
            "email": "weak@example.com",
            "password": "weak",
            "username": "weakuser"
        }
        
        response = await async_client.post("/v1/auth/register", json=data)
        assert response.status_code == 422
        assert "Weak password" in response.json()["detail"]["message"]
    
    async def test_login_success(self, async_client, test_user_data):
        """Test successful login"""
        # Register first
        await async_client.post("/v1/auth/register", json=test_user_data)
        
        # Login with email
        response = await async_client.post(
            "/v1/auth/login",
            data={
                "username": test_user_data["email"],
                "password": test_user_data["password"]
            }
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == test_user_data["email"]
    
    async def test_login_with_username(self, async_client, test_user_data):
        """Test login with username instead of email"""
        # Register first
        await async_client.post("/v1/auth/register", json=test_user_data)
        
        # Login with username
        response = await async_client.post(
            "/v1/auth/login",
            data={
                "username": test_user_data["username"],
                "password": test_user_data["password"]
            }
        )
        
        assert response.status_code == 200
    
    async def test_login_invalid_credentials(self, async_client, test_user_data):
        """Test login with invalid credentials"""
        # Register first
        await async_client.post("/v1/auth/register", json=test_user_data)
        
        # Wrong password
        response = await async_client.post(
            "/v1/auth/login",
            data={
                "username": test_user_data["email"],
                "password": "WrongPassword"
            }
        )
        
        assert response.status_code == 401
        assert "Incorrect username or password" in response.json()["detail"]
    
    async def test_refresh_token(self, async_client, test_user_data):
        """Test token refresh"""
        # Register and get tokens
        response = await async_client.post("/v1/auth/register", json=test_user_data)
        data = response.json()
        refresh_token = data["refresh_token"]
        
        # Refresh tokens
        response = await async_client.post(
            "/v1/auth/refresh",
            json={"refresh_token": refresh_token}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
    
    async def test_get_current_user(self, authenticated_client):
        """Test getting current user info"""
        client, auth_data = authenticated_client
        
        response = await client.get("/v1/auth/me")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["email"] == "test@example.com"
        assert data["username"] == "testuser"
        assert data["roles"] == ["user"]
    
    async def test_change_password(self, authenticated_client):
        """Test password change"""
        client, auth_data = authenticated_client
        
        response = await client.post(
            "/v1/auth/change-password",
            json={
                "current_password": "SecureP@ssw0rd123",
                "new_password": "NewSecureP@ssw0rd456"
            }
        )
        
        assert response.status_code == 200
        assert "successfully changed" in response.json()["message"]
    
    async def test_logout(self, authenticated_client):
        """Test logout"""
        client, auth_data = authenticated_client
        
        response = await client.post(
            "/v1/auth/logout",
            json={"refresh_token": auth_data["refresh_token"]}
        )
        
        assert response.status_code == 200
        assert "Successfully logged out" in response.json()["message"]
    
    async def test_verify_token(self, authenticated_client):
        """Test token verification endpoint"""
        client, _ = authenticated_client
        
        response = await client.post("/v1/auth/verify-token")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["valid"] is True
        assert "user_id" in data
        assert data["email"] == "test@example.com"
    
    async def test_unauthorized_access(self, async_client):
        """Test accessing protected endpoint without auth"""
        response = await client.get("/v1/auth/me")
        
        assert response.status_code == 401


@pytest.mark.asyncio
class TestRateLimiting:
    """Test rate limiting on auth endpoints"""
    
    async def test_login_rate_limit(self, async_client):
        """Test rate limiting on login endpoint"""
        # Note: This would require Redis to be running
        # and configured for the test environment
        pass


@pytest.mark.asyncio
class TestAccountSecurity:
    """Test account security features"""
    
    async def test_account_lockout(self, async_client, test_user_data):
        """Test account lockout after failed attempts"""
        # Register user
        await async_client.post("/v1/auth/register", json=test_user_data)
        
        # Multiple failed login attempts
        for _ in range(5):
            response = await async_client.post(
                "/v1/auth/login",
                data={
                    "username": test_user_data["email"],
                    "password": "WrongPassword"
                }
            )
            
            if response.status_code == 423:
                break
        
        # Account should be locked
        assert response.status_code == 423
        assert "Account locked" in response.json()["detail"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])