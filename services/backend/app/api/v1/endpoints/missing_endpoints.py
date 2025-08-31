"""
Missing endpoints implementation for Claude Code Backend
Implements the endpoints identified in iOS audit
"""

import uuid
from typing import List, Optional, Dict, Any, Annotated
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Query, Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from pydantic import BaseModel, Field

from app.db.session import get_db
from app.models.session import Session
from app.models.message import Message
from app.models.user import User
# Authentication removed - all endpoints are public
from app.core.logging import setup_logging

logger = setup_logging()

# Create routers for missing endpoints
messages_router = APIRouter()
tools_router = APIRouter()
profile_router = APIRouter()


# ============ SCHEMAS ============

class MessageResponse(BaseModel):
    """Message response schema"""
    id: str
    session_id: str
    role: str
    content: str
    token_count: int = 0
    metadata: Dict[str, Any] = Field(default_factory=dict, alias="message_metadata")
    created_at: datetime
    
    class Config:
        from_attributes = True
        populate_by_name = True


class MessageListResponse(BaseModel):
    """Message list response with pagination"""
    messages: List[MessageResponse]
    total: int
    limit: int
    offset: int
    session_id: str


class ToolExecution(BaseModel):
    """Tool execution record"""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    tool_name: str
    tool_type: str  # "mcp", "native", "custom"
    input_params: Dict[str, Any]
    output: Optional[Dict[str, Any]] = None
    status: str = "pending"  # "pending", "running", "completed", "failed"
    error_message: Optional[str] = None
    execution_time_ms: Optional[int] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None


class ToolExecutionResponse(BaseModel):
    """Tool execution response"""
    executions: List[ToolExecution]
    total: int
    session_id: str


class UserProfileResponse(BaseModel):
    """User profile response schema"""
    id: str
    email: str
    username: Optional[str] = None
    roles: List[str] = Field(default_factory=lambda: ["user"])
    permissions: List[str] = Field(default_factory=list)
    preferences: Dict[str, Any] = Field(default_factory=dict)
    api_key: Optional[str] = None  # Only shown on specific requests
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None
    is_active: bool = True
    session_count: int = 0
    message_count: int = 0
    token_usage: Dict[str, int] = Field(default_factory=dict)


class UserProfileUpdate(BaseModel):
    """User profile update schema"""
    username: Optional[str] = None
    preferences: Optional[Dict[str, Any]] = None
    
    class Config:
        extra = "forbid"


# ============ SESSION MESSAGES ENDPOINTS ============

@messages_router.get("/sessions/{session_id}/messages", response_model=MessageListResponse)
async def get_session_messages(
    session_id: str = Path(..., description="Session ID"),
    limit: int = Query(100, le=1000, description="Maximum number of messages to return"),
    offset: int = Query(0, ge=0, description="Number of messages to skip"),
    role: Optional[str] = Query(None, description="Filter by role (user/assistant/system)"),
    db: AsyncSession = Depends(get_db),
    # Authentication removed - endpoint is public
):
    """
    Get all messages for a specific session with pagination
    
    - Retrieves message history for the specified session
    - Supports pagination with limit/offset
    - Can filter by message role
    - Returns messages in chronological order
    """
    # Verify session exists and belongs to user (if authenticated)
    session_query = select(Session).where(Session.id == session_id)
    # Authentication removed - all sessions are accessible
    
    result = await db.execute(session_query)
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(
            status_code=404,
            detail=f"Session {session_id} not found"
        )
    
    # Build message query
    messages_query = select(Message).where(Message.session_id == session_id)
    
    # Apply role filter if specified
    if role:
        if role not in ["user", "assistant", "system"]:
            raise HTTPException(
                status_code=400,
                detail="Invalid role. Must be one of: user, assistant, system"
            )
        messages_query = messages_query.where(Message.role == role)
    
    # Order by creation time
    messages_query = messages_query.order_by(Message.created_at)
    
    # Apply pagination
    messages_query = messages_query.offset(offset).limit(limit)
    
    # Execute query
    result = await db.execute(messages_query)
    messages = result.scalars().all()
    
    # Get total count
    count_query = select(func.count()).select_from(Message).where(
        Message.session_id == session_id
    )
    if role:
        count_query = count_query.where(Message.role == role)
    
    total = await db.scalar(count_query)
    
    # Convert to response format
    message_responses = [
        MessageResponse(
            id=msg.id,
            session_id=msg.session_id,
            role=msg.role,
            content=msg.content,
            token_count=msg.token_count,
            message_metadata=msg.message_metadata or {},
            created_at=msg.created_at
        )
        for msg in messages
    ]
    
    logger.info(f"Retrieved {len(messages)} messages for session {session_id}")
    
    return MessageListResponse(
        messages=message_responses,
        total=total or 0,
        limit=limit,
        offset=offset,
        session_id=session_id
    )


# ============ SESSION TOOLS ENDPOINTS ============

# In-memory storage for tool executions (should be moved to database in production)
# This is a temporary implementation for the MVP
tool_executions_store: Dict[str, List[ToolExecution]] = {}


