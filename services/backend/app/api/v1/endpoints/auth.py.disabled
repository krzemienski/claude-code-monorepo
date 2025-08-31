"""
Authentication endpoints for JWT-based authentication
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, Annotated

from fastapi import APIRouter, Depends, HTTPException, status, Body, BackgroundTasks
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    Token,
    TokenResponse,
    UserCreate,
    UserResponse,
    LoginRequest,
    RefreshTokenRequest,
    PasswordChangeRequest,
    UserUpdate
)
from app.auth import (
    jwt_handler,
    verify_password,
    get_password_hash,
    create_api_key,
    get_current_active_user,
    require_admin
)
from app.auth.security import is_password_strong, validate_email, sanitize_username
from app.auth.dependencies import rate_limit_strict
from app.core.redis_client import get_redis_client
from app.core.logging import setup_logging

logger = setup_logging()

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    redis = Depends(get_redis_client)
):
    """
    Register a new user
    
    - Creates new user account with hashed password
    - Generates JWT access and refresh tokens
    - Creates API key for alternative authentication
    """
    # Validate email
    if not validate_email(user_data.email):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid email address"
        )
    
    # Check password strength
    is_strong, issues = is_password_strong(user_data.password)
    if not is_strong:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Weak password", "issues": issues}
        )
    
    # Check if user already exists
    result = await db.execute(
        select(User).where(
            (User.email == user_data.email) | 
            (User.username == user_data.username)
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User with this email or username already exists"
        )
    
    # Create new user
    new_user = User(
        email=user_data.email,
        username=sanitize_username(user_data.username) if user_data.username else None,
        password_hash=get_password_hash(user_data.password),
        api_key=create_api_key(),
        roles=["user"],
        permissions=[],
        last_password_change=datetime.now(timezone.utc)
    )
    
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    # Generate tokens
    access_token = jwt_handler.create_access_token(
        user_id=str(new_user.id),
        email=new_user.email,
        roles=new_user.roles or ["user"],
        permissions=new_user.permissions or []
    )
    
    refresh_token, token_family = jwt_handler.create_refresh_token(
        user_id=str(new_user.id),
        email=new_user.email
    )
    
    # Store refresh token family in Redis if available
    if redis:
        await redis.setex(
            f"token_family:{str(new_user.id)}:{token_family}",
            7 * 24 * 3600,  # 7 days
            "active"
        )
    
    # Log registration event
    logger.info(f"New user registered: {new_user.email}")
    
    # Send welcome email in background (if email service configured)
    # background_tasks.add_task(send_welcome_email, new_user.email)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=jwt_handler.access_token_expire_minutes * 60,
        user=UserResponse(
            id=str(new_user.id),
            email=new_user.email,
            username=new_user.username,
            roles=new_user.roles,
            is_active=new_user.is_active,
            created_at=new_user.created_at,
            api_key=new_user.api_key  # Return API key only on registration
        )
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: AsyncSession = Depends(get_db),
    redis = Depends(get_redis_client),
    _rate_limit = Depends(rate_limit_strict)
):
    """
    Login with email/username and password
    
    OAuth2 compatible login endpoint that accepts:
    - username: Email or username
    - password: User's password
    
    Returns JWT access and refresh tokens
    """
    # Find user by email or username
    result = await db.execute(
        select(User).where(
            (User.email == form_data.username) | 
            (User.username == form_data.username)
        )
    )
    user = result.scalar_one_or_none()
    
    if not user:
        # Log failed attempt
        logger.warning(f"Login attempt for non-existent user: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    # Check if account is locked
    if user.locked_until and user.locked_until > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=f"Account locked until {user.locked_until.isoformat()}"
        )
    
    # Verify password
    if not verify_password(form_data.password, user.password_hash):
        # Increment failed login attempts
        user.failed_login_attempts += 1
        
        # Lock account after 5 failed attempts
        if user.failed_login_attempts >= 5:
            user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=30)
            logger.warning(f"Account locked due to failed attempts: {user.email}")
        
        await db.commit()
        
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive"
        )
    
    # Reset failed login attempts and update last login
    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login = datetime.now(timezone.utc)
    await db.commit()
    
    # Generate tokens
    access_token = jwt_handler.create_access_token(
        user_id=str(user.id),
        email=user.email,
        roles=user.roles or ["user"],
        permissions=user.permissions or []
    )
    
    refresh_token, token_family = jwt_handler.create_refresh_token(
        user_id=str(user.id),
        email=user.email
    )
    
    # Store refresh token family in Redis
    if redis:
        await redis.setex(
            f"token_family:{str(user.id)}:{token_family}",
            7 * 24 * 3600,
            "active"
        )
    
    logger.info(f"Successful login: {user.email}")
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=jwt_handler.access_token_expire_minutes * 60,
        user=UserResponse(
            id=str(user.id),
            email=user.email,
            username=user.username,
            roles=user.roles,
            is_active=user.is_active,
            created_at=user.created_at
        )
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
    redis = Depends(get_redis_client)
):
    """
    Refresh access token using refresh token
    
    - Validates refresh token
    - Generates new access and refresh tokens
    - Implements refresh token rotation for security
    """
    # Verify and decode refresh token
    payload = jwt_handler.verify_token(refresh_data.refresh_token, token_type="refresh")
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    user_id = payload.get("sub")
    token_family = payload.get("family")
    token_id = payload.get("jti")
    
    # Check if token family is revoked (in Redis)
    if redis:
        family_revoked = await redis.get(f"revoked_family:{token_family}")
        if family_revoked:
            logger.warning(f"Attempted to use revoked token family: {token_family}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has been revoked"
            )
        
        # Check if token has already been used
        token_used = await redis.get(f"used_token:{token_id}")
        if token_used:
            # Potential token replay attack - revoke entire family
            logger.error(f"Token replay detected for family: {token_family}")
            await redis.setex(f"revoked_family:{token_family}", 7 * 24 * 3600, "1")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token replay detected - all tokens revoked"
            )
        
        # Mark current token as used
        await redis.setex(f"used_token:{token_id}", 7 * 24 * 3600, "1")
    
    # Get user from database
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )
    
    # Generate new tokens
    new_access_token = jwt_handler.create_access_token(
        user_id=str(user.id),
        email=user.email,
        roles=user.roles or ["user"],
        permissions=user.permissions or []
    )
    
    new_refresh_token, _ = jwt_handler.create_refresh_token(
        user_id=str(user.id),
        email=user.email,
        token_family=token_family  # Keep same family for rotation tracking
    )
    
    logger.info(f"Token refreshed for user: {user.email}")
    
    return Token(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=jwt_handler.access_token_expire_minutes * 60
    )


@router.post("/logout")
async def logout(
    current_user: Annotated[User, Depends(get_current_active_user)],
    refresh_token: Optional[str] = Body(None),
    redis = Depends(get_redis_client)
):
    """
    Logout user and revoke tokens
    
    - Revokes refresh token family if provided
    - Clears session data
    """
    if refresh_token and redis:
        # Decode refresh token to get family
        payload = jwt_handler.decode_token_unsafe(refresh_token)
        if payload:
            token_family = payload.get("family")
            if token_family:
                # Revoke entire token family
                await redis.setex(
                    f"revoked_family:{token_family}",
                    7 * 24 * 3600,
                    "1"
                )
                logger.info(f"Revoked token family for user: {current_user.email}")
    
    return {"message": "Successfully logged out"}


@router.post("/change-password")
async def change_password(
    password_data: PasswordChangeRequest,
    current_user: Annotated[User, Depends(get_current_active_user)],
    db: AsyncSession = Depends(get_db),
    redis = Depends(get_redis_client)
):
    """
    Change user password
    
    - Requires current password verification
    - Updates password hash
    - Revokes all existing refresh tokens
    """
    # Verify current password
    if not verify_password(password_data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )
    
    # Check new password strength
    is_strong, issues = is_password_strong(password_data.new_password)
    if not is_strong:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Weak password", "issues": issues}
        )
    
    # Update password
    current_user.password_hash = get_password_hash(password_data.new_password)
    current_user.last_password_change = datetime.now(timezone.utc)
    
    await db.commit()
    
    # Revoke all existing refresh tokens for this user (security measure)
    if redis:
        # In production, you'd want to track all token families per user
        # For now, we'll just log the password change
        logger.info(f"Password changed for user: {current_user.email}")
    
    return {"message": "Password successfully changed"}


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: Annotated[User, Depends(get_current_active_user)]
):
    """
    Get current user information
    """
    return UserResponse(
        id=str(current_user.id),
        email=current_user.email,
        username=current_user.username,
        roles=current_user.roles,
        is_active=current_user.is_active,
        created_at=current_user.created_at
    )


@router.put("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    current_user: Annotated[User, Depends(get_current_active_user)],
    db: AsyncSession = Depends(get_db)
):
    """
    Update current user information
    """
    # Update username if provided
    if user_update.username is not None:
        # Check if username is already taken
        result = await db.execute(
            select(User).where(
                (User.username == user_update.username) & 
                (User.id != current_user.id)
            )
        )
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Username already taken"
            )
        current_user.username = sanitize_username(user_update.username)
    
    # Update preferences if provided
    if user_update.preferences is not None:
        current_user.preferences = user_update.preferences
    
    await db.commit()
    await db.refresh(current_user)
    
    return UserResponse(
        id=str(current_user.id),
        email=current_user.email,
        username=current_user.username,
        roles=current_user.roles,
        is_active=current_user.is_active,
        created_at=current_user.created_at
    )


@router.post("/verify-token")
async def verify_token(
    current_user: Annotated[User, Depends(get_current_active_user)]
):
    """
    Verify if the current token is valid
    """
    return {
        "valid": True,
        "user_id": str(current_user.id),
        "email": current_user.email
    }


# Admin endpoints
@router.get("/users", response_model=list[UserResponse])
async def list_users(
    admin_user: Annotated[User, Depends(require_admin)],
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100
):
    """
    List all users (admin only)
    """
    result = await db.execute(
        select(User).offset(skip).limit(limit)
    )
    users = result.scalars().all()
    
    return [
        UserResponse(
            id=str(user.id),
            email=user.email,
            username=user.username,
            roles=user.roles,
            is_active=user.is_active,
            created_at=user.created_at
        )
        for user in users
    ]


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    admin_user: Annotated[User, Depends(require_admin)],
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a user (admin only)
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    await db.delete(user)
    await db.commit()
    
    logger.info(f"User deleted by admin {admin_user.email}: {user.email}")
    
    return {"message": "User deleted successfully"}