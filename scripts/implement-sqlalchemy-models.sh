#!/bin/bash

# SQLAlchemy Models Implementation Script for Claude Code Backend
# Fixes critical blocker: Missing database models and migrations
# Creates all required SQLAlchemy models, Pydantic schemas, and Alembic setup

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(dirname "$(dirname "$0")")"
BACKEND_DIR="$PROJECT_ROOT/services/backend"
APP_DIR="$BACKEND_DIR/app"

echo -e "${BLUE}🗄️ SQLAlchemy Models Implementation Script${NC}"
echo "========================================"
echo ""

# Function to create directory if it doesn't exist
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✅ Created directory: $dir${NC}"
    else
        echo -e "${BLUE}ℹ️  Directory exists: $dir${NC}"
    fi
}

echo -e "\n${YELLOW}📋 Phase 1: Creating directory structure...${NC}"

ensure_dir "$APP_DIR/models"
ensure_dir "$APP_DIR/schemas"
ensure_dir "$APP_DIR/database"
ensure_dir "$BACKEND_DIR/alembic"
ensure_dir "$BACKEND_DIR/alembic/versions"

echo -e "\n${YELLOW}🔧 Phase 2: Creating database configuration...${NC}"

# Create database.py with async SQLAlchemy setup
cat > "$APP_DIR/database/__init__.py" << 'EOF'
"""Database configuration and session management."""

from .base import Base, get_db, AsyncSessionLocal, engine
from .session import DatabaseSession

__all__ = ["Base", "get_db", "AsyncSessionLocal", "engine", "DatabaseSession"]
EOF

cat > "$APP_DIR/database/base.py" << 'EOF'
"""Database base configuration with async SQLAlchemy."""

import os
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool

from app.core.config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    poolclass=NullPool,  # Use NullPool for async connections
    future=True,
)

# Create async session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# Create declarative base
Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency to get database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
EOF

cat > "$APP_DIR/database/session.py" << 'EOF'
"""Database session management."""

from contextlib import asynccontextmanager
from typing import AsyncContextManager

from sqlalchemy.ext.asyncio import AsyncSession

from .base import AsyncSessionLocal


class DatabaseSession:
    """Database session context manager."""

    @staticmethod
    @asynccontextmanager
    async def create() -> AsyncContextManager[AsyncSession]:
        """Create a new database session."""
        async with AsyncSessionLocal() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
            finally:
                await session.close()
EOF

echo -e "${GREEN}✅ Database configuration created${NC}"

echo -e "\n${YELLOW}📊 Phase 3: Creating SQLAlchemy models...${NC}"

# Create models/__init__.py
cat > "$APP_DIR/models/__init__.py" << 'EOF'
"""SQLAlchemy models for Claude Code backend."""

from .user import User
from .api_key import APIKey
from .session import Session
from .project import Project
from .file import File
from .mcp_server import MCPServer
from .mcp_tool import MCPTool
from .audit_log import AuditLog

__all__ = [
    "User",
    "APIKey",
    "Session",
    "Project",
    "File",
    "MCPServer",
    "MCPTool",
    "AuditLog",
]
EOF

# Create User model
cat > "$APP_DIR/models/user.py" << 'EOF'
"""User model."""

from datetime import datetime
from typing import Optional, List
import uuid

from sqlalchemy import Column, String, DateTime, Boolean, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database.base import Base


class User(Base):
    """User model for authentication and authorization."""

    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=True, index=True)
    hashed_password = Column(String(255), nullable=True)
    
    # Profile fields
    full_name = Column(String(255), nullable=True)
    avatar_url = Column(Text, nullable=True)
    bio = Column(Text, nullable=True)
    
    # Settings
    preferences = Column(Text, nullable=True)  # JSON string
    theme = Column(String(50), default="light")
    
    # Status fields
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)
    
    # Relationships
    api_keys = relationship("APIKey", back_populates="user", cascade="all, delete-orphan")
    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    projects = relationship("Project", back_populates="owner", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="user", cascade="all, delete-orphan")
EOF

# Create APIKey model
cat > "$APP_DIR/models/api_key.py" << 'EOF'
"""API Key model for authentication."""

