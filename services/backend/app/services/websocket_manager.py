"""
Enhanced WebSocket manager with reconnection logic and heartbeat
Provides robust real-time communication with automatic recovery
"""

import asyncio
import json
import time
import uuid
from typing import Dict, Set, Optional, Any, List
from datetime import datetime, timedelta
from enum import Enum

from fastapi import WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from app.core.logging import setup_logging
from app.middleware.performance_monitoring import ConnectionTracker

logger = setup_logging()


class ConnectionState(str, Enum):
    """WebSocket connection states"""
    CONNECTING = "connecting"
    CONNECTED = "connected"
    RECONNECTING = "reconnecting"
    DISCONNECTED = "disconnected"
    FAILED = "failed"


class MessageType(str, Enum):
    """WebSocket message types"""
    HEARTBEAT = "heartbeat"
    HEARTBEAT_ACK = "heartbeat_ack"
    MESSAGE = "message"
    CONTROL = "control"
    ERROR = "error"
    RECONNECT = "reconnect"
    SESSION_UPDATE = "session_update"
    TOOL_EXECUTION = "tool_execution"
    TOKEN_UPDATE = "token_update"


class WebSocketMessage(BaseModel):
    """Standard WebSocket message format"""
    id: str
    type: MessageType
    timestamp: str
    payload: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = None


class ConnectionInfo:
    """Track individual WebSocket connection"""
    
    def __init__(self, websocket: WebSocket, client_id: str, session_id: Optional[str] = None):
        self.websocket = websocket
        self.client_id = client_id
        self.session_id = session_id
        self.state = ConnectionState.CONNECTING
        self.connected_at = datetime.utcnow()
        self.last_heartbeat = datetime.utcnow()
        self.last_activity = datetime.utcnow()
        self.reconnect_count = 0
        self.message_queue: List[WebSocketMessage] = []
        self.heartbeat_task: Optional[asyncio.Task] = None
        self.metadata: Dict[str, Any] = {}
    
    def update_activity(self):
        """Update last activity timestamp"""
        self.last_activity = datetime.utcnow()
    
    def update_heartbeat(self):
        """Update heartbeat timestamp"""
        self.last_heartbeat = datetime.utcnow()
        self.update_activity()
    
    def is_healthy(self, timeout_seconds: int = 60) -> bool:
        """Check if connection is healthy"""
        return (datetime.utcnow() - self.last_heartbeat).seconds < timeout_seconds


