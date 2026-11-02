from datetime import datetime, timezone
import hashlib
import time
import uuid
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, UploadFile, status
from app.core.config import settings

try:
    import cloudinary
    import cloudinary.uploader
    import cloudinary.utils
    HAS_CLOUDINARY_LIB = True
except ImportError:
    HAS_CLOUDINARY_LIB = False

# Allowed image MIME types and file extensions
ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
ALLOWED_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp"]
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

def is_cloudinary_configured() -> bool:
    """Checks whether valid Cloudinary API credentials have been configured."""
    return bool(
        settings.CLOUDINARY_CLOUD_NAME
        and settings.CLOUDINARY_API_KEY
        and settings.CLOUDINARY_API_SECRET
    )

def configure_cloudinary():
    """Initializes the Cloudinary SDK if credentials exist."""
    if HAS_CLOUDINARY_LIB and is_cloudinary_configured():
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True,
        )

# Initialize on import
configure_cloudinary()

class CloudinaryService:
    @staticmethod
    def validate_file_header(data: bytes, filename: Optional[str] = None) -> str:
        """
        Validates magic bytes to ensure file is genuinely a JPEG, PNG, or WebP.
        Prevents executable/script payload masquerading.
        Returns the detected format string ('jpg', 'png', 'webp').
        """
        if len(data) < 12:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file: Payload too small or corrupted.",
            )

        if len(data) > MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=getattr(status, "HTTP_413_CONTENT_TOO_LARGE", 413),
                detail=f"File exceeds maximum permissible size of {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB.",
            )


        # Check JPEG magic bytes: \xff\xd8\xff
        if data[:3] == b"\xff\xd8\xff":
            return "jpg"
        # Check PNG magic bytes: \x89PNG\r\n\x1a\n
        elif data[:8] == b"\x89PNG\r\n\x1a\n":
            return "png"
        # Check WebP magic bytes: RIFF....WEBP
        elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            return "webp"
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported file format. Only JPEG, PNG, and WebP images are permitted as field visit evidence.",
            )

    @classmethod
    def generate_signed_upload_params(
        cls,
        employee_id: str,
        visit_id: str,
        date_tag: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Generates restricted, short-lived signed upload parameters for mobile client.
        CRITICAL SECURITY & FOLDER MANAGEMENT:
        - Files are organized strictly on a DAILY basis:
            {CLOUDINARY_FOLDER}/{YYYY-MM-DD}/{employee_id}/
          preventing assets from being randomly scattered.
        - Cloudinary API secret is NEVER returned to client.
        - Only signed hash, API key, cloud name, and restricted public ID/folder are provided.
        """
        now_dt = date_tag or datetime.now(timezone.utc)
        date_str = now_dt.strftime("%Y-%m-%d")

        timestamp = int(time.time())
        sanitized_emp = employee_id.replace("-", "")[:8]
        sanitized_visit = visit_id.replace("-", "")[:12]
        unique_suffix = uuid.uuid4().hex[:8]
        
        # Structure folder strictly on daily basis: phytodoctor/visits/YYYY-MM-DD/{employee_id}
        folder = f"{settings.CLOUDINARY_FOLDER}/{date_str}/{sanitized_emp}"
        public_id = f"visit_{sanitized_visit}_{unique_suffix}"
        
        cloud_name = settings.CLOUDINARY_CLOUD_NAME or "phytodoctor_dev"
        api_key = settings.CLOUDINARY_API_KEY or "dev_api_key_12345"
        api_secret = settings.CLOUDINARY_API_SECRET or "dev_secret_dummy"

        params_to_sign = {
            "folder": folder,
            "public_id": public_id,
            "timestamp": timestamp,
        }

        if HAS_CLOUDINARY_LIB and is_cloudinary_configured():
            signature = cloudinary.utils.api_sign_request(params_to_sign, api_secret)
        else:
            # Deterministic SHA1 signature simulation for tests/offline environments
            serialized = f"folder={folder}&public_id={public_id}&timestamp={timestamp}{api_secret}"
            signature = hashlib.sha1(serialized.encode("utf-8")).hexdigest()

        upload_url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"

        return {
            "visit_id": visit_id,
            "public_id": public_id,
            "folder": folder,
            "timestamp": timestamp,
            "signature": signature,
            "api_key": api_key,
            "cloud_name": cloud_name,
            "upload_url": upload_url,
            "allowed_formats": settings.CLOUDINARY_ALLOWED_EXTENSIONS,
            "max_file_size_bytes": MAX_FILE_SIZE_BYTES,
            "is_mock": not is_cloudinary_configured(),
        }

    @classmethod
    async def upload_photo_file(
        cls,
        file_bytes: bytes,
        employee_id: str,
        visit_id: str,
        filename: Optional[str] = None,
        date_tag: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Processes and uploads photo evidence directly through FastAPI to Cloudinary.
        Validates magic bytes, restricts size, and associates metadata in daily partitioned folders.
        """
        fmt = cls.validate_file_header(file_bytes, filename)
        upload_params = cls.generate_signed_upload_params(employee_id, visit_id, date_tag=date_tag)
        
        public_id = upload_params["public_id"]
        folder = upload_params["folder"]
        full_asset_id = f"{folder}/{public_id}"


        if HAS_CLOUDINARY_LIB and is_cloudinary_configured():
            try:
                upload_result = cloudinary.uploader.upload(
                    file_bytes,
                    folder=folder,
                    public_id=public_id,
                    resource_type="image",
                    allowed_formats=["jpg", "png", "webp", "jpeg"],
                    transformation=[
                        {"quality": "auto", "fetch_format": "auto"}
                    ],
                    eager=[
                        {"width": 300, "height": 300, "crop": "fill", "gravity": "auto", "fetch_format": "webp", "quality": "auto"}
                    ]
                )
                photo_url = upload_result.get("secure_url") or upload_result.get("url")
                eager = upload_result.get("eager", [{}])
                thumbnail_url = eager[0].get("secure_url") if eager else cls.get_thumbnail_url(full_asset_id)
                width = upload_result.get("width")
                height = upload_result.get("height")
                bytes_size = upload_result.get("bytes", len(file_bytes))
                version = str(upload_result.get("version", ""))
            except Exception as e:
                err_msg = str(e).lower()
                if "quota" in err_msg or "limit" in err_msg:
                    raise HTTPException(
                        status_code=status.HTTP_507_INSUFFICIENT_STORAGE,
                        detail="Cloudinary storage quota exceeded. Please contact your system administrator.",
                    )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Cloudinary upload failed: {str(e)}",
                )
        else:
            # Simulated upload for development / test suites
            cloud_name = upload_params["cloud_name"]
            photo_url = f"https://res.cloudinary.com/{cloud_name}/image/upload/v1/{full_asset_id}.{fmt}"
            thumbnail_url = f"https://res.cloudinary.com/{cloud_name}/image/upload/c_fill,w_300,h_300,g_auto,q_auto,f_auto/v1/{full_asset_id}.webp"
            width = 1280
            height = 720
            bytes_size = len(file_bytes)
            version = "1"

        return {
            "photo_asset_id": full_asset_id,
            "photo_url": photo_url,
            "thumbnail_url": thumbnail_url,
            "width": width,
            "height": height,
            "bytes_size": bytes_size,
            "format": fmt,
            "version": version,
        }

    @classmethod
    def get_thumbnail_url(cls, photo_asset_id: str) -> str:
        """Returns an optimized 300x300 thumbnail URL for list previews."""
        cloud_name = settings.CLOUDINARY_CLOUD_NAME or "phytodoctor"
        clean_id = photo_asset_id.lstrip("/")
        return f"https://res.cloudinary.com/{cloud_name}/image/upload/c_fill,w_300,h_300,g_auto,q_auto,f_auto/{clean_id}"

    @classmethod
    def get_optimized_view_url(cls, photo_asset_id: str) -> str:
        """Returns a full-resolution auto-formatted, auto-quality delivery URL."""
        cloud_name = settings.CLOUDINARY_CLOUD_NAME or "phytodoctor"
        clean_id = photo_asset_id.lstrip("/")
        return f"https://res.cloudinary.com/{cloud_name}/image/upload/q_auto,f_auto/{clean_id}"

    @classmethod
    def estimate_usage_and_costs(cls, active_employees: int = 20) -> Dict[str, Any]:
        """
        Calculates realistic usage metrics and Cloudinary cost analysis for Phyto Doctor.
        """
        visits_per_emp_per_day = 10
        working_days = 26
        monthly_visits = active_employees * visits_per_emp_per_day * working_days
        avg_photo_kb = 250  # ~250 KB WebP compressed
        monthly_storage_gb = (monthly_visits * avg_photo_kb) / (1024 * 1024)
        
        # 1 credit = 1 GB storage OR 1,000 transformations OR 1 GB bandwidth
        storage_credits = monthly_storage_gb
        transformation_credits = (monthly_visits * 1.0) / 1000.0  # ~1 eager thumbnail per visit
        viewing_bandwidth_gb = ((monthly_visits * 0.1 * avg_photo_kb) + (monthly_visits * 30)) / (1024 * 1024)
        bandwidth_credits = viewing_bandwidth_gb

        total_credits = storage_credits + transformation_credits + bandwidth_credits
        free_tier_credits = 25.0
        utilization = (total_credits / free_tier_credits) * 100.0

        return {
            "plan_name": "Cloudinary Programmable Media Free Tier",
            "monthly_credit_allowance": int(free_tier_credits),
            "estimated_monthly_credits_used": round(total_credits, 2),
            "utilization_percentage": round(utilization, 1),
            "cost_current_usd": 0.0,
            "active_employees": active_employees,
            "estimated_visits_per_month": monthly_visits,
            "estimated_storage_gb_per_month": round(monthly_storage_gb, 2),
            "paid_upgrade_required": total_credits > free_tier_credits,
            "paid_tier_options": {
                "plus_plan": {
                    "monthly_price_usd": 89.0,
                    "monthly_credits": 225,
                    "recommended_when": "Field workforce exceeds ~75 active officers or >18,000 monthly visits."
                },
                "advanced_plan": {
                    "monthly_price_usd": 224.0,
                    "monthly_credits": 600,
                    "recommended_when": "Enterprise distribution exceeding 250 active officers."
                }
            },
            "policy_note": (
                "Phyto Doctor operates securely within Cloudinary's Free Plan tier (25 monthly credits). "
                "Upgrading to a paid plan requires explicit company approval and is not recommended at current operations."
            )
        }
