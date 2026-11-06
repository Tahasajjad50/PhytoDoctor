from datetime import datetime, timezone, date
from fastapi import APIRouter, Depends
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.visit import FieldVisit, VisitStatus
from app.models.target import EmployeeTarget, TargetPeriod
from app.api.v1.targets import _COMPANY_QUOTAS

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
    default_quota = _COMPANY_QUOTAS.get("daily_visits", 6)
    daily_target = assigned_target.target_count if assigned_target else default_quota

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
        ).order_by(FieldVisit.device_capture_time.desc())
    )
    visits_today = visits_today_query.scalars().all()
    
    completed_today = len(visits_today)
    verified_visits = sum(1 for v in visits_today if v.status == VisitStatus.VERIFIED.value)
    pending_visits = sum(1 for v in visits_today if v.status == VisitStatus.PENDING.value)
    rejected_visits = sum(1 for v in visits_today if v.status == VisitStatus.REJECTED.value)
    
    # Real-time progress calculation based on verified on-site visits
    progress_pct = round((verified_visits / daily_target * 100), 1) if daily_target > 0 else 0.0
    remaining_visits = max(0, daily_target - verified_visits)

    # Fetch supervisor info if assigned
    supervisor_name = None
    if current_user.manager_id:
        mgr = await db.get(User, current_user.manager_id)
        if mgr:
            supervisor_name = mgr.full_name

    # Fetch reviewer names for any reviewed visits
    reviewer_ids = {v.reviewed_by_id for v in visits_today if v.reviewed_by_id}
    reviewer_map = {}
    if reviewer_ids:
        reviewer_res = await db.execute(select(User).where(User.id.in_(reviewer_ids)))
        for u in reviewer_res.scalars().all():
            reviewer_map[u.id] = u.full_name

    today_visits_list = []
    for v in visits_today:
        is_updated_by_admin = bool(
            v.reviewed_at or 
            v.review_reason or 
            v.status in [VisitStatus.VERIFIED.value, VisitStatus.REJECTED.value]
        )
        today_visits_list.append({
            "id": v.id,
            "client_name": v.client_name,
            "client_phone": v.client_phone,
            "notes": v.notes,
            "latitude": v.latitude,
            "longitude": v.longitude,
            "gps_accuracy": v.gps_accuracy,
            "device_capture_time": v.device_capture_time.isoformat() if v.device_capture_time else None,
            "server_receipt_time": v.server_receipt_time.isoformat() if v.server_receipt_time else None,
            "photo_url": v.photo_url,
            "status": v.status,
            "is_flagged_for_review": v.is_flagged_for_review,
            "review_reason": v.review_reason,
            "reviewed_by_id": v.reviewed_by_id,
            "reviewed_by_name": reviewer_map.get(v.reviewed_by_id) if v.reviewed_by_id else None,
            "reviewed_at": v.reviewed_at.isoformat() if v.reviewed_at else None,
            "is_updated_by_admin": is_updated_by_admin,
        })

    return {
        "status": "success",
        "employee_name": current_user.full_name,
        "role": current_user.role,
        "designation": current_user.designation or "Field Agronomist",
        "supervisor_name": supervisor_name,
        "daily_target_visits": daily_target,
        "target_visits": daily_target,
        "completed_today": completed_today,
        "verified_visits": verified_visits,
        "pending_visits": pending_visits,
        "rejected_visits": rejected_visits,
        "remaining_visits": remaining_visits,
        "pending_sync": 0,
        "target_progress_percentage": progress_pct,
        "is_live_data": True,
        "today_visits": today_visits_list,
    }
