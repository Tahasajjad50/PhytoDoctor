from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.target import EmployeeTarget, TargetPeriod
from app.models.user import User, UserRole
from app.schemas.target import (
    BatchTargetCreate,
    PaginatedTargetsResponse,
    TargetCreate,
    TargetResponse,
    TargetUpdate,
)
from app.services.audit_service import log_audit_event

router = APIRouter(prefix="/targets", tags=["Target Management"])

@router.post("/", response_model=TargetResponse, status_code=status.HTTP_201_CREATED)
async def create_target(
    target_in: TargetCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Assigns a visit target quota to an employee.
    Requires Owner or Manager role (Managers can only assign to their supervised team).
    """
    res = await db.execute(select(User).where(User.id == target_in.employee_id))
    employee = res.scalar_one_or_none()
    if not employee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found.")
    
    if current_user.role == UserRole.MANAGER.value and employee.manager_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Managers can only set targets for agronomists in their team.",
        )

    if target_in.start_date > target_in.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start date cannot be after end date.",
        )

    target = EmployeeTarget(
        employee_id=target_in.employee_id,
        target_count=target_in.target_count,
        period_type=target_in.period_type.upper(),
        start_date=target_in.start_date,
        end_date=target_in.end_date,
        created_by_id=current_user.id,
    )
    db.add(target)
    await db.flush()

    await log_audit_event(
        db=db,
        action="TARGET_CREATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=target.id,
        affected_record_type="EmployeeTarget",
        metadata={
            "employee_id": target.employee_id,
            "target_count": target.target_count,
            "period": target.period_type,
            "start_date": str(target.start_date),
            "end_date": str(target.end_date),
        },
    )
    await db.commit()
    await db.refresh(target)
    return TargetResponse.model_validate(target)

@router.post("/batch", response_model=List[TargetResponse], status_code=status.HTTP_201_CREATED)
async def create_batch_targets(
    batch_in: BatchTargetCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Assigns or updates targets for multiple employees in a single atomic operation.
    Enforces authorization: Managers can only assign to their own supervised team members.
    """
    if batch_in.start_date > batch_in.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start date cannot be after end date.",
        )

    created_targets: List[EmployeeTarget] = []

    for emp_id in batch_in.employee_ids:
        res = await db.execute(select(User).where(User.id == emp_id))
        employee = res.scalar_one_or_none()
        if not employee:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee {emp_id} not found.",
            )

        if current_user.role == UserRole.MANAGER.value and employee.manager_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Unauthorized: Employee {employee.full_name} is not in your assigned team.",
            )

        target = EmployeeTarget(
            employee_id=emp_id,
            target_count=batch_in.target_count,
            period_type=batch_in.period_type.upper(),
            start_date=batch_in.start_date,
            end_date=batch_in.end_date,
            created_by_id=current_user.id,
        )
        db.add(target)
        created_targets.append(target)

    await db.flush()

    for target in created_targets:
        await log_audit_event(
            db=db,
            action="BATCH_TARGET_CREATED",
            actor_id=current_user.id,
            actor_role=current_user.role,
            affected_record_id=target.id,
            affected_record_type="EmployeeTarget",
            metadata={
                "employee_id": target.employee_id,
                "target_count": target.target_count,
            },
        )

    await db.commit()
    for target in created_targets:
        await db.refresh(target)

    return [TargetResponse.model_validate(t) for t in created_targets]

