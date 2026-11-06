import json
from datetime import datetime, timezone, time
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import require_admin
from app.models.audit import AuditEvent
from app.models.attendance import Attendance
from app.models.user import User, UserRole
from app.models.visit import FieldVisit, VisitStatus
from app.schemas.admin import AuditEventResponse, AuditLogsListResponse

router = APIRouter(prefix="/admin", tags=["Admin Portal"])

@router.get("/dashboard-stats")
async def get_admin_dashboard_stats(
    admin_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns live, real-time administrative summary statistics from the database.
    Protected strictly: Only OWNER and MANAGER can access this endpoint.
    Employees attempting to call this directly receive HTTP 403 Forbidden.
    """
    # 1. Pending Verifications Count
    if admin_user.role == UserRole.OWNER.value:
        pending_res = await db.execute(
            select(func.count(FieldVisit.id)).where(FieldVisit.status == VisitStatus.PENDING.value)
        )
    else:
        team_subquery = select(User.id).where(User.manager_id == admin_user.id)
        pending_res = await db.execute(
            select(func.count(FieldVisit.id)).where(
                FieldVisit.status == VisitStatus.PENDING.value,
                (FieldVisit.employee_id == admin_user.id) | (FieldVisit.employee_id.in_(team_subquery))
            )
        )
    pending_count = pending_res.scalar() or 0

    # 2. Active Employees (Clocked In on Portal Today) & Total Registered Staff
    today_utc = datetime.now(timezone.utc).date()
    if admin_user.role == UserRole.OWNER.value:
        total_emp_res = await db.execute(
            select(func.count(User.id)).where(User.role == UserRole.EMPLOYEE.value)
        )
        active_emp_res = await db.execute(
            select(func.count(Attendance.id)).join(User, Attendance.user_id == User.id).where(
                User.role == UserRole.EMPLOYEE.value,
                Attendance.date == today_utc,
                Attendance.is_active == True,
            )
        )
    else:
        team_filter = (User.manager_id == admin_user.id) | (User.created_by_id == admin_user.id)
        total_emp_res = await db.execute(
            select(func.count(User.id)).where(User.role == UserRole.EMPLOYEE.value, team_filter)
        )
        active_emp_res = await db.execute(
            select(func.count(Attendance.id)).join(User, Attendance.user_id == User.id).where(
                User.role == UserRole.EMPLOYEE.value,
                team_filter,
                Attendance.date == today_utc,
                Attendance.is_active == True,
            )
        )
    total_emp_count = total_emp_res.scalar() or 0
    active_emp_count = active_emp_res.scalar() or 0

    # 3. Today Field Visits & Verification Rate
    today_utc = datetime.now(timezone.utc).date()
    today_start = datetime.combine(today_utc, time.min, tzinfo=timezone.utc)
    if admin_user.role == UserRole.OWNER.value:
        today_res = await db.execute(
            select(func.count(FieldVisit.id)).where(FieldVisit.device_capture_time >= today_start)
        )
        verified_res = await db.execute(
            select(func.count(FieldVisit.id)).where(FieldVisit.status == VisitStatus.VERIFIED.value)
        )
        total_res = await db.execute(select(func.count(FieldVisit.id)))
    else:
        team_subquery = select(User.id).where(User.manager_id == admin_user.id)
        today_res = await db.execute(
            select(func.count(FieldVisit.id)).where(
                FieldVisit.device_capture_time >= today_start,
                (FieldVisit.employee_id == admin_user.id) | (FieldVisit.employee_id.in_(team_subquery))
            )
        )
        verified_res = await db.execute(
            select(func.count(FieldVisit.id)).where(
                FieldVisit.status == VisitStatus.VERIFIED.value,
                (FieldVisit.employee_id == admin_user.id) | (FieldVisit.employee_id.in_(team_subquery))
            )
        )
        total_res = await db.execute(
            select(func.count(FieldVisit.id)).where(
                (FieldVisit.employee_id == admin_user.id) | (FieldVisit.employee_id.in_(team_subquery))
            )
        )

    today_count = today_res.scalar() or 0
    verified_count = verified_res.scalar() or 0
    total_count = total_res.scalar() or 0
    verified_percentage = round((verified_count / total_count * 100), 1) if total_count > 0 else 100.0

    return {
        "status": "success",
        "admin_name": admin_user.full_name,
        "role": admin_user.role,
        "active_employees": active_emp_count,
        "total_employees": total_emp_count,
        "today_field_visits": today_count,
        "pending_verifications": pending_count,
        "verified_visits": verified_count,
        "verified_percentage": verified_percentage,
        "total_sales_value": 0,
    }

@router.get("/audit-logs", response_model=AuditLogsListResponse)
async def list_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    action: Optional[str] = Query(None, description="Filter by action name"),
    actor_id: Optional[str] = Query(None, description="Filter by actor UUID"),
    admin_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns immutable audit events for security and operations tracking.
    Protected strictly to Owners and Managers.
    """
    query = select(AuditEvent)
    count_query = select(func.count(AuditEvent.id))

    if action:
        query = query.where(AuditEvent.action == action.strip().upper())
        count_query = count_query.where(AuditEvent.action == action.strip().upper())

    if actor_id:
        query = query.where(AuditEvent.actor_id == actor_id.strip())
        count_query = count_query.where(AuditEvent.actor_id == actor_id.strip())

    total_res = await db.execute(count_query)
    total = total_res.scalar() or 0

    query = query.order_by(AuditEvent.server_timestamp.desc()).offset(skip).limit(limit)
    res = await db.execute(query)
    events = res.scalars().all()

    items = []
    for ev in events:
        meta = None
        if ev.metadata_json:
            try:
                meta = json.loads(ev.metadata_json)
            except Exception:
                meta = {"raw": ev.metadata_json}

        items.append(
            AuditEventResponse(
                id=ev.id,
                actor_id=ev.actor_id,
                actor_role=ev.actor_role,
                action=ev.action,
                affected_record_id=ev.affected_record_id,
                affected_record_type=ev.affected_record_type,
                timestamp=ev.server_timestamp,
                metadata=meta,
            )
        )

    return AuditLogsListResponse(items=items, total=total)
