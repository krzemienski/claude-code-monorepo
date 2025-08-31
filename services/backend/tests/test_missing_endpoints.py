"""
Test coverage for new API endpoints
Tests messages, tools, and profile endpoints
"""

import pytest
import json
from datetime import datetime
from typing import Dict, Any

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.models.session import Session, SessionStatus
from app.models.message import Message
from app.models.user import User


@pytest.mark.asyncio
class TestMessageEndpoints:
    """Test session message endpoints"""
    
    async def test_get_session_messages(
        self,
        async_client: AsyncClient,
        test_session: Session,
        test_db: AsyncSession
    ):
        """Test retrieving messages for a session"""
        # Create test messages
        messages = [
            Message(
                id=f"msg-{i}",
                session_id=test_session.id,
                role="user" if i % 2 == 0 else "assistant",
                content=f"Test message {i}",
                token_count=10 + i,
                created_at=datetime.utcnow()
            )
            for i in range(5)
        ]
        
        for msg in messages:
            test_db.add(msg)
        await test_db.commit()
        
        # Get messages
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 5
        assert len(data["messages"]) == 5
        assert data["session_id"] == test_session.id
    
    async def test_get_messages_with_pagination(
        self,
        async_client: AsyncClient,
        test_session: Session,
        test_db: AsyncSession
    ):
        """Test message pagination"""
        # Create 20 test messages
        for i in range(20):
            msg = Message(
                id=f"msg-{i}",
                session_id=test_session.id,
                role="user" if i % 2 == 0 else "assistant",
                content=f"Message {i}",
                token_count=10
            )
            test_db.add(msg)
        await test_db.commit()
        
        # Get first page
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?limit=10&offset=0"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 20
        assert len(data["messages"]) == 10
        assert data["limit"] == 10
        assert data["offset"] == 0
        
        # Get second page
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?limit=10&offset=10"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["messages"]) == 10
        assert data["offset"] == 10
    
    async def test_filter_messages_by_role(
        self,
        async_client: AsyncClient,
        test_session: Session,
        test_db: AsyncSession
    ):
        """Test filtering messages by role"""
        # Create messages with different roles
        roles = ["user", "assistant", "system", "user", "assistant"]
        for i, role in enumerate(roles):
            msg = Message(
                id=f"msg-{i}",
                session_id=test_session.id,
                role=role,
                content=f"Message from {role}",
                token_count=10
            )
            test_db.add(msg)
        await test_db.commit()
        
        # Filter by user role
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?role=user"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert all(msg["role"] == "user" for msg in data["messages"])
        
        # Filter by assistant role
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?role=assistant"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert all(msg["role"] == "assistant" for msg in data["messages"])
    
    async def test_get_messages_nonexistent_session(
        self,
        async_client: AsyncClient
    ):
        """Test getting messages for non-existent session"""
        response = await async_client.get(
            "/v1/sessions/nonexistent-session/messages"
        )
        
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()


