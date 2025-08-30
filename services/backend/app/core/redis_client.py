"""
Redis client for caching, rate limiting, and session management
"""

import redis.asyncio as redis
from typing import Optional
from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

# Global Redis client
_redis_client: Optional[redis.Redis] = None


async def init_redis() -> Optional[redis.Redis]:
    """
    Initialize Redis connection
    
    Returns:
        Redis client if configured, None otherwise
    """
    global _redis_client
    
    if not settings.REDIS_URL:
        logger.info("Redis not configured, skipping initialization")
        return None
    
    try:
        _redis_client = redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=50,
            health_check_interval=30
        )
        
        # Test connection
        await _redis_client.ping()
        logger.info("Redis connection established successfully")
        return _redis_client
        
    except Exception as e:
        logger.error(f"Failed to connect to Redis: {str(e)}")
        _redis_client = None
        return None


async def close_redis():
    """Close Redis connection"""
    global _redis_client
    
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis connection closed")


async def get_redis_client() -> Optional[redis.Redis]:
    """
    Get Redis client instance
    
    Returns:
        Redis client if available, None otherwise
    """
    global _redis_client
    
    if _redis_client is None:
        await init_redis()
    
    return _redis_client


# Utility functions for common Redis operations
class RedisCache:
    """Redis cache utilities"""
    
    @staticmethod
    async def get(key: str) -> Optional[str]:
        """Get value from cache"""
        client = await get_redis_client()
        if not client:
            return None
        
        try:
            return await client.get(key)
        except Exception as e:
            logger.error(f"Redis get error: {str(e)}")
            return None
    
    @staticmethod
    async def set(key: str, value: str, expire: int = None) -> bool:
        """Set value in cache with optional expiration"""
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            if expire:
                await client.setex(key, expire, value)
            else:
                await client.set(key, value)
            return True
        except Exception as e:
            logger.error(f"Redis set error: {str(e)}")
            return False
    
    @staticmethod
    async def delete(key: str) -> bool:
        """Delete key from cache"""
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            await client.delete(key)
            return True
        except Exception as e:
            logger.error(f"Redis delete error: {str(e)}")
            return False
    
    @staticmethod
    async def exists(key: str) -> bool:
        """Check if key exists in cache"""
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            return await client.exists(key) > 0
        except Exception as e:
            logger.error(f"Redis exists error: {str(e)}")
            return False
    
    @staticmethod
    async def expire(key: str, seconds: int) -> bool:
        """Set expiration time for a key"""
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            return await client.expire(key, seconds)
        except Exception as e:
            logger.error(f"Redis expire error: {str(e)}")
            return False
    
    @staticmethod
    async def increment(key: str, amount: int = 1) -> Optional[int]:
        """Increment a counter"""
        client = await get_redis_client()
        if not client:
            return None
        
        try:
            return await client.incrby(key, amount)
        except Exception as e:
            logger.error(f"Redis increment error: {str(e)}")
            return None


class SessionStore:
    """Redis-based session storage"""
    
    @staticmethod
    async def create_session(user_id: str, session_data: dict, ttl: int = 3600) -> str:
        """Create a new session"""
        import uuid
        import json
        
        session_id = str(uuid.uuid4())
        key = f"session:{session_id}"
        
        client = await get_redis_client()
        if not client:
            return session_id  # Return ID even if Redis unavailable
        
        try:
            session_data["user_id"] = user_id
            session_data["session_id"] = session_id
            
            await client.setex(key, ttl, json.dumps(session_data))
            
            # Track user's active sessions
            user_sessions_key = f"user_sessions:{user_id}"
            await client.sadd(user_sessions_key, session_id)
            await client.expire(user_sessions_key, ttl)
            
            return session_id
        except Exception as e:
            logger.error(f"Session creation error: {str(e)}")
            return session_id
    
    @staticmethod
    async def get_session(session_id: str) -> Optional[dict]:
        """Get session data"""
        import json
        
        client = await get_redis_client()
        if not client:
            return None
        
        try:
            key = f"session:{session_id}"
            data = await client.get(key)
            
            if data:
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Session retrieval error: {str(e)}")
            return None
    
    @staticmethod
    async def update_session(session_id: str, session_data: dict, ttl: int = 3600) -> bool:
        """Update session data"""
        import json
        
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            key = f"session:{session_id}"
            await client.setex(key, ttl, json.dumps(session_data))
            return True
        except Exception as e:
            logger.error(f"Session update error: {str(e)}")
            return False
    
    @staticmethod
    async def delete_session(session_id: str) -> bool:
        """Delete a session"""
        client = await get_redis_client()
        if not client:
            return False
        
        try:
            key = f"session:{session_id}"
            
            # Get session to find user ID
            session_data = await SessionStore.get_session(session_id)
            if session_data and "user_id" in session_data:
                # Remove from user's active sessions
                user_sessions_key = f"user_sessions:{session_data['user_id']}"
                await client.srem(user_sessions_key, session_id)
            
            # Delete session
            await client.delete(key)
            return True
        except Exception as e:
            logger.error(f"Session deletion error: {str(e)}")
            return False
    
    @staticmethod
    async def get_user_sessions(user_id: str) -> list[str]:
        """Get all active sessions for a user"""
        client = await get_redis_client()
        if not client:
            return []
        
        try:
            user_sessions_key = f"user_sessions:{user_id}"
            sessions = await client.smembers(user_sessions_key)
            return list(sessions) if sessions else []
        except Exception as e:
            logger.error(f"User sessions retrieval error: {str(e)}")
            return []
    
    @staticmethod
    async def invalidate_user_sessions(user_id: str) -> int:
        """Invalidate all sessions for a user"""
        client = await get_redis_client()
        if not client:
            return 0
        
        try:
            sessions = await SessionStore.get_user_sessions(user_id)
            
            # Delete all sessions
            for session_id in sessions:
                await SessionStore.delete_session(session_id)
            
            # Clear user sessions set
            user_sessions_key = f"user_sessions:{user_id}"
            await client.delete(user_sessions_key)
            
            return len(sessions)
        except Exception as e:
            logger.error(f"Session invalidation error: {str(e)}")
            return 0