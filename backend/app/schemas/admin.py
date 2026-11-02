from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict

class AuditEventResponse(BaseModel):
    id: str
    actor_id: Optional[str] = None
    actor_role: Optional[str] = None
    action: str
    affected_record_id: Optional[str] = None
    affected_record_type: Optional[str] = None
    timestamp: datetime
    metadata: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(from_attributes=True)

class AuditLogsListResponse(BaseModel):
    items: List[AuditEventResponse]
    total: int
