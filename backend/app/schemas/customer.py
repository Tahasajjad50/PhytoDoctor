from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class CustomerCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255, description="Customer or farm title")
    phone: Optional[str] = Field(None, max_length=50)
    customer_type: str = Field("FARMER", description="FARMER, DEALER, DISTRIBUTOR, RETAILER")
    territory: str = Field(..., min_length=2, max_length=100, description="Territory or district name")
    address: Optional[str] = None
    crop_focus: Optional[str] = None
    latitude: float = Field(30.1575, description="GPS Latitude")
    longitude: float = Field(71.5249, description="GPS Longitude")
    assigned_employee_id: Optional[str] = Field(None, description="Assigned employee UUID or null for auto-nearest")

class CustomerResponse(BaseModel):
    id: str
    name: str
    phone: Optional[str] = None
    customer_type: str
    territory: str
    address: Optional[str] = None
    crop_focus: Optional[str] = None
    latitude: float
    longitude: float
    assigned_employee_id: Optional[str] = None
    assigned_employee_name: Optional[str] = None
    created_by_id: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
