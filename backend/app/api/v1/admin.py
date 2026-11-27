import io
import json
from datetime import datetime, timedelta, timezone, time
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
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
        team_subquery = select(User.id).where((User.manager_id == admin_user.id) | (User.created_by_id == admin_user.id))
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
        team_subquery = select(User.id).where((User.manager_id == admin_user.id) | (User.created_by_id == admin_user.id))
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


@router.get("/export-audit-report")
async def export_audit_report(
    employee_id: Optional[str] = Query(None, description="Optional specific employee UUID. Omit for all employees."),
    admin_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates and streams a multi-sheet Excel (.xlsx) audit report containing:
      1. Visit Records (client, GPS coordinates, notes, status, rejection reason, Cloudinary photo URL)
      2. Daily Attendance (date, mark in/out time, working hours, first/last GPS coordinates)
      3. Employee Summary
    Authorized for CEO (OWNER) and Admin/Manager (scoped to team for non-OWNER).
    """
    import openpyxl
    from openpyxl.styles import Font, PatternFill, Alignment

    # 1. Determine allowed user IDs based on role and optional employee_id filter
    user_query = select(User)
    if admin_user.role != UserRole.OWNER.value:
        user_query = user_query.where(
            (User.id == admin_user.id)
            | (User.manager_id == admin_user.id)
            | (User.created_by_id == admin_user.id)
        )
    if employee_id and employee_id.strip():
        user_query = user_query.where(User.id == employee_id.strip())

    users_res = await db.execute(user_query.order_by(User.full_name.asc()))
    users_list = users_res.scalars().all()
    if employee_id and not users_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found or outside your supervision scope.",
        )

    user_map = {u.id: u for u in users_list}
    allowed_ids = list(user_map.keys())

    # 2. Fetch Field Visits and Attendance
    visits_list = []
    attendance_list = []
    if allowed_ids:
        v_res = await db.execute(
            select(FieldVisit)
            .where(FieldVisit.employee_id.in_(allowed_ids))
            .order_by(FieldVisit.device_capture_time.desc())
        )
        visits_list = v_res.scalars().all()

        a_res = await db.execute(
            select(Attendance)
            .where(Attendance.user_id.in_(allowed_ids))
            .order_by(Attendance.date.desc(), Attendance.clock_in_time.desc())
        )
        attendance_list = a_res.scalars().all()

    # Index visits by (employee_id, date) for attendance GPS correlation
    visits_by_emp_day = {}
    for v in visits_list:
        v_date = v.device_capture_time.date() if v.device_capture_time else None
        if v_date:
            visits_by_emp_day.setdefault((v.employee_id, v_date), []).append(v)

    # 3. Build Excel Workbook
    wb = openpyxl.Workbook()
    header_fill = PatternFill(start_color="1B5E20", end_color="1B5E20", fill_type="solid")
    header_font = Font(bold=True, color="FFFFFF", size=11)

    def style_header(ws, headers):
        ws.append(headers)
        for cell in ws[1]:
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")
        ws.freeze_panes = "A2"

    def auto_fit(ws):
        for col in ws.columns:
            max_len = 0
            col_letter = col[0].column_letter
            for cell in col:
                val = str(cell.value or "")
                if len(val) > max_len:
                    max_len = len(val)
            ws.column_dimensions[col_letter].width = min(max(max_len + 4, 14), 52)

    def safe_cell(val):
        if isinstance(val, str) and val and val[0] in ("=", "+", "-", "@", "\t", "\r"):
            return "'" + val
        return val

    PKT = timezone(timedelta(hours=5))

    def make_utc_aware(dt):
        if dt is None:
            return None
        return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt

    def to_pkt(dt):
        aware = make_utc_aware(dt)
        return aware.astimezone(PKT) if aware else None

    # --- Sheet 1: Visit Records ---
    ws_visits = wb.active
    ws_visits.title = "Visit Records"
    style_header(ws_visits, [
        "Visit ID", "Employee Name", "Username", "Client Name", "Client Phone",
        "Capture Time (PKT)", "Latitude", "Longitude", "GPS Coordinates",
        "GPS Accuracy (m)", "Mock Location", "Verification Status",
        "Rejection / Review Reason", "Field Notes", "Photo URL (Cloudinary)"
    ])
    for v in visits_list:
        emp = user_map.get(v.employee_id)
        cap_dt = to_pkt(v.device_capture_time)
        cap_str = cap_dt.strftime("%Y-%m-%d %I:%M:%S %p") if cap_dt else ""
        ws_visits.append([
            v.id,
            safe_cell(emp.full_name if emp else "Unknown"),
            safe_cell(emp.username if emp else ""),
            safe_cell(v.client_name),
            safe_cell(v.client_phone or ""),
            cap_str,
            round(v.latitude, 6),
            round(v.longitude, 6),
            f"{v.latitude:.6f}, {v.longitude:.6f}",
            round(v.gps_accuracy, 2),
            "Yes" if v.is_mock_location else "No",
            v.status,
            safe_cell(v.review_reason or ""),
            safe_cell(v.notes or ""),
            v.photo_url or "",
        ])
    auto_fit(ws_visits)

    # --- Sheet 2: Daily Attendance ---
    ws_att = wb.create_sheet(title="Daily Attendance")
    style_header(ws_att, [
        "Date", "Employee Name", "Username", "Mark In Time (PKT)",
        "Mark Out Time (PKT)", "Working Hours", "Status",
        "Day Visits Count", "First Visit GPS Coordinates", "Last Visit GPS Coordinates"
    ])
    for a in attendance_list:
        emp = user_map.get(a.user_id)
        cin = to_pkt(a.clock_in_time)
        cout = to_pkt(a.clock_out_time)
        mark_in_str = cin.strftime("%Y-%m-%d %I:%M:%S %p") if cin else ""
        mark_out_str = cout.strftime("%Y-%m-%d %I:%M:%S %p") if cout else "Still Clocked In"
        hours_str = "Active"
        if cin and cout:
            diff_hrs = (cout - cin).total_seconds() / 3600.0
            hours_str = f"{diff_hrs:.2f} hrs"

        day_visits = visits_by_emp_day.get((a.user_id, a.date), [])
        day_visits_sorted = sorted(
            day_visits,
            key=lambda x: make_utc_aware(x.device_capture_time) or datetime.min.replace(tzinfo=timezone.utc),
        )
        first_gps = f"{day_visits_sorted[0].latitude:.6f}, {day_visits_sorted[0].longitude:.6f}" if day_visits_sorted else "N/A"
        last_gps = f"{day_visits_sorted[-1].latitude:.6f}, {day_visits_sorted[-1].longitude:.6f}" if day_visits_sorted else "N/A"

        ws_att.append([
            a.date.strftime("%Y-%m-%d") if a.date else "",
            safe_cell(emp.full_name if emp else "Unknown"),
            safe_cell(emp.username if emp else ""),
            mark_in_str,
            mark_out_str,
            hours_str,
            "Active" if a.is_active else "Completed",
            len(day_visits),
            first_gps,
            last_gps,
        ])
    auto_fit(ws_att)

    # --- Sheet 3: Employee Summary ---
    ws_summary = wb.create_sheet(title="Employee Summary")
    style_header(ws_summary, [
        "Employee Name", "Username", "Role", "Designation",
        "Attendance Days", "Total Visits", "Verified Visits", "Pending Visits", "Rejected Visits"
    ])
    for u in users_list:
        u_visits = [v for v in visits_list if v.employee_id == u.id]
        u_att = [a for a in attendance_list if a.user_id == u.id]
        ws_summary.append([
            safe_cell(u.full_name),
            safe_cell(u.username),
            u.role,
            safe_cell(u.designation or ""),
            len(u_att),
            len(u_visits),
            sum(1 for v in u_visits if v.status == VisitStatus.VERIFIED.value),
            sum(1 for v in u_visits if v.status == VisitStatus.PENDING.value),
            sum(1 for v in u_visits if v.status == VisitStatus.REJECTED.value),
        ])
    auto_fit(ws_summary)

    output = io.BytesIO()
    wb.save(output)
    output.seek(0)

    scope_tag = users_list[0].username if (employee_id and len(users_list) == 1) else "all_staff"
    date_tag = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M")
    filename = f"PhytoDoctor_Audit_{scope_tag}_{date_tag}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )
