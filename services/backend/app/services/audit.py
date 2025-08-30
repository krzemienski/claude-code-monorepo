"""
Audit logging service for tracking operations
"""

import logging
from datetime import datetime
from typing import Dict, Any, Optional


class AuditLogger:
    """Simple audit logger for tracking operations"""
    
    def __init__(self):
        self.logger = logging.getLogger("audit")
        self.logger.setLevel(logging.INFO)
    
    async def log_tool_invocation(
        self,
        tool_name: str,
        server_name: str,
        parameters: Dict[str, Any],
        user_id: Optional[str] = None,
        session_id: Optional[str] = None
    ):
        """Log tool invocation for audit purposes"""
        self.logger.info(
            f"Tool invocation: {tool_name} on {server_name}",
            extra={
                "tool_name": tool_name,
                "server_name": server_name,
                "parameters": parameters,
                "user_id": user_id,
                "session_id": session_id,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    async def log_tool_result(
        self,
        tool_name: str,
        server_name: str,
        success: bool,
        duration: float,
        error: Optional[str] = None
    ):
        """Log tool execution result"""
        self.logger.info(
            f"Tool result: {tool_name} - {'Success' if success else 'Failed'}",
            extra={
                "tool_name": tool_name,
                "server_name": server_name,
                "success": success,
                "duration": duration,
                "error": error,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    async def log_server_event(
        self,
        server_name: str,
        event: str,
        details: Optional[Dict[str, Any]] = None
    ):
        """Log server lifecycle events"""
        self.logger.info(
            f"Server event: {server_name} - {event}",
            extra={
                "server_name": server_name,
                "event": event,
                "details": details or {},
                "timestamp": datetime.utcnow().isoformat()
            }
        )