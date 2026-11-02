from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

class VisitCreate(BaseModel):
    id: Optional[str] = Field(None, max_length=36, description="Client-generated UUID idempotency key")
    client_name: str = Field(..., min_length=2, max_length=255, description="Mandatory client/dealer/farmer name")
    client_phone: Optional[str] = Field(None, max_length=50, description="Optional client contact phone")
    notes: Optional[str] = Field(None, max_length=2000, description="Optional field reference notes")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS Latitude (-90 to 90)")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS Longitude (-180 to 180)")
    gps_accuracy: float = Field(..., ge=0.0, le=1000.0, description="Reported GPS accuracy radius in meters")
    is_mock_location: bool = Field(False, description="Whether Android mock location provider was reported")
    device_capture_time: datetime = Field(..., description="UTC timestamp of in-app camera shutter capture")
    photo_asset_id: str = Field(..., min_length=5, max_length=255, description="Unique in-app camera asset ID")
    photo_url: Optional[str] = Field(None, max_length=512, description="Cloudinary delivery URL if uploaded")

    @field_validator("client_name")
    @classmethod
    def validate_client_name(cls, v: str) -> str:
        trimmed = v.strip()
        if len(trimmed) < 2:
            raise ValueError("Client name must be at least 2 characters long.")
        return trimmed

    @field_validator("photo_asset_id")
    @classmethod
    def validate_photo_asset_id(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("A fresh in-app camera photo asset ID is mandatory.")
        return trimmed

class VisitVerifyRequest(BaseModel):
    status: str = Field(..., description="'VERIFIED' or 'REJECTED'")
    review_reason: Optional[str] = Field(None, max_length=1000, description="Supervisor audit explanation")

class VisitResponse(BaseModel):
    id: str
    employee_id: str
    client_name: str
    client_phone: Optional[str] = None
    notes: Optional[str] = None
    latitude: float
    longitude: float
    gps_accuracy: float
    is_mock_location: bool
    device_capture_time: datetime
    server_receipt_time: datetime
    photo_asset_id: str
    photo_url: Optional[str] = None
    photo_metadata: Optional[str] = None
    photo_uploaded_at: Optional[datetime] = None
    status: str
    is_flagged_for_review: bool
    review_signals: Optional[str] = None
    clock_drift_seconds: Optional[float] = None
    review_reason: Optional[str] = None
    reviewed_by_id: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime


    model_config = ConfigDict(from_attributes=True)

class PaginatedVisitsResponse(BaseModel):
    items: List[VisitResponse]
    total: int
    skip: int
    limit: int

class EvidencePolicyResponse(BaseModel):
    company: str = "Phyto Doctor (Pvt) Ltd"
    policy_title: str = "Field Evidence Collection & Fraud-Aware Review Policy"
    background_tracking_enabled: bool = False
    gps_accuracy_threshold_meters: float = 50.0
    evidence_disclosure: str = (
        "Phyto Doctor collects on-site in-app camera photos and GNSS location coordinates "
        "exclusively during visit submission to verify customer engagement and crop inspections. "
        "No hidden background location tracking is performed on employee personal devices."
    )
    disclaimer: str = (
        "GNSS coordinates, reported accuracy, and device timestamps serve as verification signals "
        "for supervisor review and do not alone prove physical presence. Flags represent review signals, "
        "not definitive proof of fraud."
    )
