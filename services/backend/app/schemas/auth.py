"""
Pydantic schemas for authentication
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, EmailStr, Field, validator


class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr
    username: Optional[str] = None


class UserCreate(UserBase):
    """Schema for user registration"""
    password: str = Field(..., min_length=8, max_length=72)
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if len(v) > 72:  # bcrypt limitation
            raise ValueError('Password must not exceed 72 characters')
        return v


class UserUpdate(BaseModel):
    """Schema for user profile update"""
    username: Optional[str] = None
    preferences: Optional[Dict[str, Any]] = None


class UserResponse(UserBase):
    """Schema for user response"""
    id: str
    roles: Optional[List[str]] = Field(default_factory=lambda: ["user"])
    is_active: bool = True
    created_at: datetime
    api_key: Optional[str] = None  # Only returned on registration
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    """Token response schema"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # Seconds until access token expires


class TokenResponse(Token):
    """Extended token response with user info"""
    user: UserResponse


class LoginRequest(BaseModel):
    """Login request schema"""
    email: EmailStr
    password: str


class RefreshTokenRequest(BaseModel):
    """Refresh token request schema"""
    refresh_token: str


class PasswordChangeRequest(BaseModel):
    """Password change request schema"""
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=72)
    
    @validator('new_password')
    def validate_new_password(cls, v, values):
        if 'current_password' in values and v == values['current_password']:
            raise ValueError('New password must be different from current password')
        return v


class PasswordResetRequest(BaseModel):
    """Password reset request schema"""
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    """Password reset confirmation schema"""
    token: str
    new_password: str = Field(..., min_length=8, max_length=72)


class TokenPayload(BaseModel):
    """JWT token payload schema"""
    sub: str  # User ID
    email: str
    type: str  # "access" or "refresh"
    roles: List[str] = Field(default_factory=list)
    permissions: List[str] = Field(default_factory=list)
    iat: datetime
    exp: datetime
    iss: str
    aud: List[str]
    jti: Optional[str] = None  # JWT ID for refresh tokens
    family: Optional[str] = None  # Token family for refresh token rotation


class APIKeyCreate(BaseModel):
    """API key creation request"""
    name: str = Field(..., description="Name for the API key")
    expires_in_days: Optional[int] = Field(None, description="Days until expiration")
    permissions: List[str] = Field(default_factory=list)


class APIKeyResponse(BaseModel):
    """API key response"""
    id: str
    name: str
    key: str  # Only shown once on creation
    created_at: datetime
    expires_at: Optional[datetime] = None
    last_used: Optional[datetime] = None


class RoleUpdate(BaseModel):
    """Role update request (admin only)"""
    user_id: str
    roles: List[str]
    permissions: Optional[List[str]] = None


class SessionInfo(BaseModel):
    """Active session information"""
    session_id: str
    user_id: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime
    last_activity: datetime
    expires_at: datetime


class SecurityEvent(BaseModel):
    """Security event for audit logging"""
    event_type: str  # login, logout, password_change, etc.
    user_id: Optional[str] = None
    email: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    success: bool
    details: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)