import json
import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.user import User, UserRole
from app.models.visit import FieldVisit, VisitStatus
from app.schemas.visit import (
    EvidencePolicyResponse,
    PaginatedVisitsResponse,
    VisitCreate,
    VisitResponse,
    VisitVerifyRequest,
)
from app.services.audit_service import log_audit_event

router = APIRouter(prefix="/visits", tags=["Field Visits"])

# Configurable accuracy threshold in meters
GPS_ACCURACY_THRESHOLD_METERS = 50.0

@router.get("/evidence-policy", response_model=EvidencePolicyResponse)
async def get_evidence_policy():
    """
    Returns the company's evidence collection policy and transparency disclosures.
    Explains that no hidden background location tracking is performed.
    """
    return EvidencePolicyResponse(gps_accuracy_threshold_meters=GPS_ACCURACY_THRESHOLD_METERS)

@router.post("", response_model=VisitResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=VisitResponse, status_code=status.HTTP_201_CREATED)
async def create_visit(
    visit_in: VisitCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits a new on-site field visit with mandatory photo proof and GPS metrics.
    Runs fraud-aware review checks (mock location signals, clock drift, upload delays, accuracy threshold).
    Guarantees immutability: Never silently replaces existing submitted evidence.
    """
    now_utc = datetime.now(timezone.utc)

    # 1. UUID Idempotency Check: Safe recovery from repeated Sync Now or network retries
    if visit_in.id:
        existing_by_id = await db.get(FieldVisit, visit_in.id.strip())
        if existing_by_id:
            if existing_by_id.employee_id == current_user.id:
                # Idempotent return of already synced visit
                return VisitResponse.model_validate(existing_by_id)
            else:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Visit UUID collision with an existing record.",
                )

    # 2. Immutability & Duplicate Check: Ensure photo_asset_id has never been used
    existing_photo_query = select(FieldVisit).where(FieldVisit.photo_asset_id == visit_in.photo_asset_id.strip())
    existing_photo_res = await db.execute(existing_photo_query)
    existing_photo = existing_photo_res.scalar_one_or_none()
    if existing_photo:
        if visit_in.id and existing_photo.id == visit_in.id.strip() and existing_photo.employee_id == current_user.id:
            return VisitResponse.model_validate(existing_photo)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Duplicate photo evidence: This photo asset has already been associated with an existing visit and cannot be resubmitted or silently replaced.",
        )

    # 2. Fraud-Aware Review Signals (Review signals for supervisor inspection, not automatic proof of fraud)
    review_signals: List[str] = []
    is_flagged = False

    # A. GPS Accuracy Check (> 50m threshold)
    if visit_in.gps_accuracy > GPS_ACCURACY_THRESHOLD_METERS:
        is_flagged = True
        review_signals.append(
            f"LOW_GPS_ACCURACY: Reported accuracy {visit_in.gps_accuracy:.1f}m exceeds the {GPS_ACCURACY_THRESHOLD_METERS}m threshold."
        )

    # B. Mock Location Signal
    if visit_in.is_mock_location:
        is_flagged = True
        review_signals.append("REPORTED_MOCK_LOCATION: Device reported a mock or simulated location signal.")

    # C. Device vs Server Clock Drift Calculation
    clock_drift_sec = (now_utc - visit_in.device_capture_time).total_seconds()

    # If device clock is noticeably in the future (> 5 min)
    if clock_drift_sec < -300:
        is_flagged = True
        review_signals.append(
            f"IMPLAUSIBLE_DEVICE_CLOCK: Device capture time is {abs(clock_drift_sec):.0f}s in the future compared to server UTC."
        )
    # If device capture was more than 24 hours ago (suspicious upload delay)
    elif clock_drift_sec > 86400:
        is_flagged = True
        review_signals.append(
            f"SUSPICIOUS_UPLOAD_DELAY: Photo capture occurred {clock_drift_sec / 3600:.1f} hours prior to server upload."
        )

    visit = FieldVisit(
        id=visit_in.id.strip() if visit_in.id else str(uuid.uuid4()),
        employee_id=current_user.id,
        client_name=visit_in.client_name.strip(),
        client_phone=visit_in.client_phone.strip() if visit_in.client_phone else None,
        notes=visit_in.notes.strip() if visit_in.notes else None,
        latitude=visit_in.latitude,
        longitude=visit_in.longitude,
        gps_accuracy=visit_in.gps_accuracy,
        is_mock_location=visit_in.is_mock_location,
        device_capture_time=visit_in.device_capture_time,
        server_receipt_time=now_utc,
        photo_asset_id=visit_in.photo_asset_id.strip(),
        photo_url=visit_in.photo_url,
        is_flagged_for_review=is_flagged,
        review_signals=json.dumps(review_signals) if review_signals else None,
        clock_drift_seconds=round(clock_drift_sec, 2),
        status=VisitStatus.PENDING.value,
    )
    db.add(visit)
    await db.flush()

    await log_audit_event(
        db=db,
        action="VISIT_CREATED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id,
        affected_record_type="FieldVisit",
        metadata={
            "client_name": visit.client_name,
            "accuracy": visit.gps_accuracy,
            "is_flagged": is_flagged,
            "review_signals": review_signals,
            "clock_drift_sec": clock_drift_sec,
        },
    )
    await db.commit()
    await db.refresh(visit)
    return VisitResponse.model_validate(visit)

@router.get("", response_model=PaginatedVisitsResponse)
@router.get("/", response_model=PaginatedVisitsResponse)
async def list_visits(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None, description="Filter by status: PENDING, VERIFIED, REJECTED"),
    is_flagged: Optional[bool] = Query(None, description="Filter flagged visits requiring supervisor review"),
    employee_id: Optional[str] = Query(None, description="Filter by employee UUID"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(FieldVisit)
    count_query = select(func.count(FieldVisit.id))

    # Role-Based Scoping
    if current_user.role == UserRole.EMPLOYEE.value:
        query = query.where(FieldVisit.employee_id == current_user.id)
        count_query = count_query.where(FieldVisit.employee_id == current_user.id)
    elif current_user.role == UserRole.MANAGER.value:
        team_subquery = select(User.id).where(User.manager_id == current_user.id)
        query = query.where(
            (FieldVisit.employee_id == current_user.id) | (FieldVisit.employee_id.in_(team_subquery))
        )
        count_query = count_query.where(
            (FieldVisit.employee_id == current_user.id) | (FieldVisit.employee_id.in_(team_subquery))
        )
        if employee_id:
            query = query.where(FieldVisit.employee_id == employee_id)
            count_query = count_query.where(FieldVisit.employee_id == employee_id)
    elif current_user.role == UserRole.OWNER.value:
        if employee_id:
            query = query.where(FieldVisit.employee_id == employee_id)
            count_query = count_query.where(FieldVisit.employee_id == employee_id)

    if status:
        query = query.where(FieldVisit.status == status.upper())
        count_query = count_query.where(FieldVisit.status == status.upper())

    if is_flagged is not None:
        query = query.where(FieldVisit.is_flagged_for_review == is_flagged)
        count_query = count_query.where(FieldVisit.is_flagged_for_review == is_flagged)

    total_res = await db.execute(count_query)
    total = total_res.scalar() or 0

    query = query.order_by(FieldVisit.device_capture_time.desc()).offset(skip).limit(limit)
    res = await db.execute(query)
    visits = res.scalars().all()

    return PaginatedVisitsResponse(
        items=[VisitResponse.model_validate(v) for v in visits],
        total=total,
        skip=skip,
        limit=limit,
    )

@router.get("/{visit_id}", response_model=VisitResponse)
async def get_visit_details(
    visit_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if not visit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Visit record not found.")

    if current_user.role == UserRole.EMPLOYEE.value and visit.employee_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    
    return VisitResponse.model_validate(visit)

@router.post("/{visit_id}/verify", response_model=VisitResponse)
async def verify_or_reject_visit(
    visit_id: str,
    verify_in: VisitVerifyRequest,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Supervisor endpoint to verify or reject a field visit.
    Enforces that unverified drafts cannot count toward employee targets.
    """
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if not visit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Visit record not found.")

    target_status = verify_in.status.upper()
    if target_status not in [VisitStatus.VERIFIED.value, VisitStatus.REJECTED.value]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Status must be either 'VERIFIED' or 'REJECTED'.",
        )

    visit.status = target_status
    visit.review_reason = verify_in.review_reason
    visit.reviewed_by_id = current_user.id
    visit.reviewed_at = datetime.now(timezone.utc)

    await log_audit_event(
        db=db,
        action=f"VISIT_{target_status}",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id,
        affected_record_type="FieldVisit",
        metadata={"new_status": target_status, "reason": verify_in.review_reason},
    )
    await db.commit()
    await db.refresh(visit)
    return VisitResponse.model_validate(visit)
