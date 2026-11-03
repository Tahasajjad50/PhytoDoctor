from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class AppVersionConfig(Base):
    __tablename__ = "app_version_configs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    latest_version: Mapped[str] = mapped_column(String(50), default="1.0.0", nullable=False)
    latest_build_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    min_required_build_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    force_update: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    title: Mapped[str] = mapped_column(String(150), default="Update Required", nullable=False)
    message: Mapped[str] = mapped_column(
        Text,
        default="A newer version of PhytoDoctor is available. Please update to continue using the application.",
        nullable=False
    )
    release_notes: Mapped[str] = mapped_column(
        Text,
        default="Latest updates and performance improvements.",
        nullable=False
    )
    download_url: Mapped[str] = mapped_column(
        String(500),
        default="https://phytodoctor-api.onrender.com/api/v1/system/download-apk",
        nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

