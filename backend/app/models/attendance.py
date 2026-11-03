from datetime import datetime, timezone, date
from typing import Optional
import uuid
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base

class Attendance(Base):
    __tablename__ = "attendances"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    date: Mapped[date] = mapped_column(Date, default=lambda: datetime.now(timezone.utc).date(), index=True, nullable=False)
    clock_in_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    clock_out_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)

    user: Mapped["User"] = relationship("User", backref="attendances")
