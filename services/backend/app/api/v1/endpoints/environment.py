"""
Environment endpoint - Reports host system information
Provides real-time environment data about the host system
Mirrors Claude Code's environment reporting structure
"""

import os
import sys
import platform
import socket
from datetime import datetime
from typing import Dict, Any, List, Optional
from pathlib import Path

# Try to import psutil, provide fallback if not available
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

# Try to import pkg_resources for package listing
try:
    import pkg_resources
    PKG_RESOURCES_AVAILABLE = True
except ImportError:
    PKG_RESOURCES_AVAILABLE = False

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.deps import get_optional_user

router = APIRouter()


class SystemInfo(BaseModel):
    """System information model"""
    platform: str
    platform_release: str
    platform_version: str
    architecture: str
    hostname: str
    ip_address: str
    processor: str
    python_version: str
    python_implementation: str


class MemoryInfo(BaseModel):
    """Memory information model"""
    total: int
    available: int
    percent: float
    used: int
    free: int


class DiskInfo(BaseModel):
    """Disk information model"""
    total: int
    used: int
    free: int
    percent: float


class ProcessInfo(BaseModel):
    """Process information model"""
    pid: int
    name: str
    username: str
    cpu_percent: float
    memory_percent: float
    status: str
    create_time: float


class EnvironmentVariables(BaseModel):
    """Filtered environment variables"""
    python_path: Optional[str]
    virtual_env: Optional[str]
    path: Optional[str]
    home: Optional[str]
    user: Optional[str]
    shell: Optional[str]
    term: Optional[str]
    lang: Optional[str]
    pwd: Optional[str]
    hostname: Optional[str]


class PythonPackage(BaseModel):
    """Python package information"""
    name: str
    version: str


class EnvironmentResponse(BaseModel):
    """Complete environment response"""
    timestamp: datetime
    system: SystemInfo
    memory: MemoryInfo
    disk: DiskInfo
    process: ProcessInfo
    environment: EnvironmentVariables
    python_packages: List[PythonPackage]
    working_directory: str
    user: str
    cpu_count: int
    cpu_percent: float


def get_safe_env_vars() -> Dict[str, Optional[str]]:
    """Get filtered environment variables (excluding sensitive data)"""
    safe_keys = [
        "PYTHONPATH", "VIRTUAL_ENV", "PATH", "HOME", "USER",
        "SHELL", "TERM", "LANG", "PWD", "HOSTNAME"
    ]
    
    env_vars = {}
    for key in safe_keys:
        env_vars[key.lower().replace("_", "_")] = os.environ.get(key)
    
    return env_vars


def get_system_info() -> Dict[str, Any]:
    """Collect system information"""
    hostname = socket.gethostname()
    
    try:
        ip_address = socket.gethostbyname(hostname)
    except:
        ip_address = "127.0.0.1"
    
    return {
        "platform": platform.system(),
        "platform_release": platform.release(),
        "platform_version": platform.version(),
        "architecture": platform.machine(),
        "hostname": hostname,
        "ip_address": ip_address,
        "processor": platform.processor() or "Unknown",
        "python_version": sys.version,
        "python_implementation": platform.python_implementation()
    }


def get_memory_info() -> Dict[str, Any]:
    """Get memory information"""
    if not PSUTIL_AVAILABLE:
        # Provide fallback values when psutil is not available
        return {
            "total": 0,
            "available": 0,
            "percent": 0.0,
            "used": 0,
            "free": 0,
            "error": "psutil not available"
        }
    
    mem = psutil.virtual_memory()
    return {
        "total": mem.total,
        "available": mem.available,
        "percent": mem.percent,
        "used": mem.used,
        "free": mem.free
    }


def get_disk_info() -> Dict[str, Any]:
    """Get disk usage information for current directory"""
    if not PSUTIL_AVAILABLE:
        return {
            "total": 0,
            "used": 0,
            "free": 0,
            "percent": 0.0,
            "error": "psutil not available"
        }
    
    disk = psutil.disk_usage('/')
    return {
        "total": disk.total,
        "used": disk.used,
        "free": disk.free,
        "percent": disk.percent
    }


def get_process_info() -> Dict[str, Any]:
    """Get current process information"""
    if not PSUTIL_AVAILABLE:
        return {
            "pid": os.getpid(),
            "name": "python",
            "username": os.environ.get("USER", "unknown"),
            "cpu_percent": 0.0,
            "memory_percent": 0.0,
            "status": "running",
            "create_time": 0.0,
            "error": "psutil not available"
        }
    
    process = psutil.Process()
    
    try:
        username = process.username()
    except:
        username = "unknown"
    
    return {
        "pid": process.pid,
        "name": process.name(),
        "username": username,
        "cpu_percent": process.cpu_percent(interval=0.1),
        "memory_percent": process.memory_percent(),
        "status": process.status(),
        "create_time": process.create_time()
    }


