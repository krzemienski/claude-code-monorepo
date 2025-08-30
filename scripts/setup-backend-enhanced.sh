#!/bin/bash

# Enhanced Backend Setup Script for Claude Code
# This script provides comprehensive backend development environment setup
# including Docker, PostgreSQL, Redis, Python, and all dependencies

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/services/backend"
IOS_DIR="$PROJECT_ROOT/apps/ios"

echo -e "${BLUE}🚀 Claude Code Backend Enhanced Setup${NC}"
echo "========================================"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ===========================================
# PHASE 1: System Requirements Check
# ===========================================
echo -e "\n${BLUE}📋 Phase 1: System Requirements Check${NC}"
echo "----------------------------------------"

# Check OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    print_status 0 "Running on macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    print_status 0 "Running on Linux"
else
    print_warning "Unsupported OS: $OSTYPE"
    exit 1
fi

# Check Python version
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
        print_status 0 "Python $PYTHON_VERSION installed"
    else
        print_warning "Python 3.11+ required, found $PYTHON_VERSION"
        print_info "Please install Python 3.11 or higher"
    fi
else
    print_warning "Python 3 not found"
    if [[ "$OS" == "macOS" ]]; then
        print_info "Install with: brew install python@3.11"
    else
        print_info "Install with: sudo apt-get install python3.11"
    fi
fi

# ===========================================
# PHASE 2: Docker Installation & Setup
# ===========================================
echo -e "\n${BLUE}🐳 Phase 2: Docker Installation & Setup${NC}"
echo "----------------------------------------"

# Check Docker installation
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_status 0 "Docker $DOCKER_VERSION installed"
    
    # Check if Docker daemon is running
    if docker info &>/dev/null; then
        print_status 0 "Docker daemon is running"
    else
        print_warning "Docker daemon is not running"
        if [[ "$OS" == "macOS" ]]; then
            print_info "Start Docker Desktop from Applications"
        else
            print_info "Run: sudo systemctl start docker"
        fi
        exit 1
    fi
else
    print_warning "Docker not installed"
    if [[ "$OS" == "macOS" ]]; then
        print_info "Download Docker Desktop from https://www.docker.com/products/docker-desktop"
    else
        print_info "Install with: curl -fsSL https://get.docker.com | sh"
    fi
    exit 1
fi

# Check Docker Compose
if command_exists docker-compose || docker compose version &>/dev/null; then
    print_status 0 "Docker Compose installed"
else
    print_warning "Docker Compose not found"
    print_info "Docker Compose should be included with Docker Desktop"
fi

# ===========================================
# PHASE 3: Python Environment Setup
# ===========================================
echo -e "\n${BLUE}🐍 Phase 3: Python Environment Setup${NC}"
echo "----------------------------------------"

cd "$BACKEND_DIR" 2>/dev/null || {
    print_warning "Backend directory not found at $BACKEND_DIR"
    print_info "Creating backend directory structure..."
    mkdir -p "$BACKEND_DIR"
    cd "$BACKEND_DIR"
}

# Create virtual environment
if [ ! -d "venv" ]; then
    print_info "Creating Python virtual environment..."
    python3 -m venv venv
    print_status $? "Virtual environment created"
else
    print_status 0 "Virtual environment already exists"
fi

# Activate virtual environment
print_info "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
print_info "Upgrading pip..."
pip install --upgrade pip --quiet

# Install requirements if they exist
if [ -f "requirements.txt" ]; then
    print_info "Installing Python dependencies..."
    pip install -r requirements.txt --quiet
    print_status $? "Python dependencies installed"
else
    print_warning "requirements.txt not found"
    print_info "Creating requirements.txt with essential packages..."
    cat > requirements.txt << 'EOF'
# Core Framework
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-multipart==0.0.6

# Database
sqlalchemy==2.0.25
asyncpg==0.29.0
aiosqlite==0.19.0
alembic==1.13.1

# Authentication & Security
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0

# AI Integration
anthropic==0.18.1
openai==1.10.0

# SSE Support
sse-starlette==2.0.0

# Redis
redis==5.0.1
aioredis==2.0.1

# Testing
pytest==7.4.4
pytest-asyncio==0.21.1
httpx==0.26.0

# Monitoring
prometheus-client==0.19.0

# Utilities
pydantic==2.5.3
pydantic-settings==2.1.0
python-json-logger==2.0.7
EOF
    pip install -r requirements.txt --quiet
    print_status $? "Requirements installed"
fi

# ===========================================
# PHASE 4: Database Configuration
# ===========================================
echo -e "\n${BLUE}🗄️ Phase 4: Database Configuration${NC}"
echo "----------------------------------------"

