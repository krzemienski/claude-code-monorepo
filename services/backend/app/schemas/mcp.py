"""
MCP (Model Context Protocol) schemas
"""

from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field
from datetime import datetime


class MCPServer(BaseModel):
    """MCP Server information"""
    name: str
    description: Optional[str] = None
    status: str = "unknown"
    url: Optional[str] = None
    version: Optional[str] = None


class MCPTool(BaseModel):
    """MCP Tool information"""
    name: str
    description: Optional[str] = None
    server: str
    parameters: Optional[Dict[str, Any]] = None
    enabled: bool = True


class MCPToolCall(BaseModel):
    """MCP Tool call request"""
    tool: str
    server: str
    parameters: Dict[str, Any] = Field(default_factory=dict)
    timeout: Optional[int] = 30


class MCPToolResult(BaseModel):
    """MCP Tool execution result"""
    tool: str
    server: str
    success: bool
    result: Optional[Any] = None
    error: Optional[str] = None
    duration: Optional[float] = None
    timestamp: datetime = Field(default_factory=datetime.now)


class MCPConfig(BaseModel):
    """MCP Configuration"""
    servers: List[MCPServer] = Field(default_factory=list)
    tools: List[MCPTool] = Field(default_factory=list)
    enabled: bool = True
    discovery_enabled: bool = True
    audit_logging: bool = True


class MCPServerConfig(BaseModel):
    """MCP Server configuration"""
    name: str
    command: Optional[str] = None
    args: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    url: Optional[str] = None
    version: Optional[str] = None
    enabled: bool = True


class ToolInvocation(BaseModel):
    """Tool invocation request"""
    tool_name: str
    server_name: str
    parameters: Dict[str, Any] = Field(default_factory=dict)
    priority: Optional[str] = None
    timeout: Optional[int] = 30


class ToolPriority(BaseModel):
    """Tool priority configuration"""
    high: List[str] = Field(default_factory=list)
    medium: List[str] = Field(default_factory=list)
    low: List[str] = Field(default_factory=list)