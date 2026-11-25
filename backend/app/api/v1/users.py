from datetime import datetime, timezone
import secrets
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin, require_owner
from app.core.security import get_password_hash, encrypt_credential, decrypt_credential
from app.models.attendance import Attendance
from app.models.chat import ChatMessage, ChatRoom
from app.models.customer import Customer
from app.models.refresh_token import RefreshToken
from app.models.target import EmployeeTarget
from app.models.user import User, UserRole
from app.models.visit import FieldVisit
from app.schemas.auth import MessageResponse
from app.schemas.user import (
    AdminPasswordResetResponse,
    CreatedAccountResponse,
    EmployeeSupervisionItem,
    PaginatedUsersResponse,
    PasswordResetRequest,
    SupervisionListResponse,
    SupervisorOption,
    TransferSupervisorRequest,
    UpdateCredentialsRequest,
    RevealedCredentialResponse,
    UserCreate,
    UserResponse,
    UserUpdate,
)
from app.services.audit_service import log_audit_event

router = APIRouter(prefix="/users", tags=["User Management"])

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_in: UserCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Creates a new user account.
    Owner can create Managers and Employees.
    Managers can only create Employees in their team.
    """
    if current_user.role == UserRole.MANAGER.value:
        if user_in.role != UserRole.EMPLOYEE.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Managers can only provision Field Employee accounts.",
            )
        manager_id = current_user.id
    else:
        manager_id = user_in.manager_id

    # Check for existing email or username
    existing_query = select(User).where(
        or_(
            User.email == user_in.email.lower(),
            User.username == user_in.username.lower()
        )
    )
    existing_res = await db.execute(existing_query)
    if existing_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email or username already exists.",
        )

    new_user = User(
        full_name=user_in.full_name.strip(),
        email=user_in.email.lower(),
        username=user_in.username.lower().strip(),
        hashed_password=get_password_hash(user_in.password),
        role=user_in.role.upper(),
        manager_id=manager_id,
        created_by_id=current_user.id,
        assigned_password=None,
        must_change_password=True,
        is_active=user_in.is_active,
        phone=user_in.phone,
        designation=user_in.designation,
    )
    db.add(new_user)
    await db.flush()

    await log_audit_event(
        db=db,
        action="USER_CREATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=new_user.id,
        affected_record_type="User",
        metadata={"role": new_user.role, "email": new_user.email},
    )
    await db.commit()
    await db.refresh(new_user)
    return UserResponse.model_validate(new_user)

@router.get("/", response_model=PaginatedUsersResponse)
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    role: Optional[str] = Query(None, description="Filter by role"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    query = select(User)
    count_query = select(func.count(User.id))

    # Managers only see their team members
    if current_user.role == UserRole.MANAGER.value:
        query = query.where(User.manager_id == current_user.id)
        count_query = count_query.where(User.manager_id == current_user.id)

    if role:
        query = query.where(User.role == role.upper())
        count_query = count_query.where(User.role == role.upper())
    if is_active is not None:
        query = query.where(User.is_active == is_active)
        count_query = count_query.where(User.is_active == is_active)

    total_res = await db.execute(count_query)
    total = total_res.scalar() or 0

    query = query.order_by(User.created_at.desc()).offset(skip).limit(limit)
    res = await db.execute(query)
    users = res.scalars().all()

    return PaginatedUsersResponse(
        items=[UserResponse.model_validate(u) for u in users],
        total=total,
        skip=skip,
        limit=limit,
    )

@router.get("/created-accounts", response_model=List[CreatedAccountResponse])
async def list_created_accounts(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    CEO has full visibility into all created accounts (admins and employees),
    which admin created them, when they were created, and their login credentials.
    Admins can only see employee accounts that they personally created or manage.
    """
    from sqlalchemy.orm import aliased
    Creator = aliased(User)

    if current_user.role == UserRole.OWNER.value:
        query = (
            select(User, Creator.full_name.label("creator_name"))
            .outerjoin(Creator, User.created_by_id == Creator.id)
            .where(User.id != current_user.id)
            .order_by(User.created_at.desc())
        )
    elif current_user.role == UserRole.MANAGER.value:
        query = (
            select(User, Creator.full_name.label("creator_name"))
            .outerjoin(Creator, User.created_by_id == Creator.id)
            .where(
                or_(
                    User.created_by_id == current_user.id,
                    User.manager_id == current_user.id
                )
            )
            .where(User.id != current_user.id)
            .where(User.role == UserRole.EMPLOYEE.value)
            .order_by(User.created_at.desc())
        )
    else:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")

    res = await db.execute(query)
    rows = res.all()

    items = []
    for user_obj, creator_name in rows:
        items.append(
            CreatedAccountResponse(
                id=user_obj.id,
                full_name=user_obj.full_name,
                email=user_obj.email,
                username=user_obj.username,
                role=user_obj.role,
                is_active=user_obj.is_active,
                phone=user_obj.phone,
                designation=user_obj.designation,
                manager_id=user_obj.manager_id,
                created_at=user_obj.created_at,
                created_by_id=user_obj.created_by_id,
                created_by_name=creator_name or ("Executive Office (CEO)" if user_obj.created_by_id else "System Root"),
                login_password="••••••••",
                must_change_password=getattr(user_obj, "must_change_password", False),
            )
        )
    return items

