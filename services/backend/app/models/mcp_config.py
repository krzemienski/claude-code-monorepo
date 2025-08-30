"""MCP Configuration model for SQLAlchemy ORM."""

from typing import Optional
from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin


class MCPConfig(Base, TimestampMixin):
    """MCP Configuration model for storing MCP server configurations."""
    
    __tablename__ = "mcp_configs"
    
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
    
    server_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True
    )
    
    config: Mapped[dict] = mapped_column(
        JSON,
        nullable=False,
        default=dict
    )
    
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False
    )
    
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True
    )
    
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="mcp_configs"
    )
    
    def __repr__(self) -> str:
        return f"<MCPConfig(id={self.id}, name={self.name}, type={self.server_type})>"