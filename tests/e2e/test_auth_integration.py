"""
End-to-End Integration Tests for Authentication Flow
Tests complete authentication workflow between iOS client and FastAPI backend
"""

import pytest
import asyncio
import json
from typing import Dict, Any, Optional
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
import jwt
from datetime import datetime, timedelta

from app.models import User, Session
from app.core.security import hash_password, create_access_token
from app.core.config import settings


class MockiOSClient:
    """Simulates iOS client authentication requests"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.auth_token: Optional[str] = None
        self.refresh_token: Optional[str] = None
        self.api_key: Optional[str] = None
    
    async def login(self, client: AsyncClient, email: str, password: str) -> Dict[str, Any]:
        """Simulate iOS login request"""
        response = await client.post(
            f"{self.base_url}/api/auth/login",
            json={"email": email, "password": password},
            headers={"User-Agent": "ClaudeCode-iOS/1.0"}
        )
        
        if response.status_code == 200:
            data = response.json()
            self.auth_token = data.get("access_token")
            self.refresh_token = data.get("refresh_token")
            self.api_key = data.get("api_key")
        
        return {
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None,
            "error": response.json() if response.status_code != 200 else None
        }
    
    async def make_authenticated_request(
        self, 
        client: AsyncClient, 
        endpoint: str,
        method: str = "GET",
        data: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """Make authenticated request with automatic token refresh"""
        headers = {
            "User-Agent": "ClaudeCode-iOS/1.0",
            "Authorization": f"Bearer {self.auth_token}" if self.auth_token else ""
        }
        
        # First attempt
        if method == "GET":
            response = await client.get(f"{self.base_url}{endpoint}", headers=headers)
        elif method == "POST":
            response = await client.post(
                f"{self.base_url}{endpoint}", 
                json=data, 
                headers=headers
            )
        
        # Handle token refresh if 401
        if response.status_code == 401 and self.refresh_token:
            refresh_response = await self.refresh_access_token(client)
            if refresh_response["status_code"] == 200:
                # Retry with new token
                headers["Authorization"] = f"Bearer {self.auth_token}"
                if method == "GET":
                    response = await client.get(f"{self.base_url}{endpoint}", headers=headers)
                elif method == "POST":
                    response = await client.post(
                        f"{self.base_url}{endpoint}", 
                        json=data, 
                        headers=headers
                    )
        
        return {
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None,
            "error": response.json() if response.status_code != 200 else None
        }
    
    async def refresh_access_token(self, client: AsyncClient) -> Dict[str, Any]:
        """Refresh access token using refresh token"""
        response = await client.post(
            f"{self.base_url}/api/auth/refresh",
            headers={
                "User-Agent": "ClaudeCode-iOS/1.0",
                "Authorization": f"Bearer {self.refresh_token}"
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            self.auth_token = data.get("access_token")
            self.refresh_token = data.get("refresh_token")
        
        return {
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None
        }
    
    async def logout(self, client: AsyncClient) -> Dict[str, Any]:
        """Logout and invalidate session"""
        response = await client.post(
            f"{self.base_url}/api/auth/logout",
            headers={
                "User-Agent": "ClaudeCode-iOS/1.0",
                "Authorization": f"Bearer {self.auth_token}"
            }
        )
        
        if response.status_code == 200:
            self.auth_token = None
            self.refresh_token = None
        
        return {"status_code": response.status_code}
    
    async def validate_api_key(self, client: AsyncClient) -> Dict[str, Any]:
        """Validate API key"""
        response = await client.get(
            f"{self.base_url}/api/auth/validate",
            headers={
                "User-Agent": "ClaudeCode-iOS/1.0",
                "X-API-Key": self.api_key if self.api_key else ""
            }
        )
        
        return {
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None
        }


@pytest.mark.asyncio
class TestE2EAuthenticationFlow:
    """End-to-end authentication flow tests"""
    
    async def test_complete_login_flow(self, client: AsyncClient, db_session: AsyncSession):
        """Test complete login flow from iOS client to backend"""
        # Setup: Create test user
        test_email = "e2e.test@example.com"
        test_password = "SecureE2EPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(test_password),
            api_key="e2e-api-key-12345"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Initialize iOS client simulator
        ios_client = MockiOSClient(base_url="")
        
        # Step 1: Login from iOS
        login_result = await ios_client.login(client, test_email, test_password)
        
        # Verify login success
        assert login_result["status_code"] == 200
        assert login_result["data"]["access_token"] is not None
        assert login_result["data"]["refresh_token"] is not None
        assert login_result["data"]["user"]["email"] == test_email
        assert ios_client.auth_token is not None
        
        # Step 2: Verify session created in database
        session = await db_session.query(Session).filter_by(
            user_id=user.id,
            token=ios_client.auth_token
        ).first()
        assert session is not None
        assert session.is_active == True
        
        # Step 3: Make authenticated request
        auth_result = await ios_client.make_authenticated_request(
            client, 
            "/api/user/profile"
        )
        assert auth_result["status_code"] == 200
        
        # Step 4: Verify API key validation
        api_result = await ios_client.validate_api_key(client)
        assert api_result["status_code"] == 200
        assert api_result["data"]["valid"] == True
        
        # Step 5: Logout
        logout_result = await ios_client.logout(client)
        assert logout_result["status_code"] == 200
        
        # Step 6: Verify session deactivated
        await db_session.refresh(session)
        assert session.is_active == False
        
        # Step 7: Verify authenticated request fails after logout
        post_logout_result = await ios_client.make_authenticated_request(
            client,
            "/api/user/profile"
        )
        assert post_logout_result["status_code"] == 401
    
    async def test_token_refresh_flow(self, client: AsyncClient, db_session: AsyncSession):
        """Test automatic token refresh flow"""
        # Setup: Create user and login
        test_email = "refresh.test@example.com"
        test_password = "RefreshPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(test_password),
            api_key="refresh-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        ios_client = MockiOSClient(base_url="")
        await ios_client.login(client, test_email, test_password)
        
        # Store original tokens
        original_access = ios_client.auth_token
        original_refresh = ios_client.refresh_token
        
        # Create expired access token to force refresh
        expired_token = create_access_token(
            data={"sub": str(user.id)},
            expires_delta=timedelta(seconds=-1)
        )
        ios_client.auth_token = expired_token
        
        # Make request that should trigger refresh
        result = await ios_client.make_authenticated_request(
            client,
            "/api/user/profile"
        )
        
        # Verify request succeeded after refresh
        assert result["status_code"] == 200
        assert ios_client.auth_token != expired_token
        assert ios_client.auth_token != original_access
        assert ios_client.refresh_token != original_refresh
    
    async def test_concurrent_login_sessions(self, client: AsyncClient, db_session: AsyncSession):
        """Test multiple concurrent login sessions from different iOS devices"""
        # Setup: Create test user
        test_email = "concurrent.test@example.com"
        test_password = "ConcurrentPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(test_password),
            api_key="concurrent-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Simulate 3 iOS devices logging in concurrently
        ios_clients = [MockiOSClient(base_url="") for _ in range(3)]
        
        # Concurrent login
        login_tasks = [
            ios_client.login(client, test_email, test_password)
            for ios_client in ios_clients
        ]
        login_results = await asyncio.gather(*login_tasks)
        
        # Verify all logins succeeded
        for result in login_results:
            assert result["status_code"] == 200
            assert result["data"]["access_token"] is not None
        
        # Verify all tokens are unique
        tokens = [ios_client.auth_token for ios_client in ios_clients]
        assert len(set(tokens)) == 3  # All tokens should be unique
        
        # Verify all sessions exist in database
        sessions = await db_session.query(Session).filter_by(user_id=user.id).all()
        assert len(sessions) == 3
        assert all(session.is_active for session in sessions)
        
        # Each device can make authenticated requests
        request_tasks = [
            ios_client.make_authenticated_request(client, "/api/user/profile")
            for ios_client in ios_clients
        ]
        request_results = await asyncio.gather(*request_tasks)
        
        for result in request_results:
            assert result["status_code"] == 200
        
        # Logout from one device shouldn't affect others
        await ios_clients[0].logout(client)
        
        # Other devices can still make requests
        result1 = await ios_clients[1].make_authenticated_request(
            client, 
            "/api/user/profile"
        )
        result2 = await ios_clients[2].make_authenticated_request(
            client,
            "/api/user/profile"
        )
        
        assert result1["status_code"] == 200
        assert result2["status_code"] == 200
        
        # Verify only one session was deactivated
        await db_session.refresh(sessions[0])
        await db_session.refresh(sessions[1])
        await db_session.refresh(sessions[2])
        
        active_sessions = [s for s in sessions if s.is_active]
        assert len(active_sessions) == 2
    
    async def test_invalid_credentials_flow(self, client: AsyncClient, db_session: AsyncSession):
        """Test authentication failure scenarios"""
        # Setup: Create test user
        test_email = "invalid.test@example.com"
        test_password = "ValidPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(test_password),
            api_key="test-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        ios_client = MockiOSClient(base_url="")
        
        # Test 1: Wrong password
        wrong_password_result = await ios_client.login(
            client,
            test_email,
            "WrongPassword123!"
        )
        assert wrong_password_result["status_code"] == 401
        assert ios_client.auth_token is None
        
        # Test 2: Non-existent user
        no_user_result = await ios_client.login(
            client,
            "nonexistent@example.com",
            test_password
        )
        assert no_user_result["status_code"] == 401
        assert ios_client.auth_token is None
        
        # Test 3: Invalid email format
        invalid_email_result = await ios_client.login(
            client,
            "not-an-email",
            test_password
        )
        assert invalid_email_result["status_code"] in [400, 422]
        
        # Test 4: Empty credentials
        empty_result = await ios_client.login(client, "", "")
        assert empty_result["status_code"] in [400, 422]
    
    async def test_api_key_validation_flow(self, client: AsyncClient, db_session: AsyncSession):
        """Test API key validation independent of JWT auth"""
        # Setup: Create user with API key
        test_email = "apikey.test@example.com"
        api_key = "valid-e2e-api-key-98765"
        
        user = User(
            email=test_email,
            password_hash=hash_password("Password123!"),
            api_key=api_key
        )
        db_session.add(user)
        await db_session.commit()
        
        # Test with valid API key (no login required)
        ios_client = MockiOSClient(base_url="")
        ios_client.api_key = api_key
        
        validation_result = await ios_client.validate_api_key(client)
        assert validation_result["status_code"] == 200
        assert validation_result["data"]["valid"] == True
        assert validation_result["data"]["user"]["email"] == test_email
        
        # Test with invalid API key
        ios_client.api_key = "invalid-key"
        invalid_result = await ios_client.validate_api_key(client)
        assert invalid_result["status_code"] == 401
        
        # Test with missing API key
        ios_client.api_key = None
        missing_result = await ios_client.validate_api_key(client)
        assert missing_result["status_code"] == 400
    
    async def test_session_expiration_handling(self, client: AsyncClient, db_session: AsyncSession):
        """Test handling of expired sessions"""
        # Setup: Create user and login
        test_email = "expiry.test@example.com"
        test_password = "ExpiryPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(test_password),
            api_key="expiry-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        ios_client = MockiOSClient(base_url="")
        await ios_client.login(client, test_email, test_password)
        
        # Manually expire the session in database
        session = await db_session.query(Session).filter_by(
            user_id=user.id,
            token=ios_client.auth_token
        ).first()
        
        # Set last_activity to 25 hours ago (assuming 24hr expiry)
        session.last_activity = datetime.utcnow() - timedelta(hours=25)
        await db_session.commit()
        
        # Try to make authenticated request with expired session
        result = await ios_client.make_authenticated_request(
            client,
            "/api/user/profile"
        )
        
        # Should trigger refresh if refresh token is still valid
        # or return 401 if both are expired
        assert result["status_code"] in [200, 401]
        
        if result["status_code"] == 200:
            # Verify new session was created
            new_session = await db_session.query(Session).filter_by(
                user_id=user.id,
                token=ios_client.auth_token
            ).first()
            assert new_session is not None
            assert new_session.id != session.id
    
    async def test_rate_limiting_protection(self, client: AsyncClient, db_session: AsyncSession):
        """Test rate limiting on authentication endpoints"""
        ios_client = MockiOSClient(base_url="")
        
        # Attempt rapid login attempts
        login_attempts = []
        for i in range(25):  # Try 25 rapid attempts
            result = await ios_client.login(
                client,
                f"ratelimit{i}@example.com",
                "Password123!"
            )
            login_attempts.append(result["status_code"])
        
        # Should hit rate limit at some point
        rate_limited_count = sum(1 for status in login_attempts if status == 429)
        assert rate_limited_count > 0, "Rate limiting should trigger after multiple attempts"
        
        # Verify rate limit response includes retry-after header
        for i in range(25, 30):  # Additional attempts should definitely be rate limited
            result = await ios_client.login(
                client,
                f"ratelimit{i}@example.com",
                "Password123!"
            )
            if result["status_code"] == 429:
                # In a real implementation, check for Retry-After header
                break
    
    async def test_password_reset_flow(self, client: AsyncClient, db_session: AsyncSession):
        """Test password reset request flow"""
        # Setup: Create user
        test_email = "reset.test@example.com"
        old_password = "OldPassword123!"
        
        user = User(
            email=test_email,
            password_hash=hash_password(old_password),
            api_key="reset-api-key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Request password reset
        response = await client.post(
            "/api/auth/reset-password",
            json={"email": test_email}
        )
        
        assert response.status_code == 200
        assert response.json()["message"] == "Password reset email sent"
        
        # In a real implementation, verify:
        # 1. Email was sent (mock email service)
        # 2. Reset token was generated and stored
        # 3. Old password still works until reset is completed
        
        ios_client = MockiOSClient(base_url="")
        login_result = await ios_client.login(client, test_email, old_password)
        assert login_result["status_code"] == 200  # Old password still works