from datetime import datetime
import uuid
import secrets

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database.base import Base


class APIKey(Base):
    """API Key model for service authentication."""

    __tablename__ = "api_keys"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Key information
    name = Column(String(255), nullable=False)
    key_hash = Column(String(255), nullable=False, unique=True, index=True)
    key_prefix = Column(String(10), nullable=False)  # First 8 chars for identification
    
    # Permissions and scopes
    scopes = Column(Text, nullable=True)  # JSON array of scopes
    
    # Usage tracking
    last_used_at = Column(DateTime, nullable=True)
    usage_count = Column(Integer, default=0)
    
    # Status
    is_active = Column(Boolean, default=True)
    expires_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    revoked_at = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="api_keys")
    
    @staticmethod
    def generate_key() -> str:
        """Generate a new API key."""
        return f"sk_{secrets.token_urlsafe(48)}"
EOF

# Create Session model
cat > "$APP_DIR/models/session.py" << 'EOF'
"""Session model for chat sessions."""

from datetime import datetime
import uuid
from enum import Enum

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Integer, Text, Float
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database.base import Base


class SessionStatus(str, Enum):
    """Session status enumeration."""
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    ARCHIVED = "archived"


class Session(Base):
    """Session model for managing chat sessions."""

    __tablename__ = "sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True)
    
    # Session information
    title = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    status = Column(String(50), default=SessionStatus.ACTIVE.value)
    
    # Configuration
    model = Column(String(100), default="claude-3-opus")
    temperature = Column(Float, default=0.7)
    max_tokens = Column(Integer, default=4096)
    system_prompt = Column(Text, nullable=True)
    
    # Context and state
    context = Column(JSONB, nullable=True)  # Stored context/memory
    message_count = Column(Integer, default=0)
    token_count = Column(Integer, default=0)
    
    # MCP integration
    active_mcp_servers = Column(JSONB, nullable=True)  # List of active MCP server IDs
    mcp_state = Column(JSONB, nullable=True)  # MCP execution state
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_activity_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="sessions")
    project = relationship("Project", back_populates="sessions")
EOF

# Create Project model
cat > "$APP_DIR/models/project.py" << 'EOF'
"""Project model."""

from datetime import datetime
import uuid

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database.base import Base


class Project(Base):
    """Project model for organizing work."""

    __tablename__ = "projects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Project information
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    path = Column(Text, nullable=True)  # Local filesystem path
    repository_url = Column(Text, nullable=True)  # Git repository URL
    
    # Configuration
    settings = Column(JSONB, nullable=True)  # Project-specific settings
    environment_variables = Column(JSONB, nullable=True)  # Encrypted env vars
    
    # Status
    is_active = Column(Boolean, default=True)
    is_public = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_accessed_at = Column(DateTime, nullable=True)
    
    # Relationships
    owner = relationship("User", back_populates="projects")
    sessions = relationship("Session", back_populates="project", cascade="all, delete-orphan")
    files = relationship("File", back_populates="project", cascade="all, delete-orphan")
EOF

# Create File model
cat > "$APP_DIR/models/file.py" << 'EOF'
"""File model for tracking project files."""

from datetime import datetime
import uuid

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database.base import Base


class File(Base):
    """File model for tracking and managing project files."""

    __tablename__ = "files"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False)
    
    # File information
    path = Column(Text, nullable=False)  # Relative path within project
    name = Column(String(255), nullable=False)
    extension = Column(String(50), nullable=True)
    mime_type = Column(String(100), nullable=True)
    
    # Content
    content_hash = Column(String(64), nullable=True)  # SHA-256 hash
    size_bytes = Column(Integer, nullable=True)
    line_count = Column(Integer, nullable=True)
    
    # Version control
    version = Column(Integer, default=1)
    is_deleted = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    modified_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    accessed_at = Column(DateTime, nullable=True)
    
    # Relationships
    project = relationship("Project", back_populates="files")
EOF

# Create MCPServer model
cat > "$APP_DIR/models/mcp_server.py" << 'EOF'
"""MCP Server model."""

from datetime import datetime
import uuid