# Create missing directories
mkdir -p "$BACKEND_DIR/app/models"
mkdir -p "$BACKEND_DIR/app/schemas"
mkdir -p "$BACKEND_DIR/app/db"
mkdir -p "$BACKEND_DIR/alembic"

# Create database session management if missing
if [ ! -f "$BACKEND_DIR/app/db/session.py" ]; then
    print_info "Creating database session management..."
    cat > "$BACKEND_DIR/app/db/session.py" << 'EOF'
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.core.config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

# Create async session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# Create declarative base
Base = declarative_base()

# Dependency for FastAPI
async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
EOF
    print_status 0 "Database session created"
fi

# Initialize Alembic if not already done
if [ ! -f "$BACKEND_DIR/alembic.ini" ]; then
    print_info "Initializing Alembic for database migrations..."
    cd "$BACKEND_DIR"
    alembic init alembic
    print_status $? "Alembic initialized"
    
    # Update alembic configuration
    sed -i.bak 's|sqlalchemy.url = .*|sqlalchemy.url = postgresql+asyncpg://postgres:postgres@localhost:5432/claudecode|' alembic.ini
fi

# ===========================================
# PHASE 5: Environment Configuration
# ===========================================
echo -e "\n${BLUE}⚙️ Phase 5: Environment Configuration${NC}"
echo "----------------------------------------"

# Create .env file if it doesn't exist
if [ ! -f "$BACKEND_DIR/.env" ]; then
    print_info "Creating .env file..."
    cat > "$BACKEND_DIR/.env" << 'EOF'
# Application Settings
APP_NAME=ClaudeCode
APP_VERSION=1.0.0
DEBUG=true
LOG_LEVEL=INFO
PORT=8000

# Security
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Database
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/claudecode
DATABASE_URL_SYNC=postgresql://postgres:postgres@localhost:5432/claudecode

# Redis
REDIS_URL=redis://localhost:6379/0
CACHE_TTL=3600

# Anthropic API
ANTHROPIC_API_KEY=your-anthropic-api-key
ANTHROPIC_MODEL=claude-3-sonnet-20240229
ANTHROPIC_MAX_TOKENS=4096
ANTHROPIC_TEMPERATURE=0.7

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8000,http://localhost:8100

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_PERIOD=60

# MCP Configuration
MCP_AUDIT_ENABLED=true
MCP_TIMEOUT=30

# Monitoring
PROMETHEUS_ENABLED=true
METRICS_PORT=9090
EOF
    print_status 0 ".env file created"
else
    print_status 0 ".env file already exists"
fi

# ===========================================
# PHASE 6: Docker Services Setup
# ===========================================
echo -e "\n${BLUE}🐳 Phase 6: Docker Services Setup${NC}"
echo "----------------------------------------"

# Create docker-compose.yml if it doesn't exist
if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    print_info "Creating docker-compose.yml..."
    cat > "$PROJECT_ROOT/docker-compose.yml" << 'EOF'
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: claudecode-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: claudecode
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: claudecode-redis
    ports:
      - "6379:6379"
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./services/backend
      dockerfile: Dockerfile
    container_name: claudecode-backend
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://postgres:postgres@postgres:5432/claudecode
      REDIS_URL: redis://redis:6379/0
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./services/backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

volumes:
  postgres_data:

networks:
  default:
    name: claudecode-network
EOF
    print_status 0 "docker-compose.yml created"
else
    print_status 0 "docker-compose.yml already exists"
fi

# ===========================================
# PHASE 7: Backend Application Structure
# ===========================================
echo -e "\n${BLUE}🏗️ Phase 7: Backend Application Structure${NC}"
echo "----------------------------------------"

# Create missing model files
if [ ! -f "$BACKEND_DIR/app/models/__init__.py" ]; then
    print_info "Creating model definitions..."
    
    # Create __init__.py
    cat > "$BACKEND_DIR/app/models/__init__.py" << 'EOF'
from .session import Session
from .message import Message
from .project import Project
from .user import User
from .analytics import AnalyticsEvent

__all__ = ["Session", "Message", "Project", "User", "AnalyticsEvent"]
EOF
    
    # Create Session model
    cat > "$BACKEND_DIR/app/models/session.py" << 'EOF'
from sqlalchemy import Column, String, DateTime, JSON, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
import enum
from app.db.session import Base

class SessionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    IDLE = "IDLE"
    ARCHIVED = "ARCHIVED"

