#!/usr/bin/env python3
"""
Simple FastAPI test to verify public access and environment endpoint
"""

import uvicorn
from fastapi import FastAPI
import platform
import psutil
import os
from datetime import datetime

app = FastAPI(title="Simple Test API")

@app.get("/health")
def health_check():
    """Health check - no auth required"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/v1/environment")
def get_environment():
    """Get real host environment information - no auth required"""
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "system": {
            "platform": platform.system(),
            "platform_release": platform.release(),
            "platform_version": platform.version(),
            "architecture": platform.machine(),
            "processor": platform.processor() or "Unknown",
            "python_version": platform.python_version()
        },
        "memory": {
            "total": mem.total,
            "available": mem.available,
            "percent": mem.percent,
            "used": mem.used,
            "free": mem.free
        },
        "disk": {
            "total": disk.total,
            "used": disk.used,
            "free": disk.free,
            "percent": disk.percent
        },
        "cpu_count": psutil.cpu_count(),
        "cpu_percent": psutil.cpu_percent(interval=0.1),
        "working_directory": os.getcwd(),
        "user": os.environ.get("USER", "unknown")
    }

@app.get("/")
def root():
    """Root endpoint - no auth required"""
    return {
        "name": "Simple Test API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "environment": "/v1/environment"
        },
        "authentication": "NONE - All endpoints are publicly accessible"
    }

if __name__ == "__main__":
    print("Starting Simple Test API on port 8002")
    print("ALL ENDPOINTS ARE PUBLIC - NO AUTHENTICATION REQUIRED")
    print("Visit http://localhost:8002/v1/environment for real host data")
    uvicorn.run(app, host="0.0.0.0", port=8002)