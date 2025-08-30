"""
Simple cache manager for the backend
"""

from typing import Optional, Any
import json
from datetime import datetime, timedelta


class CacheManager:
    """Simple in-memory cache manager"""
    
    def __init__(self):
        self.cache = {}
        self.expiry_times = {}
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        # Check if key exists and hasn't expired
        if key in self.cache:
            if key in self.expiry_times:
                if datetime.now() > self.expiry_times[key]:
                    # Expired, remove it
                    del self.cache[key]
                    del self.expiry_times[key]
                    return None
            return self.cache[key]
        return None
    
    async def set(self, key: str, value: Any, expire: int = 3600) -> bool:
        """Set value in cache with optional expiry (in seconds)"""
        self.cache[key] = value
        if expire:
            self.expiry_times[key] = datetime.now() + timedelta(seconds=expire)
        return True
    
    async def delete(self, key: str) -> bool:
        """Delete key from cache"""
        if key in self.cache:
            del self.cache[key]
            if key in self.expiry_times:
                del self.expiry_times[key]
            return True
        return False
    
    async def exists(self, key: str) -> bool:
        """Check if key exists in cache"""
        return key in self.cache
    
    async def clear(self) -> bool:
        """Clear all cache"""
        self.cache.clear()
        self.expiry_times.clear()
        return True
    
    async def ttl(self, key: str) -> int:
        """Get time to live for key (in seconds)"""
        if key in self.expiry_times:
            remaining = (self.expiry_times[key] - datetime.now()).total_seconds()
            return max(0, int(remaining))
        return -1


# Global cache manager instance
cache_manager = CacheManager()