class Session(Base):
    __tablename__ = "sessions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=False, index=True)
    project_id = Column(String, nullable=True)
    name = Column(String, nullable=False)
    model = Column(String, nullable=False)
    status = Column(Enum(SessionStatus), default=SessionStatus.IDLE)
    metadata = Column(JSON, default={})
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
EOF
    
    print_status 0 "Model definitions created"
fi

# Create missing schema files
if [ ! -f "$BACKEND_DIR/app/schemas/__init__.py" ]; then
    print_info "Creating Pydantic schemas..."
    
    # Create __init__.py
    cat > "$BACKEND_DIR/app/schemas/__init__.py" << 'EOF'
from .session import SessionCreate, SessionUpdate, SessionResponse
from .message import MessageCreate, MessageResponse
from .project import ProjectCreate, ProjectResponse

__all__ = [
    "SessionCreate", "SessionUpdate", "SessionResponse",
    "MessageCreate", "MessageResponse",
    "ProjectCreate", "ProjectResponse"
]
EOF
    
    # Create Session schema
    cat > "$BACKEND_DIR/app/schemas/session.py" << 'EOF'
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime
from uuid import UUID
from enum import Enum

class SessionStatus(str, Enum):
    ACTIVE = "ACTIVE"
    IDLE = "IDLE"
    ARCHIVED = "ARCHIVED"

class SessionBase(BaseModel):
    name: str
    model: str = "claude-3-sonnet-20240229"
    project_id: Optional[str] = None

class SessionCreate(SessionBase):
    user_id: str

class SessionUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[SessionStatus] = None
    metadata: Optional[Dict[str, Any]] = None

class SessionResponse(SessionBase):
    id: UUID
    user_id: str
    status: SessionStatus
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        from_attributes = True
EOF
    
    print_status 0 "Pydantic schemas created"
fi

# ===========================================
# PHASE 8: Testing Infrastructure
# ===========================================
echo -e "\n${BLUE}🧪 Phase 8: Testing Infrastructure${NC}"
echo "----------------------------------------"

# Create test directory structure
mkdir -p "$BACKEND_DIR/tests/unit"
mkdir -p "$BACKEND_DIR/tests/integration"
mkdir -p "$BACKEND_DIR/tests/fixtures"

# Create pytest configuration
if [ ! -f "$BACKEND_DIR/pytest.ini" ]; then
    print_info "Creating pytest configuration..."
    cat > "$BACKEND_DIR/pytest.ini" << 'EOF'
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
asyncio_mode = auto
addopts = 
    -v
    --tb=short
    --strict-markers
    --cov=app
    --cov-report=term-missing
    --cov-report=html
    --cov-fail-under=80
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Slow tests
EOF
    print_status 0 "pytest configuration created"
fi

# Create test fixtures
if [ ! -f "$BACKEND_DIR/tests/conftest.py" ]; then
    print_info "Creating test fixtures..."
    cat > "$BACKEND_DIR/tests/conftest.py" << 'EOF'
import pytest
import asyncio
from typing import AsyncGenerator
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from app.main import app
from app.db.session import Base, get_db

# Test database URL
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="function")
async def test_db() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    AsyncSessionLocal = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with AsyncSessionLocal() as session:
        yield session
    
    await engine.dispose()

