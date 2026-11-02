from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class LoginRequest(BaseModel):
    username_or_email: str = Field(..., min_length=2, max_length=255, description="Username or email")
    password: str = Field(..., min_length=4, max_length=128, description="Password")
    portal: Optional[str] = Field(None, description="'employee' or 'admin'")

class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=10, description="Opaque refresh token string")

class UserSummary(BaseModel):
    id: str
    full_name: str
    email: str
    username: str
    role: str
    is_active: bool
    manager_id: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in_seconds: int
    user: UserSummary

class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = Field(None, description="Optional refresh token to revoke")

class MessageResponse(BaseModel):
    message: str
    status: str = "success"
