from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.chat import ChatMessage, ChatRoom, ChatRoomType
from app.models.user import User, UserRole
from app.schemas.chat import (
    AdminContactResponse,
    ChatContactResponse,
    ChatMessageCreate,
    ChatMessageResponse,
    ChatRoomCreate,
    ChatRoomResponse,
)

router = APIRouter(prefix="/chat", tags=["Chat & Announcements"])

GLOBAL_ANNOUNCEMENT_TITLE = "📢 Company Announcements"
LEADERSHIP_ROOM_TITLE = "👔 Management & Leadership Room"

async def _ensure_default_rooms(db: AsyncSession, owner_id: Optional[str] = None):
    """Ensures that the global announcement channel and leadership channel exist."""
    # Check announcement room
    ann_res = await db.execute(
        select(ChatRoom).where(ChatRoom.room_type == ChatRoomType.ANNOUNCEMENT.value)
    )
    ann_room = ann_res.scalar_one_or_none()
    if not ann_room:
        ann_room = ChatRoom(
            title=GLOBAL_ANNOUNCEMENT_TITLE,
            room_type=ChatRoomType.ANNOUNCEMENT.value,
            created_by_id=owner_id,
        )
        db.add(ann_room)

    # Check leadership room
    lead_res = await db.execute(
        select(ChatRoom).where(ChatRoom.room_type == ChatRoomType.MANAGEMENT.value)
    )
    lead_room = lead_res.scalar_one_or_none()
    if not lead_room:
        lead_room = ChatRoom(
            title=LEADERSHIP_ROOM_TITLE,
            room_type=ChatRoomType.MANAGEMENT.value,
            created_by_id=owner_id,
        )
        db.add(lead_room)

    await db.commit()


@router.get("/rooms", response_model=List[ChatRoomResponse])
async def list_chat_rooms(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List accessible chat rooms for current user.
    - OWNER (CEO): Has full visibility into EVERY chatroom (announcements, management, and all employee-admin direct chats).
    - MANAGER (Admin): Has access to announcements, management channel, and all employee chats where they or another admin participate.
    - EMPLOYEE: Has access to announcements and their own direct chats with their assigned admin or other admins.
    """
    await _ensure_default_rooms(db, current_user.id if current_user.role == UserRole.OWNER.value else None)

    if current_user.role == UserRole.OWNER.value:
        # CEO has access to EVERY chatroom
        query = select(ChatRoom).order_by(desc(ChatRoom.updated_at))
    elif current_user.role == UserRole.MANAGER.value:
        # Manager has access to announcements, leadership room, and any direct chats
        query = select(ChatRoom).where(
            or_(
                ChatRoom.room_type.in_([ChatRoomType.ANNOUNCEMENT.value, ChatRoomType.MANAGEMENT.value]),
                ChatRoom.participant_1_id == current_user.id,
                ChatRoom.participant_2_id == current_user.id,
                # Managers can also see general employee-admin rooms if needed
                ChatRoom.room_type == ChatRoomType.DIRECT.value
            )
        ).order_by(desc(ChatRoom.updated_at))
    else:
        # Field Employee: Announcements + their direct rooms with admins
        query = select(ChatRoom).where(
            or_(
                ChatRoom.room_type == ChatRoomType.ANNOUNCEMENT.value,
                ChatRoom.participant_1_id == current_user.id,
                ChatRoom.participant_2_id == current_user.id,
            )
        ).order_by(desc(ChatRoom.updated_at))

    res = await db.execute(query)
    rooms = res.scalars().all()

    # Enrich rooms with latest message preview (lightweight)
    room_responses = []
    for r in rooms:
        last_msg_res = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.room_id == r.id)
            .order_by(desc(ChatMessage.created_at))
            .limit(1)
        )
        last_msg = last_msg_res.scalar_one_or_none()

        room_responses.append(
            ChatRoomResponse(
                id=r.id,
                title=r.title,
                room_type=r.room_type,
                participant_1_id=r.participant_1_id,
                participant_2_id=r.participant_2_id,
                last_message=last_msg.content if last_msg else None,
                last_message_sender=last_msg.sender_name if last_msg else None,
                last_message_at=last_msg.created_at if last_msg else None,
                created_at=r.created_at,
                updated_at=r.updated_at,
            )
        )

    return room_responses


@router.post("/rooms", response_model=ChatRoomResponse, status_code=status.HTTP_201_CREATED)
async def create_or_get_direct_room(
    data: ChatRoomCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Open or create a 1-on-1 direct chatroom between the current user and an admin/employee.
    If a room already exists between these two users, return the existing room.
    """
    target_res = await db.execute(select(User).where(User.id == data.target_user_id))
    target_user = target_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target user not found.",
        )

    # Enforce role-based direct messaging permissions:
    # 1. CEO (OWNER) can message ANYONE (any employee or admin).
    # 2. Admin (MANAGER) can message CEO OR only employees assigned to this admin (target_user.manager_id == current_user.id).
    # 3. Employee (EMPLOYEE) can message CEO OR only their assigned admin (target_user.id == current_user.manager_id).
    if current_user.role == UserRole.MANAGER.value:
        if target_user.role != UserRole.OWNER.value and target_user.manager_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admins can only message employees assigned to them by the CEO, or message the CEO.",
            )
    elif current_user.role == UserRole.EMPLOYEE.value:
        if target_user.role != UserRole.OWNER.value and current_user.manager_id != target_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Employees can only message their assigned Admin or the CEO.",
            )

    # Check if a direct room already exists between these two users
    existing_res = await db.execute(
        select(ChatRoom).where(
            ChatRoom.room_type == ChatRoomType.DIRECT.value,
            or_(
                (ChatRoom.participant_1_id == current_user.id) & (ChatRoom.participant_2_id == target_user.id),
                (ChatRoom.participant_1_id == target_user.id) & (ChatRoom.participant_2_id == current_user.id),
            )
        )
    )
    existing_room = existing_res.scalar_one_or_none()
    if existing_room:
        return ChatRoomResponse.model_validate(existing_room)

    # Compose informative room title
    room_title = f"{current_user.full_name} ↔ {target_user.full_name}"

    new_room = ChatRoom(
        title=room_title,
        room_type=ChatRoomType.DIRECT.value,
        created_by_id=current_user.id,
        participant_1_id=current_user.id,
        participant_2_id=target_user.id,
    )
    db.add(new_room)
    await db.commit()
    await db.refresh(new_room)

    return ChatRoomResponse.model_validate(new_room)


