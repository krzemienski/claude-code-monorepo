"""
MCP (Model Context Protocol) Service
Manages MCP server lifecycle, tool discovery, and execution
"""

import os
import json
import asyncio
import logging
from typing import List, Dict, Any, Optional, Set
from datetime import datetime
from pathlib import Path
import subprocess
import aiohttp
import websockets

from app.core.config import settings
from app.schemas.mcp import (
    MCPServer,
    MCPTool,
    MCPServerConfig,
    ToolInvocation,
    ToolPriority
)
from app.services.audit import AuditLogger

logger = logging.getLogger(__name__)


class MCPManager:
    """
    Manages MCP server lifecycle and tool orchestration
    """
    
    def __init__(self):
        self.servers: Dict[str, MCPServer] = {}
        self.tools: Dict[str, MCPTool] = {}
        self.server_processes: Dict[str, subprocess.Popen] = {}
        self.audit_logger = AuditLogger() if settings.MCP_AUDIT_LOGGING else None
        self.config_dir = Path(settings.MCP_CONFIG_DIR)
        self.tool_priorities: Dict[str, ToolPriority] = {}
        self._initialized = False
    
    async def initialize(self):
        """
        Initialize MCP manager and discover available servers
        """
        if self._initialized:
            return
        
        logger.info("Initializing MCP Manager...")
        
        # Create config directory if it doesn't exist
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Discover and start MCP servers
        if settings.MCP_DISCOVERY_ENABLED:
            await self.discover_servers()
        
        # Load tool priorities
        await self.load_tool_priorities()
        
        self._initialized = True
        logger.info(f"MCP Manager initialized with {len(self.servers)} servers and {len(self.tools)} tools")
    
    async def discover_servers(self):
        """
        Discover available MCP servers from configuration
        """
        # Check for MCP server configurations in multiple locations
        config_paths = [
            self.config_dir / "mcp-servers.json",
            Path.home() / ".claude" / "mcp-servers.json",
            Path("/etc/claude/mcp-servers.json")
        ]
        
        for config_path in config_paths:
            if config_path.exists():
                await self.load_server_config(config_path)
        
        # Also check environment variables for MCP servers
        for key, value in os.environ.items():
            if key.startswith("MCP_SERVER_"):
                server_name = key.replace("MCP_SERVER_", "").lower()
                await self.register_server_from_env(server_name, value)
    
    async def load_server_config(self, config_path: Path):
        """
        Load MCP server configuration from JSON file
        """
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            
            for server_id, server_config in config.get("servers", {}).items():
                await self.register_server(
                    server_id=server_id,
                    config=MCPServerConfig(**server_config)
                )
        except Exception as e:
            logger.error(f"Failed to load MCP server config from {config_path}: {e}")
    
    async def register_server(self, server_id: str, config: MCPServerConfig):
        """
        Register and start an MCP server
        """
        try:
            # Create server instance
            server = MCPServer(
                id=server_id,
                name=config.name or server_id,
                description=config.description,
                version=config.version or "1.0.0",
                protocol=config.protocol or "stdio",
                endpoint=config.endpoint,
                capabilities=config.capabilities or [],
                status="starting",
                metadata=config.metadata or {}
            )
            
            # Start the server based on protocol
            if server.protocol == "stdio":
                await self.start_stdio_server(server, config)
            elif server.protocol == "websocket":
                await self.start_websocket_server(server, config)
            elif server.protocol == "http":
                await self.start_http_server(server, config)
            else:
                logger.warning(f"Unsupported MCP protocol: {server.protocol}")
                return
            
            # Discover tools from the server
            await self.discover_server_tools(server)
            
            # Update server status
            server.status = "running"
            self.servers[server_id] = server
            
            logger.info(f"Registered MCP server: {server_id} with {len(server.tools)} tools")
            
        except Exception as e:
            logger.error(f"Failed to register MCP server {server_id}: {e}")
    
    async def start_stdio_server(self, server: MCPServer, config: MCPServerConfig):
        """
        Start an stdio-based MCP server
        """
        if not config.command:
            raise ValueError(f"No command specified for stdio server {server.id}")
        
        try:
            # Start the server process
            process = subprocess.Popen(
                config.command if isinstance(config.command, list) else config.command.split(),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, **config.env} if config.env else None,
                cwd=config.working_dir
            )
            
            self.server_processes[server.id] = process
            server.metadata["pid"] = process.pid
            
            # Give the server time to start
            await asyncio.sleep(1)
            
            # Check if process is still running
            if process.poll() is not None:
                stderr = process.stderr.read().decode() if process.stderr else ""
                raise RuntimeError(f"Server process exited immediately: {stderr}")
            
        except Exception as e:
            logger.error(f"Failed to start stdio server {server.id}: {e}")
            raise
    
    async def start_websocket_server(self, server: MCPServer, config: MCPServerConfig):
        """
        Connect to a WebSocket-based MCP server
        """
        if not server.endpoint:
            raise ValueError(f"No endpoint specified for WebSocket server {server.id}")
        
        try:
            # Test WebSocket connection
            async with websockets.connect(server.endpoint) as ws:
                # Send initialization message
                await ws.send(json.dumps({
                    "jsonrpc": "2.0",
                    "method": "initialize",
                    "params": {
                        "clientInfo": {
                            "name": "Claude Code Backend",
                            "version": settings.VERSION
                        }
                    },
                    "id": 1
                }))
                
                # Wait for response
                response = await ws.recv()
                result = json.loads(response)
                
                if "error" in result:
                    raise RuntimeError(f"Server initialization failed: {result['error']}")
                
                server.metadata["connection"] = "websocket"
                
        except Exception as e:
            logger.error(f"Failed to connect to WebSocket server {server.id}: {e}")
            raise
    
    async def start_http_server(self, server: MCPServer, config: MCPServerConfig):
        """
        Connect to an HTTP-based MCP server
        """
        if not server.endpoint:
            raise ValueError(f"No endpoint specified for HTTP server {server.id}")
        
        try:
            # Test HTTP connection
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{server.endpoint}/initialize",
                    json={
                        "clientInfo": {
                            "name": "Claude Code Backend",
                            "version": settings.VERSION
                        }
                    }
                ) as response:
                    if response.status != 200:
                        text = await response.text()
                        raise RuntimeError(f"Server initialization failed: {text}")
                    
                    result = await response.json()
                    server.metadata["connection"] = "http"
                    server.metadata["server_info"] = result.get("serverInfo", {})
                    
        except Exception as e:
            logger.error(f"Failed to connect to HTTP server {server.id}: {e}")
            raise
    
    async def discover_server_tools(self, server: MCPServer):
        """
        Discover available tools from an MCP server
        """
        try:
            tools = []
            
            if server.protocol == "stdio":
                tools = await self.discover_stdio_tools(server)
            elif server.protocol == "websocket":
                tools = await self.discover_websocket_tools(server)
            elif server.protocol == "http":
                tools = await self.discover_http_tools(server)
            
            # Register tools
            for tool_data in tools:
                tool = MCPTool(
                    id=f"{server.id}.{tool_data['name']}",
                    name=tool_data["name"],
                    description=tool_data.get("description", ""),
                    server_id=server.id,
                    input_schema=tool_data.get("inputSchema", {}),
                    output_schema=tool_data.get("outputSchema", {}),
                    metadata=tool_data.get("metadata", {})
                )
                
                self.tools[tool.id] = tool
                server.tools.append(tool.id)
            
            logger.info(f"Discovered {len(tools)} tools from server {server.id}")
            
        except Exception as e:
            logger.error(f"Failed to discover tools from server {server.id}: {e}")
    
    async def discover_stdio_tools(self, server: MCPServer) -> List[Dict[str, Any]]:
        """
        Discover tools from an stdio-based server
        """
        process = self.server_processes.get(server.id)
        if not process:
            return []
        
        try:
            # Send tool discovery request
            request = json.dumps({
                "jsonrpc": "2.0",
                "method": "tools/list",
                "id": 1
            }) + "\n"
            
            process.stdin.write(request.encode())
            process.stdin.flush()
            
            # Read response
            response_line = process.stdout.readline().decode()
            response = json.loads(response_line)
            
            if "error" in response:
                logger.error(f"Tool discovery error: {response['error']}")
                return []
            
            return response.get("result", {}).get("tools", [])
            
        except Exception as e:
            logger.error(f"Failed to discover stdio tools: {e}")
            return []
    
    async def discover_websocket_tools(self, server: MCPServer) -> List[Dict[str, Any]]:
        """
        Discover tools from a WebSocket-based server
        """
        try:
            async with websockets.connect(server.endpoint) as ws:
                # Send tool discovery request
                await ws.send(json.dumps({
                    "jsonrpc": "2.0",
                    "method": "tools/list",
                    "id": 1
                }))
                
                # Wait for response
                response = await ws.recv()
                result = json.loads(response)
                
                if "error" in result:
                    logger.error(f"Tool discovery error: {result['error']}")
                    return []
                
                return result.get("result", {}).get("tools", [])
                
        except Exception as e:
            logger.error(f"Failed to discover WebSocket tools: {e}")
            return []
    
    async def discover_http_tools(self, server: MCPServer) -> List[Dict[str, Any]]:
        """
        Discover tools from an HTTP-based server
        """
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{server.endpoint}/tools") as response:
                    if response.status != 200:
                        logger.error(f"Tool discovery failed with status {response.status}")
                        return []
                    
                    result = await response.json()
                    return result.get("tools", [])
                    
        except Exception as e:
            logger.error(f"Failed to discover HTTP tools: {e}")
            return []
    
    async def invoke_tool(
        self,
        tool_id: str,
        parameters: Dict[str, Any],
        session_id: Optional[str] = None,
        user_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Invoke an MCP tool
        """
        tool = self.tools.get(tool_id)
        if not tool:
            raise ValueError(f"Tool not found: {tool_id}")
        
        server = self.servers.get(tool.server_id)
        if not server or server.status != "running":
            raise RuntimeError(f"Server not available: {tool.server_id}")
        
        # Log invocation if audit logging is enabled
        if self.audit_logger:
            await self.audit_logger.log_tool_invocation(
                tool_id=tool_id,
                parameters=parameters,
                session_id=session_id,
                user_id=user_id
            )
        
        start_time = datetime.utcnow()
        
        try:
            # Invoke based on server protocol
            if server.protocol == "stdio":
                result = await self.invoke_stdio_tool(server, tool, parameters)
            elif server.protocol == "websocket":
                result = await self.invoke_websocket_tool(server, tool, parameters)
            elif server.protocol == "http":
                result = await self.invoke_http_tool(server, tool, parameters)
            else:
                raise ValueError(f"Unsupported protocol: {server.protocol}")
            
            # Log successful invocation
            if self.audit_logger:
                duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
                await self.audit_logger.log_tool_result(
                    tool_id=tool_id,
                    success=True,
                    duration_ms=duration_ms,
                    session_id=session_id
                )
            
            return result
            
        except Exception as e:
            # Log failed invocation
            if self.audit_logger:
                duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
                await self.audit_logger.log_tool_result(
                    tool_id=tool_id,
                    success=False,
                    error=str(e),
                    duration_ms=duration_ms,
                    session_id=session_id
                )
            raise
    
    async def invoke_stdio_tool(
        self,
        server: MCPServer,
        tool: MCPTool,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Invoke a tool on an stdio-based server
        """
        process = self.server_processes.get(server.id)
        if not process:
            raise RuntimeError(f"Server process not found: {server.id}")
        
        # Send tool invocation request
        request = json.dumps({
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool.name,
                "arguments": parameters
            },
            "id": 1
        }) + "\n"
        
        process.stdin.write(request.encode())
        process.stdin.flush()
        
        # Read response
        response_line = process.stdout.readline().decode()
        response = json.loads(response_line)
        
        if "error" in response:
            raise RuntimeError(f"Tool invocation error: {response['error']}")
        
        return response.get("result", {})
    
    async def load_tool_priorities(self):
        """
        Load tool execution priorities from configuration
        """
        priority_file = self.config_dir / "tool-priorities.json"
        
        if priority_file.exists():
            try:
                with open(priority_file, 'r') as f:
                    priorities = json.load(f)
                
                for tool_id, priority_data in priorities.items():
                    self.tool_priorities[tool_id] = ToolPriority(**priority_data)
                    
                logger.info(f"Loaded {len(self.tool_priorities)} tool priorities")
                
            except Exception as e:
                logger.error(f"Failed to load tool priorities: {e}")
    
    async def get_tools_for_session(
        self,
        session_id: str,
        project_id: Optional[str] = None,
        user_preferences: Optional[Dict[str, Any]] = None
    ) -> List[MCPTool]:
        """
        Get the list of tools available for a specific session
        Applies priority ordering and filtering based on configuration
        """
        available_tools = []
        
        # Get enabled tools based on scope (user > project > global)
        enabled_tool_ids = await self.get_enabled_tools(project_id, user_preferences)
        
        for tool_id in enabled_tool_ids:
            tool = self.tools.get(tool_id)
            if tool:
                server = self.servers.get(tool.server_id)
                if server and server.status == "running":
                    available_tools.append(tool)
        
        # Sort by priority
        available_tools.sort(
            key=lambda t: self.tool_priorities.get(t.id, ToolPriority()).priority,
            reverse=True
        )
        
        return available_tools
    
    async def get_enabled_tools(
        self,
        project_id: Optional[str] = None,
        user_preferences: Optional[Dict[str, Any]] = None
    ) -> Set[str]:
        """
        Determine which tools are enabled based on configuration hierarchy
        """
        enabled = set()
        
        # Start with global defaults
        global_config = self.config_dir / "global-tools.json"
        if global_config.exists():
            with open(global_config, 'r') as f:
                config = json.load(f)
                enabled.update(config.get("enabled_tools", []))
        
        # Apply project-level overrides
        if project_id:
            project_config = self.config_dir / f"projects/{project_id}/tools.json"
            if project_config.exists():
                with open(project_config, 'r') as f:
                    config = json.load(f)
                    if config.get("override_global", False):
                        enabled = set(config.get("enabled_tools", []))
                    else:
                        enabled.update(config.get("enabled_tools", []))
                        enabled -= set(config.get("disabled_tools", []))
        
        # Apply user preferences
        if user_preferences:
            if user_preferences.get("override_all", False):
                enabled = set(user_preferences.get("enabled_tools", []))
            else:
                enabled.update(user_preferences.get("enabled_tools", []))
                enabled -= set(user_preferences.get("disabled_tools", []))
        
        return enabled
    
    async def shutdown(self):
        """
        Shutdown all MCP servers and clean up resources
        """
        logger.info("Shutting down MCP Manager...")
        
        # Stop all stdio server processes
        for server_id, process in self.server_processes.items():
            try:
                process.terminate()
                await asyncio.sleep(1)
                if process.poll() is None:
                    process.kill()
            except Exception as e:
                logger.error(f"Failed to stop server process {server_id}: {e}")
        
        self.servers.clear()
        self.tools.clear()
        self.server_processes.clear()
        
        logger.info("MCP Manager shutdown complete")
    
    async def list_servers(self) -> List[MCPServer]:
        """
        List all registered MCP servers
        """
        return list(self.servers.values())
    
    async def get_server(self, server_id: str) -> Optional[MCPServer]:
        """
        Get a specific MCP server by ID
        """
        return self.servers.get(server_id)
    
    async def list_tools(self, server_id: Optional[str] = None) -> List[MCPTool]:
        """
        List available tools, optionally filtered by server
        """
        if server_id:
            server = self.servers.get(server_id)
            if not server:
                return []
            return [self.tools[tool_id] for tool_id in server.tools if tool_id in self.tools]
        
        return list(self.tools.values())
    
    async def register_server_from_env(self, server_name: str, config_str: str):
        """
        Register an MCP server from environment variable configuration
        """
        try:
            # Parse configuration from environment variable
            # Format: protocol:endpoint:options
            parts = config_str.split(":")
            
            if len(parts) < 2:
                logger.warning(f"Invalid MCP server config in environment: {config_str}")
                return
            
            protocol = parts[0]
            endpoint = ":".join(parts[1:-1]) if len(parts) > 2 else parts[1]
            
            config = MCPServerConfig(
                name=server_name,
                protocol=protocol,
                endpoint=endpoint if protocol != "stdio" else None,
                command=endpoint if protocol == "stdio" else None
            )
            
            await self.register_server(server_name, config)
            
        except Exception as e:
            logger.error(f"Failed to register server from environment {server_name}: {e}")