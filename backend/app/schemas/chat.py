from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

class ChatMessageCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=4000, description="Message text content")

class ChatMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    room_id: str
    sender_id: Optional[str] = None
    sender_name: str
    sender_role: str
    content: str
    is_announcement: bool = False
    created_at: datetime

class ChatRoomCreate(BaseModel):
    target_user_id: str = Field(..., description="ID of the user (Admin or Employee) to open a direct chat with")

class ChatRoomResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    room_type: str
    participant_1_id: Optional[str] = None
    participant_2_id: Optional[str] = None
    last_message: Optional[str] = None
    last_message_sender: Optional[str] = None
    last_message_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class AdminContactResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    username: str
    email: str
    role: str
    is_assigned: bool = False

class ChatContactResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    username: str
    email: str
    role: str
    designation: Optional[str] = None
    is_assigned: bool = False
