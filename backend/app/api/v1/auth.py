from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.rate_limit import login_rate_limiter
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    get_password_hash,
    hash_refresh_token,
    verify_password,
)
from app.models.refresh_token import RefreshToken
from app.models.user import User, UserRole
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    RefreshTokenRequest,
    TokenResponse,
    UserSummary,
)
from app.services.audit_service import log_audit_event

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/login", response_model=TokenResponse)
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    identifier = login_data.username_or_email.strip().lower()

    # 0. Check Login Rate Limiting (Protects against credential stuffing and brute-force)
    login_rate_limiter.check_rate_limit(identifier)
    
    # 1. Lookup user by email OR username (case-insensitive)
    query = select(User).where(
        or_(
            func.lower(User.email) == identifier,
            func.lower(User.username) == identifier,
        )
    )
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    # 2. Validate user existence and password
    password_valid = False
    if user:
        password_valid = verify_password(login_data.password, user.hashed_password) or (
            login_data.password.strip() != login_data.password
            and verify_password(login_data.password.strip(), user.hashed_password)
        )

    if not user or not password_valid:
        login_rate_limiter.record_failed_attempt(identifier)
        await log_audit_event(
            db=db,
            action="LOGIN_FAILED",
            metadata={"identifier": identifier, "reason": "invalid_credentials"},
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username/email or password. Please verify your credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 3. Check account active status
    if not user.is_active:
        await log_audit_event(
            db=db,
            action="LOGIN_BLOCKED_INACTIVE",
            actor_id=user.id,
            actor_role=user.role,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is currently deactivated. Please contact management.",
        )
        
    # 4. Enforce Portal-Specific Role Requirements
    if login_data.portal:
        portal = login_data.portal.strip().lower()
        if portal == "admin":
            if user.role not in [UserRole.OWNER.value, UserRole.MANAGER.value]:
                await log_audit_event(
                    db=db,
                    action="ADMIN_PORTAL_ACCESS_DENIED",
                    actor_id=user.id,
                    actor_role=user.role,
                )
                await db.commit()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied: Employee accounts cannot access the Administrator dashboard. Please use Employee Login.",
                )
        elif portal == "employee":
            # Field app portal
            pass

    # 5. Generate short-lived access token
    access_token = create_access_token(subject=user.id, role=user.role)
    
    # 6. Generate and persist secure refresh token
    raw_refresh_token = generate_refresh_token()
    token_hash = hash_refresh_token(raw_refresh_token)
    refresh_record = RefreshToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        is_revoked=False,
    )
    db.add(refresh_record)

    login_rate_limiter.record_successful_attempt(identifier)
    await log_audit_event(
        db=db,
        action="LOGIN_SUCCESS",
        actor_id=user.id,
        actor_role=user.role,
        metadata={"portal": login_data.portal},
    )
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="bearer",
        expires_in_seconds=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserSummary.model_validate(user)
    )

@router.post("/refresh", response_model=TokenResponse)
async def refresh_access_token(
    request: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db)
):
    token_hash = hash_refresh_token(request.refresh_token)
    now = datetime.now(timezone.utc)

    # Lookup valid, non-revoked, unexpired refresh token
    query = select(RefreshToken).where(
        RefreshToken.token_hash == token_hash,
        RefreshToken.is_revoked.is_(False),
        RefreshToken.expires_at > now
    )
    result = await db.execute(query)
    token_record = result.scalar_one_or_none()

    if not token_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid, expired, or revoked refresh token. Please sign in again.",
        )

    # Fetch user associated with refresh token
    user_result = await db.execute(select(User).where(User.id == token_record.user_id))
    user = user_result.scalar_one_or_none()

    if not user or not user.is_active:
        token_record.is_revoked = True
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive or not found.",
        )

    # Rotate refresh token: revoke current, issue new
    token_record.is_revoked = True
    new_raw_refresh = generate_refresh_token()
    new_hash = hash_refresh_token(new_raw_refresh)
    new_record = RefreshToken(
        user_id=user.id,
        token_hash=new_hash,
        expires_at=now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        is_revoked=False,
    )
    db.add(new_record)

    new_access_token = create_access_token(subject=user.id, role=user.role)
    await log_audit_event(
        db=db,
        action="TOKEN_REFRESH",
        actor_id=user.id,
        actor_role=user.role,
    )
    await db.commit()

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_raw_refresh,
        token_type="bearer",
        expires_in_seconds=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserSummary.model_validate(user)
    )

@router.post("/logout", response_model=MessageResponse)
async def logout(
    request: LogoutRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if request.refresh_token:
        token_hash = hash_refresh_token(request.refresh_token)
        query = select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.user_id == current_user.id
        )
        res = await db.execute(query)
        token_record = res.scalar_one_or_none()
        if token_record:
            token_record.is_revoked = True

    await log_audit_event(
        db=db,
        action="LOGOUT",
        actor_id=current_user.id,
        actor_role=current_user.role,
    )
    await db.commit()
    return MessageResponse(message="Successfully logged out.")

@router.get("/me", response_model=UserSummary)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    return UserSummary.model_validate(current_user)

@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    req: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Allows authenticated users to change their password.
    Clears must_change_password flag, revokes previous refresh tokens,
    and removes recoverable assigned_password ciphertext.
    """
    if not verify_password(req.old_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password verification failed."
        )

    if req.old_password == req.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password."
        )

    current_user.hashed_password = get_password_hash(req.new_password)
    current_user.must_change_password = False
    current_user.assigned_password = None

    # Invalidate existing refresh tokens
    token_query = select(RefreshToken).where(RefreshToken.user_id == current_user.id)
    tokens_res = await db.execute(token_query)
    for tok in tokens_res.scalars().all():
        tok.is_revoked = True

    await log_audit_event(
        db=db,
        action="PASSWORD_CHANGED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        metadata={"user_id": current_user.id, "username": current_user.username},
    )
    await db.commit()
    return MessageResponse(message="Password changed successfully.")
