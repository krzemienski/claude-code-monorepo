"""
Analytics model for tracking events and metrics
"""

from enum import Enum
from sqlalchemy import Column, String, Text, JSON, DateTime, Float, Integer
from datetime import datetime

from app.db.session import Base


class EventType(str, Enum):
    """Analytics event types"""
    SESSION_CREATED = "session_created"
    SESSION_COMPLETED = "session_completed"
    MESSAGE_SENT = "message_sent"
    TOOL_EXECUTED = "tool_executed"
    ERROR_OCCURRED = "error_occurred"
    API_CALLED = "api_called"
    USER_ACTION = "user_action"


class AnalyticsEvent(Base):
    """Analytics event model for tracking user actions and system metrics"""
    __tablename__ = "analytics_events"
    
    id = Column(String, primary_key=True)
    event_type = Column(String, nullable=False)
    user_id = Column(String)
    session_id = Column(String)
    project_id = Column(String)
    
    # Event details
    event_data = Column(JSON, default=dict)
    event_metadata = Column(JSON, default=dict)
    
    # Metrics
    duration_ms = Column(Float)
    token_count = Column(Integer)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f"<AnalyticsEvent {self.event_type} at {self.created_at}>"