@router.get("/rooms/{room_id}/messages", response_model=List[ChatMessageResponse])
async def get_room_messages(
    room_id: str,
    after: Optional[datetime] = Query(None, description="Only fetch messages created after this timestamp for lightweight polling"),
    limit: int = Query(50, ge=1, le=100, description="Max messages to fetch (default 50 for low server load)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetch messages for a specific room.
    Verifies user authorization (CEO can view all rooms).
    Optimized for lightweight bandwidth with `after` parameter.
    """
    room_res = await db.execute(select(ChatRoom).where(ChatRoom.id == room_id))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat room not found.")

    # Authorization check
    is_owner = current_user.role == UserRole.OWNER.value
    is_admin = current_user.role == UserRole.MANAGER.value
    if not is_owner:
        if room.room_type == ChatRoomType.ANNOUNCEMENT.value:
            pass  # Anyone can view announcements
        elif room.room_type == ChatRoomType.MANAGEMENT.value:
            if not is_admin:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only Admins & Management can access this room.")
        elif room.room_type == ChatRoomType.DIRECT.value:
            if not is_admin and current_user.id not in [room.participant_1_id, room.participant_2_id]:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this private chat.")

    query = select(ChatMessage).where(ChatMessage.room_id == room_id)
    if after:
        query = query.where(ChatMessage.created_at > after)
    
    query = query.order_by(ChatMessage.created_at.asc()).limit(limit)
    res = await db.execute(query)
    messages = res.scalars().all()

    return [ChatMessageResponse.model_validate(m) for m in messages]


@router.post("/rooms/{room_id}/messages", response_model=ChatMessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    room_id: str,
    msg_in: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Send a message into a chatroom.
    - In ANNOUNCEMENT room: Only CEO (OWNER) and Admins can broadcast.
    - In MANAGEMENT room: Only CEO and Admins can participate.
    - In DIRECT room: Participants and CEO have write access.
    """
    room_res = await db.execute(select(ChatRoom).where(ChatRoom.id == room_id))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat room not found.")

    is_owner = current_user.role == UserRole.OWNER.value
    is_admin = current_user.role == UserRole.MANAGER.value

    # Permission verification
    if room.room_type == ChatRoomType.ANNOUNCEMENT.value:
        if not (is_owner or is_admin):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the CEO and Administrators can post company announcements.",
            )
    elif room.room_type == ChatRoomType.MANAGEMENT.value:
        if not (is_owner or is_admin):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Admins & Management can send messages in this room.",
            )
    elif room.room_type == ChatRoomType.DIRECT.value:
        if not is_owner and not is_admin and current_user.id not in [room.participant_1_id, room.participant_2_id]:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this conversation.")

    is_announcement = (room.room_type == ChatRoomType.ANNOUNCEMENT.value)

    new_msg = ChatMessage(
        room_id=room.id,
        sender_id=current_user.id,
        sender_name=current_user.full_name,
        sender_role=current_user.role,
        content=msg_in.content.strip(),
        is_announcement=is_announcement,
        created_at=datetime.now(timezone.utc),
    )
    db.add(new_msg)

    # Touch room updated_at
    room.updated_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(new_msg)

    return ChatMessageResponse.model_validate(new_msg)


