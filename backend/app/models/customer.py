from datetime import datetime, timezone
from enum import Enum
from typing import Optional
import uuid
from sqlalchemy import DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base

class CustomerType(str, Enum):
    FARMER = "FARMER"
    DEALER = "DEALER"
    DISTRIBUTOR = "DISTRIBUTOR"
    RETAILER = "RETAILER"

class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    customer_type: Mapped[str] = mapped_column(String(50), default=CustomerType.FARMER.value, nullable=False)
    territory: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    crop_focus: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # GPS coordinates for territory mapping
    latitude: Mapped[float] = mapped_column(Float, default=30.1575, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, default=71.5249, nullable=False)

    # Assignment to nearest or designated field agronomist
    assigned_employee_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    created_by_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

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

    assigned_employee: Mapped[Optional["User"]] = relationship("User", foreign_keys=[assigned_employee_id])
    creator: Mapped["User"] = relationship("User", foreign_keys=[created_by_id])
