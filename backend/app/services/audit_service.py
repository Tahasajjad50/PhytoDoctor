import json
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.audit import AuditEvent

async def log_audit_event(
    db: AsyncSession,
    action: str,
    actor_id: Optional[str] = None,
    actor_role: Optional[str] = None,
    affected_record_id: Optional[str] = None,
    affected_record_type: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> AuditEvent:
    """
    Creates an immutable audit event in the database.
    Ensures safe metadata storage without passwords or secrets.
    """
    safe_metadata_str = None
    if metadata:
        # Sanitize sensitive fields if present
        clean_meta = {
            k: v for k, v in metadata.items()
            if "password" not in k.lower() and "token" not in k.lower() and "secret" not in k.lower()
        }
        safe_metadata_str = json.dumps(clean_meta, default=str)

    event = AuditEvent(
        actor_id=actor_id,
        actor_role=actor_role,
        action=action,
        affected_record_id=affected_record_id,
        affected_record_type=affected_record_type,
        server_timestamp=datetime.now(timezone.utc),
        metadata_json=safe_metadata_str,
    )
    db.add(event)
    await db.flush()
    return event
