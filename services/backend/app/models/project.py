"""Project model for SQLAlchemy ORM."""

from typing import List, Optional
from uuid import uuid4

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin


class Project(Base, TimestampMixin):
    """Project model for user projects."""
    
    __tablename__ = "projects"
    
    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid4())
    )
    
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True
    )
    
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True
    )
    
    path: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )
    
    settings: Mapped[Optional[dict]] = mapped_column(
        JSON,
        nullable=True,
        default=dict
    )
    
    owner_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    # Relationships
    owner: Mapped["User"] = relationship(
        "User",
        back_populates="projects"
    )
    
    sessions: Mapped[List["Session"]] = relationship(
        "Session",
        back_populates="project",
        cascade="all, delete-orphan"
    )
    
    def __repr__(self) -> str:
        return f"<Project(id={self.id}, name={self.name})>"