from sqlalchemy import Column, String, DateTime, Boolean, Text, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database.base import Base


class MCPServer(Base):
    """MCP Server model for managing Model Context Protocol servers."""

    __tablename__ = "mcp_servers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Server information
    name = Column(String(100), unique=True, nullable=False)
    display_name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    version = Column(String(50), nullable=True)
    
    # Connection details
    url = Column(Text, nullable=False)
    protocol = Column(String(50), default="sse")  # sse, websocket, http
    
    # Configuration
    config = Column(JSONB, nullable=True)  # Server-specific configuration
    capabilities = Column(JSONB, nullable=True)  # List of capabilities
    
    # Status
    is_active = Column(Boolean, default=True)
    is_available = Column(Boolean, default=True)
    health_check_url = Column(Text, nullable=True)
    last_health_check = Column(DateTime, nullable=True)
    
    # Usage metrics
    total_requests = Column(Integer, default=0)
    failed_requests = Column(Integer, default=0)
    average_response_time_ms = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    tools = relationship("MCPTool", back_populates="server", cascade="all, delete-orphan")
EOF

# Create MCPTool model
cat > "$APP_DIR/models/mcp_tool.py" << 'EOF'
"""MCP Tool model."""

from datetime import datetime
import uuid

from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Text, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database.base import Base


