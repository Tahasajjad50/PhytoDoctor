from datetime import datetime, timezone, date
from fastapi import APIRouter, Depends
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.visit import FieldVisit, VisitStatus
from app.models.target import EmployeeTarget, TargetPeriod

router = APIRouter(prefix="/employee", tags=["Employee Portal"])

@router.get("/dashboard-summary")
async def get_employee_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns actual, real-time employee-specific daily summary, target progress, and verified visits.
    Queries the actual database for this specific employee.
    """
    today = date.today()
    today_start = datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)
    
    # 1. Fetch real target assigned to this employee (if any set in employee_targets)
    target_query = await db.execute(
        select(EmployeeTarget).where(
            and_(
                EmployeeTarget.employee_id == current_user.id,
                EmployeeTarget.period_type == TargetPeriod.DAILY.value,
                EmployeeTarget.start_date <= today,
                EmployeeTarget.end_date >= today
            )
        ).order_by(EmployeeTarget.created_at.desc())
    )
    assigned_target = target_query.scalars().first()
    daily_target = assigned_target.target_count if assigned_target else 6

    # 2. Count real visits submitted by this employee today
    visits_today_query = await db.execute(
        select(FieldVisit).where(
            and_(
                FieldVisit.employee_id == current_user.id,
                or_(
                    FieldVisit.server_receipt_time >= today_start,
                    FieldVisit.device_capture_time >= today_start
                )
            )
        )
    )
    visits_today = visits_today_query.scalars().all()
    
    completed_today = len(visits_today)
    verified_visits = sum(1 for v in visits_today if v.status == VisitStatus.VERIFIED.value)
    pending_visits = sum(1 for v in visits_today if v.status == VisitStatus.PENDING.value)
    
    # Real-time progress calculation based on verified on-site visits
    progress_pct = round((verified_visits / daily_target * 100), 1) if daily_target > 0 else 0.0
    remaining_visits = max(0, daily_target - verified_visits)

    # Fetch supervisor info if assigned
    supervisor_name = None
    if current_user.manager_id:
        mgr = await db.get(User, current_user.manager_id)
        if mgr:
            supervisor_name = mgr.full_name

    return {
        "status": "success",
        "employee_name": current_user.full_name,
        "role": current_user.role,
        "designation": current_user.designation or "Field Agronomist",
        "supervisor_name": supervisor_name,
        "daily_target_visits": daily_target,
        "completed_today": completed_today,
        "verified_visits": verified_visits,
        "pending_visits": pending_visits,
        "remaining_visits": remaining_visits,
        "pending_sync": 0,
        "target_progress_percentage": progress_pct,
        "is_live_data": True
    }
