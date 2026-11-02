from datetime import datetime, timezone
from enum import Enum
from typing import Optional
import uuid
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base

class VisitStatus(str, Enum):
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"

class FieldVisit(Base):
    __tablename__ = "field_visits"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    client_name: Mapped[str] = mapped_column(String(255), nullable=False)
    client_phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Geolocation metrics
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    gps_accuracy: Mapped[float] = mapped_column(Float, nullable=False)
    is_mock_location: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Time tracking (Strict UTC)
    device_capture_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    server_receipt_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Photo evidence reference (Cloudinary public ID / asset key)
    photo_asset_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    photo_metadata: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON-encoded metadata (format, dimensions, bytes, thumbnail_url, etc.)
    photo_uploaded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Fraud-aware Review Signals (Signals for supervisor review, not proof of fraud)
    is_flagged_for_review: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    review_signals: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON-encoded array of signals
    clock_drift_seconds: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Verification workflow
    status: Mapped[str] = mapped_column(
        String(50),
        default=VisitStatus.PENDING.value,
        nullable=False,
        index=True
    )
    review_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reviewed_by_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    employee: Mapped["User"] = relationship("User", foreign_keys=[employee_id], backref="visits")
    reviewer: Mapped[Optional["User"]] = relationship("User", foreign_keys=[reviewed_by_id])
