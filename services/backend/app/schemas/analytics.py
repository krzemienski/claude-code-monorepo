"""
Analytics schemas for request/response validation
"""

from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field

from app.models.analytics import EventType


class AnalyticsEventBase(BaseModel):
    """Base analytics event schema"""
    event_type: EventType
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    project_id: Optional[str] = None
    event_data: Dict[str, Any] = Field(default_factory=dict)
    event_metadata: Dict[str, Any] = Field(default_factory=dict)
    duration_ms: Optional[float] = None
    token_count: Optional[int] = None


class AnalyticsEventCreate(AnalyticsEventBase):
    """Schema for creating analytics events"""
    pass


class AnalyticsEventResponse(AnalyticsEventBase):
    """Schema for analytics event response"""
    id: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class SessionAnalytics(BaseModel):
    """Session analytics summary"""
    session_id: str
    total_messages: int
    total_tokens: int
    average_response_time: float
    error_rate: float
    tool_usage_count: int
    duration_seconds: float
    created_at: datetime
    last_activity: datetime


class UserAnalytics(BaseModel):
    """User analytics summary"""
    user_id: str
    total_sessions: int
    total_messages: int
    total_tokens: int
    average_session_duration: float
    most_used_tools: List[str]
    activity_by_day: Dict[str, int]
    created_at: datetime
    last_activity: datetime


class SystemAnalytics(BaseModel):
    """System-wide analytics"""
    total_users: int
    total_sessions: int
    total_messages: int
    total_tokens: int
    average_response_time: float
    error_rate: float
    active_users_today: int
    active_sessions_today: int
    popular_tools: List[Dict[str, Any]]
    peak_usage_hour: int


class ToolUsage(BaseModel):
    """Tool usage statistics"""
    tool_name: str
    tool_type: str
    usage_count: int
    success_rate: float
    average_execution_time: float
    last_used: datetime


class AnalyticsResponse(BaseModel):
    """General analytics response"""
    data: Dict[str, Any]
    period: str
    generated_at: datetime = Field(default_factory=datetime.utcnow)


class UsageStats(BaseModel):
    """Usage statistics summary"""
    total_sessions: int
    total_messages: int
    total_tokens: int
    active_users: int
    average_session_duration: float
    period: str


class TokenUsage(BaseModel):
    """Token usage statistics"""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    cost_estimate: Optional[float] = None


class TimeSeriesData(BaseModel):
    """Time series data point"""
    timestamp: datetime
    value: float
    label: Optional[str] = None