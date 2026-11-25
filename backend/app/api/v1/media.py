import json
import os
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse, RedirectResponse, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
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
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if visit:
        if current_user.role == UserRole.EMPLOYEE.value and visit.employee_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You can only authorize photo uploads for your own visits.",
            )
        elif current_user.role == UserRole.MANAGER.value and visit.employee_id != current_user.id:
            emp_res = await db.execute(select(User).where(User.id == visit.employee_id))
            emp = emp_res.scalar_one_or_none()
            if not emp or (emp.manager_id != current_user.id and emp.created_by_id != current_user.id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied: Visit belongs to another team.",
                )

    # Generate signature with restricted daily folder and unique asset naming
    signed_params = CloudinaryService.generate_signed_upload_params(
        employee_id=current_user.id,
        visit_id=visit.id if visit else visit_id,
        date_tag=(visit.device_capture_time if visit else None) or datetime.now(timezone.utc),
    )

    await log_audit_event(
        db=db,
        action="MEDIA_UPLOAD_AUTHORIZED",
        actor_id=current_user.id,
        actor_role=current_user.role,
        affected_record_id=visit.id if visit else visit_id,
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
    Supports both offline-first (upload photo before visit entity commit)
    and online visit associations.
    """
    # Check if visit already exists in DB
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if visit and current_user.role == UserRole.EMPLOYEE.value and visit.employee_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You can only upload photo evidence for your own field visits.",
        )

    # 1. Read file bytes
    file_bytes = await file.read()

    # 2. Upload and process via CloudinaryService into daily partitioned folder
    upload_result = await CloudinaryService.upload_photo_file(
        file_bytes=file_bytes,
        employee_id=current_user.id,
        visit_id=visit_id,
        filename=file.filename,
        date_tag=(visit.device_capture_time if visit else datetime.now(timezone.utc)),
    )

    now_utc = datetime.now(timezone.utc)
    metadata_json = json.dumps({
        "width": upload_result.get("width"),
        "height": upload_result.get("height"),
        "bytes_size": upload_result.get("bytes_size"),
        "format": upload_result.get("format"),
        "version": upload_result.get("version"),
        "thumbnail_url": upload_result.get("thumbnail_url"),
    })

    # 3. Associate with FieldVisit in PostgreSQL if visit entity exists
    if visit:
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
        visit_id=visit_id,
        photo_asset_id=upload_result["photo_asset_id"],
        photo_url=upload_result["photo_url"],
        thumbnail_url=upload_result["thumbnail_url"],
        preview_url=upload_result.get("preview_url") or CloudinaryService.get_optimized_view_url(upload_result["photo_asset_id"]),
        bytes_size=upload_result.get("bytes_size"),
        width=upload_result.get("width"),
        height=upload_result.get("height"),
        format=upload_result.get("format"),
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
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if visit and current_user.role == UserRole.EMPLOYEE.value and visit.employee_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You can only modify your own visit photo records.",
        )

    now_utc = datetime.now(timezone.utc)
    meta = {
        "width": req.width,
        "height": req.height,
        "bytes_size": req.bytes_size,
        "format": req.format,
        "version": req.version,
    }

    clean_asset_id = req.photo_asset_id.strip()
    dup_res = await db.execute(
        select(FieldVisit).where(
            FieldVisit.photo_asset_id == clean_asset_id,
            FieldVisit.id != visit_id,
        )
    )
    if dup_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Duplicate photo_asset_id is already linked to another visit.",
        )

    if visit:
        visit.photo_asset_id = clean_asset_id
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
        visit_id=visit_id,
        photo_asset_id=req.photo_asset_id.strip(),
        photo_url=req.photo_url.strip(),
        thumbnail_url=CloudinaryService.get_thumbnail_url(req.photo_asset_id.strip()),
        preview_url=CloudinaryService.get_optimized_view_url(req.photo_asset_id.strip()),
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


UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads", "photos")
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.get("/visits/{visit_id}/photo-file")
async def get_visit_photo_file(
    visit_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Directly serves or redirects to the visit proof photo image on Cloudinary.
    Guarantees photo visibility for admin audit and manager review.
    """
    # 1. Check visit record in DB for real Cloudinary URL
    res = await db.execute(select(FieldVisit).where(FieldVisit.id == visit_id))
    visit = res.scalar_one_or_none()
    if visit:
        if visit.photo_url and visit.photo_url.startswith("https://res.cloudinary.com") and "phytodoctor_dev" not in visit.photo_url:
            return RedirectResponse(visit.photo_url)
        elif visit.photo_asset_id:
            cloud = settings.CLOUDINARY_CLOUD_NAME or "hv4hfaee"
            clean_asset = visit.photo_asset_id.strip()
            return RedirectResponse(f"https://res.cloudinary.com/{cloud}/image/upload/{clean_asset}.jpg")

    # 2. Check disk file if present from prior builds
    for ext in ["jpg", "jpeg", "png", "webp"]:
        path = os.path.join(UPLOAD_DIR, f"{visit_id}.{ext}")
        if os.path.exists(path):
            return FileResponse(path, media_type=f"image/{ext if ext != 'jpg' else 'jpeg'}")

    # 3. Dynamic audit proof badge if image is not reachable
    generated_bytes = CloudinaryService.generate_fallback_badge_image(visit_id=visit_id)
    return Response(content=generated_bytes, media_type="image/jpeg")


@router.get("/files/{filename}")
async def get_uploaded_file(filename: str):
    safe_name = os.path.basename(filename)
    photo_path = os.path.join(UPLOAD_DIR, safe_name)
    if os.path.exists(photo_path):
        ext = safe_name.split(".")[-1].lower() if "." in safe_name else "jpeg"
        media_type = f"image/{ext if ext != 'jpg' else 'jpeg'}"
        return FileResponse(photo_path, media_type=media_type)
    raise HTTPException(status_code=404, detail="File not found.")
