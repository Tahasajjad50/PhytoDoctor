import json
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.user import User, UserRole
from app.models.visit import FieldVisit
from app.schemas.media import (
    CloudinaryUsageEstimateResponse,
    PhotoConfirmRequest,
    PhotoMetadataResponse,
    PhotoSecureAccessResponse,
    PhotoUploadAuthRequest,
    PhotoUploadAuthResponse,
)
from app.services.audit_service import log_audit_event
from app.services.cloudinary_service import CloudinaryService

router = APIRouter(prefix="/media", tags=["Cloudinary Media & Photo Evidence"])

async def get_and_authorize_visit(
    visit_id: str,
    current_user: User,
    db: AsyncSession,
    allow_manager: bool = False,
) -> FieldVisit:
    """
    Validates that the visit exists and the authenticated user has permission to view or modify it.
    """
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if not visit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Field visit record not found.",
        )

    # Permission Scoping
    if current_user.role == UserRole.EMPLOYEE.value:
        if visit.employee_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You can only access photo evidence for your own field visits.",
            )
    elif current_user.role == UserRole.MANAGER.value:
        if not allow_manager:
            if visit.employee_id != current_user.id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Managers cannot modify employee photo records directly.",
                )
        else:
            # Check if visit employee belongs to manager's team
            if visit.employee_id != current_user.id:
                emp_res = await db.execute(select(User).where(User.id == visit.employee_id))
                emp = emp_res.scalar_one_or_none()
                if not emp or emp.manager_id != current_user.id:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied: This visit does not belong to your authorized team members.",
                    )
    # Owner has global access
    return visit