class EnhancedWebSocketManager:
    """
    Enhanced WebSocket manager with robust connection handling
    """
    
    def __init__(self):
        # Connection tracking
        self.connections: Dict[str, ConnectionInfo] = {}
        self.session_connections: Dict[str, Set[str]] = {}  # session_id -> client_ids
        
        # Configuration
        self.heartbeat_interval = 30  # seconds
        self.heartbeat_timeout = 60  # seconds
        self.reconnect_window = 300  # 5 minutes to reconnect
        self.max_reconnect_attempts = 5
        self.message_queue_size = 100
        
        # Background tasks
        self.monitor_task: Optional[asyncio.Task] = None
    
    async def connect(
        self,
        websocket: WebSocket,
        client_id: Optional[str] = None,
        session_id: Optional[str] = None,
        reconnect_token: Optional[str] = None
    ) -> str:
        """
        Establish WebSocket connection with optional reconnection
        """
        # Generate or validate client ID
        if reconnect_token and client_id in self.connections:
            # Reconnection attempt
            connection = self.connections[client_id]
            if connection.state == ConnectionState.DISCONNECTED:
                if (datetime.utcnow() - connection.last_activity).seconds < self.reconnect_window:
                    # Valid reconnection window
                    await websocket.accept()
                    connection.websocket = websocket
                    connection.state = ConnectionState.RECONNECTING
                    connection.reconnect_count += 1
                    logger.info(f"Client {client_id} reconnecting (attempt {connection.reconnect_count})")
                    
                    # Send queued messages
                    await self._flush_message_queue(connection)
                    
                    connection.state = ConnectionState.CONNECTED
                    ConnectionTracker.add_websocket_connection()
                    
                    # Restart heartbeat
                    await self._start_heartbeat(connection)
                    
                    return client_id
                else:
                    # Reconnection window expired
                    del self.connections[client_id]
        
        # New connection
        if not client_id:
            client_id = str(uuid.uuid4())
        
        await websocket.accept()
        
        connection = ConnectionInfo(websocket, client_id, session_id)
        connection.state = ConnectionState.CONNECTED
        self.connections[client_id] = connection
        
        # Track session association
        if session_id:
            if session_id not in self.session_connections:
                self.session_connections[session_id] = set()
            self.session_connections[session_id].add(client_id)
        
        ConnectionTracker.add_websocket_connection()
        logger.info(f"Client {client_id} connected (session: {session_id})")
        
        # Start heartbeat
        await self._start_heartbeat(connection)
        
        # Send connection confirmation
        await self.send_message(
            client_id,
            MessageType.CONTROL,
            {
                "action": "connected",
                "client_id": client_id,
                "session_id": session_id,
                "heartbeat_interval": self.heartbeat_interval,
                "reconnect_window": self.reconnect_window
            }
        )
        
        return client_id
    
    async def disconnect(self, client_id: str, code: int = 1000, reason: str = "Normal closure"):
        """
        Handle WebSocket disconnection
        """
        if client_id not in self.connections:
            return
        
        connection = self.connections[client_id]
        connection.state = ConnectionState.DISCONNECTED
        
        # Cancel heartbeat task
        if connection.heartbeat_task and not connection.heartbeat_task.done():
            connection.heartbeat_task.cancel()
        
        # Remove from session tracking
        if connection.session_id and connection.session_id in self.session_connections:
            self.session_connections[connection.session_id].discard(client_id)
            if not self.session_connections[connection.session_id]:
                del self.session_connections[connection.session_id]
        
        ConnectionTracker.remove_websocket_connection()
        logger.info(f"Client {client_id} disconnected: {reason}")
        
        # Keep connection info for reconnection window
        asyncio.create_task(self._cleanup_connection(client_id))
    
    async def _cleanup_connection(self, client_id: str):
        """
        Clean up connection after reconnection window expires
        """
        await asyncio.sleep(self.reconnect_window)
        
        if client_id in self.connections:
            connection = self.connections[client_id]
            if connection.state == ConnectionState.DISCONNECTED:
                del self.connections[client_id]
                logger.info(f"Cleaned up expired connection for client {client_id}")
    
    async def send_message(
        self,
        client_id: str,
        message_type: MessageType,
        payload: Dict[str, Any],
        metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Send message to specific client
        """
        if client_id not in self.connections:
            logger.warning(f"Client {client_id} not found")
            return False
        
        connection = self.connections[client_id]
        
        message = WebSocketMessage(
            id=str(uuid.uuid4()),
            type=message_type,
            timestamp=datetime.utcnow().isoformat(),
            payload=payload,
            metadata=metadata
        )
        
        if connection.state == ConnectionState.CONNECTED:
            try:
                await connection.websocket.send_json(message.model_dump())
                connection.update_activity()
                return True
            except Exception as e:
                logger.error(f"Failed to send message to {client_id}: {e}")
                # Queue message for retry
                self._queue_message(connection, message)
                return False
        else:
            # Queue message for when connection is restored
            self._queue_message(connection, message)
            return False
    
    async def broadcast_to_session(
        self,
        session_id: str,
        message_type: MessageType,
        payload: Dict[str, Any],
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Broadcast message to all clients in a session
        """
        if session_id not in self.session_connections:
            logger.warning(f"No connections for session {session_id}")
            return
        
        client_ids = list(self.session_connections[session_id])
        tasks = [
            self.send_message(client_id, message_type, payload, metadata)
            for client_id in client_ids
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        success_count = sum(1 for r in results if r is True)
        logger.info(f"Broadcast to session {session_id}: {success_count}/{len(client_ids)} successful")
    
    async def handle_message(self, client_id: str, data: Dict[str, Any]):
        """
        Handle incoming WebSocket message
        """
        if client_id not in self.connections:
            logger.warning(f"Message from unknown client {client_id}")
            return
        
        connection = self.connections[client_id]
        connection.update_activity()
        
        try:
            message = WebSocketMessage(**data)
            
            if message.type == MessageType.HEARTBEAT:
                # Respond to heartbeat
                connection.update_heartbeat()
                await self.send_message(
                    client_id,
                    MessageType.HEARTBEAT_ACK,
                    {"timestamp": datetime.utcnow().isoformat()}
                )
            
            elif message.type == MessageType.MESSAGE:
                # Process regular message
                await self._process_message(connection, message)
            
            elif message.type == MessageType.CONTROL:
                # Handle control messages
                await self._handle_control_message(connection, message)
            
            else:
                logger.warning(f"Unknown message type from {client_id}: {message.type}")
        
        except Exception as e:
            logger.error(f"Error handling message from {client_id}: {e}")
            await self.send_message(
                client_id,
                MessageType.ERROR,
                {"error": str(e), "original_message": data}
            )
    
    async def _start_heartbeat(self, connection: ConnectionInfo):
        """
        Start heartbeat task for connection
        """
        if connection.heartbeat_task and not connection.heartbeat_task.done():
            connection.heartbeat_task.cancel()
        
        connection.heartbeat_task = asyncio.create_task(
            self._heartbeat_loop(connection)
        )
    
    async def _heartbeat_loop(self, connection: ConnectionInfo):
        """
        Send periodic heartbeats to maintain connection
        """
        while connection.state == ConnectionState.CONNECTED:
            try:
                await asyncio.sleep(self.heartbeat_interval)
                
                if not connection.is_healthy(self.heartbeat_timeout):
                    logger.warning(f"Client {connection.client_id} heartbeat timeout")
                    await self.disconnect(
                        connection.client_id,
                        code=1001,
                        reason="Heartbeat timeout"
                    )
                    break
                
                # Send heartbeat
                await self.send_message(
                    connection.client_id,
                    MessageType.HEARTBEAT,
                    {"timestamp": datetime.utcnow().isoformat()}
                )
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Heartbeat error for {connection.client_id}: {e}")
    
    def _queue_message(self, connection: ConnectionInfo, message: WebSocketMessage):
        """
        Queue message for later delivery
        """
        if len(connection.message_queue) >= self.message_queue_size:
            # Remove oldest message if queue is full
            connection.message_queue.pop(0)
        
        connection.message_queue.append(message)
        logger.debug(f"Queued message for {connection.client_id}: {message.type}")
    
    async def _flush_message_queue(self, connection: ConnectionInfo):
        """
        Send all queued messages
        """
        if not connection.message_queue:
            return
        
        logger.info(f"Flushing {len(connection.message_queue)} queued messages for {connection.client_id}")
        
        for message in connection.message_queue:
            try:
                await connection.websocket.send_json(message.model_dump())
            except Exception as e:
                logger.error(f"Failed to send queued message: {e}")
                break
        
        connection.message_queue.clear()
    
    async def _process_message(self, connection: ConnectionInfo, message: WebSocketMessage):
        """
        Process regular messages
        """
        # This can be extended based on application needs
        logger.info(f"Processing message from {connection.client_id}: {message.payload}")
        
        # Example: Echo back
        await self.send_message(
            connection.client_id,
            MessageType.MESSAGE,
            {
                "echo": message.payload,
                "processed_at": datetime.utcnow().isoformat()
            }
        )
    
    async def _handle_control_message(self, connection: ConnectionInfo, message: WebSocketMessage):
        """
        Handle control messages
        """
        action = message.payload.get("action")
        
        if action == "ping":
            await self.send_message(
                connection.client_id,
                MessageType.CONTROL,
                {"action": "pong", "timestamp": datetime.utcnow().isoformat()}
            )
        
        elif action == "subscribe":
            # Handle subscription to events
            topics = message.payload.get("topics", [])
            connection.metadata["subscriptions"] = topics
            logger.info(f"Client {connection.client_id} subscribed to: {topics}")
        
        elif action == "unsubscribe":
            # Handle unsubscription
            connection.metadata.pop("subscriptions", None)
            logger.info(f"Client {connection.client_id} unsubscribed")
        
        else:
            logger.warning(f"Unknown control action from {connection.client_id}: {action}")
    
    async def start_monitoring(self):
        """
        Start background monitoring task
        """
        if not self.monitor_task or self.monitor_task.done():
            self.monitor_task = asyncio.create_task(self._monitor_connections())
            logger.info("Started WebSocket monitoring task")
    
    async def stop_monitoring(self):
        """
        Stop background monitoring task
        """
        if self.monitor_task and not self.monitor_task.done():
            self.monitor_task.cancel()
            try:
                await self.monitor_task
            except asyncio.CancelledError:
                pass
            logger.info("Stopped WebSocket monitoring task")
    
    async def _monitor_connections(self):
        """
        Monitor connection health
        """
        while True:
            try:
                await asyncio.sleep(30)  # Check every 30 seconds
                
                disconnected = []
                for client_id, connection in self.connections.items():
                    if connection.state == ConnectionState.CONNECTED:
                        if not connection.is_healthy(self.heartbeat_timeout * 2):
                            disconnected.append(client_id)
                
                for client_id in disconnected:
                    await self.disconnect(
                        client_id,
                        code=1001,
                        reason="Connection timeout"
                    )
                
                # Log statistics
                active = sum(
                    1 for c in self.connections.values()
                    if c.state == ConnectionState.CONNECTED
                )
                logger.debug(f"WebSocket stats: {active} active, {len(self.connections)} total")
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in connection monitoring: {e}")
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """
        Get connection statistics
        """
        active = sum(
            1 for c in self.connections.values()
            if c.state == ConnectionState.CONNECTED
        )
        
        sessions_with_connections = len(self.session_connections)
        
        return {
            "total_connections": len(self.connections),
            "active_connections": active,
            "disconnected_connections": len(self.connections) - active,
            "sessions_with_connections": sessions_with_connections,
            "average_reconnect_count": sum(
                c.reconnect_count for c in self.connections.values()
            ) / max(1, len(self.connections))
        }


# Global WebSocket manager instance
websocket_manager = EnhancedWebSocketManager()


# WebSocket endpoint handler
async def websocket_endpoint(
    websocket: WebSocket,
    client_id: Optional[str] = None,
    session_id: Optional[str] = None,
    reconnect_token: Optional[str] = None
):
    """
    WebSocket endpoint handler with reconnection support
    """
    client_id = await websocket_manager.connect(
        websocket,
        client_id,
        session_id,
        reconnect_token
    )
    
    try:
        while True:
            data = await websocket.receive_json()
            await websocket_manager.handle_message(client_id, data)
            
    except WebSocketDisconnect as e:
        await websocket_manager.disconnect(client_id, e.code, e.reason)
    except Exception as e:
        logger.error(f"WebSocket error for {client_id}: {e}")
        await websocket_manager.disconnect(client_id, 1011, str(e))