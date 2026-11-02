from datetime import date, datetime, time, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import distinct, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.target import EmployeeTarget, TargetPeriod
from app.models.user import User, UserRole
from app.models.visit import FieldVisit, VisitStatus
from app.schemas.performance import (
    CompanyPerformanceSummary,
    EmployeePerformanceSummary,
    PerformanceAnalyticsResponse,
    ReviewReasonItem,
    TeamComparisonResponse,
    TeamMemberPerformance,
    TrendPoint,
)

router = APIRouter(prefix="/performance", tags=["Performance & Reporting"])

# Company business timezone offset: PKT (UTC+5)
PKT_OFFSET = timezone(timedelta(hours=5))

def make_utc_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

def get_current_utc_date() -> date:
    return datetime.now(timezone.utc).date()

def get_period_boundaries(as_of: date, timeframe: str):
    """
    Computes strict start and end datetime boundaries in UTC
    corresponding to Asia/Karachi (PKT) calendar dates.
    """
    tf = timeframe.upper()
    if tf == "DAILY":
        start_d = as_of
        end_d = as_of
    elif tf == "WEEKLY":
        # Monday of current week
        start_d = as_of - timedelta(days=as_of.weekday())
        # Sunday of current week
        end_d = start_d + timedelta(days=6)
    elif tf == "MONTHLY":
        # 1st of month to end of month
        start_d = date(as_of.year, as_of.month, 1)
        next_month = date(as_of.year + 1, 1, 1) if as_of.month == 12 else date(as_of.year, as_of.month + 1, 1)
        end_d = next_month - timedelta(days=1)
    else:
        start_d = as_of
        end_d = as_of

    start_dt = datetime.combine(start_d, time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(end_d, time.max, tzinfo=timezone.utc)
    return start_d, end_d, start_dt, end_dt

@router.get("/employee/{employee_id}/summary", response_model=EmployeePerformanceSummary)
async def get_employee_performance_summary(
    employee_id: str,
    period: str = Query("DAILY", description="'DAILY', 'WEEKLY', or 'MONTHLY'"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Computes employee summary metrics strictly from VERIFIED visits.
    Drafts, pending, and rejected visits never inflate verified counts.
    """
    if current_user.role == UserRole.EMPLOYEE.value and current_user.id != employee_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if current_user.role == UserRole.MANAGER.value:
        emp = await db.get(User, employee_id)
        if not emp or (emp.id != current_user.id and emp.manager_id != current_user.id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this employee.")

    emp_res = await db.execute(select(User).where(User.id == employee_id))
    employee = emp_res.scalar_one_or_none()
    if not employee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found.")

    today = get_current_utc_date()
    start_d, end_d, start_dt, end_dt = get_period_boundaries(today, period)

    # 1. Fetch effective target for employee
    target_query = select(EmployeeTarget).where(
        EmployeeTarget.employee_id == employee_id,
        EmployeeTarget.start_date <= end_d,
        EmployeeTarget.end_date >= start_d
    ).order_by(EmployeeTarget.created_at.desc())
    target_res = await db.execute(target_query)
    target_record = target_res.scalars().first()
    target_count = target_record.target_count if target_record else 6

    # 2. Total completed (submitted) visits
    total_query = select(func.count(distinct(FieldVisit.id))).where(
        FieldVisit.employee_id == employee_id,
        FieldVisit.device_capture_time >= start_dt,
        FieldVisit.device_capture_time <= end_dt
    )
    total_res = await db.execute(total_query)
    completed_today = total_res.scalar() or 0

    # 3. Verified visits (CRITICAL: Only VERIFIED status counts)
    verified_query = select(func.count(distinct(FieldVisit.id))).where(
        FieldVisit.employee_id == employee_id,
        FieldVisit.status == VisitStatus.VERIFIED.value,
        FieldVisit.device_capture_time >= start_dt,
        FieldVisit.device_capture_time <= end_dt
    )
    verified_res = await db.execute(verified_query)
    verified_visits = verified_res.scalar() or 0

    # 4. Pending verification
    pending_query = select(func.count(distinct(FieldVisit.id))).where(
        FieldVisit.employee_id == employee_id,
        FieldVisit.status == VisitStatus.PENDING.value
    )
    pending_res = await db.execute(pending_query)
    pending_sync_count = pending_res.scalar() or 0

    remaining = max(0, target_count - verified_visits)
    progress_pct = round((verified_visits / target_count * 100.0), 1) if target_count > 0 else 0.0

    return EmployeePerformanceSummary(
        employee_id=employee.id,
        employee_name=employee.full_name,
        period=period.upper(),
        target_visits=target_count,
        completed_today=completed_today,
        verified_visits=verified_visits,
        remaining_visits=remaining,
        pending_sync_count=pending_sync_count,
        target_progress_percentage=progress_pct,
        is_live_data=True,
    )

@router.get("/employee/{employee_id}/analytics", response_model=PerformanceAnalyticsResponse)
async def get_employee_performance_analytics(
    employee_id: str,
    timeframe: str = Query("DAILY", description="'DAILY', 'WEEKLY', or 'MONTHLY'"),
    as_of_date: Optional[date] = Query(None, description="Anchor calendar date"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Comprehensive multi-period analytics:
    - Daily, Weekly, and Monthly aggregations.
    - Day-by-day trend points.
    - Personal visit history with supervisor review reasons.
    - Guarantees drafts, pending, and rejected visits do NOT inflate verified counts.
    """
    if current_user.role == UserRole.EMPLOYEE.value and current_user.id != employee_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if current_user.role == UserRole.MANAGER.value:
        emp = await db.get(User, employee_id)
        if not emp or (emp.id != current_user.id and emp.manager_id != current_user.id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this employee.")

    emp_res = await db.execute(select(User).where(User.id == employee_id))
    employee = emp_res.scalar_one_or_none()
    if not employee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found.")

    anchor_date = as_of_date or get_current_utc_date()
    start_d, end_d, start_dt, end_dt = get_period_boundaries(anchor_date, timeframe)

    # 1. Target count computation
    target_query = select(EmployeeTarget).where(
        EmployeeTarget.employee_id == employee_id,
        EmployeeTarget.start_date <= end_d,
        EmployeeTarget.end_date >= start_d
    ).order_by(EmployeeTarget.created_at.desc())
    target_res = await db.execute(target_query)
    target_record = target_res.scalars().first()
    
    # Scale daily target if timeframe is weekly or monthly
    base_target = target_record.target_count if target_record else 6
    if timeframe.upper() == "WEEKLY":
        target_visits = base_target * 6  # 6-day work week
    elif timeframe.upper() == "MONTHLY":
        target_visits = base_target * 26 # 26-day work month
    else:
        target_visits = base_target

    # 2. Fetch all visits within date boundaries
    visits_query = select(FieldVisit).where(
        FieldVisit.employee_id == employee_id,
        FieldVisit.device_capture_time >= start_dt,
        FieldVisit.device_capture_time <= end_dt
    ).order_by(FieldVisit.device_capture_time.desc())
    visits_res = await db.execute(visits_query)
    period_visits = visits_res.scalars().all()

    submitted_visits = len(period_visits)
    verified_visits = sum(1 for v in period_visits if v.status == VisitStatus.VERIFIED.value)
    rejected_visits = sum(1 for v in period_visits if v.status == VisitStatus.REJECTED.value)
    flagged_visits_count = sum(1 for v in period_visits if v.is_flagged_for_review)

    # Overall pending count
    pending_query = select(func.count(distinct(FieldVisit.id))).where(
        FieldVisit.employee_id == employee_id,
        FieldVisit.status == VisitStatus.PENDING.value
    )
    pending_res = await db.execute(pending_query)
    pending_sync_count = pending_res.scalar() or 0

    remaining_visits = max(0, target_visits - verified_visits)
    completion_percentage = round((verified_visits / target_visits * 100.0), 1) if target_visits > 0 else 0.0

    # 3. Generate Day-by-Day Trend Points
    trend_points: List[TrendPoint] = []
    # If daily, show past 7 days trend for immediate context; if weekly/monthly, show each day in period
    trend_start = (anchor_date - timedelta(days=6)) if timeframe.upper() == "DAILY" else start_d
    trend_end = anchor_date if timeframe.upper() == "DAILY" else end_d

    curr_day = trend_start
    while curr_day <= trend_end:
        day_start = datetime.combine(curr_day, time.min, tzinfo=timezone.utc)
        day_end = datetime.combine(curr_day, time.max, tzinfo=timezone.utc)

        day_visits = [v for v in period_visits if day_start <= make_utc_aware(v.device_capture_time) <= day_end]
        day_submitted = len(day_visits)
        day_verified = sum(1 for v in day_visits if v.status == VisitStatus.VERIFIED.value)
        day_rejected = sum(1 for v in day_visits if v.status == VisitStatus.REJECTED.value)
        day_pct = round((day_verified / base_target * 100.0), 1) if base_target > 0 else 0.0

        trend_points.append(
            TrendPoint(
                date=curr_day,
                target_count=base_target,
                submitted_count=day_submitted,
                verified_count=day_verified,
                rejected_count=day_rejected,
                completion_percentage=day_pct,
            )
        )
        curr_day += timedelta(days=1)

    # 4. Fetch recent reviewed/rejected/flagged visits with supervisor reasons
    recent_reviews: List[ReviewReasonItem] = []
    for v in period_visits[:10]:
        if v.status in (VisitStatus.REJECTED.value, VisitStatus.VERIFIED.value) or v.is_flagged_for_review:
            recent_reviews.append(
                ReviewReasonItem(
                    visit_id=v.id,
                    client_name=v.client_name,
                    status=v.status,
                    review_reason=v.review_reason,
                    reviewed_at=v.reviewed_at,
                    is_flagged=v.is_flagged_for_review,
                    review_signals=v.review_signals,
                )
            )

    return PerformanceAnalyticsResponse(
        employee_id=employee.id,
        employee_name=employee.full_name,
        timeframe=timeframe.upper(),
        start_date=start_d,
        end_date=end_d,
        target_visits=target_visits,
        submitted_visits=submitted_visits,
        verified_visits=verified_visits,
        remaining_visits=remaining_visits,
        rejected_visits=rejected_visits,
        pending_sync_count=pending_sync_count,
        flagged_visits_count=flagged_visits_count,
        completion_percentage=completion_percentage,
        trend_points=trend_points,
        recent_reviews=recent_reviews,
        is_live_data=True,
    )

@router.get("/team-comparison", response_model=TeamComparisonResponse)
async def get_team_comparison(
    timeframe: str = Query("DAILY", description="'DAILY', 'WEEKLY', or 'MONTHLY'"),
    date_from: Optional[date] = Query(None),
    date_to: Optional[date] = Query(None),
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Team performance comparisons for authorized users:
    - Managers see only their authorized team members.
    - Owners see all agronomists across teams.
    - Compares target, submitted, verified, remaining, and completion percentage.
    """
    today = get_current_utc_date()
    start_d, end_d, start_dt, end_dt = get_period_boundaries(date_from or today, timeframe)
    if date_to:
        end_d = date_to
        end_dt = datetime.combine(end_d, time.max, tzinfo=timezone.utc)

    # 1. Scope employees by role
    if current_user.role == UserRole.MANAGER.value:
        emp_query = select(User).where(User.manager_id == current_user.id, User.is_active.is_(True))
    else:
        emp_query = select(User).where(User.role == UserRole.EMPLOYEE.value, User.is_active.is_(True))

    emp_res = await db.execute(emp_query)
    employees = emp_res.scalars().all()

    members: List[TeamMemberPerformance] = []
    total_target = 0
    total_verified = 0

    for emp in employees:
        # Fetch target for this employee in period
        target_res = await db.execute(
            select(EmployeeTarget).where(
                EmployeeTarget.employee_id == emp.id,
                EmployeeTarget.start_date <= end_d,
                EmployeeTarget.end_date >= start_d
            ).order_by(EmployeeTarget.created_at.desc())
        )
        target_rec = target_res.scalars().first()
        base_t = target_rec.target_count if target_rec else 6
        target_count = base_t * (6 if timeframe.upper() == "WEEKLY" else (26 if timeframe.upper() == "MONTHLY" else 1))

        # Query visits in period
        v_res = await db.execute(
            select(FieldVisit).where(
                FieldVisit.employee_id == emp.id,
                FieldVisit.device_capture_time >= start_dt,
                FieldVisit.device_capture_time <= end_dt
            )
        )
        emp_visits = v_res.scalars().all()

        submitted = len(emp_visits)
        verified = sum(1 for v in emp_visits if v.status == VisitStatus.VERIFIED.value)
        rejected = sum(1 for v in emp_visits if v.status == VisitStatus.REJECTED.value)
        flagged = sum(1 for v in emp_visits if v.is_flagged_for_review)
        remaining = max(0, target_count - verified)
        pct = round((verified / target_count * 100.0), 1) if target_count > 0 else 0.0

        total_target += target_count
        total_verified += verified

        members.append(
            TeamMemberPerformance(
                employee_id=emp.id,
                employee_name=emp.full_name,
                manager_id=emp.manager_id,
                target_visits=target_count,
                submitted_visits=submitted,
                verified_visits=verified,
                remaining_visits=remaining,
                completion_percentage=pct,
                flagged_visits=flagged,
                rejected_visits=rejected,
            )
        )

    # Sort team by completion percentage descending
    members.sort(key=lambda m: m.completion_percentage, reverse=True)

    avg_pct = round((total_verified / total_target * 100.0), 1) if total_target > 0 else 0.0

    return TeamComparisonResponse(
        manager_id=current_user.id if current_user.role == UserRole.MANAGER.value else None,
        manager_name=current_user.full_name if current_user.role == UserRole.MANAGER.value else "All Company Teams",
        timeframe=timeframe.upper(),
        start_date=start_d,
        end_date=end_d,
        team_size=len(members),
        team_total_target=total_target,
        team_total_verified=total_verified,
        team_average_completion_pct=avg_pct,
        members=members,
    )

@router.get("/company-overview", response_model=CompanyPerformanceSummary)
async def get_company_performance_overview(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    today = get_current_utc_date()
    start_of_day = datetime.combine(today, time.min, tzinfo=timezone.utc)
    end_of_day = datetime.combine(today, time.max, tzinfo=timezone.utc)

    total_emp_res = await db.execute(select(func.count(User.id)).where(User.role == UserRole.EMPLOYEE.value))
    total_employees = total_emp_res.scalar() or 0

    active_emp_res = await db.execute(
        select(func.count(User.id)).where(
            User.role == UserRole.EMPLOYEE.value,
            User.is_active.is_(True)
        )
    )
    active_employees = active_emp_res.scalar() or 0

    logged_res = await db.execute(
        select(func.count(distinct(FieldVisit.id))).where(
            FieldVisit.device_capture_time >= start_of_day,
            FieldVisit.device_capture_time <= end_of_day
        )
    )
    today_logged = logged_res.scalar() or 0

    verified_res = await db.execute(
        select(func.count(distinct(FieldVisit.id))).where(
            FieldVisit.status == VisitStatus.VERIFIED.value,
            FieldVisit.device_capture_time >= start_of_day,
            FieldVisit.device_capture_time <= end_of_day
        )
    )
    today_verified = verified_res.scalar() or 0

    pending_res = await db.execute(
        select(func.count(distinct(FieldVisit.id))).where(FieldVisit.status == VisitStatus.PENDING.value)
    )
    pending_count = pending_res.scalar() or 0

    target_res = await db.execute(
        select(func.sum(EmployeeTarget.target_count)).where(
            EmployeeTarget.start_date <= today,
            or_(EmployeeTarget.end_date.is_(None), EmployeeTarget.end_date >= today)
        )
    )
    today_target_sum = target_res.scalar() or 0

    flagged_res = await db.execute(
        select(func.count(distinct(FieldVisit.id))).where(FieldVisit.is_flagged_for_review.is_(True))
    )
    flagged_count = flagged_res.scalar() or 0

    completion_rate = round((today_verified / today_target_sum * 100.0), 1) if today_target_sum > 0 else 0.0

    rate = round((today_verified / today_logged * 100.0), 1) if today_logged > 0 else 100.0

    return CompanyPerformanceSummary(
        total_employees=total_employees,
        active_employees=active_employees,
        today_logged_visits=today_logged,
        today_verified_visits=today_verified,
        pending_verification_count=pending_count,
        verification_rate_percentage=rate,
        today_target_sum=today_target_sum,
        today_submitted_visits=today_logged,
        today_completion_rate=completion_rate,
        pending_review_count=pending_count,
        flagged_visits_count=flagged_count,
    )

