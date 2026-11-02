from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class UserCreate(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=128)
    role: str = Field("EMPLOYEE", description="OWNER, MANAGER, or EMPLOYEE")
    manager_id: Optional[str] = None
    is_active: bool = True
    phone: Optional[str] = None
    designation: Optional[str] = None

class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=255)
    email: Optional[EmailStr] = None
    manager_id: Optional[str] = None
    is_active: Optional[bool] = None
    phone: Optional[str] = None
    designation: Optional[str] = None

class PasswordResetRequest(BaseModel):
    new_password: str = Field(..., min_length=6, max_length=128)

class UserResponse(BaseModel):
    id: str
    full_name: str
    email: str
    username: str
    role: str
    is_active: bool
    phone: Optional[str] = None
    designation: Optional[str] = None
    manager_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PaginatedUsersResponse(BaseModel):
    items: List[UserResponse]
    total: int
    skip: int
    limit: int

class CreatedAccountResponse(BaseModel):
    id: str
    full_name: str
    email: str
    username: str
    role: str
    is_active: bool
    phone: Optional[str] = None
    designation: Optional[str] = None
    manager_id: Optional[str] = None
    created_at: datetime
    created_by_id: Optional[str] = None
    created_by_name: Optional[str] = None
    login_password: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class UpdateCredentialsRequest(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = Field(None, min_length=6, max_length=128)
    full_name: Optional[str] = None
    phone: Optional[str] = None
    designation: Optional[str] = None
    is_active: Optional[bool] = None

class EmployeeSupervisionItem(BaseModel):
    id: str
    full_name: str
    username: str
    email: str
    phone: Optional[str] = None
    designation: Optional[str] = None
    is_active: bool
    manager_id: Optional[str] = None
    manager_name: Optional[str] = None
    manager_username: Optional[str] = None
    created_by_id: Optional[str] = None
    created_by_name: Optional[str] = None
    can_transfer: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class SupervisorOption(BaseModel):
    id: str
    full_name: str
    username: str
    role: str
    designation: Optional[str] = None

class SupervisionListResponse(BaseModel):
    employees: List[EmployeeSupervisionItem]
    available_supervisors: List[SupervisorOption]
    is_owner: bool

class TransferSupervisorRequest(BaseModel):
    employee_id: str
    new_manager_id: Optional[str] = None
    notes: Optional[str] = None