def get_python_packages(limit: int = 50) -> List[Dict[str, str]]:
    """Get list of installed Python packages"""
    packages = []
    
    if not PKG_RESOURCES_AVAILABLE:
        # Return basic Python info when pkg_resources is not available
        return [{
            "name": "python",
            "version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        }]
    
    # Get key packages that are likely installed
    important_packages = [
        "fastapi", "uvicorn", "sqlalchemy", "pydantic", "anthropic",
        "redis", "psutil", "aiohttp", "httpx", "pytest", "alembic"
    ]
    
    installed_packages = {pkg.key: pkg.version for pkg in pkg_resources.working_set}
    
    # Add important packages first
    for pkg_name in important_packages:
        if pkg_name in installed_packages:
            packages.append({
                "name": pkg_name,
                "version": installed_packages[pkg_name]
            })
    
    # Add other packages up to limit
    for pkg_name, version in installed_packages.items():
        if pkg_name not in important_packages and len(packages) < limit:
            packages.append({
                "name": pkg_name,
                "version": version
            })
    
    return packages[:limit]


@router.get("", response_model=EnvironmentResponse)
async def get_environment(
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Get current host environment information.
    
    Returns comprehensive information about:
    - System (OS, platform, architecture)
    - Memory usage
    - Disk usage
    - Process information
    - Environment variables (filtered)
    - Python packages
    - Working directory
    """
    
    # Collect all environment data
    system_info = get_system_info()
    memory_info = get_memory_info()
    disk_info = get_disk_info()
    process_info = get_process_info()
    env_vars = get_safe_env_vars()
    packages = get_python_packages()
    
    # Get CPU information
    if PSUTIL_AVAILABLE:
        cpu_count = psutil.cpu_count()
        cpu_percent = psutil.cpu_percent(interval=0.1)
    else:
        cpu_count = os.cpu_count() or 1  # os.cpu_count() is available without psutil
        cpu_percent = 0.0
    
    # Get working directory and user
    working_dir = os.getcwd()
    current_user = os.environ.get("USER", "unknown")
    
    return EnvironmentResponse(
        timestamp=datetime.utcnow(),
        system=SystemInfo(**system_info),
        memory=MemoryInfo(**memory_info),
        disk=DiskInfo(**disk_info),
        process=ProcessInfo(**process_info),
        environment=EnvironmentVariables(
            python_path=env_vars.get("pythonpath"),
            virtual_env=env_vars.get("virtual_env"),
            path=env_vars.get("path"),
            home=env_vars.get("home"),
            user=env_vars.get("user"),
            shell=env_vars.get("shell"),
            term=env_vars.get("term"),
            lang=env_vars.get("lang"),
            pwd=env_vars.get("pwd"),
            hostname=env_vars.get("hostname")
        ),
        python_packages=[PythonPackage(**pkg) for pkg in packages],
        working_directory=working_dir,
        user=current_user,
        cpu_count=cpu_count,
        cpu_percent=cpu_percent
    )


@router.get("/summary")
async def get_environment_summary(
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Get a simplified environment summary.
    
    Returns basic environment information in a compact format.
    Similar to Claude Code's environment context.
    """
    
    summary = {
        "platform": f"{platform.system()} {platform.release()}",
        "os_version": platform.version(),
        "python": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "hostname": socket.gethostname(),
        "user": os.environ.get("USER", "unknown"),
        "working_directory": os.getcwd(),
        "cpu_count": os.cpu_count() or 1,
        "timestamp": datetime.utcnow().isoformat(),
        "is_git_repo": os.path.exists(os.path.join(os.getcwd(), ".git"))
    }
    
    # Add psutil-dependent fields if available
    if PSUTIL_AVAILABLE:
        summary.update({
            "memory_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "disk_free_gb": round(psutil.disk_usage('/').free / (1024**3), 2),
            "cpu_percent": psutil.cpu_percent(interval=0.1)
        })
    else:
        summary["psutil_available"] = False
    
    return summary


@router.get("/claude-format")
async def get_claude_format_environment(
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Get environment info in Claude Code's format.
    
    Returns environment information structured exactly like Claude Code's 
    environment context for seamless integration.
    """
    
    # Check if current directory is a git repo
    is_git_repo = os.path.exists(os.path.join(os.getcwd(), ".git"))
    
    # Get today's date
    today = datetime.now().strftime("%Y-%m-%d")
    
    # Build Claude Code compatible environment structure
    claude_env = {
        "working_directory": os.getcwd(),
        "is_directory_a_git_repo": "Yes" if is_git_repo else "No",
        "platform": platform.system().lower(),  # darwin, linux, windows
        "os_version": f"{platform.system()} {platform.release()}",
        "todays_date": today,
        "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "hostname": socket.gethostname(),
        "user": os.environ.get("USER", "unknown")
    }
    
    # Add hardware info if psutil is available
    if PSUTIL_AVAILABLE:
        mem = psutil.virtual_memory()
        claude_env.update({
            "cpu_count": psutil.cpu_count(),
            "memory_gb": round(mem.total / (1024**3), 2),
            "memory_available_gb": round(mem.available / (1024**3), 2),
            "disk_usage_percent": psutil.disk_usage('/').percent
        })
    else:
        claude_env.update({
            "cpu_count": os.cpu_count() or 1,
            "psutil_note": "Hardware metrics unavailable (psutil not installed)"
        })
    
    # Add environment variables (filtered for security)
    safe_env_vars = {
        "PATH": os.environ.get("PATH", "").split(":")[0:3],  # First 3 PATH entries only
        "VIRTUAL_ENV": os.environ.get("VIRTUAL_ENV"),
        "PYTHON_PATH": os.environ.get("PYTHONPATH"),
        "LANG": os.environ.get("LANG"),
        "SHELL": os.environ.get("SHELL")
    }
    
    # Filter out None values
    claude_env["environment_variables"] = {k: v for k, v in safe_env_vars.items() if v is not None}
    
    return claude_env