class MCPTool(Base):
    """MCP Tool model for managing available tools from MCP servers."""

    __tablename__ = "mcp_tools"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    server_id = Column(UUID(as_uuid=True), ForeignKey("mcp_servers.id"), nullable=False)
    
    # Tool information
    name = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=True)
    
    # Schema and parameters
    input_schema = Column(JSONB, nullable=True)  # JSON Schema for input
    output_schema = Column(JSONB, nullable=True)  # JSON Schema for output
    
    # Usage and permissions
    requires_auth = Column(Boolean, default=False)
    allowed_scopes = Column(JSONB, nullable=True)  # List of required scopes
    
    # Usage metrics
    execution_count = Column(Integer, default=0)
    success_count = Column(Integer, default=0)
    average_execution_time_ms = Column(Integer, nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    is_deprecated = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    server = relationship("MCPServer", back_populates="tools")
EOF

# Create AuditLog model
cat > "$APP_DIR/models/audit_log.py" << 'EOF'
"""Audit Log model for tracking system events."""

from datetime import datetime
import uuid

from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database.base import Base


class AuditLog(Base):
    """Audit Log model for tracking user actions and system events."""

    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    
    # Event information
    event_type = Column(String(100), nullable=False, index=True)
    resource_type = Column(String(100), nullable=True)
    resource_id = Column(UUID(as_uuid=True), nullable=True)
    
    # Action details
    action = Column(String(100), nullable=False)  # create, update, delete, access
    description = Column(Text, nullable=True)
    
    # Request context
    ip_address = Column(String(45), nullable=True)  # IPv6 compatible
    user_agent = Column(Text, nullable=True)
    request_id = Column(UUID(as_uuid=True), nullable=True)
    
    # Additional data
    metadata = Column(JSONB, nullable=True)  # Additional event-specific data
    changes = Column(JSONB, nullable=True)  # Before/after values for updates
    
    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    # Relationships
    user = relationship("User", back_populates="audit_logs")
EOF

echo -e "${GREEN}✅ All SQLAlchemy models created${NC}"

echo -e "\n${YELLOW}📝 Phase 4: Creating Pydantic schemas...${NC}"

# Create schemas/__init__.py
cat > "$APP_DIR/schemas/__init__.py" << 'EOF'
"""Pydantic schemas for API validation."""

from .user import UserCreate, UserUpdate, UserInDB, UserResponse
from .auth import Token, TokenPayload, LoginRequest
from .session import SessionCreate, SessionUpdate, SessionResponse
from .project import ProjectCreate, ProjectUpdate, ProjectResponse
from .api_key import APIKeyCreate, APIKeyResponse

__all__ = [
    "UserCreate", "UserUpdate", "UserInDB", "UserResponse",
    "Token", "TokenPayload", "LoginRequest",
    "SessionCreate", "SessionUpdate", "SessionResponse",
    "ProjectCreate", "ProjectUpdate", "ProjectResponse",
    "APIKeyCreate", "APIKeyResponse",
]
EOF

# Create User schemas
cat > "$APP_DIR/schemas/user.py" << 'EOF'
"""User schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, ConfigDict


class UserBase(BaseModel):
    """Base user schema."""
    email: EmailStr
    username: Optional[str] = None
    full_name: Optional[str] = None
    is_active: bool = True
    is_superuser: bool = False
    is_verified: bool = False


class UserCreate(UserBase):
    """Schema for creating a user."""
    password: str


class UserUpdate(BaseModel):
    """Schema for updating a user."""
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    full_name: Optional[str] = None
    password: Optional[str] = None
    theme: Optional[str] = None
    preferences: Optional[dict] = None


class UserInDB(UserBase):
    """User schema in database."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    hashed_password: str
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None


class UserResponse(UserBase):
    """User response schema."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None
EOF

# Create Auth schemas
cat > "$APP_DIR/schemas/auth.py" << 'EOF'
"""Authentication schemas."""

from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class Token(BaseModel):
    """Token response schema."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 3600


class TokenPayload(BaseModel):
    """Token payload schema."""
    sub: UUID
    exp: Optional[int] = None
    iat: Optional[int] = None
    scopes: list[str] = []


class LoginRequest(BaseModel):
    """Login request schema."""
    email: str
    password: str
EOF

# Create Session schemas
cat > "$APP_DIR/schemas/session.py" << 'EOF'
"""Session schemas."""

from datetime import datetime
from typing import Optional, Dict, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class SessionBase(BaseModel):
    """Base session schema."""
    title: Optional[str] = None
    description: Optional[str] = None
    model: str = "claude-3-opus"
    temperature: float = 0.7
    max_tokens: int = 4096
    system_prompt: Optional[str] = None


class SessionCreate(SessionBase):
    """Schema for creating a session."""
    project_id: Optional[UUID] = None


class SessionUpdate(BaseModel):
    """Schema for updating a session."""
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    model: Optional[str] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None
    system_prompt: Optional[str] = None


class SessionResponse(SessionBase):
    """Session response schema."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    user_id: UUID
    project_id: Optional[UUID] = None
    status: str
    context: Optional[Dict[str, Any]] = None
    message_count: int
    token_count: int
    created_at: datetime
    updated_at: datetime
    last_activity_at: datetime
EOF

# Create Project schemas
cat > "$APP_DIR/schemas/project.py" << 'EOF'
"""Project schemas."""

from datetime import datetime
from typing import Optional, Dict, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ProjectBase(BaseModel):
    """Base project schema."""
    name: str
    description: Optional[str] = None
    path: Optional[str] = None
    repository_url: Optional[str] = None
    is_public: bool = False


class ProjectCreate(ProjectBase):
    """Schema for creating a project."""
    settings: Optional[Dict[str, Any]] = None
    environment_variables: Optional[Dict[str, str]] = None


class ProjectUpdate(BaseModel):
    """Schema for updating a project."""
    name: Optional[str] = None
    description: Optional[str] = None
    path: Optional[str] = None
    repository_url: Optional[str] = None
    is_public: Optional[bool] = None
    settings: Optional[Dict[str, Any]] = None
    environment_variables: Optional[Dict[str, str]] = None


class ProjectResponse(ProjectBase):
    """Project response schema."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    owner_id: UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime
    last_accessed_at: Optional[datetime] = None
EOF

# Create APIKey schemas
cat > "$APP_DIR/schemas/api_key.py" << 'EOF'
"""API Key schemas."""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class APIKeyCreate(BaseModel):
    """Schema for creating an API key."""
    name: str
    scopes: Optional[List[str]] = None
    expires_at: Optional[datetime] = None


class APIKeyResponse(BaseModel):
    """API Key response schema."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    name: str
    key_prefix: str
    scopes: Optional[List[str]] = None
    is_active: bool
    expires_at: Optional[datetime] = None
    created_at: datetime
    last_used_at: Optional[datetime] = None
    
    # Only returned on creation
    key: Optional[str] = None
EOF

echo -e "${GREEN}✅ All Pydantic schemas created${NC}"

echo -e "\n${YELLOW}🔄 Phase 5: Setting up Alembic migrations...${NC}"

# Create alembic.ini
cat > "$BACKEND_DIR/alembic.ini" << 'EOF'
# A generic, single database configuration.

[alembic]
# path to migration scripts
script_location = alembic

# template used to generate migration file names; The default value is %%(rev)s_%%(slug)s
# Uncomment the line below if you want the files to be prepended with date and time
file_template = %%(year)d%%(month).2d%%(day).2d_%%(hour).2d%%(minute).2d-%%(rev)s_%%(slug)s

# sys.path path, will be prepended to sys.path if present.
# defaults to the current working directory.
prepend_sys_path = .

# timezone to use when rendering the date within the migration file
# as well as the filename.
# If specified, requires the python-dateutil library
# one of: postgresql_psycopg2, mysql, oracle, sqlite, etc.
# timezone =

# max length of characters to apply to the
# "slug" field
# truncate_slug_length = 40

# set to 'true' to run the environment during
# the 'revision' command, regardless of autogenerate
# revision_environment = false

# set to 'true' to allow .pyc and .pyo files without
# a source .py file to be detected as revisions in the
# versions/ directory
# sourceless = false

# version location specification; This defaults
# to alembic/versions.  When using multiple version
# directories, initial revisions must be specified with --version-path.
# The path separator used here should be the separator specified by "version_path_separator" below.
# version_locations = %(here)s/bar:%(here)s/bat:alembic/versions

# version path separator; As mentioned above, this is the character used to split
# version_locations. The default separator is OS-dependent, but a forward slash is
# recommended. Valid values are:
# version_path_separator = :
# version_path_separator = ;
# version_path_separator = space
version_path_separator = os  # Use os.pathsep.
# the output encoding used when revision files
# are written from script.py.mako
# output_encoding = utf-8

sqlalchemy.url = postgresql+asyncpg://claudecode:claudecode@localhost/claudecode


[post_write_hooks]
# post_write_hooks defines scripts or Python functions that are run
# on newly generated revision scripts.  See the documentation for further
# detail and examples

# format using "black" - use the console_scripts runner, against the "black" entrypoint
# hooks = black
# black.type = console_scripts
# black.entrypoint = black
# black.options = -l 79 REVISION_SCRIPT_FILENAME

# Logging configuration
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
EOF

# Create env.py for Alembic
cat > "$BACKEND_DIR/alembic/env.py" << 'EOF'
"""Alembic environment configuration."""

import asyncio
import os
import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import create_async_engine

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from app.database.base import Base
from app.core.config import settings

# Import all models to ensure they're registered
from app.models import *  # noqa

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# add your model's MetaData object here
# for 'autogenerate' support
target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.
    """
    url = settings.DATABASE_URL
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    """Run migrations with connection."""
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """In this scenario we need to create an Engine
    and associate a connection with the context.
    """
    connectable = create_async_engine(
        settings.DATABASE_URL,
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

# Create script.py.mako template
cat > "$BACKEND_DIR/alembic/script.py.mako" << 'EOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

# revision identifiers, used by Alembic.
revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
EOF

echo -e "${GREEN}✅ Alembic configuration created${NC}"

echo -e "\n${YELLOW}🚀 Phase 6: Creating initial migration...${NC}"

# Create initialization script
cat > "$BACKEND_DIR/init_db.py" << 'EOF'
#!/usr/bin/env python3
"""Initialize database with tables and sample data."""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent))