@router.get("/supervision/list", response_model=SupervisionListResponse)
async def get_supervision_list(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns employees and available supervisors.
    CEO Mehmood Ayyaz: Full visibility of all employees, full power to assign/transfer anyone.
    Admin/Manager: Sees employees assigned to them or created by them, can transfer their reporting to any other admin.
    """
    from sqlalchemy.orm import aliased
    ManagerAlias = aliased(User)
    CreatorAlias = aliased(User)

    is_owner = current_user.role == UserRole.OWNER.value

    # 1. Fetch available supervisors (All managers + owner)
    sup_query = select(User).where(
        User.role.in_([UserRole.OWNER.value, UserRole.MANAGER.value]),
        User.is_active == True
    ).order_by(User.role.desc(), User.full_name.asc())
    sup_res = await db.execute(sup_query)
    available_supervisors = [
        SupervisorOption(
            id=u.id,
            full_name=u.full_name,
            username=u.username,
            role=u.role,
            designation=u.designation,
        )
        for u in sup_res.scalars().all()
    ]

    # 2. Fetch employees with their manager and creator details
    query = (
        select(
            User,
            ManagerAlias.full_name.label("mgr_name"),
            ManagerAlias.username.label("mgr_user"),
            CreatorAlias.full_name.label("creator_name")
        )
        .outerjoin(ManagerAlias, User.manager_id == ManagerAlias.id)
        .outerjoin(CreatorAlias, User.created_by_id == CreatorAlias.id)
        .where(User.role == UserRole.EMPLOYEE.value)
    )

    if not is_owner:
        # Manager only sees employees assigned to them OR created by them
        query = query.where(
            or_(
                User.manager_id == current_user.id,
                User.created_by_id == current_user.id
            )
        )

    query = query.order_by(User.full_name.asc())
    res = await db.execute(query)
    rows = res.all()

    employees = []
    for emp, mgr_name, mgr_user, creator_name in rows:
        can_transfer = is_owner or (emp.manager_id == current_user.id or emp.created_by_id == current_user.id)
        employees.append(
            EmployeeSupervisionItem(
                id=emp.id,
                full_name=emp.full_name,
                username=emp.username,
                email=emp.email,
                phone=emp.phone,
                designation=emp.designation,
                is_active=emp.is_active,
                manager_id=emp.manager_id,
                manager_name=mgr_name,
                manager_username=mgr_user,
                created_by_id=emp.created_by_id,
                created_by_name=creator_name or ("Executive Office (CEO)" if emp.created_by_id else "System Root"),
                can_transfer=can_transfer,
                created_at=emp.created_at,
            )
        )

    return SupervisionListResponse(
        employees=employees,
        available_supervisors=available_supervisors,
        is_owner=is_owner,
    )

@router.post("/supervision/transfer", response_model=MessageResponse)
async def transfer_employee_supervision(
    req: TransferSupervisorRequest,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    CEO can forcefully transfer any employee to any admin (or unassign).
    Admin can transfer mentorship or reporting of employees they created or currently supervise to another admin.
    """
    res = await db.execute(select(User).where(User.id == req.employee_id))
    employee = res.scalar_one_or_none()
    if not employee or employee.role != UserRole.EMPLOYEE.value:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Field employee not found.")

    is_owner = current_user.role == UserRole.OWNER.value

    # Permission check:
    if not is_owner:
        if employee.manager_id != current_user.id and employee.created_by_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You can only transfer employees that you created or supervise."
            )

    new_manager_name = "Unassigned"
    if req.new_manager_id:
        mgr_res = await db.execute(select(User).where(User.id == req.new_manager_id))
        new_mgr = mgr_res.scalar_one_or_none()
        if not new_mgr or new_mgr.role not in [UserRole.OWNER.value, UserRole.MANAGER.value]:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Selected supervisor is invalid.")
        new_manager_name = new_mgr.full_name

    old_manager_id = employee.manager_id
    employee.manager_id = req.new_manager_id

    await log_audit_event(
        db=db,
        action="SUPERVISOR_TRANSFERRED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=employee.id,
        affected_record_type="User",
        metadata={
            "employee_id": employee.id,
            "employee_name": employee.full_name,
            "old_manager_id": old_manager_id,
            "new_manager_id": req.new_manager_id,
            "transferred_by": current_user.username,
            "notes": req.notes,
        },
    )
    await db.commit()
    await db.refresh(employee)

    return MessageResponse(
        message=f"Reporting for {employee.full_name} transferred successfully to {new_manager_name}."
    )

