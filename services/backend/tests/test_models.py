"""
Test suite for SQLAlchemy database models.
Tests User, Project, Session, and MCPConfig models with relationships.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timedelta
import uuid

from app.models import User, Project, Session, MCPConfig


@pytest.mark.asyncio
class TestUserModel:
    """Test User model and its relationships."""
    
    async def test_create_user(self, db_session: AsyncSession):
        """Test creating a new user."""
        user = User(
            email="test@example.com",
            password_hash="hashed_password",
            api_key="test-api-key-123"
        )
        db_session.add(user)
        await db_session.commit()
        
        assert user.id is not None
        assert user.email == "test@example.com"
        assert user.created_at is not None
        assert user.updated_at is not None
    
    async def test_user_unique_email(self, db_session: AsyncSession):
        """Test email uniqueness constraint."""
        user1 = User(
            email="duplicate@example.com",
            password_hash="hash1",
            api_key="key1"
        )
        user2 = User(
            email="duplicate@example.com",
            password_hash="hash2",
            api_key="key2"
        )
        
        db_session.add(user1)
        await db_session.commit()
        
        db_session.add(user2)
        with pytest.raises(IntegrityError):
            await db_session.commit()
    
    async def test_user_unique_api_key(self, db_session: AsyncSession):
        """Test API key uniqueness constraint."""
        user1 = User(
            email="user1@example.com",
            password_hash="hash1",
            api_key="duplicate-key"
        )
        user2 = User(
            email="user2@example.com",
            password_hash="hash2",
            api_key="duplicate-key"
        )
        
        db_session.add(user1)
        await db_session.commit()
        
        db_session.add(user2)
        with pytest.raises(IntegrityError):
            await db_session.commit()
    
    async def test_user_projects_relationship(self, db_session: AsyncSession):
        """Test user-projects one-to-many relationship."""
        user = User(
            email="owner@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Create projects
        project1 = Project(name="Project 1", owner_id=user.id)
        project2 = Project(name="Project 2", owner_id=user.id)
        db_session.add_all([project1, project2])
        await db_session.commit()
        
        # Test relationship
        await db_session.refresh(user)
        assert len(user.projects) == 2
        assert project1 in user.projects
        assert project2 in user.projects
    
    async def test_user_sessions_relationship(self, db_session: AsyncSession):
        """Test user-sessions one-to-many relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Create sessions
        session1 = Session(user_id=user.id, token="token1")
        session2 = Session(user_id=user.id, token="token2")
        db_session.add_all([session1, session2])
        await db_session.commit()
        
        # Test relationship
        await db_session.refresh(user)
        assert len(user.sessions) == 2
    
    async def test_user_cascade_delete(self, db_session: AsyncSession):
        """Test cascade delete of related objects."""
        user = User(
            email="delete@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Create related objects
        project = Project(name="To Delete", owner_id=user.id)
        session = Session(user_id=user.id, token="token")
        db_session.add_all([project, session])
        await db_session.commit()
        
        # Delete user
        await db_session.delete(user)
        await db_session.commit()
        
        # Check cascaded deletions
        assert await db_session.get(Project, project.id) is None
        assert await db_session.get(Session, session.id) is None


@pytest.mark.asyncio
class TestProjectModel:
    """Test Project model and its relationships."""
    
    async def test_create_project(self, db_session: AsyncSession):
        """Test creating a new project."""
        user = User(
            email="owner@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        project = Project(
            name="Test Project",
            description="A test project",
            owner_id=user.id,
            settings={"theme": "dark", "language": "python"}
        )
        db_session.add(project)
        await db_session.commit()
        
        assert project.id is not None
        assert project.name == "Test Project"
        assert project.settings["theme"] == "dark"
        assert project.created_at is not None
    
    async def test_project_owner_relationship(self, db_session: AsyncSession):
        """Test project-owner many-to-one relationship."""
        user = User(
            email="owner@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        project = Project(name="Owned Project", owner_id=user.id)
        db_session.add(project)
        await db_session.commit()
        
        await db_session.refresh(project)
        assert project.owner == user
        assert project.owner.email == "owner@example.com"
    
    async def test_project_sessions_relationship(self, db_session: AsyncSession):
        """Test project-sessions one-to-many relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        # Create sessions for project
        session1 = Session(user_id=user.id, project_id=project.id, token="token1")
        session2 = Session(user_id=user.id, project_id=project.id, token="token2")
        db_session.add_all([session1, session2])
        await db_session.commit()
        
        await db_session.refresh(project)
        assert len(project.sessions) == 2
    
    async def test_project_mcp_configs_relationship(self, db_session: AsyncSession):
        """Test project-mcp_configs one-to-many relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        # Create MCP configs
        config1 = MCPConfig(
            project_id=project.id,
            name="Config 1",
            config={"server": "localhost"}
        )
        config2 = MCPConfig(
            project_id=project.id,
            name="Config 2",
            config={"server": "remote"}
        )
        db_session.add_all([config1, config2])
        await db_session.commit()
        
        await db_session.refresh(project)
        assert len(project.mcp_configs) == 2
    
    async def test_project_json_settings(self, db_session: AsyncSession):
        """Test JSON field for project settings."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Test various JSON structures
        complex_settings = {
            "theme": {"primary": "blue", "secondary": "green"},
            "features": ["auth", "sse", "websocket"],
            "limits": {"max_sessions": 10, "timeout": 3600},
            "nested": {
                "level1": {
                    "level2": {
                        "value": "deep"
                    }
                }
            }
        }
        
        project = Project(
            name="Complex Project",
            owner_id=user.id,
            settings=complex_settings
        )
        db_session.add(project)
        await db_session.commit()
        
        # Retrieve and verify
        await db_session.refresh(project)
        assert project.settings["theme"]["primary"] == "blue"
        assert "auth" in project.settings["features"]
        assert project.settings["nested"]["level1"]["level2"]["value"] == "deep"


@pytest.mark.asyncio
class TestSessionModel:
    """Test Session model and its relationships."""
    
    async def test_create_session(self, db_session: AsyncSession):
        """Test creating a new session."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        session = Session(
            user_id=user.id,
            project_id=project.id,
            token="session-token-123",
            is_active=True
        )
        db_session.add(session)
        await db_session.commit()
        
        assert session.id is not None
        assert session.token == "session-token-123"
        assert session.is_active == True
        assert session.last_activity is not None
    
    async def test_session_user_relationship(self, db_session: AsyncSession):
        """Test session-user many-to-one relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        session = Session(user_id=user.id, token="token")
        db_session.add(session)
        await db_session.commit()
        
        await db_session.refresh(session)
        assert session.user == user
    
    async def test_session_project_relationship(self, db_session: AsyncSession):
        """Test session-project many-to-one relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        session = Session(
            user_id=user.id,
            project_id=project.id,
            token="token"
        )
        db_session.add(session)
        await db_session.commit()
        
        await db_session.refresh(session)
        assert session.project == project
    
    async def test_session_activity_tracking(self, db_session: AsyncSession):
        """Test session activity timestamp updates."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        session = Session(user_id=user.id, token="token")
        db_session.add(session)
        await db_session.commit()
        
        original_activity = session.last_activity
        
        # Simulate activity update
        await asyncio.sleep(0.1)
        session.last_activity = datetime.utcnow()
        await db_session.commit()
        
        assert session.last_activity > original_activity
    
    async def test_session_expiration(self, db_session: AsyncSession):
        """Test session expiration logic."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Create expired session
        expired_time = datetime.utcnow() - timedelta(hours=25)
        session = Session(
            user_id=user.id,
            token="expired-token",
            last_activity=expired_time
        )
        db_session.add(session)
        await db_session.commit()
        
        # Check if session is expired (assuming 24hr expiry)
        time_since_activity = datetime.utcnow() - session.last_activity
        is_expired = time_since_activity > timedelta(hours=24)
        
        assert is_expired == True


@pytest.mark.asyncio
class TestMCPConfigModel:
    """Test MCPConfig model and its relationships."""
    
    async def test_create_mcp_config(self, db_session: AsyncSession):
        """Test creating a new MCP configuration."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        config = MCPConfig(
            project_id=project.id,
            name="Test MCP Server",
            config={
                "host": "localhost",
                "port": 3000,
                "features": ["sse", "websocket"],
                "auth": {
                    "type": "bearer",
                    "token": "mcp-token"
                }
            },
            is_active=True
        )
        db_session.add(config)
        await db_session.commit()
        
        assert config.id is not None
        assert config.name == "Test MCP Server"
        assert config.config["port"] == 3000
        assert config.is_active == True
    
    async def test_mcp_config_project_relationship(self, db_session: AsyncSession):
        """Test MCP config-project many-to-one relationship."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        config = MCPConfig(
            project_id=project.id,
            name="Config",
            config={"test": "data"}
        )
        db_session.add(config)
        await db_session.commit()
        
        await db_session.refresh(config)
        assert config.project == project
    
    async def test_mcp_config_json_validation(self, db_session: AsyncSession):
        """Test complex JSON configuration storage."""
        user = User(
            email="user@example.com",
            password_hash="hash",
            api_key="key"
        )
        project = Project(name="Project", owner_id=user.id)
        db_session.add_all([user, project])
        await db_session.commit()
        
        complex_config = {
            "servers": [
                {"name": "primary", "url": "http://primary.example.com"},
                {"name": "backup", "url": "http://backup.example.com"}
            ],
            "retry_policy": {
                "max_attempts": 3,
                "backoff": "exponential",
                "base_delay": 1000
            },
            "features": {
                "sse": {"enabled": True, "timeout": 30000},
                "websocket": {"enabled": False},
                "polling": {"enabled": True, "interval": 5000}
            }
        }
        
        config = MCPConfig(
            project_id=project.id,
            name="Complex Config",
            config=complex_config
        )
        db_session.add(config)
        await db_session.commit()
        
        await db_session.refresh(config)
        assert len(config.config["servers"]) == 2
        assert config.config["retry_policy"]["max_attempts"] == 3
        assert config.config["features"]["sse"]["enabled"] == True


