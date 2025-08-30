"""
Analytics API endpoints
Provides usage analytics, metrics aggregation, and reporting
"""

from datetime import datetime, timedelta, date
from typing import Dict, Any, List, Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, cast, Date

from app.db.session import get_db
from app.models.session import Session, SessionStatus
from app.models.message import Message
from app.models.analytics import AnalyticsEvent, EventType
from app.schemas.analytics import (
    AnalyticsResponse,
    UsageStats,
    TokenUsage,
    ToolUsage,
    SessionAnalytics,
    TimeSeriesData
)
# Authentication removed - all endpoints are public
from app.core.config import settings

router = APIRouter()


@router.get("/usage", response_model=UsageStats)
async def get_usage_stats(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    project_id: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get usage statistics for the current user
    """
    user_id = "default-user"
    
    # Default to last 30 days if no dates provided
    if not end_date:
        end_date = date.today()
    if not start_date:
        start_date = end_date - timedelta(days=30)
    
    # Build base query
    session_query = select(Session).where(
        and_(
            Session.user_id == user_id,
            Session.created_at >= start_date,
            Session.created_at <= end_date + timedelta(days=1)
        )
    )
    
    if project_id:
        session_query = session_query.where(Session.project_id == project_id)
    
    # Get session statistics
    result = await db.execute(session_query)
    sessions = result.scalars().all()
    
    total_sessions = len(sessions)
    active_sessions = len([s for s in sessions if s.status == SessionStatus.ACTIVE])
    
    # Calculate token usage
    total_tokens = 0
    prompt_tokens = 0
    completion_tokens = 0
    
    for session in sessions:
        token_data = session.metadata.get("token_usage", {})
        total_tokens += token_data.get("total_tokens", 0)
        prompt_tokens += token_data.get("prompt_tokens", 0)
        completion_tokens += token_data.get("completion_tokens", 0)
    
    # Get message count
    message_count = 0
    for session in sessions:
        count = await db.scalar(
            select(func.count()).select_from(Message).where(
                Message.session_id == session.id
            )
        )
        message_count += count
    
    # Calculate average session duration
    total_duration = 0
    session_count = 0
    
    for session in sessions:
        if session.updated_at and session.created_at:
            duration = (session.updated_at - session.created_at).total_seconds()
            total_duration += duration
            session_count += 1
    
    avg_session_duration = total_duration / session_count if session_count > 0 else 0
    
    # Get unique projects
    unique_projects = len(set(s.project_id for s in sessions if s.project_id))
    
    return UsageStats(
        user_id=user_id,
        period={
            "start": start_date.isoformat(),
            "end": end_date.isoformat()
        },
        total_sessions=total_sessions,
        active_sessions=active_sessions,
        total_messages=message_count,
        total_tokens=total_tokens,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        unique_projects=unique_projects,
        average_session_duration=avg_session_duration,
        estimated_cost=calculate_cost(prompt_tokens, completion_tokens, settings.ANTHROPIC_MODEL)
    )


@router.get("/tokens", response_model=TokenUsage)
async def get_token_usage(
    period: str = Query("day", regex="^(hour|day|week|month)$"),
    project_id: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get detailed token usage breakdown
    """
    user_id = "default-user"
    
    # Calculate date range based on period
    end_date = datetime.utcnow()
    if period == "hour":
        start_date = end_date - timedelta(hours=1)
    elif period == "day":
        start_date = end_date - timedelta(days=1)
    elif period == "week":
        start_date = end_date - timedelta(weeks=1)
    else:  # month
        start_date = end_date - timedelta(days=30)
    
    # Query sessions
    query = select(Session).where(
        and_(
            Session.user_id == user_id,
            Session.created_at >= start_date,
            Session.created_at <= end_date
        )
    )
    
    if project_id:
        query = query.where(Session.project_id == project_id)
    
    result = await db.execute(query)
    sessions = result.scalars().all()
    
    # Aggregate token usage by model
    usage_by_model = {}
    total_prompt = 0
    total_completion = 0
    
    for session in sessions:
        model = session.model or "unknown"
        token_data = session.metadata.get("token_usage", {})
        
        if model not in usage_by_model:
            usage_by_model[model] = {
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0,
                "sessions": 0
            }
        
        usage_by_model[model]["prompt_tokens"] += token_data.get("prompt_tokens", 0)
        usage_by_model[model]["completion_tokens"] += token_data.get("completion_tokens", 0)
        usage_by_model[model]["total_tokens"] += token_data.get("total_tokens", 0)
        usage_by_model[model]["sessions"] += 1
        
        total_prompt += token_data.get("prompt_tokens", 0)
        total_completion += token_data.get("completion_tokens", 0)
    
    # Calculate costs
    total_cost = 0
    for model, usage in usage_by_model.items():
        cost = calculate_cost(usage["prompt_tokens"], usage["completion_tokens"], model)
        usage["estimated_cost"] = cost
        total_cost += cost
    
    return TokenUsage(
        period=period,
        start_date=start_date,
        end_date=end_date,
        total_prompt_tokens=total_prompt,
        total_completion_tokens=total_completion,
        total_tokens=total_prompt + total_completion,
        usage_by_model=usage_by_model,
        estimated_total_cost=total_cost
    )


@router.get("/tools", response_model=ToolUsage)
async def get_tool_usage(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get MCP tool usage statistics
    """
    user_id = "default-user"
    
    # Default to last 7 days
    if not end_date:
        end_date = date.today()
    if not start_date:
        start_date = end_date - timedelta(days=7)
    
    # Query analytics events for tool usage
    result = await db.execute(
        select(AnalyticsEvent).where(
            and_(
                AnalyticsEvent.user_id == user_id,
                AnalyticsEvent.event_type == EventType.TOOL_INVOCATION,
                AnalyticsEvent.created_at >= start_date,
                AnalyticsEvent.created_at <= end_date + timedelta(days=1)
            )
        )
    )
    events = result.scalars().all()
    
    # Aggregate tool usage
    tool_stats = {}
    total_invocations = len(events)
    
    for event in events:
        tool_name = event.metadata.get("tool_name", "unknown")
        server_id = event.metadata.get("server_id", "unknown")
        success = event.metadata.get("success", True)
        duration = event.metadata.get("duration_ms", 0)
        
        if tool_name not in tool_stats:
            tool_stats[tool_name] = {
                "invocations": 0,
                "successes": 0,
                "failures": 0,
                "average_duration_ms": 0,
                "total_duration_ms": 0,
                "servers": set()
            }
        
        tool_stats[tool_name]["invocations"] += 1
        if success:
            tool_stats[tool_name]["successes"] += 1
        else:
            tool_stats[tool_name]["failures"] += 1
        
        tool_stats[tool_name]["total_duration_ms"] += duration
        tool_stats[tool_name]["servers"].add(server_id)
    
    # Calculate averages and format response
    formatted_stats = []
    for tool_name, stats in tool_stats.items():
        avg_duration = stats["total_duration_ms"] / stats["invocations"] if stats["invocations"] > 0 else 0
        
        formatted_stats.append({
            "tool_name": tool_name,
            "invocations": stats["invocations"],
            "success_rate": stats["successes"] / stats["invocations"] if stats["invocations"] > 0 else 0,
            "average_duration_ms": avg_duration,
            "servers": list(stats["servers"])
        })
    
    # Sort by invocation count
    formatted_stats.sort(key=lambda x: x["invocations"], reverse=True)
    
    return ToolUsage(
        period={
            "start": start_date.isoformat(),
            "end": end_date.isoformat()
        },
        total_invocations=total_invocations,
        unique_tools=len(tool_stats),
        tools=formatted_stats[:20]  # Top 20 tools
    )


@router.get("/sessions/{session_id}", response_model=SessionAnalytics)
async def get_session_analytics(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get detailed analytics for a specific session
    """
    # Get session
    result = await db.execute(
        select(Session).where(
            and_(
                Session.id == session_id,
                Session.user_id == "default-user"
            )
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Get messages
    result = await db.execute(
        select(Message).where(Message.session_id == session_id)
        .order_by(Message.created_at)
    )
    messages = result.scalars().all()
    
    # Calculate metrics
    message_count = len(messages)
    
    # Token usage over time
    token_timeline = []
    cumulative_tokens = 0
    
    for message in messages:
        if message.metadata:
            tokens = message.metadata.get("tokens", 0)
            cumulative_tokens += tokens
            token_timeline.append({
                "timestamp": message.created_at.isoformat(),
                "tokens": tokens,
                "cumulative": cumulative_tokens
            })
    
    # Response times
    response_times = []
    for i in range(1, len(messages), 2):  # Assuming alternating user/assistant
        if i < len(messages):
            response_time = (messages[i].created_at - messages[i-1].created_at).total_seconds()
            response_times.append(response_time)
    
    avg_response_time = sum(response_times) / len(response_times) if response_times else 0
    
    # Tool invocations
    tool_events = await db.execute(
        select(AnalyticsEvent).where(
            and_(
                AnalyticsEvent.session_id == session_id,
                AnalyticsEvent.event_type == EventType.TOOL_INVOCATION
            )
        )
    )
    tool_invocations = tool_events.scalars().all()
    
    tools_used = {}
    for event in tool_invocations:
        tool_name = event.metadata.get("tool_name", "unknown")
        tools_used[tool_name] = tools_used.get(tool_name, 0) + 1
    
    # Session duration
    duration = (session.updated_at - session.created_at).total_seconds() if session.updated_at else 0
    
    return SessionAnalytics(
        session_id=session_id,
        created_at=session.created_at,
        updated_at=session.updated_at,
        status=session.status,
        model=session.model,
        message_count=message_count,
        token_usage=session.metadata.get("token_usage", {}),
        duration_seconds=duration,
        average_response_time=avg_response_time,
        tools_used=tools_used,
        token_timeline=token_timeline,
        metadata=session.metadata
    )


@router.get("/timeseries", response_model=TimeSeriesData)
async def get_timeseries_data(
    metric: str = Query(..., regex="^(sessions|messages|tokens|errors)$"),
    period: str = Query("day", regex="^(hour|day|week|month)$"),
    project_id: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    
):
    """
    Get time series data for various metrics
    """
    user_id = "default-user"
    
    # Calculate date range
    end_date = datetime.utcnow()
    if period == "hour":
        start_date = end_date - timedelta(hours=24)
        interval = timedelta(hours=1)
    elif period == "day":
        start_date = end_date - timedelta(days=7)
        interval = timedelta(days=1)
    elif period == "week":
        start_date = end_date - timedelta(weeks=4)
        interval = timedelta(weeks=1)
    else:  # month
        start_date = end_date - timedelta(days=365)
        interval = timedelta(days=30)
    
    # Generate time buckets
    buckets = []
    current = start_date
    while current <= end_date:
        buckets.append(current)
        current += interval
    
    # Query data based on metric
    data_points = []
    
    if metric == "sessions":
        for i in range(len(buckets) - 1):
            count = await db.scalar(
                select(func.count()).select_from(Session).where(
                    and_(
                        Session.user_id == user_id,
                        Session.created_at >= buckets[i],
                        Session.created_at < buckets[i + 1]
                    )
                )
            )
            data_points.append({
                "timestamp": buckets[i].isoformat(),
                "value": count
            })
    
    elif metric == "messages":
        # Need to join with sessions to filter by user
        for i in range(len(buckets) - 1):
            result = await db.execute(
                select(func.count()).select_from(Message)
                .join(Session, Message.session_id == Session.id)
                .where(
                    and_(
                        Session.user_id == user_id,
                        Message.created_at >= buckets[i],
                        Message.created_at < buckets[i + 1]
                    )
                )
            )
            count = result.scalar() or 0
            data_points.append({
                "timestamp": buckets[i].isoformat(),
                "value": count
            })
    
    elif metric == "tokens":
        for i in range(len(buckets) - 1):
            result = await db.execute(
                select(Session).where(
                    and_(
                        Session.user_id == user_id,
                        Session.created_at >= buckets[i],
                        Session.created_at < buckets[i + 1]
                    )
                )
            )
            sessions = result.scalars().all()
            
            total_tokens = sum(
                s.metadata.get("token_usage", {}).get("total_tokens", 0)
                for s in sessions
            )
            
            data_points.append({
                "timestamp": buckets[i].isoformat(),
                "value": total_tokens
            })
    
    elif metric == "errors":
        for i in range(len(buckets) - 1):
            count = await db.scalar(
                select(func.count()).select_from(AnalyticsEvent).where(
                    and_(
                        AnalyticsEvent.user_id == user_id,
                        AnalyticsEvent.event_type == EventType.ERROR,
                        AnalyticsEvent.created_at >= buckets[i],
                        AnalyticsEvent.created_at < buckets[i + 1]
                    )
                )
            )
            data_points.append({
                "timestamp": buckets[i].isoformat(),
                "value": count
            })
    
    return TimeSeriesData(
        metric=metric,
        period=period,
        start_date=start_date,
        end_date=end_date,
        data_points=data_points
    )


def calculate_cost(prompt_tokens: int, completion_tokens: int, model: str) -> float:
    """
    Calculate estimated cost based on token usage and model
    """
    # Pricing per 1M tokens (as of 2024)
    pricing = {
        "claude-3-opus": {"prompt": 15.0, "completion": 75.0},
        "claude-3-sonnet": {"prompt": 3.0, "completion": 15.0},
        "claude-3-haiku": {"prompt": 0.25, "completion": 1.25},
        "claude-2.1": {"prompt": 8.0, "completion": 24.0},
        "claude-2": {"prompt": 8.0, "completion": 24.0}
    }
    
    # Get model family
    model_family = "claude-3-sonnet"  # default
    for key in pricing.keys():
        if key in model.lower():
            model_family = key
            break
    
    rates = pricing.get(model_family, pricing["claude-3-sonnet"])
    
    # Calculate cost
    prompt_cost = (prompt_tokens / 1_000_000) * rates["prompt"]
    completion_cost = (completion_tokens / 1_000_000) * rates["completion"]
    
    return round(prompt_cost + completion_cost, 4)