import json
import logging
import os
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import Club, ClubMember, User, Event
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
    db.commit()

    return ClubResponse(
        id=new_club.id,
        name=new_club.name,
        description=new_club.description,
        category=new_club.category,
        banner_url=new_club.banner_url,
        logo_url=new_club.logo_url,
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
        member_count=count,
        created_at=club.created_at,
        is_member=is_member,
        creator_id=club.creator_id
    )

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
            avatar_url=m.user.avatar_url,
            role=role_str,
            joined_at=m.joined_at
        ))
    return result

@router.put("/{club_id}/members/{user_id}/role")
def update_member_role(club_id: int, user_id: int, payload: MemberRoleUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
        
    if club.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the club creator can update member roles")
        
    member = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == user_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Club member not found")
        
    if member.user_id == club.creator_id:
        raise HTTPException(status_code=400, detail="Cannot change creator's role")
        
    member.role = payload.role.strip()
    db.commit()
    return {"message": f"Updated role to {member.role}"}

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