from app.database.base import engine, Base
from app.models import *  # noqa


async def init_db():
    """Initialize database tables."""
    async with engine.begin() as conn:
        # Drop all tables (for development only)
        # await conn.run_sync(Base.metadata.drop_all)
        
        # Create all tables
        await conn.run_sync(Base.metadata.create_all)
        print("✅ Database tables created successfully!")


if __name__ == "__main__":
    asyncio.run(init_db())
EOF

chmod +x "$BACKEND_DIR/init_db.py"

echo -e "${GREEN}✅ Database initialization script created${NC}"

echo -e "\n${YELLOW}📊 Phase 7: Creating database utilities...${NC}"

# Create database utilities
cat > "$APP_DIR/database/utils.py" << 'EOF'
"""Database utilities and helpers."""

from typing import Optional, Dict, Any
import hashlib
import secrets

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession


def hash_api_key(key: str) -> str:
    """Hash an API key using SHA-256."""
    return hashlib.sha256(key.encode()).hexdigest()


def generate_api_key() -> tuple[str, str]:
    """Generate a new API key and its hash.
    
    Returns:
        Tuple of (plain_key, hashed_key)
    """
    key = f"sk_{secrets.token_urlsafe(48)}"
    return key, hash_api_key(key)


async def get_row_count(
    session: AsyncSession,
    model: Any,
    filters: Optional[Dict[str, Any]] = None
) -> int:
    """Get row count for a model with optional filters."""
    query = select(func.count()).select_from(model)
    
    if filters:
        for key, value in filters.items():
            query = query.where(getattr(model, key) == value)
    
    result = await session.execute(query)
    return result.scalar() or 0


