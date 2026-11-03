from datetime import datetime, timezone, date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.attendance import Attendance
from app.models.user import User, UserRole

router = APIRouter(prefix="/attendance", tags=["Attendance"])

class AttendanceStatusResponse(BaseModel):
    is_active: bool
    clock_in_time: Optional[datetime] = None
    clock_out_time: Optional[datetime] = None
    date: date
    message: str

class EmployeeAttendanceItem(BaseModel):
    id: str
    full_name: str
    username: str
    phone: Optional[str] = None
    designation: Optional[str] = None
    is_active_now: bool
    clock_in_time: Optional[datetime] = None
    clock_out_time: Optional[datetime] = None

class AdminRosterResponse(BaseModel):
    date: date
    total_employees: int
    active_count: int
    inactive_count: int
    employees: List[EmployeeAttendanceItem]

@router.post("/clock-in", response_model=AttendanceStatusResponse)
async def clock_in(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != UserRole.EMPLOYEE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Attendance clock-in is only available for Field Agronomists/Employees."
        )

    today = datetime.now(timezone.utc).date()
    now = datetime.now(timezone.utc)

    # Check for existing record for today
    stmt = select(Attendance).where(
        and_(Attendance.user_id == current_user.id, Attendance.date == today)
    ).order_by(Attendance.clock_in_time.desc())
    res = await db.execute(stmt)
    existing = res.scalars().first()

    if existing and existing.is_active:
        return AttendanceStatusResponse(
            is_active=True,
            clock_in_time=existing.clock_in_time,
            clock_out_time=existing.clock_out_time,
            date=today,
            message="Already clocked in and active."
        )

    if existing and not existing.is_active:
        # Re-clocking in for today
        existing.is_active = True
        existing.clock_in_time = now
        existing.clock_out_time = None
        await db.commit()
        await db.refresh(existing)
        return AttendanceStatusResponse(
            is_active=True,
            clock_in_time=existing.clock_in_time,
            clock_out_time=None,
            date=today,
            message="Marked as Active (Clocked In)."
        )

    # First clock-in of the day
    new_record = Attendance(
        user_id=current_user.id,
        date=today,
        clock_in_time=now,
        clock_out_time=None,
        is_active=True
    )
    db.add(new_record)
    await db.commit()
    await db.refresh(new_record)

    return AttendanceStatusResponse(
        is_active=True,
        clock_in_time=new_record.clock_in_time,
        clock_out_time=None,
        date=today,
        message="Marked as Active (Clocked In)."
    )

@router.post("/clock-out", response_model=AttendanceStatusResponse)
async def clock_out(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != UserRole.EMPLOYEE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Attendance clock-out is only available for Field Agronomists/Employees."
        )

    today = datetime.now(timezone.utc).date()
    now = datetime.now(timezone.utc)

    stmt = select(Attendance).where(
        and_(Attendance.user_id == current_user.id, Attendance.date == today)
    ).order_by(Attendance.clock_in_time.desc())
    res = await db.execute(stmt)
    existing = res.scalars().first()

    if not existing:
        # If no clock-in existed today, record a completed attendance session
        record = Attendance(
            user_id=current_user.id,
            date=today,
            clock_in_time=now,
            clock_out_time=now,
            is_active=False
        )
        db.add(record)
        await db.commit()
        await db.refresh(record)
        return AttendanceStatusResponse(
            is_active=False,
            clock_in_time=record.clock_in_time,
            clock_out_time=record.clock_out_time,
            date=today,
            message="Marked as Inactive (Clocked Out)."
        )

    existing.is_active = False
    existing.clock_out_time = now
    await db.commit()
    await db.refresh(existing)

    return AttendanceStatusResponse(
        is_active=False,
        clock_in_time=existing.clock_in_time,
        clock_out_time=existing.clock_out_time,
        date=today,
        message="Marked as Inactive (Clocked Out)."
    )

@router.get("/status", response_model=AttendanceStatusResponse)
async def get_attendance_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    today = datetime.now(timezone.utc).date()

    stmt = select(Attendance).where(
        and_(Attendance.user_id == current_user.id, Attendance.date == today)
    ).order_by(Attendance.clock_in_time.desc())
    res = await db.execute(stmt)
    existing = res.scalars().first()

    if existing:
        return AttendanceStatusResponse(
            is_active=existing.is_active,
            clock_in_time=existing.clock_in_time,
            clock_out_time=existing.clock_out_time,
            date=today,
            message="Active on portal" if existing.is_active else "Off duty / Inactive"
        )

    return AttendanceStatusResponse(
        is_active=False,
        clock_in_time=None,
        clock_out_time=None,
        date=today,
        message="Not clocked in today."
    )

@router.get("/admin/roster", response_model=AdminRosterResponse)
async def get_admin_attendance_roster(
    admin_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    today = datetime.now(timezone.utc).date()

    # Query all active employees
    emp_query = select(User).where(
        and_(User.role == UserRole.EMPLOYEE.value, User.is_active == True)
    ).order_by(User.full_name.asc())
    emp_res = await db.execute(emp_query)
    employees = emp_res.scalars().all()

    # Query today's attendance records
    att_query = select(Attendance).where(Attendance.date == today)
    att_res = await db.execute(att_query)
    attendances = att_res.scalars().all()
    att_map = {att.user_id: att for att in attendances}

    roster: List[EmployeeAttendanceItem] = []
    active_count = 0

    for emp in employees:
        att = att_map.get(emp.id)
        is_active_now = att.is_active if att else False
        if is_active_now:
            active_count += 1

        roster.append(
            EmployeeAttendanceItem(
                id=emp.id,
                full_name=emp.full_name,
                username=emp.username,
                phone=emp.phone,
                designation=emp.designation,
                is_active_now=is_active_now,
                clock_in_time=att.clock_in_time if att else None,
                clock_out_time=att.clock_out_time if att else None
            )
        )

    # Sort so active employees appear first
    roster.sort(key=lambda x: (not x.is_active_now, x.full_name))

    total = len(employees)
    return AdminRosterResponse(
        date=today,
        total_employees=total,
        active_count=active_count,
        inactive_count=total - active_count,
        employees=roster
    )
