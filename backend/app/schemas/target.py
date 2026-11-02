from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

class TargetCreate(BaseModel):
    employee_id: str = Field(..., description="Target employee UUID")
    target_count: int = Field(..., ge=1, le=1000, description="Visit target count")
    period_type: str = Field("DAILY", description="'DAILY', 'WEEKLY', or 'MONTHLY'")
    start_date: date
    end_date: date

class BatchTargetCreate(BaseModel):
    employee_ids: List[str] = Field(..., min_length=1, description="List of target employee UUIDs")
    target_count: int = Field(..., ge=1, le=1000, description="Visit target count")
    period_type: str = Field("DAILY", description="'DAILY', 'WEEKLY', or 'MONTHLY'")
    start_date: date
    end_date: date

class TargetUpdate(BaseModel):
    target_count: Optional[int] = Field(None, ge=1, le=1000)
    period_type: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None

class TargetResponse(BaseModel):
    id: str
    employee_id: str
    target_count: int
    period_type: str
    start_date: date
    end_date: date
    created_by_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PaginatedTargetsResponse(BaseModel):
    items: List[TargetResponse]
    total: int
    skip: int
    limit: int