@pytest.mark.asyncio
class TestToolEndpoints:
    """Test session tool execution endpoints"""
    
    async def test_get_session_tools_empty(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test getting tools for session with no executions"""
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/tools"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["executions"] == []
        assert data["total"] == 0
        assert data["session_id"] == test_session.id
    
    async def test_record_tool_execution(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test recording a tool execution"""
        tool_data = {
            "id": "exec-1",
            "tool_name": "calculator",
            "tool_type": "native",
            "input_params": {"operation": "add", "a": 5, "b": 3},
            "output": {"result": 8},
            "status": "completed",
            "execution_time_ms": 15,
            "created_at": datetime.utcnow().isoformat(),
            "completed_at": datetime.utcnow().isoformat()
        }
        
        response = await async_client.post(
            f"/v1/sessions/{test_session.id}/tools",
            json=tool_data
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["tool_name"] == "calculator"
        assert data["status"] == "completed"
        
        # Verify it was stored
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/tools"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert len(data["executions"]) == 1
    
    async def test_filter_tools_by_type(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test filtering tool executions by type"""
        # Record different tool types
        tool_types = [
            ("mcp", "context7"),
            ("native", "grep"),
            ("custom", "analyzer"),
            ("mcp", "sequential")
        ]
        
        for i, (tool_type, tool_name) in enumerate(tool_types):
            response = await async_client.post(
                f"/v1/sessions/{test_session.id}/tools",
                json={
                    "id": f"exec-{i}",
                    "tool_name": tool_name,
                    "tool_type": tool_type,
                    "input_params": {},
                    "status": "completed",
                    "created_at": datetime.utcnow().isoformat()
                }
            )
            assert response.status_code == 200
        
        # Filter by MCP tools
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/tools?tool_type=mcp"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert all(e["tool_type"] == "mcp" for e in data["executions"])
    
    async def test_filter_tools_by_status(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test filtering tool executions by status"""
        # Record tools with different statuses
        statuses = ["pending", "running", "completed", "failed", "completed"]
        
        for i, status in enumerate(statuses):
            response = await async_client.post(
                f"/v1/sessions/{test_session.id}/tools",
                json={
                    "id": f"exec-{i}",
                    "tool_name": f"tool-{i}",
                    "tool_type": "native",
                    "input_params": {},
                    "status": status,
                    "created_at": datetime.utcnow().isoformat()
                }
            )
            assert response.status_code == 200
        
        # Filter by completed status
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/tools?status=completed"
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert all(e["status"] == "completed" for e in data["executions"])


@pytest.mark.asyncio
class TestUserProfileEndpoints:
    """Test user profile endpoints"""
    
    async def test_get_user_profile(
        self,
        async_client: AsyncClient,
        test_user: User,
        test_db: AsyncSession
    ):
        """Test getting user profile"""
        # Create some sessions for the user
        for i in range(3):
            session = Session(
                id=f"session-{i}",
                user_id=str(test_user.id),
                project_id="test-project",
                name=f"Session {i}",
                status=SessionStatus.ACTIVE
            )
            test_db.add(session)
        await test_db.commit()
        
        response = await async_client.get(
            "/v1/user/profile",
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == test_user.email
        assert data["session_count"] == 3
        assert "api_key" not in data  # Not included by default
    
    async def test_get_profile_with_api_key(
        self,
        async_client: AsyncClient,
        test_user: User
    ):
        """Test getting profile with API key included"""
        response = await async_client.get(
            "/v1/user/profile?include_api_key=true",
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["api_key"] == test_user.api_key
    
    async def test_update_user_profile(
        self,
        async_client: AsyncClient,
        test_user: User
    ):
        """Test updating user profile"""
        update_data = {
            "username": "new_username",
            "preferences": {
                "theme": "dark",
                "language": "en",
                "notifications": True
            }
        }
        
        response = await async_client.put(
            "/v1/user/profile",
            json=update_data,
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "new_username"
        assert data["preferences"]["theme"] == "dark"
    
    async def test_reset_api_key(
        self,
        async_client: AsyncClient,
        test_user: User
    ):
        """Test resetting API key"""
        old_key = test_user.api_key
        
        response = await async_client.post(
            "/v1/user/profile/reset-api-key",
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "api_key" in data
        assert data["api_key"] != old_key
        assert "message" in data
    
    async def test_delete_user_account(
        self,
        async_client: AsyncClient,
        test_user: User,
        test_db: AsyncSession
    ):
        """Test soft delete of user account"""
        # First attempt without confirmation
        response = await async_client.delete(
            "/v1/user/profile",
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 400
        assert "confirmation" in response.json()["detail"].lower()
        
        # Delete with confirmation
        response = await async_client.delete(
            "/v1/user/profile?confirm=true",
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == test_user.email
        
        # Verify account is deactivated
        await test_db.refresh(test_user)
        assert test_user.is_active is False
        assert test_user.api_key is None
    
    async def test_profile_public_access(
        self,
        async_client: AsyncClient
    ):
        """Test that profile endpoints are now public"""
        # Test public access without auth
        response = await async_client.get("/v1/user/profile")
        assert response.status_code in [401, 403]
        
        response = await async_client.put(
            "/v1/user/profile",
            json={"username": "test"}
        )
        assert response.status_code in [401, 403]
        
        response = await async_client.post("/v1/user/profile/reset-api-key")
        assert response.status_code in [401, 403]


@pytest.mark.asyncio
class TestEdgeCases:
    """Test edge cases and error scenarios"""
    
    async def test_invalid_role_filter(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test invalid role filter"""
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?role=invalid"
        )
        
        assert response.status_code == 400
        assert "invalid role" in response.json()["detail"].lower()
    
    async def test_invalid_tool_type_filter(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test invalid tool type filter"""
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/tools?tool_type=invalid"
        )
        
        assert response.status_code == 400
        assert "invalid tool_type" in response.json()["detail"].lower()
    
    async def test_large_pagination_limit(
        self,
        async_client: AsyncClient,
        test_session: Session
    ):
        """Test pagination with limit exceeding maximum"""
        response = await async_client.get(
            f"/v1/sessions/{test_session.id}/messages?limit=10000"
        )
        
        # Should be capped at maximum (1000)
        assert response.status_code == 200
        data = response.json()
        assert data["limit"] <= 1000
    
    async def test_username_uniqueness(
        self,
        async_client: AsyncClient,
        test_user: User,
        test_db: AsyncSession
    ):
        """Test username uniqueness constraint"""
        # Create another user
        other_user = User(
            id="other-user",
            email="other@example.com",
            username="existing_username",
            api_key="other-key"
        )
        test_db.add(other_user)
        await test_db.commit()
        
        # Try to update test_user with same username
        response = await async_client.put(
            "/v1/user/profile",
            json={"username": "existing_username"},
            # Authentication removed - no headers needed
        )
        
        assert response.status_code == 409
        assert "already taken" in response.json()["detail"].lower()