@pytest.mark.asyncio
class TestTimestampMixin:
    """Test TimestampMixin functionality across models."""
    
    async def test_auto_timestamps(self, db_session: AsyncSession):
        """Test automatic timestamp creation and updates."""
        user = User(
            email="timestamp@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        # Check creation timestamps
        assert user.created_at is not None
        assert user.updated_at is not None
        assert user.created_at == user.updated_at
        
        original_created = user.created_at
        original_updated = user.updated_at
        
        # Update user
        await asyncio.sleep(0.1)
        user.email = "updated@example.com"
        await db_session.commit()
        
        # Check updated timestamp changed but created didn't
        assert user.created_at == original_created
        assert user.updated_at > original_updated


@pytest.mark.asyncio
class TestRelationshipIntegrity:
    """Test referential integrity and constraints."""
    
    async def test_foreign_key_constraint(self, db_session: AsyncSession):
        """Test foreign key constraints are enforced."""
        # Try to create project with non-existent user
        project = Project(
            name="Orphan Project",
            owner_id="non-existent-user-id"
        )
        db_session.add(project)
        
        with pytest.raises(IntegrityError):
            await db_session.commit()
    
    async def test_orphan_deletion_protection(self, db_session: AsyncSession):
        """Test that deleting parent with children is handled properly."""
        user = User(
            email="parent@example.com",
            password_hash="hash",
            api_key="key"
        )
        db_session.add(user)
        await db_session.commit()
        
        project = Project(name="Child Project", owner_id=user.id)
        db_session.add(project)
        await db_session.commit()
        
        # Attempt to delete user (should cascade)
        await db_session.delete(user)
        await db_session.commit()
        
        # Verify cascade worked
        assert await db_session.get(Project, project.id) is None