"""
Sessions API endpoints
Manages chat session lifecycle, streaming control, and metrics
"""

import uuid
import asyncio
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any

from fastapi import APIRouter, HTTPException, Depends, Query, BackgroundTasks
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func

from app.db.session import get_db
from app.models.session import Session, SessionStatus
from app.schemas.session import (
    SessionCreate,
    SessionResponse,
    SessionUpdate,
    SessionStats,
    SessionList
)
from app.core.config import settings
from app.services.session_manager import SessionManager
# Authentication removed - all endpoints are public

router = APIRouter()

# Session manager instance
session_manager = SessionManager()


@router.post("", response_model=SessionResponse)
async def create_session(
    session_data: SessionCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new chat session
    """
    # Create session in database
    session = Session(
        id=str(uuid.uuid4()),
        user_id="default-user",  # No auth - using default user
        project_id=session_data.project_id,
        name=session_data.name or f"Session {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        model=session_data.model or settings.ANTHROPIC_MODEL,
        status=SessionStatus.ACTIVE,
        metadata=session_data.metadata or {},
    )
    
    db.add(session)
    await db.commit()
    await db.refresh(session)
    
    # Initialize in session manager
    session_dict = {
        "id": session.id,
        "user_id": session.user_id,
        "project_id": session.project_id,
        "name": session.name,
        "model": session.model,
        "status": session.status.value if hasattr(session.status, 'value') else session.status,
        "metadata": session.metadata
    }
    await session_manager.create_session(session.id, session_dict)
    
    return SessionResponse.model_validate(session)


@router.get("", response_model=SessionList)
async def list_sessions(
    project_id: Optional[str] = Query(None),
    status: Optional[SessionStatus] = Query(None),
    limit: int = Query(100, le=1000),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    List all sessions with optional filtering
    """
    query = select(Session).where(Session.user_id == "default-user")
    
    if project_id:
        query = query.where(Session.project_id == project_id)
    if status:
        query = query.where(Session.status == status)
    
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    sessions = result.scalars().all()
    
    # Get total count
    count_query = select(func.count()).select_from(Session).where(
        Session.user_id == "default-user"
    )
    if project_id:
        count_query = count_query.where(Session.project_id == project_id)
    if status:
        count_query = count_query.where(Session.status == status)
    
    total = await db.scalar(count_query)
    
    return SessionList(
        sessions=[SessionResponse.from_orm(s) for s in sessions],
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{session_id}", response_model=SessionResponse)
async def get_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Get a specific session by ID
    """
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return SessionResponse.model_validate(session)


@router.patch("/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: str,
    session_update: SessionUpdate,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Update session properties
    """
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Update fields
    update_data = session_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(session, field, value)
    
    # Updated_at is handled by the model
    
    await db.commit()
    await db.refresh(session)
    
    # Update in session manager
    await session_manager.update_session(session_id, update_data)
    
    return SessionResponse.model_validate(session)


@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Delete a session
    """
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Stop any active streaming
    await session_manager.stop_streaming(session_id)
    
    # Delete from database
    await db.delete(session)
    await db.commit()
    
    # Remove from session manager
    await session_manager.remove_session(session_id)
    
    return {"message": "Session deleted successfully"}


@router.post("/{session_id}/stop")
async def stop_session_streaming(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Stop active streaming for a session
    This endpoint interrupts any ongoing SSE stream for the specified session
    """
    # Verify session exists and belongs to user
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Stop streaming in session manager
    stopped = await session_manager.stop_streaming(session_id)
    
    if not stopped:
        return {
            "message": "No active streaming found for session",
            "session_id": session_id,
            "status": "idle"
        }
    
    # Update session status
    session.status = SessionStatus.IDLE
    # Updated_at is handled by the model
    await db.commit()
    
    return {
        "message": "Streaming stopped successfully",
        "session_id": session_id,
        "status": "stopped"
    }


@router.get("/{session_id}/stats", response_model=SessionStats)
async def get_session_stats(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Get detailed statistics and metrics for a session
    """
    # Verify session exists
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Get stats from session manager
    stats = await session_manager.get_session_stats(session_id)
    
    # Calculate additional metrics
    now = datetime.utcnow()
    duration = (now - session.created_at).total_seconds()
    
    # Get message count from database
    message_count = await db.scalar(
        select(func.count()).select_from(Message).where(
            Message.session_id == session_id
        )
    )
    
    # Get token usage from session metadata
    token_usage = session.metadata.get("token_usage", {})
    
    return SessionStats(
        session_id=session_id,
        created_at=session.created_at,
        updated_at=session.updated_at,
        status=session.status,
        duration_seconds=duration,
        message_count=message_count,
        token_usage={
            "prompt_tokens": token_usage.get("prompt_tokens", 0),
            "completion_tokens": token_usage.get("completion_tokens", 0),
            "total_tokens": token_usage.get("total_tokens", 0)
        },
        model=session.model,
        active_tools=stats.get("active_tools", []),
        tool_invocations=stats.get("tool_invocations", 0),
        error_count=stats.get("error_count", 0),
        average_response_time=stats.get("average_response_time", 0),
        memory_usage=stats.get("memory_usage", {}),
        metadata=session.metadata
    )


@router.post("/{session_id}/clear")
async def clear_session_history(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Clear message history for a session while keeping the session active
    """
    # Verify session exists
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Clear messages from database
    await db.execute(
        delete(Message).where(Message.session_id == session_id)
    )
    
    # Reset session metadata
    session.metadata["message_count"] = 0
    session.metadata["token_usage"] = {
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_tokens": 0
    }
    # Updated_at is handled by the model
    
    await db.commit()
    
    # Clear in session manager
    await session_manager.clear_session_history(session_id)
    
    return {
        "message": "Session history cleared successfully",
        "session_id": session_id
    }


@router.post("/{session_id}/archive")
async def archive_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    # Auth removed
):
    """
    Archive a session (mark as archived, stop streaming)
    """
    # Verify session exists
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == "default-user"
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Stop any active streaming
    await session_manager.stop_streaming(session_id)
    
    # Update session status
    session.status = SessionStatus.ARCHIVED
    # Updated_at is handled by the model
    
    await db.commit()
    
    return {
        "message": "Session archived successfully",
        "session_id": session_id,
        "status": "archived"
    }


# Import Message model
from app.models.message import Message