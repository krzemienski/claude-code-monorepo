"""Session model for SQLAlchemy ORM."""

from typing import Optional
from uuid import uuid4
from enum import Enum

from sqlalchemy import Boolean, ForeignKey, String, Text, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin


class SessionStatus(str, Enum):
    """Session status enumeration"""
    ACTIVE = "active"
    IDLE = "idle"  
    STREAMING = "streaming"
    ARCHIVED = "archived"
    ERROR = "error"


class Session(Base, TimestampMixin):
    """Session model for chat sessions."""
    
    __tablename__ = "sessions"
    
    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid4())
    )
    
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True
    )
    
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=True
    )
    
    model: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="claude-3-opus-20240229"
    )
    
    status: Mapped[SessionStatus] = mapped_column(
        SQLEnum(SessionStatus),
        default=SessionStatus.ACTIVE,
        nullable=False
    )
    
    context: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True
    )
    
    session_metadata: Mapped[Optional[dict]] = mapped_column(
        JSON,
        nullable=True,
        default=dict
    )
    
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False
    )
    
    user_id: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        default="default"
    )
    
    project_id: Mapped[Optional[str]] = mapped_column(
        String,
        nullable=True,
        index=True
    )
    
    # Relationships
    messages = relationship("Message", back_populates="session", cascade="all, delete-orphan")
    
    def __repr__(self) -> str:
        return f"<Session(id={self.id}, name={self.name}, status={self.status})>"