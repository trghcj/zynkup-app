import json
import logging
import os
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Request, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import Club, ClubMember, User, Event, Registration, FeedPost, FeedLike, FeedComment, ClubMessage
from ..auth import get_current_user, get_optional_current_user

router = APIRouter(prefix="/clubs", tags=["Clubs"])
logger = logging.getLogger(__name__)

_SEP = "|||---|||"
_NAME_SEP = "|||"
UPLOAD_DIR = "uploads"
MAX_GALLERY_FILES = 50
ALLOWED_MIME = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp"}
EXT_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}

class ClubCreate(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = "general"
    banner_url: Optional[str] = None
    logo_url: Optional[str] = None

class ClubResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    category: Optional[str]
    banner_url: Optional[str]
    logo_url: Optional[str]
    clubProfileUrl: Optional[str] = None
    member_count: int
    created_at: datetime
    is_member: bool = False
    creator_id: int

    class Config:
        orm_mode = True

class ClubMemberResponse(BaseModel):
    user_id: int
    name: str
    avatar_url: Optional[str]
    role: str
    joined_at: datetime

    class Config:
        orm_mode = True

class MemberRoleUpdate(BaseModel):
    role: str

def _is_valid_image_source(value: str) -> bool:
    value = value.strip()
    return value.startswith("http://") or value.startswith("https://") or value.startswith("data:image/")

def _normalize_gallery(raw: object) -> str:
    if isinstance(raw, list):
        return _SEP.join(str(item).strip() for item in raw if str(item).strip())
    return str(raw or "")

def _parse_gallery(raw: object) -> List[dict]:
    raw = _normalize_gallery(raw)
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return [
                item
                for item in parsed
                if isinstance(item, dict) and (item.get("url") or item.get("data"))
            ]
    except json.JSONDecodeError:
        pass
    items = []
    for entry in raw.split(_SEP):
        if not entry.strip():
            continue
        parts = entry.split(_NAME_SEP, 2)
        if len(parts) == 3:
            items.append({"name": parts[0], "mime": parts[1], "data": parts[2]})
    return items

def _serialize_gallery(items: List[dict]) -> str:
    return json.dumps(items)

def _public_upload_url(request: Request, filename: str) -> str:
    base_url = os.getenv("PUBLIC_BACKEND_URL", "").rstrip("/")
    if base_url:
        return f"{base_url}/uploads/{filename}"
    return str(request.url_for("uploads", path=filename))

@router.post("/", response_model=ClubResponse)
def create_club(club_data: ClubCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    existing = db.query(Club).filter(Club.name == club_data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Club name already taken")

    new_club = Club(
        name=club_data.name,
        description=club_data.description,
        category=club_data.category,
        banner_url=club_data.banner_url,
        logo_url=club_data.logo_url,
        creator_id=current_user.id
    )
    db.add(new_club)
    db.commit()
    db.refresh(new_club)

    # Creator is automatically an admin member
    member = ClubMember(club_id=new_club.id, user_id=current_user.id, role="admin")
    db.add(member)
    
    # Increase XP by 40 for creating a club
    current_user.xp = (current_user.xp or 0) + 40
    
    db.commit()

    return ClubResponse(
        id=new_club.id,
        name=new_club.name,
        description=new_club.description,
        category=new_club.category,
        banner_url=new_club.banner_url,
        logo_url=new_club.logo_url,
        clubProfileUrl=new_club.logo_url,
        member_count=1,
        created_at=new_club.created_at,
        is_member=True,
        creator_id=new_club.creator_id
    )

@router.get("/", response_model=List[ClubResponse])
def get_clubs(db: Session = Depends(get_db), current_user: Optional[User] = Depends(get_optional_current_user)):
    clubs = db.query(Club).all()
    user_memberships = set()
    if current_user:
        user_memberships = {m.club_id for m in db.query(ClubMember).filter(ClubMember.user_id == current_user.id).all()}

    result = []
    for c in clubs:
        count = db.query(ClubMember).filter(ClubMember.club_id == c.id).count()
        result.append(ClubResponse(
            id=c.id,
            name=c.name,
            description=c.description,
            category=c.category,
            banner_url=c.banner_url,
            logo_url=c.logo_url,
            clubProfileUrl=c.logo_url,
            member_count=count,
            created_at=c.created_at,
            is_member=(c.id in user_memberships),
            creator_id=c.creator_id
        ))
    return result

@router.get("/{club_id}", response_model=ClubResponse)
def get_club(club_id: int, db: Session = Depends(get_db), current_user: Optional[User] = Depends(get_optional_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    is_member = False
    if current_user:
        is_member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first() is not None

    count = db.query(ClubMember).filter(ClubMember.club_id == club_id).count()
    return ClubResponse(
        id=club.id,
        name=club.name,
        description=club.description,
        category=club.category,
        banner_url=club.banner_url,
        logo_url=club.logo_url,
        clubProfileUrl=club.logo_url,
        member_count=count,
        created_at=club.created_at,
        is_member=is_member,
        creator_id=club.creator_id
    )

@router.delete("/{club_id}")
def delete_club(club_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    if club.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the club creator can delete this club")

    # Cascade-delete all dependencies first to avoid orphan FK rows
    
    # 1. Events and their attendees
    event_ids = [e.id for e in db.query(Event.id).filter(Event.club_id == club_id).all()]
    if event_ids:
        db.query(Registration).filter(Registration.event_id.in_(event_ids)).delete(synchronize_session=False)
        db.query(Event).filter(Event.club_id == club_id).delete(synchronize_session=False)
        
    # 2. Feed Posts and their likes/comments
    post_ids = [p.id for p in db.query(FeedPost.id).filter(FeedPost.club_id == club_id).all()]
    if post_ids:
        db.query(FeedComment).filter(FeedComment.post_id.in_(post_ids)).delete(synchronize_session=False)
        db.query(FeedLike).filter(FeedLike.post_id.in_(post_ids)).delete(synchronize_session=False)
        db.query(FeedPost).filter(FeedPost.club_id == club_id).delete(synchronize_session=False)
        
    # 3. Club Messages
    db.query(ClubMessage).filter(ClubMessage.club_id == club_id).delete(synchronize_session=False)

    # 4. Club Members
    db.query(ClubMember).filter(ClubMember.club_id == club_id).delete(synchronize_session=False)
    
    db.delete(club)
    db.commit()
    return {"message": "Club deleted successfully"}

@router.post("/{club_id}/join")
def join_club(club_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    existing = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    if existing:
        # Toggle leave if already joined to make it toggleable, or handle standard leave/join
        db.delete(existing)
        db.commit()
        return {"message": "Left club successfully", "joined": False}

    member = ClubMember(club_id=club_id, user_id=current_user.id, role="member")
    db.add(member)
    db.commit()
    return {"message": "Joined club successfully", "joined": True}

@router.get("/{club_id}/members", response_model=List[ClubMemberResponse])
def get_club_members(club_id: int, db: Session = Depends(get_db)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    members = db.query(ClubMember).filter(ClubMember.club_id == club_id).order_by(ClubMember.joined_at.asc()).all()
    result = []
    for m in members:
        # Determine displaying role
        role_str = m.role
        if m.user_id == club.creator_id:
            role_str = "creator" # Ensure creator stands out

        result.append(ClubMemberResponse(
            user_id=m.user_id,
            name=m.user.name or m.user.display_name or "Student",
            avatar_url=m.user.resolved_avatar_url,
            role=role_str,
            joined_at=m.joined_at
        ))
    return result

@router.put("/{club_id}/members/{user_id}/role")
def update_member_role(club_id: int, user_id: int, payload: MemberRoleUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    actor = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    is_owner = club.creator_id == current_user.id or (actor and actor.role == "owner")

    if not is_owner and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only club owners can update member roles")

    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == user_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Club member not found")

    if member.user_id == club.creator_id:
        raise HTTPException(status_code=400, detail="Cannot change creator's role")

    member.role = payload.role.strip()
    db.commit()
    return {"message": f"Updated role to {member.role}"}

@router.delete("/{club_id}/members/{user_id}")
def remove_member(club_id: int, user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    actor = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    has_permission = club.creator_id == current_user.id or current_user.role == "admin"

    if not has_permission:
        raise HTTPException(status_code=403, detail="Not authorized to remove members")

    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == user_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    if member.user_id == club.creator_id or member.role == "owner":
        raise HTTPException(status_code=403, detail="Cannot remove club owner")

    db.delete(member)
    db.commit()
    return {"message": "Member removed"}

@router.get("/{club_id}/events")
def get_club_events(club_id: int, db: Session = Depends(get_db)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    # Helper to convert events
    from .events import _event_to_dict
    events = db.query(Event).filter(Event.club_id == club_id).order_by(Event.date.asc()).all()
    return [_event_to_dict(event) for event in events]

@router.get("/{club_id}/gallery")
def get_club_gallery(club_id: int, db: Session = Depends(get_db)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    return {"club_id": club_id, "files": _parse_gallery(club.gallery_files)}

@router.post("/{club_id}/gallery")
async def upload_club_gallery(
    request: Request,
    club_id: int,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    # Permission check: creator or non-member roles (admin, moderator, custom assigned role)
    member_record = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    has_permission = (
        club.creator_id == current_user.id or
        (member_record is not None and member_record.role != "member")
    )
    if not has_permission:
        raise HTTPException(status_code=403, detail="Only the club creator or assigned organizers can upload to gallery")

    existing = _parse_gallery(club.gallery_files)
    if len(existing) + len(files) > MAX_GALLERY_FILES:
        raise HTTPException(status_code=400, detail=f"Max {MAX_GALLERY_FILES} gallery files allowed")

    additions = []
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    for file in files:
        ext = Path(file.filename or "gallery.jpg").suffix.lower()
        mime = (file.content_type or EXT_MIME.get(ext, "")).lower()
        if ext not in ALLOWED_EXT:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        if mime not in ALLOWED_MIME:
            mime = EXT_MIME[ext]
        contents = await file.read()
        if len(contents) > 15 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large. Max 15MB")
        filename = f"{uuid.uuid4().hex}{ext}"
        file_path = Path(UPLOAD_DIR) / filename
        file_path.write_bytes(contents)
        additions.append({
            "name": file.filename or "gallery-file",
            "filename": filename,
            "mime": mime,
            "url": _public_upload_url(request, filename),
        })
    try:
        club.gallery_files = _serialize_gallery(existing + additions)
        db.commit()
    except Exception as db_err:
        db.rollback()
        logger.error(f"CLUB GALLERY DB SAVE ERROR: {db_err}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to save club gallery: {str(db_err)}")

    return {
        "message": f"{len(additions)} file(s) uploaded",
        "files": additions,
        "total": len(existing) + len(additions),
    }

@router.delete("/{club_id}/gallery/{index}")
def delete_club_gallery_by_index(
    club_id: int,
    index: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    member_record = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    has_permission = (
        club.creator_id == current_user.id or
        (member_record is not None and member_record.role != "member")
    )
    if not has_permission:
        raise HTTPException(status_code=403, detail="Only the club creator or assigned organizers can delete from gallery")

    existing = _parse_gallery(club.gallery_files)
    if index < 0 or index >= len(existing):
        raise HTTPException(status_code=404, detail="Gallery item not found")

    existing.pop(index)

    try:
        club.gallery_files = _serialize_gallery(existing)
        db.commit()
    except Exception as db_err:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete club gallery image: {str(db_err)}")
        
    return {"message": "Image deleted successfully"}

@router.get("/{club_id}/feed")
def get_club_feed(club_id: int, db: Session = Depends(get_db), current_user: Optional[User] = Depends(get_optional_current_user)):
    from ..models import FeedPost, FeedLike
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    posts = db.query(FeedPost).filter(FeedPost.club_id == club_id, FeedPost.report_count < 10).order_by(FeedPost.created_at.desc()).limit(100).all()

    liked_post_ids = set()
    if current_user:
        liked_post_ids = {like.post_id for like in db.query(FeedLike).filter(FeedLike.user_id == current_user.id).all()}

    from .feed import FeedPostResponse
    result = []
    for p in posts:
        react_counts = {}
        for r in p.reactions:
            react_counts[r.emoji] = react_counts.get(r.emoji, 0) + 1

        poll_dict = None
        if p.poll:
            poll_dict = {
                "question": p.poll.question,
                "options": json.loads(p.poll.options),
                "votes": json.loads(p.poll.votes) if p.poll.votes else {}
            }

        result.append(FeedPostResponse(
            id=p.id,
            author_id=p.author_id,
            author_name=p.author.name or p.author.display_name,
            author_avatar=p.author.resolved_avatar_url,
            club_id=p.club_id,
            club_name=club.name,
            club_logo=club.logo_url,
            content=p.content,
            image_url=p.image_url,
            banner_url=p.banner_url,
            likes=p.likes,
            is_liked=(p.id in liked_post_ids),
            created_at=p.created_at,
            reactions=react_counts,
            poll=poll_dict
        ))
    return result


# ── Club Chat ─────────────────────────────────────────────────────────────────

from typing import Dict, List
import asyncio

class ClubConnectionManager:
    def __init__(self):
        # club_id -> list of websockets
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, club_id: int):
        await websocket.accept()
        if club_id not in self.active_connections:
            self.active_connections[club_id] = []
        self.active_connections[club_id].append(websocket)

    def disconnect(self, websocket: WebSocket, club_id: int):
        if club_id in self.active_connections:
            if websocket in self.active_connections[club_id]:
                self.active_connections[club_id].remove(websocket)

    async def broadcast(self, message: dict, club_id: int):
        if club_id in self.active_connections:
            for connection in self.active_connections[club_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass

manager = ClubConnectionManager()

@router.get("/{club_id}/chat")
def get_club_chat_history(club_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from ..models import ClubMessage, UserHiddenMessage
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
        
    hidden_message_ids = {h.message_id for h in db.query(UserHiddenMessage).filter(UserHiddenMessage.user_id == current_user.id).all()}
        
    messages = db.query(ClubMessage).filter(ClubMessage.club_id == club_id).order_by(ClubMessage.created_at.desc()).limit(50).all()
    
    from ..models import ClubMember
    memberships = {m.user_id: m.role for m in db.query(ClubMember).filter(ClubMember.club_id == club_id).all()}
    
    result = []
    for msg in messages:
        if msg.id in hidden_message_ids:
            continue
            
        content = "This message was deleted" if msg.is_deleted else msg.content
        attachment_url = None if msg.is_deleted else msg.attachment_url
        attachment_type = None if msg.is_deleted else msg.attachment_type
        
        result.append({
            "id": msg.id,
            "content": content,
            "attachment_url": attachment_url,
            "attachment_type": attachment_type,
            "is_edited": msg.is_edited and not msg.is_deleted,
            "is_deleted": msg.is_deleted,
            "created_at": msg.created_at.isoformat(),
            "user_id": msg.user_id,
            "user_name": msg.user.name or msg.user.display_name or "User",
            "user_avatar": msg.user.resolved_avatar_url,
            "user_role": memberships.get(msg.user_id, "member")
        })
    return result

@router.websocket("/{club_id}/chat/ws")
async def club_chat_websocket(websocket: WebSocket, club_id: int, token: str, db: Session = Depends(get_db)):
    # Very basic token validation for ws
    from ..auth import verify_access_token
    payload = verify_access_token(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    user_id_str = payload.get("sub")
    if not user_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    user_id = int(user_id_str)
    
    # check membership
    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == user_id).first()
    if not member:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    user = member.user

    await manager.connect(websocket, club_id)
    try:
        while True:
            data = await websocket.receive_text()
            
            # Save to db
            from ..models import ClubMessage
            import json
            
            content = data
            attachment_url = None
            attachment_type = None
            
            try:
                payload = json.loads(data)
                if isinstance(payload, dict):
                    content = payload.get("content", "")
                    attachment_url = payload.get("attachment_url")
                    attachment_type = payload.get("attachment_type")
            except Exception:
                pass
                
            new_msg = ClubMessage(
                club_id=club_id, 
                user_id=user_id, 
                content=content,
                attachment_url=attachment_url,
                attachment_type=attachment_type
            )
            db.add(new_msg)
            db.commit()
            db.refresh(new_msg)
            
            # Broadcast
            msg_dict = {
                "id": new_msg.id,
                "content": new_msg.content,
                "attachment_url": new_msg.attachment_url,
                "attachment_type": new_msg.attachment_type,
                "is_edited": False,
                "is_deleted": False,
                "created_at": new_msg.created_at.isoformat(),
                "user_id": user_id,
                "user_name": user.name or user.display_name or "User",
                "user_avatar": user.resolved_avatar_url,
                "user_role": member.role
            }
            
            await manager.broadcast({"action": "new", "message": msg_dict}, club_id)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket, club_id)

from pydantic import BaseModel
class EditMessagePayload(BaseModel):
    content: str

from datetime import datetime, timedelta

@router.put("/{club_id}/chat/{message_id}")
async def edit_club_message(club_id: int, message_id: int, payload: EditMessagePayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from ..models import ClubMessage, ClubMember
    msg = db.query(ClubMessage).filter(ClubMessage.id == message_id, ClubMessage.club_id == club_id).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
        
    if msg.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own messages")
        
    if msg.is_deleted:
        raise HTTPException(status_code=400, detail="Cannot edit a deleted message")
        
    # Check 5 minutes
    if datetime.utcnow() - msg.created_at > timedelta(minutes=5):
        raise HTTPException(status_code=400, detail="Messages can only be edited within 5 minutes of sending")
        
    msg.content = payload.content
    msg.is_edited = True
    db.commit()
    
    # Broadcast edit
    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    msg_dict = {
        "id": msg.id,
        "content": msg.content,
        "attachment_url": msg.attachment_url,
        "attachment_type": msg.attachment_type,
        "is_edited": msg.is_edited,
        "is_deleted": msg.is_deleted,
        "created_at": msg.created_at.isoformat(),
        "user_id": msg.user_id,
        "user_name": msg.user.name or msg.user.display_name or "User",
        "user_avatar": msg.user.resolved_avatar_url,
        "user_role": member.role if member else "member"
    }
    
    await manager.broadcast({"action": "edit", "message": msg_dict}, club_id)
    return {"message": "Message edited successfully"}

@router.delete("/{club_id}/chat/{message_id}")
async def delete_club_message(club_id: int, message_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from ..models import ClubMessage, UserHiddenMessage
    msg = db.query(ClubMessage).filter(ClubMessage.id == message_id, ClubMessage.club_id == club_id).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
        
    # Check 5 minutes for "delete for everyone"
    time_passed = datetime.utcnow() - msg.created_at
    
    if msg.user_id == current_user.id and time_passed <= timedelta(minutes=5):
        # Delete for everyone
        msg.is_deleted = True
        msg.content = ""
        msg.attachment_url = None
        msg.attachment_type = None
        db.commit()
        await manager.broadcast({"action": "delete_for_everyone", "message_id": msg.id}, club_id)
        return {"message": "Message deleted for everyone"}
    else:
        # Delete for me
        hidden = UserHiddenMessage(user_id=current_user.id, message_id=msg.id)
        db.add(hidden)
        db.commit()
        return {"message": "Message deleted for you"}

@router.post("/{club_id}/chat/upload")
async def upload_club_chat_attachment(
    club_id: int, 
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    import os
    import uuid
    from pathlib import Path
    
    # Verify membership
    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this club")

    os.makedirs(UPLOAD_DIR, exist_ok=True)

    ext = ""
    if file.filename:
        ext = os.path.splitext(file.filename)[1]
    
    filename = f"chat_{club_id}_{uuid.uuid4().hex}{ext}"
    file_path = Path(UPLOAD_DIR) / filename
    
    # Determine type
    attachment_type = "doc"
    if ext.lower() in [".jpg", ".jpeg", ".png", ".webp", ".gif"]:
        attachment_type = "image"
    elif ext.lower() == ".pdf":
        attachment_type = "pdf"
        
    with open(file_path, "wb") as f:
        f.write(await file.read())

    url = _public_upload_url(request, filename)
    return {"url": url, "type": attachment_type}
