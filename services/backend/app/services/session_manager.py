"""
Session Manager Service
Handles chat session lifecycle, streaming, and state management
"""

import asyncio
import uuid
from typing import Dict, Any, Optional, Set
from datetime import datetime
from collections import defaultdict


class SessionManager:
    """
    Manages active chat sessions, streaming state, and metrics
    """
    
    def __init__(self):
        # Active sessions storage
        self.sessions: Dict[str, Dict[str, Any]] = {}
        
        # Streaming control
        self.active_streams: Set[str] = set()
        self.stream_cancellation: Dict[str, asyncio.Event] = {}
        
        # Session metrics
        self.session_metrics: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
            "message_count": 0,
            "token_usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
            "tool_invocations": 0,
            "error_count": 0,
            "response_times": [],
            "active_tools": set()
        })
    
    async def create_session(self, session_id: str, session_data: Dict[str, Any]) -> None:
        """Create a new session"""
        self.sessions[session_id] = {
            **session_data,
            "created_at": datetime.utcnow(),
            "last_activity": datetime.utcnow(),
            "is_streaming": False
        }
        
        # Initialize streaming control
        self.stream_cancellation[session_id] = asyncio.Event()
    
    async def update_session(self, session_id: str, update_data: Dict[str, Any]) -> None:
        """Update session data"""
        if session_id in self.sessions:
            self.sessions[session_id].update(update_data)
            self.sessions[session_id]["last_activity"] = datetime.utcnow()
    
    async def remove_session(self, session_id: str) -> None:
        """Remove a session"""
        # Stop any active streaming
        await self.stop_streaming(session_id)
        
        # Clean up session data
        self.sessions.pop(session_id, None)
        self.stream_cancellation.pop(session_id, None)
        self.session_metrics.pop(session_id, None)
    
    async def start_streaming(self, session_id: str) -> None:
        """Mark session as actively streaming"""
        if session_id in self.sessions:
            self.sessions[session_id]["is_streaming"] = True
            self.active_streams.add(session_id)
            
            # Reset cancellation event
            if session_id in self.stream_cancellation:
                self.stream_cancellation[session_id].clear()
    
    async def stop_streaming(self, session_id: str) -> bool:
        """Stop streaming for a session"""
        if session_id in self.active_streams:
            # Set cancellation event
            if session_id in self.stream_cancellation:
                self.stream_cancellation[session_id].set()
            
            # Update session state
            if session_id in self.sessions:
                self.sessions[session_id]["is_streaming"] = False
            
            self.active_streams.discard(session_id)
            return True
        
        return False
    
    async def is_streaming_cancelled(self, session_id: str) -> bool:
        """Check if streaming has been cancelled for a session"""
        if session_id in self.stream_cancellation:
            return self.stream_cancellation[session_id].is_set()
        return False
    
    async def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data"""
        return self.sessions.get(session_id)
    
    async def get_session_stats(self, session_id: str) -> Dict[str, Any]:
        """Get detailed session statistics"""
        metrics = self.session_metrics[session_id]
        
        # Calculate average response time
        avg_response_time = 0
        if metrics["response_times"]:
            avg_response_time = sum(metrics["response_times"]) / len(metrics["response_times"])
        
        return {
            "message_count": metrics["message_count"],
            "token_usage": metrics["token_usage"],
            "tool_invocations": metrics["tool_invocations"],
            "error_count": metrics["error_count"],
            "average_response_time": avg_response_time,
            "active_tools": list(metrics["active_tools"]),
            "memory_usage": {
                "session_data": len(str(self.sessions.get(session_id, {}))),
                "metrics_data": len(str(metrics))
            }
        }
    
    async def update_metrics(self, session_id: str, metric_type: str, value: Any) -> None:
        """Update session metrics"""
        metrics = self.session_metrics[session_id]
        
        if metric_type == "message":
            metrics["message_count"] += 1
        elif metric_type == "tokens":
            for key in ["prompt_tokens", "completion_tokens", "total_tokens"]:
                if key in value:
                    metrics["token_usage"][key] += value[key]
        elif metric_type == "tool":
            metrics["tool_invocations"] += 1
            if "tool_name" in value:
                metrics["active_tools"].add(value["tool_name"])
        elif metric_type == "error":
            metrics["error_count"] += 1
        elif metric_type == "response_time":
            metrics["response_times"].append(value)
            # Keep only last 100 response times
            if len(metrics["response_times"]) > 100:
                metrics["response_times"] = metrics["response_times"][-100:]
    
    async def clear_session_history(self, session_id: str) -> None:
        """Clear session message history while keeping session active"""
        if session_id in self.sessions:
            # Reset metrics
            self.session_metrics[session_id] = {
                "message_count": 0,
                "token_usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
                "tool_invocations": 0,
                "error_count": 0,
                "response_times": [],
                "active_tools": set()
            }
            
            # Update session
            self.sessions[session_id]["last_activity"] = datetime.utcnow()
    
    async def get_active_sessions(self) -> Dict[str, Dict[str, Any]]:
        """Get all active sessions"""
        return self.sessions.copy()
    
    async def get_streaming_sessions(self) -> Set[str]:
        """Get IDs of all sessions currently streaming"""
        return self.active_streams.copy()
    
    async def cleanup_inactive_sessions(self, timeout_seconds: int = 3600) -> int:
        """Clean up inactive sessions older than timeout"""
        now = datetime.utcnow()
        sessions_to_remove = []
        
        for session_id, session_data in self.sessions.items():
            last_activity = session_data.get("last_activity", session_data.get("created_at"))
            if last_activity:
                time_diff = (now - last_activity).total_seconds()
                if time_diff > timeout_seconds and session_id not in self.active_streams:
                    sessions_to_remove.append(session_id)
        
        # Remove inactive sessions
        for session_id in sessions_to_remove:
            await self.remove_session(session_id)
        
        return len(sessions_to_remove)