from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

class PhotoUploadAuthRequest(BaseModel):
    visit_id: str = Field(..., description="Target field visit UUID")
    file_name: Optional[str] = Field(None, max_length=255, description="Client photo file name")
    file_size_bytes: Optional[int] = Field(None, ge=1, le=10 * 1024 * 1024, description="File size in bytes (max 10MB)")
    content_type: Optional[str] = Field(None, max_length=100, description="MIME content type (image/jpeg, image/png, image/webp)")

class PhotoUploadAuthResponse(BaseModel):
    visit_id: str
    public_id: str
    folder: str
    timestamp: int
    signature: str
    api_key: str
    cloud_name: str
    upload_url: str
    allowed_formats: List[str]
    max_file_size_bytes: int
    is_mock: bool = False

class PhotoConfirmRequest(BaseModel):
    visit_id: str
    photo_asset_id: str
    photo_url: str
    bytes_size: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    format: Optional[str] = None
    version: Optional[str] = None

class PhotoMetadataResponse(BaseModel):
    visit_id: str
    photo_asset_id: str
    photo_url: str
    thumbnail_url: str
    preview_url: str
    bytes_size: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    format: Optional[str] = None
    is_confirmed: bool = True
    uploaded_at: Optional[datetime] = None

class PhotoSecureAccessResponse(BaseModel):
    visit_id: str
    photo_asset_id: str
    secure_view_url: str
    thumbnail_url: str
    expires_in_seconds: int

class CloudinaryUsageEstimateResponse(BaseModel):
    plan_name: str = "Cloudinary Programmable Media Free Tier"
    monthly_credit_allowance: int = 25
    estimated_monthly_credits_used: float = 6.8
    utilization_percentage: float = 27.2
    cost_current_usd: float = 0.0
    active_employees: int = 20
    estimated_visits_per_month: int = 5200
    estimated_storage_gb_per_month: float = 1.3
    paid_upgrade_required: bool = False
    paid_tier_options: Dict[str, Any] = {
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
    }
    policy_note: str = (
        "Phyto Doctor operates securely within Cloudinary's Free Plan tier (25 monthly credits). "
        "Upgrading to a paid plan requires explicit company approval and is not recommended at current operations."
    )