@router.get("/admins", response_model=List[AdminContactResponse])
async def list_available_admins(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List all administrators and the CEO available for contact.
    Highlights if an admin is the assigned manager for the calling employee.
    """
    query = select(User).where(
        User.role.in_([UserRole.OWNER.value, UserRole.MANAGER.value]),
        User.is_active == True,
    ).order_by(User.role.asc(), User.full_name.asc())

    res = await db.execute(query)
    admins = res.scalars().all()

    contacts = []
    for adm in admins:
        is_assigned = (current_user.manager_id == adm.id)
        contacts.append(
            AdminContactResponse(
                id=adm.id,
                full_name=adm.full_name,
                username=adm.username,
                email=adm.email,
                role=adm.role,
                is_assigned=is_assigned,
            )
        )

    return contacts


@router.get("/contacts", response_model=List[ChatContactResponse])
async def list_chat_contacts(
    query: Optional[str] = Query(None, description="Search term for employee or admin name"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List permitted contacts for direct messaging:
    - CEO (OWNER): Can search and message ANY admin or employee by name.
    - Admin (MANAGER): Can only message employees assigned to them (User.manager_id == current_user.id) + CEO.
    - Employee (EMPLOYEE): Can only message their assigned Admin (User.id == current_user.manager_id) + CEO.
    """
    stmt = select(User).where(User.is_active == True, User.id != current_user.id)

    if current_user.role == UserRole.OWNER.value:
        # CEO can message any active admin or employee
        stmt = stmt.where(User.role.in_([UserRole.MANAGER.value, UserRole.EMPLOYEE.value]))
    elif current_user.role == UserRole.MANAGER.value:
        # Admin can ONLY message CEO or assigned employees
        stmt = stmt.where(
            or_(
                User.role == UserRole.OWNER.value,
                (User.role == UserRole.EMPLOYEE.value) & (User.manager_id == current_user.id),
            )
        )
    else:
        # Employee can ONLY message CEO or their assigned manager
        conditions = [User.role == UserRole.OWNER.value]
        if current_user.manager_id:
            conditions.append(User.id == current_user.manager_id)
        stmt = stmt.where(or_(*conditions))

    if query:
        search_pattern = f"%{query.strip()}%"
        stmt = stmt.where(
            or_(
                User.full_name.ilike(search_pattern),
                User.username.ilike(search_pattern),
                User.designation.ilike(search_pattern),
            )
        )

    stmt = stmt.order_by(User.role.asc(), User.full_name.asc())
    res = await db.execute(stmt)
    users = res.scalars().all()

    contacts = []
    for u in users:
        is_assigned = (u.manager_id == current_user.id) if current_user.role == UserRole.MANAGER.value else (current_user.manager_id == u.id)
        contacts.append(
            ChatContactResponse(
                id=u.id,
                full_name=u.full_name,
                username=u.username,
                email=u.email,
                role=u.role,
                designation=u.designation,
                is_assigned=is_assigned,
            )
        )
    return contacts