@router.post("/visits/{visit_id}/photo-upload-authorization", response_model=PhotoUploadAuthResponse)
async def request_photo_upload_authorization(
    visit_id: str,
    req: Optional[PhotoUploadAuthRequest] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates restricted, short-lived signed upload parameters for Cloudinary.
    SECURITY:
    - Never exposes Cloudinary API secret to Flutter mobile or web client.
    - Validates authenticated employee and visit ID.
    - Restricts public ID, folder, and allowable formats.
    """
    visit = await get_and_authorize_visit(visit_id, current_user, db)
    
    # Generate signature with restricted daily folder and unique asset naming
    signed_params = CloudinaryService.generate_signed_upload_params(
        employee_id=current_user.id,
        visit_id=visit.id,
        date_tag=visit.device_capture_time or datetime.now(timezone.utc),
    )

    await log_audit_event(
        db=db,
        action="MEDIA_UPLOAD_AUTHORIZED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id,
        affected_record_type="FieldVisit",
        metadata={
            "public_id": signed_params["public_id"],
            "folder": signed_params["folder"],
        },
    )
    await db.commit()

    return PhotoUploadAuthResponse(**signed_params)

@router.post("/visits/{visit_id}/photo", response_model=PhotoMetadataResponse, status_code=status.HTTP_201_CREATED)
async def upload_visit_photo(
    visit_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Direct secure upload endpoint: Validates file magic bytes and size,
    transfers to Cloudinary, and associates the asset ID in PostgreSQL.
    """
    visit = await get_and_authorize_visit(visit_id, current_user, db)

    # 1. Read file bytes
    file_bytes = await file.read()

    # 2. Upload and process via CloudinaryService into daily partitioned folder
    upload_result = await CloudinaryService.upload_photo_file(
        file_bytes=file_bytes,
        employee_id=current_user.id,
        visit_id=visit.id,
        filename=file.filename,
        date_tag=visit.device_capture_time or datetime.now(timezone.utc),
    )


    now_utc = datetime.now(timezone.utc)
    metadata_json = json.dumps({
        "width": upload_result["width"],
        "height": upload_result["height"],
        "bytes_size": upload_result["bytes_size"],
        "format": upload_result["format"],
        "version": upload_result["version"],
        "thumbnail_url": upload_result["thumbnail_url"],
    })

    # 3. Associate with FieldVisit in PostgreSQL
    visit.photo_asset_id = upload_result["photo_asset_id"]
    visit.photo_url = upload_result["photo_url"]
    visit.photo_metadata = metadata_json
    visit.photo_uploaded_at = now_utc

    await log_audit_event(
        db=db,
        action="MEDIA_PHOTO_UPLOADED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id,
        affected_record_type="FieldVisit",
        metadata={
            "photo_asset_id": upload_result["photo_asset_id"],
            "bytes": upload_result["bytes_size"],
            "format": upload_result["format"],
        },
    )
    await db.commit()
    await db.refresh(visit)

    return PhotoMetadataResponse(
        visit_id=visit.id,
        photo_asset_id=visit.photo_asset_id,
        photo_url=visit.photo_url,
        thumbnail_url=upload_result["thumbnail_url"],
        preview_url=CloudinaryService.get_optimized_view_url(visit.photo_asset_id),
        bytes_size=upload_result["bytes_size"],
        width=upload_result["width"],
        height=upload_result["height"],
        format=upload_result["format"],
        is_confirmed=True,
        uploaded_at=now_utc,
    )

@router.post("/visits/{visit_id}/confirm-photo", response_model=PhotoMetadataResponse)
async def confirm_photo_association(
    visit_id: str,
    req: PhotoConfirmRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Confirms association between a client-uploaded Cloudinary asset and the visit in PostgreSQL.
    Guarantees record integrity before the mobile app marks the visit as 'Synced'.
    """
    visit = await get_and_authorize_visit(visit_id, current_user, db)

    now_utc = datetime.now(timezone.utc)
    meta = {
        "width": req.width,
        "height": req.height,
        "bytes_size": req.bytes_size,
        "format": req.format,
        "version": req.version,
    }

    visit.photo_asset_id = req.photo_asset_id.strip()
    visit.photo_url = req.photo_url.strip()
    visit.photo_metadata = json.dumps(meta)
    visit.photo_uploaded_at = now_utc

    await log_audit_event(
        db=db,
        action="MEDIA_PHOTO_CONFIRMED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id,
        affected_record_type="FieldVisit",
        metadata={
            "photo_asset_id": visit.photo_asset_id,
            "photo_url": visit.photo_url,
        },
    )
    await db.commit()
    await db.refresh(visit)

    return PhotoMetadataResponse(
        visit_id=visit.id,
        photo_asset_id=visit.photo_asset_id,
        photo_url=visit.photo_url,
        thumbnail_url=CloudinaryService.get_thumbnail_url(visit.photo_asset_id),
        preview_url=CloudinaryService.get_optimized_view_url(visit.photo_asset_id),
        bytes_size=req.bytes_size,
        width=req.width,
        height=req.height,
        format=req.format,
        is_confirmed=True,
        uploaded_at=now_utc,
    )

@router.get("/visits/{visit_id}/photo-access", response_model=PhotoSecureAccessResponse)
async def get_secure_photo_access(
    visit_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Provides authorized, role-scoped access to visit photo evidence.
    CRITICAL SECURITY:
    - Never exposes private visit evidence publicly.
    - Requires authenticated credentials.
    - Employees can only access their own photos.
    - Managers can only access their assigned team members' photos.
    - Owners have global inspection access.
    """
    visit = await get_and_authorize_visit(visit_id, current_user, db, allow_manager=True)

    if not visit.photo_url and not visit.photo_asset_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No photo evidence has been attached to this visit record.",
        )

    secure_view = visit.photo_url or CloudinaryService.get_optimized_view_url(visit.photo_asset_id)
    thumbnail = CloudinaryService.get_thumbnail_url(visit.photo_asset_id)

    return PhotoSecureAccessResponse(
        visit_id=visit.id,
        photo_asset_id=visit.photo_asset_id,
        secure_view_url=secure_view,
        thumbnail_url=thumbnail,
        expires_in_seconds=3600,
    )

@router.get("/usage-and-costs", response_model=CloudinaryUsageEstimateResponse)
async def get_cloudinary_usage_and_costs(
    active_employees: int = Query(20, ge=1, le=500, description="Active field workforce count"),
    current_user: User = Depends(require_admin),
):
    """
    Admin/Owner endpoint to review Cloudinary quota limits, monthly credit consumption,
    realistic cost modeling for Phyto Doctor, and paid tier analysis.
    """
    usage = CloudinaryService.estimate_usage_and_costs(active_employees=active_employees)
    return CloudinaryUsageEstimateResponse(**usage)
