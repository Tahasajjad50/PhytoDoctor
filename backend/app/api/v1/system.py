import os
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, Header, UploadFile, status
from fastapi.responses import FileResponse, RedirectResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.app_version import AppVersionConfig
from app.models.user import User, UserRole

router = APIRouter(prefix="/system", tags=["System & App Updates"])

STATIC_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "static")
os.makedirs(STATIC_DIR, exist_ok=True)
APK_STORAGE_PATH = os.path.join(STATIC_DIR, "PhytoDoctor-release.apk")
DEFAULT_GITHUB_DOWNLOAD = "https://github.com/Tahasajjad50/PhytoDoctor/releases/latest/download/PhytoDoctor-release.apk"

class AppVersionResponse(BaseModel):
    latest_version: str
    latest_build_number: int
    min_required_build_number: int
    force_update: bool
    title: str
    message: str
    release_notes: str
    download_url: str
    updated_at: Optional[datetime] = None

class UpdateVersionRequest(BaseModel):
    latest_version: Optional[str] = None
    latest_build_number: Optional[int] = None
    min_required_build_number: Optional[int] = None
    force_update: Optional[bool] = None
    title: Optional[str] = None
    message: Optional[str] = None
    release_notes: Optional[str] = None
    download_url: Optional[str] = None

async def verify_admin_or_key(
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    current_user: Optional[User] = Depends(lambda: None),
    db: AsyncSession = Depends(get_db),
):
    if x_admin_key and x_admin_key == settings.SECRET_KEY:
        return True
    return False

@router.get("/version", response_model=AppVersionResponse)
async def get_app_version_info(db: AsyncSession = Depends(get_db)):
    """
    Public endpoint: Checks the latest required app version.
    Called on app launch before login to verify if a mandatory update is required.
    """
    res = await db.execute(select(AppVersionConfig).where(AppVersionConfig.id == 1))
    config = res.scalars().first()

    if not config:
        return AppVersionResponse(
            latest_version="1.0.0",
            latest_build_number=1,
            min_required_build_number=1,
            force_update=True,
            title="Update Required",
            message="A new official version of PhytoDoctor is available. Please update to proceed.",
            release_notes="Official release with Employee Attendance Roster and Offline Sync.",
            download_url="https://phytodoctor-api.onrender.com/api/v1/system/download-apk",
            updated_at=datetime.now(timezone.utc),
        )

    return AppVersionResponse(
        latest_version=config.latest_version,
        latest_build_number=config.latest_build_number,
        min_required_build_number=config.min_required_build_number,
        force_update=config.force_update,
        title=config.title,
        message=config.message,
        release_notes=config.release_notes,
        download_url=config.download_url,
        updated_at=config.updated_at,
    )

@router.post("/version", response_model=AppVersionResponse)
async def update_app_version_info(
    body: UpdateVersionRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: AsyncSession = Depends(get_db)
):
    """
    Sets the required version. Can be authorized via X-Admin-Key (SECRET_KEY).
    Allows 'single-button' automated publisher script to enforce updates.
    """
    if not x_admin_key or x_admin_key != settings.SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized to modify system app version configuration."
        )

    res = await db.execute(select(AppVersionConfig).where(AppVersionConfig.id == 1))
    config = res.scalars().first()

    if not config:
        config = AppVersionConfig(id=1)
        db.add(config)

    if body.latest_version is not None:
        config.latest_version = body.latest_version
    if body.latest_build_number is not None:
        config.latest_build_number = body.latest_build_number
    if body.min_required_build_number is not None:
        config.min_required_build_number = body.min_required_build_number
    if body.force_update is not None:
        config.force_update = body.force_update
    if body.title is not None:
        config.title = body.title
    if body.message is not None:
        config.message = body.message
    if body.release_notes is not None:
        config.release_notes = body.release_notes
    if body.download_url is not None:
        config.download_url = body.download_url

    config.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(config)

    return AppVersionResponse(
        latest_version=config.latest_version,
        latest_build_number=config.latest_build_number,
        min_required_build_number=config.min_required_build_number,
        force_update=config.force_update,
        title=config.title,
        message=config.message,
        release_notes=config.release_notes,
        download_url=config.download_url,
        updated_at=config.updated_at,
    )

@router.get("/download-apk")
async def download_apk():
    """
    Public endpoint: Downloads the latest production APK directly to the user's phone.
    If cached on the server, serves it directly. Otherwise, redirects to the latest GitHub Release.
    """
    if os.path.exists(APK_STORAGE_PATH) and os.path.getsize(APK_STORAGE_PATH) > 1000000:
        return FileResponse(
            path=APK_STORAGE_PATH,
            filename="PhytoDoctor-release.apk",
            media_type="application/vnd.android.package-archive"
        )
    return RedirectResponse(url=DEFAULT_GITHUB_DOWNLOAD)

@router.post("/upload-apk")
async def upload_apk(
    file: UploadFile = File(...),
    version: Optional[str] = None,
    release_notes: Optional[str] = None,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: AsyncSession = Depends(get_db)
):
    """
    Uploads a new production APK directly to the server and automatically bumps
    min_required_build_number to enforce the update for all mobile users.
    """
    if not x_admin_key or x_admin_key != settings.SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized to upload system production APK."
        )

    # Save uploaded APK
    content = await file.read()
    with open(APK_STORAGE_PATH, "wb") as f:
        f.write(content)

    # Auto-bump build number in DB
    res = await db.execute(select(AppVersionConfig).where(AppVersionConfig.id == 1))
    config = res.scalars().first()
    if not config:
        config = AppVersionConfig(id=1)
        db.add(config)

    next_build = config.latest_build_number + 1
    config.latest_build_number = next_build
    config.min_required_build_number = next_build
    config.force_update = True
    if version:
        config.latest_version = version
    if release_notes:
        config.release_notes = release_notes
    config.download_url = "https://phytodoctor-api.onrender.com/api/v1/system/download-apk"
    config.updated_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(config)

    return {
        "status": "success",
        "message": f"New APK uploaded successfully ({len(content)} bytes). Mandatory update enforced at build {next_build}!",
        "latest_version": config.latest_version,
        "latest_build_number": config.latest_build_number,
        "min_required_build_number": config.min_required_build_number,
    }