@router.get("/{user_id}", response_model=UserResponse)
async def get_user_by_id(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    
    if current_user.role == UserRole.MANAGER.value and user.manager_id != current_user.id and user.id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to users outside your team.")
    
    return UserResponse.model_validate(user)
    
@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    user_in: UserUpdate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if current_user.role == UserRole.MANAGER.value and user.manager_id != current_user.id and user.id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")

    if user_in.full_name is not None:
        user.full_name = user_in.full_name.strip()
    if user_in.email is not None:
        user.email = user_in.email.lower()
    if user_in.phone is not None:
        user.phone = user_in.phone.strip() if user_in.phone.strip() else None
    if user_in.designation is not None:
        user.designation = user_in.designation.strip() if user_in.designation.strip() else None
    if user_in.manager_id is not None and current_user.role == UserRole.OWNER.value:
        user.manager_id = user_in.manager_id
    if user_in.is_active is not None:
        user.is_active = user_in.is_active
        if not user.is_active:
            token_query = select(RefreshToken).where(RefreshToken.user_id == user.id)
            tokens_res = await db.execute(token_query)
            for tok in tokens_res.scalars().all():
                tok.is_revoked = True

    await log_audit_event(
        db=db,
        action="USER_UPDATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=user.id,
        affected_record_type="User",
        metadata={"is_active": user.is_active},
    )
    await db.commit()
    await db.refresh(user)
    return UserResponse.model_validate(user)

@router.post("/{user_id}/activate", response_model=MessageResponse)
async def activate_user(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if current_user.role != UserRole.OWNER.value:
        if user.role in [UserRole.OWNER.value, UserRole.MANAGER.value]:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the CEO can modify Admin/Owner accounts.")
        if user.manager_id != current_user.id and user.created_by_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Employee outside your team.")

    user.is_active = True
    await log_audit_event(
        db=db,
        action="USER_ACTIVATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=user.id,
        affected_record_type="User",
    )
    await db.commit()
    return MessageResponse(message=f"Account for {user.username} has been activated.")

@router.post("/{user_id}/deactivate", response_model=MessageResponse)

async def deactivate_user(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if user.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot deactivate your own account.")

    if user.role == UserRole.OWNER.value:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="CEO / Owner account cannot be deactivated.")

    if current_user.role != UserRole.OWNER.value:
        if user.role == UserRole.MANAGER.value:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the CEO can deactivate Admin accounts.")
        if user.manager_id != current_user.id and user.created_by_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Employee outside your team.")

    user.is_active = False

    # Revoke all active refresh tokens immediately
    token_query = select(RefreshToken).where(RefreshToken.user_id == user.id)
    tokens_res = await db.execute(token_query)
    for tok in tokens_res.scalars().all():
        tok.is_revoked = True

    await log_audit_event(
        db=db,
        action="USER_DEACTIVATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=user.id,
        affected_record_type="User",
    )
    await db.commit()
    return MessageResponse(message=f"Account for {user.username} has been deactivated.")

@router.post("/{user_id}/reset-password", response_model=AdminPasswordResetResponse)
async def reset_password(
    user_id: str,
    req: Optional[PasswordResetRequest] = None,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Preferred modern security architecture: Secure password reset.
    Accepts custom new_password or generates a cryptographically random temporary password.
    Hashes it into hashed_password, sets must_change_password = True, and clears assigned_password.
    Strictly scoped: OWNER can reset any user; MANAGER can only reset supervised employees.
    """
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if current_user.role == UserRole.MANAGER.value:
        is_supervisor = user.manager_id == current_user.id
        is_creator = user.created_by_id == current_user.id
        if not (is_supervisor or is_creator):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You are not authorized to reset credentials for this user."
            )

    temp_pwd = req.new_password if (req and req.new_password) else ("Phyto#" + secrets.token_hex(4).upper())
    user.hashed_password = get_password_hash(temp_pwd)
    user.assigned_password = None
    user.must_change_password = True

    # Invalidate all existing refresh tokens
    token_query = select(RefreshToken).where(RefreshToken.user_id == user.id)
    tokens_res = await db.execute(token_query)
    for tok in tokens_res.scalars().all():
        tok.is_revoked = True

    now_utc = datetime.now(timezone.utc)
    await log_audit_event(
        db=db,
        action="PASSWORD_RESET",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=user.id,
        affected_record_type="User",
        metadata={
            "reset_user_id": user.id,
            "reset_username": user.username,
            "reset_by_username": current_user.username,
        },
    )
    await db.commit()
    return AdminPasswordResetResponse(
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        temporary_password=temp_pwd,
        must_change_password=True,
        reset_at=now_utc,
        reset_by=current_user.username,
        message=f"Password for {user.username} successfully reset.",
    )

@router.put("/{user_id}/credentials", response_model=CreatedAccountResponse)
async def update_account_credentials(
    user_id: str,
    req: UpdateCredentialsRequest,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    CEO can update credentials for any account.
    Admin can ONLY update credentials for employees they created or manage.
    """
    res = await db.execute(select(User).where(User.id == user_id))
    target_user = res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if current_user.role == UserRole.MANAGER.value:
        if (target_user.created_by_id != current_user.id and target_user.manager_id != current_user.id) or target_user.role != UserRole.EMPLOYEE.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You only have authority to manage credentials of employees you created.",
            )

    # Check username conflicts
    if req.username and req.username.strip().lower() != target_user.username.lower():
        existing = await db.execute(select(User).where(User.username == req.username.strip().lower()))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already in use.")
        target_user.username = req.username.strip().lower()

    # Check email conflicts
    if req.email and req.email.strip().lower() != target_user.email.lower():
        existing = await db.execute(select(User).where(User.email == req.email.strip().lower()))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already in use.")
        target_user.email = req.email.strip().lower()

    if req.full_name is not None:
        target_user.full_name = req.full_name.strip()
    if req.phone is not None:
        target_user.phone = req.phone.strip()
    if req.designation is not None:
        target_user.designation = req.designation.strip()
    if req.is_active is not None:
        target_user.is_active = req.is_active

    if req.password:
        target_user.hashed_password = get_password_hash(req.password)
        target_user.assigned_password = None
        target_user.must_change_password = True

        # Invalidate active refresh tokens
        token_query = select(RefreshToken).where(RefreshToken.user_id == target_user.id)
        tokens_res = await db.execute(token_query)
        for tok in tokens_res.scalars().all():
            tok.is_revoked = True

    await log_audit_event(
        db=db,
        action="CREDENTIALS_UPDATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=target_user.id,
        affected_record_type="User",
        metadata={"username": target_user.username, "updated_by": current_user.username},
    )
    await db.commit()
    await db.refresh(target_user)

    creator_name = None
    if target_user.created_by_id:
        creator_res = await db.execute(select(User.full_name).where(User.id == target_user.created_by_id))
        creator_name = creator_res.scalar_one_or_none()

    return CreatedAccountResponse(
        id=target_user.id,
        full_name=target_user.full_name,
        email=target_user.email,
        username=target_user.username,
        role=target_user.role,
        is_active=target_user.is_active,
        phone=target_user.phone,
        designation=target_user.designation,
        manager_id=target_user.manager_id,
        created_at=target_user.created_at,
        created_by_id=target_user.created_by_id,
        created_by_name=creator_name or "System Administrator",
        login_password="••••••••",
    )

@router.post("/{user_id}/reveal-credential", response_model=RevealedCredentialResponse)
async def reveal_user_credential(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Secure, audited on-demand credential reveal endpoint.
    Strict Authorization:
      - OWNER (CEO) can reveal any employee/manager credential.
      - MANAGER can only reveal credentials for employees they directly supervise
        (manager_id == current_user.id) or employees they personally created (created_by_id == current_user.id).
    Every reveal event is permanently recorded in the tamper-evident audit log.
    """
    res = await db.execute(select(User).where(User.id == user_id))
    target_user = res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User record not found.")

    # Strict authorization enforcement
    if current_user.role == UserRole.MANAGER.value:
        is_supervisor = target_user.manager_id == current_user.id
        is_creator = target_user.created_by_id == current_user.id
        if not (is_supervisor or is_creator):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You are not authorized to view credentials for this user."
            )

    now_utc = datetime.now(timezone.utc)
    decrypted_pwd = decrypt_credential(target_user.assigned_password) or "••••••••"

    # Log security audit trail
    await log_audit_event(
        db=db,
        action="CREDENTIAL_REVEALED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=target_user.id,
        affected_record_type="User",
        metadata={
            "revealed_user_id": target_user.id,
            "revealed_username": target_user.username,
            "revealed_by_username": current_user.username,
        },
    )
    await db.commit()

    return RevealedCredentialResponse(
        user_id=target_user.id,
        username=target_user.username,
        login_password=decrypted_pwd,
        revealed_at=now_utc,
        revealed_by=current_user.username,
    )


@router.delete("/{user_id}", response_model=MessageResponse)
async def delete_user(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes a user or admin (manager) account.
    Authorization:
      - OWNER (CEO) can delete MANAGER (Admin) and EMPLOYEE accounts.
      - MANAGER (Admin) can delete EMPLOYEE accounts.
      - Self-deletion and OWNER deletion are strictly prohibited.
    """
    if current_user.id == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete your own account.",
        )

    res = await db.execute(select(User).where(User.id == user_id))
    target_user = res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    if target_user.role == UserRole.OWNER.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="CEO / Owner account cannot be deleted.",
        )

    if current_user.role != UserRole.OWNER.value:
        if target_user.role == UserRole.MANAGER.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the CEO can delete Admin accounts.",
            )
        if target_user.manager_id != current_user.id and target_user.created_by_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You can only delete employees under your supervision.",
            )

    deleted_info = {
        "deleted_user_id": target_user.id,
        "deleted_username": target_user.username,
        "deleted_role": target_user.role,
        "deleted_email": target_user.email,
        "deleted_by": current_user.username,
    }

    # Clean up dependent rows explicitly for both SQLite (no FK cascade) and PostgreSQL compatibility
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == target_user.id))
    await db.execute(delete(FieldVisit).where(FieldVisit.employee_id == target_user.id))
    await db.execute(update(FieldVisit).where(FieldVisit.reviewed_by_id == target_user.id).values(reviewed_by_id=None))
    await db.execute(delete(Attendance).where(Attendance.user_id == target_user.id))
    await db.execute(delete(EmployeeTarget).where(EmployeeTarget.employee_id == target_user.id))
    await db.execute(update(EmployeeTarget).where(EmployeeTarget.created_by_id == target_user.id).values(created_by_id=None))
    await db.execute(update(Customer).where(Customer.assigned_employee_id == target_user.id).values(assigned_employee_id=None))
    await db.execute(delete(Customer).where(Customer.created_by_id == target_user.id))
    await db.execute(delete(ChatMessage).where(ChatMessage.sender_id == target_user.id))
    room_ids_subq = select(ChatRoom.id).where(
        or_(ChatRoom.participant_1_id == target_user.id, ChatRoom.participant_2_id == target_user.id)
    )
    await db.execute(delete(ChatMessage).where(ChatMessage.room_id.in_(room_ids_subq)))
    await db.execute(
        delete(ChatRoom).where(
            or_(ChatRoom.participant_1_id == target_user.id, ChatRoom.participant_2_id == target_user.id)
        )
    )
    await db.execute(update(ChatRoom).where(ChatRoom.created_by_id == target_user.id).values(created_by_id=None))
    await db.execute(update(User).where(User.manager_id == target_user.id).values(manager_id=None))
    await db.execute(update(User).where(User.created_by_id == target_user.id).values(created_by_id=None))
    await db.delete(target_user)

    await log_audit_event(
        db=db,
        action="USER_DELETED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=user_id,
        affected_record_type="User",
        metadata=deleted_info,
    )
    await db.commit()

    return MessageResponse(
        message=f"Account '{target_user.username}' ({target_user.role}) has been permanently deleted."
    )





