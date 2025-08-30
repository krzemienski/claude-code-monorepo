"""
Session schemas for request/response models
"""

from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


class SessionStatus(str, Enum):
    """Session status enum"""
    ACTIVE = "active"
    IDLE = "idle"
    STREAMING = "streaming"
    ARCHIVED = "archived"
    ERROR = "error"


class SessionCreate(BaseModel):
    """Session creation request"""
    project_id: Optional[str] = None
    name: Optional[str] = None
    model: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict)


class SessionUpdate(BaseModel):
    """Session update request"""
    name: Optional[str] = None
    status: Optional[SessionStatus] = None
    metadata: Optional[Dict[str, Any]] = None


class SessionResponse(BaseModel):
    """Session response model"""
    id: str
    user_id: str
    project_id: Optional[str]
    name: str
    model: str
    status: SessionStatus
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
        use_enum_values = True


class SessionStats(BaseModel):
    """Session statistics"""
    session_id: str
    created_at: datetime
    updated_at: datetime
    status: SessionStatus
    duration_seconds: float
    message_count: int
    token_usage: Dict[str, int]
    model: str
    active_tools: List[str]
    tool_invocations: int
    error_count: int
    average_response_time: float
    memory_usage: Dict[str, Any]
    metadata: Dict[str, Any]


class SessionList(BaseModel):
    """List of sessions response"""
    sessions: List[SessionResponse]
    total: int
    limit: int
    offset: int