"""
Application configuration
"""

import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, validator


class Settings(BaseSettings):
    """Application settings with environment variable support"""
    
    # API Configuration
    PROJECT_NAME: str = "Claude Code Backend API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/v1"
    DEBUG: bool = Field(default=False, env="DEBUG")
    PORT: int = Field(default=8000, env="PORT")
    
    # Anthropic Configuration
    ANTHROPIC_API_KEY: str = Field(..., env="ANTHROPIC_API_KEY")
    ANTHROPIC_MODEL: str = Field(default="claude-3-opus-20240229", env="ANTHROPIC_MODEL")
    ANTHROPIC_MAX_TOKENS: int = Field(default=4096, env="ANTHROPIC_MAX_TOKENS")
    
    # Database Configuration
    DATABASE_URL: str = Field(
        default="sqlite+aiosqlite:///./claude_code.db",
        env="DATABASE_URL"
    )
    
    # Redis Configuration (for caching and rate limiting)
    REDIS_URL: Optional[str] = Field(default=None, env="REDIS_URL")
    CACHE_TTL: int = Field(default=3600, env="CACHE_TTL")  # 1 hour default
    
    # CORS Configuration - Allow all origins
    CORS_ORIGINS: List[str] = Field(
        default=["*"],  # Allow all origins
        env="CORS_ORIGINS"
    )
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = Field(default=True, env="RATE_LIMIT_ENABLED")
    RATE_LIMIT_REQUESTS: int = Field(default=100, env="RATE_LIMIT_REQUESTS")
    RATE_LIMIT_PERIOD: int = Field(default=60, env="RATE_LIMIT_PERIOD")  # seconds
    
    # Session Configuration
    SESSION_TIMEOUT: int = Field(default=3600, env="SESSION_TIMEOUT")  # 1 hour
    MAX_SESSIONS_PER_USER: int = Field(default=10, env="MAX_SESSIONS_PER_USER")
    
    # MCP Configuration
    MCP_CONFIG_DIR: str = Field(default="/workspace/.claude", env="MCP_CONFIG_DIR")
    MCP_DISCOVERY_ENABLED: bool = Field(default=True, env="MCP_DISCOVERY_ENABLED")
    MCP_AUDIT_LOGGING: bool = Field(default=True, env="MCP_AUDIT_LOGGING")
    
    # File System Configuration
    WORKSPACE_DIR: str = Field(default="/workspace", env="WORKSPACE_DIR")
    MAX_FILE_SIZE: int = Field(default=10485760, env="MAX_FILE_SIZE")  # 10MB
    ALLOWED_FILE_EXTENSIONS: List[str] = Field(
        default=[".txt", ".md", ".py", ".js", ".ts", ".json", ".yaml", ".yml"],
        env="ALLOWED_FILE_EXTENSIONS"
    )
    
    # Security Configuration - JWT Authentication
    SECRET_KEY: str = Field(
        default="CHANGE-THIS-IN-PRODUCTION-USE-SECURE-RANDOM-KEY",
        env="SECRET_KEY"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=15, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7, env="REFRESH_TOKEN_EXPIRE_DAYS")
    ALGORITHM: str = Field(default="RS256", env="ALGORITHM")  # Using RS256 for JWT
    
    # Monitoring Configuration
    METRICS_ENABLED: bool = Field(default=True, env="METRICS_ENABLED")
    TRACING_ENABLED: bool = Field(default=False, env="TRACING_ENABLED")
    LOG_LEVEL: str = Field(default="INFO", env="LOG_LEVEL")
    
    # Analytics Configuration
    ANALYTICS_ENABLED: bool = Field(default=True, env="ANALYTICS_ENABLED")
    ANALYTICS_RETENTION_DAYS: int = Field(default=30, env="ANALYTICS_RETENTION_DAYS")
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True
    )
    
    @validator("CORS_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v):
        """Parse CORS origins from comma-separated string"""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v
    
    @validator("ALLOWED_FILE_EXTENSIONS", pre=True)
    def assemble_file_extensions(cls, v):
        """Parse file extensions from comma-separated string"""
        if isinstance(v, str):
            return [ext.strip() for ext in v.split(",")]
        return v
    
    @validator("DATABASE_URL")
    def validate_database_url(cls, v):
        """Ensure async SQLAlchemy driver is used"""
        if v.startswith("sqlite://"):
            return v.replace("sqlite://", "sqlite+aiosqlite://")
        elif v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+asyncpg://")
        return v
    
    @property
    def redis_enabled(self) -> bool:
        """Check if Redis is configured"""
        return self.REDIS_URL is not None
    
    @property
    def workspace_path(self):
        """Get workspace directory path"""
        return os.path.abspath(self.WORKSPACE_DIR)
    
    @property
    def mcp_config_path(self):
        """Get MCP configuration directory path"""
        return os.path.abspath(self.MCP_CONFIG_DIR)


# Create settings instance
settings = Settings()