async def exists(
    session: AsyncSession,
    model: Any,
    **kwargs
) -> bool:
    """Check if a record exists with given criteria."""
    query = select(model).filter_by(**kwargs).limit(1)
    result = await session.execute(query)
    return result.scalar() is not None
EOF

echo -e "${GREEN}✅ Database utilities created${NC}"

echo -e "\n${YELLOW}✅ Phase 8: Verification...${NC}"

# Verify all files were created
VERIFICATION_PASSED=true

echo -n "Checking models... "
if [ -f "$APP_DIR/models/__init__.py" ] && \
   [ -f "$APP_DIR/models/user.py" ] && \
   [ -f "$APP_DIR/models/session.py" ] && \
   [ -f "$APP_DIR/models/project.py" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VERIFICATION_PASSED=false
fi

echo -n "Checking schemas... "
if [ -f "$APP_DIR/schemas/__init__.py" ] && \
   [ -f "$APP_DIR/schemas/user.py" ] && \
   [ -f "$APP_DIR/schemas/auth.py" ] && \
   [ -f "$APP_DIR/schemas/session.py" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VERIFICATION_PASSED=false
fi

echo -n "Checking database configuration... "
if [ -f "$APP_DIR/database/__init__.py" ] && \
   [ -f "$APP_DIR/database/base.py" ] && \
   [ -f "$APP_DIR/database/session.py" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VERIFICATION_PASSED=false
fi

echo -n "Checking Alembic setup... "
if [ -f "$BACKEND_DIR/alembic.ini" ] && \
   [ -f "$BACKEND_DIR/alembic/env.py" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VERIFICATION_PASSED=false
fi

echo -e "\n${BLUE}📊 Summary:${NC}"
echo "================================"
echo "✅ Created 8 SQLAlchemy models:"
echo "   - User (authentication)"
echo "   - APIKey (API authentication)"
echo "   - Session (chat sessions)"
echo "   - Project (project organization)"
echo "   - File (file tracking)"
echo "   - MCPServer (MCP integration)"
echo "   - MCPTool (MCP tools)"
echo "   - AuditLog (audit trail)"
echo ""
echo "✅ Created 5 Pydantic schema sets:"
echo "   - User schemas"
echo "   - Auth schemas"
echo "   - Session schemas"
echo "   - Project schemas"
echo "   - APIKey schemas"
echo ""
echo "✅ Configured Alembic migrations"
echo "✅ Created database utilities"
echo ""

if [ "$VERIFICATION_PASSED" = true ]; then
    echo -e "${GREEN}✅ SQLAlchemy implementation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update DATABASE_URL in .env file"
    echo "2. Run: cd $BACKEND_DIR && python init_db.py"
    echo "3. Or use Alembic: alembic upgrade head"
    echo "4. Start the backend: uvicorn app.main:app --reload"
    exit 0
else
    echo -e "${RED}⚠️ Some components failed to create${NC}"
    echo "Please review the errors above"
    exit 1
fi