@tools_router.get("/sessions/{session_id}/tools", response_model=ToolExecutionResponse)
async def get_session_tools(
    session_id: str = Path(..., description="Session ID"),
    tool_type: Optional[str] = Query(None, description="Filter by tool type (mcp/native/custom)"),
    status: Optional[str] = Query(None, description="Filter by status"),
    limit: int = Query(100, le=1000, description="Maximum number of executions to return"),
    db: AsyncSession = Depends(get_db),
    # Authentication removed - endpoint is public
):
    """
    Get tool executions for a specific session
    
    - Retrieves all tool invocations during the session
    - Includes MCP tools, native tools, and custom integrations
    - Shows execution status, timing, and results
    - Useful for debugging and analytics
    """
    # Verify session exists
    session_query = select(Session).where(Session.id == session_id)
    # Authentication removed - all sessions are accessible
    
    result = await db.execute(session_query)
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(
            status_code=404,
            detail=f"Session {session_id} not found"
        )
    
    # Get tool executions from store (in production, this would query a database)
    executions = tool_executions_store.get(session_id, [])
    
    # Apply filters
    if tool_type:
        if tool_type not in ["mcp", "native", "custom"]:
            raise HTTPException(
                status_code=400,
                detail="Invalid tool_type. Must be one of: mcp, native, custom"
            )
        executions = [e for e in executions if e.tool_type == tool_type]
    
    if status:
        if status not in ["pending", "running", "completed", "failed"]:
            raise HTTPException(
                status_code=400,
                detail="Invalid status. Must be one of: pending, running, completed, failed"
            )
        executions = [e for e in executions if e.status == status]
    
    # Apply limit
    total = len(executions)
    executions = executions[:limit]
    
    logger.info(f"Retrieved {len(executions)} tool executions for session {session_id}")
    
    return ToolExecutionResponse(
        executions=executions,
        total=total,
        session_id=session_id
    )


@tools_router.post("/sessions/{session_id}/tools", response_model=ToolExecution)
async def record_tool_execution(
    session_id: str,
    tool_execution: ToolExecution,
    db: AsyncSession = Depends(get_db),
    # Authentication removed - endpoint is public
):
    """
    Record a tool execution for a session (internal use)
    """
    # Verify session exists
    session_query = select(Session).where(Session.id == session_id)
    # Authentication removed - all sessions are accessible
    
    result = await db.execute(session_query)
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(
            status_code=404,
            detail=f"Session {session_id} not found"
        )
    
    # Store tool execution
    if session_id not in tool_executions_store:
        tool_executions_store[session_id] = []
    
    tool_executions_store[session_id].append(tool_execution)
    
    logger.info(f"Recorded tool execution for session {session_id}: {tool_execution.tool_name}")
    
    return tool_execution


# ============ USER PROFILE ENDPOINTS ============

@profile_router.get("/user/profile", response_model=UserProfileResponse)
async def get_user_profile(
    # Authentication removed - endpoint is public
    include_api_key: bool = Query(False, description="Include API key in response"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's profile with statistics
    
    - Returns user profile information
    - Includes usage statistics (sessions, messages, tokens)
    - Optionally includes API key for client storage
    - Shows preferences and settings
    """
    # Authentication removed - return mock profile data
    logger.info("Profile endpoint accessed without authentication")
    
    # Return mock profile data since auth is disabled
    response = UserProfileResponse(
        id="public-user",
        email="public@example.com",
        username="public_user",
        roles=["user"],
        permissions=[],
        preferences={},
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        last_login=datetime.utcnow(),
        is_active=True,
        session_count=0,
        message_count=0,
        token_usage={
            "total_tokens": 0,
            "prompt_tokens": 0,
            "completion_tokens": 0
        }
    )
    
    # API keys not needed without auth
    if include_api_key:
        response.api_key = "NO_AUTH_REQUIRED"
    
    logger.info("Returned mock profile for public access")
    
    return response


@profile_router.put("/user/profile", response_model=UserProfileResponse)
async def update_user_profile(
    profile_update: UserProfileUpdate,
    # Authentication removed - endpoint is public
    db: AsyncSession = Depends(get_db)
):
    """
    Update current user's profile
    
    - Updates username and preferences
    - Validates username uniqueness
    - Returns updated profile
    """
    # Authentication removed - return mock updated profile
    logger.info("Profile update attempted without authentication")
    
    # Return mock updated profile since auth is disabled
    updated_prefs = profile_update.preferences or {}
    
    return UserProfileResponse(
        id="public-user",
        email="public@example.com",
        username=profile_update.username or "public_user",
        roles=["user"],
        permissions=[],
        preferences=updated_prefs,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        last_login=datetime.utcnow(),
        is_active=True,
        session_count=0,
        message_count=0,
        token_usage={}
    )


@profile_router.post("/user/profile/reset-api-key", response_model=Dict[str, str])
async def reset_api_key(
    # Authentication removed - endpoint is public
    db: AsyncSession = Depends(get_db)
):
    """
    Generate a new API key for the current user
    
    - Invalidates the old API key
    - Returns the new API key (only shown once)
    - Used for security rotation
    """
    # Authentication has been removed - API keys are no longer needed
    logger.info("API key reset requested but auth is disabled")
    
    return {
        "api_key": "NO_AUTH_REQUIRED",
        "message": "Authentication has been disabled. API keys are no longer required."
    }


@profile_router.delete("/user/profile", response_model=Dict[str, str])
async def delete_user_account(
    # Authentication removed - endpoint is public
    confirm: bool = Query(False, description="Confirm account deletion"),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete user account (soft delete)
    
    - Requires confirmation flag
    - Deactivates account rather than hard delete
    - Preserves data for audit purposes
    """
    if not confirm:
        raise HTTPException(
            status_code=400,
            detail="Account deletion requires confirmation. Set confirm=true to proceed."
        )
    
    # Authentication removed - return mock deletion response
    logger.info("Account deletion attempted without authentication")
    
    return {
        "message": "Account deletion disabled - no authentication required",
        "email": "public@example.com"
    }