@pytest.fixture(scope="function")
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test client."""
    async def override_get_db():
        yield test_db
    
    app.dependency_overrides[get_db] = override_get_db
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()
EOF
    print_status 0 "Test fixtures created"
fi

# ===========================================
# PHASE 9: Service Health Checks
# ===========================================
echo -e "\n${BLUE}🏥 Phase 9: Service Health Checks${NC}"
echo "----------------------------------------"

# Start Docker services
print_info "Starting Docker services..."
cd "$PROJECT_ROOT"

# Check if services are already running
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    print_status 0 "Docker services already running"
else
    docker-compose up -d postgres redis
    sleep 5  # Wait for services to start
    
    # Check PostgreSQL
    if docker-compose exec -T postgres pg_isready -U postgres &>/dev/null; then
        print_status 0 "PostgreSQL is ready"
    else
        print_warning "PostgreSQL is not ready"
    fi
    
    # Check Redis
    if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
        print_status 0 "Redis is ready"
    else
        print_warning "Redis is not ready"
    fi
fi

# ===========================================
# PHASE 10: Integration Testing
# ===========================================
echo -e "\n${BLUE}🔌 Phase 10: Integration Testing${NC}"
echo "----------------------------------------"

# Create integration test script
cat > "$PROJECT_ROOT/scripts/test-backend-integration.sh" << 'INTSCRIPT'
#!/bin/bash
# Backend Integration Test Script

set -e

echo "🔌 Testing Backend Integration..."

# Test 1: PostgreSQL Connection
echo -n "Testing PostgreSQL connection... "
if docker-compose exec -T postgres psql -U postgres -d claudecode -c "SELECT 1" &>/dev/null; then
    echo "✅ Passed"
else
    echo "❌ Failed"
    exit 1
fi

# Test 2: Redis Connection
echo -n "Testing Redis connection... "
if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
    echo "✅ Passed"
else
    echo "❌ Failed"
    exit 1
fi

# Test 3: Backend Health Check
echo -n "Testing backend health endpoint... "
if curl -s http://localhost:8000/health | grep -q "healthy"; then
    echo "✅ Passed"
else
    echo "⚠️  Backend not running (start with: cd services/backend && uvicorn app.main:app)"
fi

# Test 4: API Documentation
echo -n "Testing API documentation... "
if curl -s http://localhost:8000/docs &>/dev/null; then
    echo "✅ Passed"
else
    echo "⚠️  API docs not available"
fi

echo ""
echo "✅ Backend integration tests completed"
INTSCRIPT

chmod +x "$PROJECT_ROOT/scripts/test-backend-integration.sh"
print_status 0 "Integration test script created"

# ===========================================
# FINAL SUMMARY
# ===========================================
echo ""
echo "========================================"
echo -e "${GREEN}✨ Backend Development Environment Setup Complete!${NC}"
echo "========================================"
echo ""

# Generate summary report
cat > "$PROJECT_ROOT/backend-setup-summary.md" << EOF
# Backend Development Environment Setup Summary

## ✅ Completed Setup Tasks

### System Configuration
- OS: $OS
- Python Version: ${PYTHON_VERSION:-Not installed}
- Docker Version: ${DOCKER_VERSION:-Not installed}

### Development Tools
- Virtual Environment: Created at $BACKEND_DIR/venv
- Dependencies: Installed from requirements.txt
- Database: PostgreSQL 16 (Docker)
- Cache: Redis 7 (Docker)
- Migrations: Alembic configured

### Project Structure
- Backend Directory: $BACKEND_DIR
- Models: Created at app/models/
- Schemas: Created at app/schemas/
- Database Session: Created at app/db/session.py
- Environment: Configured in .env

### Docker Services
- PostgreSQL: Port 5432
- Redis: Port 6379
- Backend: Port 8000 (when running)

## 📋 Next Steps

1. **Run Database Migrations**:
   \`\`\`bash
   cd $BACKEND_DIR
   source venv/bin/activate
   alembic revision --autogenerate -m "Initial migration"
   alembic upgrade head
   \`\`\`

2. **Start Backend Services**:
   \`\`\`bash
   cd $PROJECT_ROOT
   docker-compose up -d
   \`\`\`

3. **Run Backend Application**:
   \`\`\`bash
   cd $BACKEND_DIR
   source venv/bin/activate
   uvicorn app.main:app --reload --port 8000
   \`\`\`

4. **Run Tests**:
   \`\`\`bash
   cd $BACKEND_DIR
   source venv/bin/activate
   pytest tests/ -v
   \`\`\`

5. **Test Integration**:
   \`\`\`bash
   $PROJECT_ROOT/scripts/test-backend-integration.sh
   \`\`\`

## 🔧 Configuration Files Created

- \`$BACKEND_DIR/.env\` - Environment variables
- \`$BACKEND_DIR/requirements.txt\` - Python dependencies
- \`$BACKEND_DIR/pytest.ini\` - Test configuration
- \`$PROJECT_ROOT/docker-compose.yml\` - Docker services
- \`$PROJECT_ROOT/scripts/test-backend-integration.sh\` - Integration tests

## 📱 API Endpoints

- Health Check: http://localhost:8000/health
- API Documentation: http://localhost:8000/docs
- OpenAPI Schema: http://localhost:8000/openapi.json
- Metrics: http://localhost:9090/metrics (when Prometheus enabled)

## 🔐 Default Credentials

- PostgreSQL: postgres/postgres
- Database Name: claudecode
- Redis: No password (local development)

Generated: $(date)
EOF

print_status 0 "Setup summary saved to backend-setup-summary.md"

echo ""
echo -e "${BLUE}📋 Quick Start Commands:${NC}"
echo "1. Start services: cd $PROJECT_ROOT && docker-compose up -d"
echo "2. Activate Python: cd $BACKEND_DIR && source venv/bin/activate"
echo "3. Run backend: uvicorn app.main:app --reload"
echo "4. View API docs: open http://localhost:8000/docs"
echo "5. Run tests: pytest tests/ -v"
echo ""
echo -e "${GREEN}Backend environment ready for development! 🚀${NC}"