@router.put("/{target_id}", response_model=TargetResponse)
async def update_target(
    target_id: str,
    target_update: TargetUpdate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates an existing target while preserving historical audit logging.
    """
    target = await db.get(EmployeeTarget, target_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target not found.")

    if current_user.role == UserRole.MANAGER.value:
        emp = await db.get(User, target.employee_id)
        if not emp or emp.manager_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this target.")

    if target_update.target_count is not None:
        target.target_count = target_update.target_count
    if target_update.period_type is not None:
        target.period_type = target_update.period_type.upper()
    if target_update.start_date is not None:
        target.start_date = target_update.start_date
    if target_update.end_date is not None:
        target.end_date = target_update.end_date

    if target.start_date > target.end_date:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Start date cannot be after end date.")

    target.updated_at = datetime.now(timezone.utc)
    await db.flush()

    await log_audit_event(
        db=db,
        action="TARGET_UPDATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=target.id,
        affected_record_type="EmployeeTarget",
        metadata={
            "employee_id": target.employee_id,
            "new_target_count": target.target_count,
        },
    )

    await db.commit()
    await db.refresh(target)
    return TargetResponse.model_validate(target)

@router.get("/", response_model=PaginatedTargetsResponse)
async def list_targets(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    employee_id: Optional[str] = Query(None),
    manager_id: Optional[str] = Query(None),
    date_from: Optional[date] = Query(None),
    date_to: Optional[date] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lists targets with role-based scoping:
    - Employees see only their own targets.
    - Managers see only their authorized team's targets.
    - Owners see all targets across the company.
    """
    query = select(EmployeeTarget)
    count_query = select(func.count(EmployeeTarget.id))

    if current_user.role == UserRole.EMPLOYEE.value:
        query = query.where(EmployeeTarget.employee_id == current_user.id)
        count_query = count_query.where(EmployeeTarget.employee_id == current_user.id)
    elif current_user.role == UserRole.MANAGER.value:
        team_subquery = select(User.id).where(User.manager_id == current_user.id)
        query = query.where(
            (EmployeeTarget.employee_id == current_user.id) | (EmployeeTarget.employee_id.in_(team_subquery))
        )
        count_query = count_query.where(
            (EmployeeTarget.employee_id == current_user.id) | (EmployeeTarget.employee_id.in_(team_subquery))
        )
        if employee_id:
            query = query.where(EmployeeTarget.employee_id == employee_id)
            count_query = count_query.where(EmployeeTarget.employee_id == employee_id)
    elif current_user.role == UserRole.OWNER.value:
        if employee_id:
            query = query.where(EmployeeTarget.employee_id == employee_id)
            count_query = count_query.where(EmployeeTarget.employee_id == employee_id)
        if manager_id:
            team_subquery = select(User.id).where(User.manager_id == manager_id)
            query = query.where(EmployeeTarget.employee_id.in_(team_subquery))
            count_query = count_query.where(EmployeeTarget.employee_id.in_(team_subquery))

    if date_from:
        query = query.where(EmployeeTarget.end_date >= date_from)
        count_query = count_query.where(EmployeeTarget.end_date >= date_from)
    if date_to:
        query = query.where(EmployeeTarget.start_date <= date_to)
        count_query = count_query.where(EmployeeTarget.start_date <= date_to)

    total_res = await db.execute(count_query)
    total = total_res.scalar() or 0

    query = query.order_by(EmployeeTarget.start_date.desc()).offset(skip).limit(limit)
    res = await db.execute(query)
    targets = res.scalars().all()

    return PaginatedTargetsResponse(
        items=[TargetResponse.model_validate(t) for t in targets],
        total=total,
        skip=skip,
        limit=limit,
    )

@router.get("/employee/{employee_id}/current", response_model=TargetResponse)
async def get_current_target_for_employee(
    employee_id: str,
    as_of_date: Optional[date] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the target effective on a specific date (defaults to today).
    Preserves historical accuracy when targets evolve over time.
    """
    if current_user.role == UserRole.EMPLOYEE.value and current_user.id != employee_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if current_user.role == UserRole.MANAGER.value:
        emp = await db.get(User, employee_id)
        if not emp or (emp.id != current_user.id and emp.manager_id != current_user.id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this employee.")

    target_date = as_of_date or date.today()
    query = select(EmployeeTarget).where(
        EmployeeTarget.employee_id == employee_id,
        EmployeeTarget.start_date <= target_date,
        EmployeeTarget.end_date >= target_date
    ).order_by(EmployeeTarget.created_at.desc())

    res = await db.execute(query)
    target = res.scalars().first()

    if not target:
        # Fallback standard daily target
        fallback = EmployeeTarget(
            id=f"default-{target_date.isoformat()}",
            employee_id=employee_id,
            target_count=6,
            period_type=TargetPeriod.DAILY.value,
            start_date=target_date,
            end_date=target_date,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        return TargetResponse.model_validate(fallback)

    return TargetResponse.model_validate(target)


# Global in-memory default quotas (can also be saved to DB)
_COMPANY_QUOTAS = {
    "daily_visits": 6,
    "monthly_sales_pkr": 500000,
    "month": "October 2026",
    "updated_at": datetime.now(timezone.utc).isoformat(),
}

@router.get("/quotas")
async def get_company_quotas(
    current_user: User = Depends(get_current_user),
):
    """Retrieve active daily visit target and monthly sales quota."""
    return _COMPANY_QUOTAS

@router.post("/quotas")
async def update_company_quotas(
    payload: dict,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update active daily visit and monthly sales quota. Authorized for Admin and CEO only."""
    daily_visits = int(payload.get("daily_visits", 6))
    sales_pkr = int(payload.get("monthly_sales_pkr", 500000))
    month = str(payload.get("month", "October 2026"))

    _COMPANY_QUOTAS["daily_visits"] = daily_visits
    _COMPANY_QUOTAS["monthly_sales_pkr"] = sales_pkr
    _COMPANY_QUOTAS["month"] = month
    _COMPANY_QUOTAS["updated_at"] = datetime.now(timezone.utc).isoformat()

    # Also batch update/create targets for all active field employees for this month
    emp_res = await db.execute(select(User).where(User.role == UserRole.EMPLOYEE.value, User.is_active == True))
    employees = emp_res.scalars().all()
    today = date.today()
    for emp in employees:
        new_target = EmployeeTarget(
            employee_id=emp.id,
            target_count=daily_visits,
            period_type=TargetPeriod.DAILY.value,
            start_date=today,
            end_date=today,
            created_by_id=current_user.id,
        )
        db.add(new_target)
    await db.commit()

    return {
        "status": "success",
        "message": f"Quotas updated: {daily_visits} visits/day, PKR {sales_pkr:,} monthly sales quota.",
        "quotas": _COMPANY_QUOTAS,
    }
