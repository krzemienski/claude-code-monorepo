"""
Message model for chat sessions
"""

from sqlalchemy import Column, String, Text, JSON, DateTime, ForeignKey, Integer
from sqlalchemy.orm import relationship
from datetime import datetime

from app.db.session import Base


class Message(Base):
    """Message model for storing chat history"""
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True)
    session_id = Column(String, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    role = Column(String, nullable=False)  # "user", "assistant", "system"
    content = Column(Text, nullable=False)
    token_count = Column(Integer, default=0)
    message_metadata = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    session = relationship("Session", back_populates="messages")