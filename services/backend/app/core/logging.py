"""
Logging configuration for Claude Code Backend
"""

import logging
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional

import structlog
from structlog.processors import JSONRenderer, TimeStamper, add_log_level
from structlog.stdlib import LoggerFactory

from app.core.config import settings


def setup_logging(log_level: Optional[str] = None) -> logging.Logger:
    """
    Configure structured logging for the application
    
    Args:
        log_level: Override log level from settings
        
    Returns:
        Configured logger instance
    """
    # Use provided log level or fall back to settings
    level = log_level or settings.LOG_LEVEL
    
    # Configure standard logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, level.upper(), logging.INFO)
    )
    
    # Configure structlog
    structlog.configure(
        processors=[
            TimeStamper(fmt="iso"),
            add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            JSONRenderer() if settings.ENVIRONMENT == "production" else structlog.dev.ConsoleRenderer()
        ],
        context_class=dict,
        logger_factory=LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Get logger
    logger = structlog.get_logger()
    
    # Log startup information
    logger.info(
        "Logging configured",
        level=level,
        environment=settings.ENVIRONMENT,
        debug=settings.DEBUG
    )
    
    return logger


def get_logger(name: str = __name__) -> structlog.BoundLogger:
    """
    Get a logger instance for a specific module
    
    Args:
        name: Logger name (usually __name__)
        
    Returns:
        Configured logger instance
    """
    return structlog.get_logger(name)


# Create log directory if it doesn't exist
def ensure_log_directory():
    """Ensure log directory exists"""
    log_dir = Path("logs")
    if not log_dir.exists():
        log_dir.mkdir(parents=True, exist_ok=True)
        

# Initialize on import
ensure_log_directory()