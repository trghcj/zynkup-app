import json
import logging
import os
import uuid
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user, get_optional_current_user
from app.gamification import add_xp
from app.fcm import send_fcm_notification, EVENT_JOINED, ATTENDANCE_MARKED

router = APIRouter(prefix="/events", tags=["Events"])
logger = logging.getLogger(__name__)

_SEP = "|||---|||"
_NAME_SEP = "|||"
UPLOAD_DIR = "uploads"
MAX_GALLERY_FILES = 50
MAX_EVENTS_PER_DAY = 5
ALLOWED_MIME = {"image/jpeg", "image/jpg", "image/png", "image/webp", "video/mp4", "video/quicktime", "video/x-msvideo"}
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".mp4", ".mov", ".avi"}
EXT_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".avi": "video/x-msvideo",
}


class EventCreate(BaseModel):
    title: str
    description: str
    venue: str
    college: Optional[str] = None
    date: str
    category: str
    image_urls: Optional[List[str]] = []
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None
    co_host_email: Optional[str] = None
    club_id: Optional[int] = None


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    venue: Optional[str] = None
    college: Optional[str] = None
    date: Optional[str] = None
    category: Optional[str] = None
    image_urls: Optional[List[str]] = None
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None
    co_host_email: Optional[str] = None


def _is_valid_image_source(value: str) -> bool:
    value = value.strip()
    return value.startswith("http://") or value.startswith("https://") or value.startswith("data:image/")


def _normalize_text_list(raw: object) -> str:
    if isinstance(raw, list):
        return ",".join(str(item).strip() for item in raw if str(item).strip())
    return str(raw or "")


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


def _format_datetime_utc(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def _extract_parentheses(text: str) -> List[str]:
    """Extracts strings inside parentheses without regex to eliminate ReDoS risk."""
    tokens: List[str] = []
    start = -1
    for i, ch in enumerate(text):
        if ch == '(':
            start = i + 1
        elif ch == ')' and start != -1:
            token = text[start:i].strip()
            if token:
                tokens.append(token)
            start = -1
    return tokens


def _colleges_match(user_college: str, ch_college: str) -> bool:
    u = (user_college or "").strip().lower()
    c = (ch_college or "").strip().lower()
    if not u or not c:
        return False
    if u == c or u in c or c in u:
        return True
    u_acros = [a.lower() for a in _extract_parentheses(user_college)]
    c_acros = [a.lower() for a in _extract_parentheses(ch_college)]
    if any(a == c or a in c or c in a for a in u_acros):
        return True
    if any(a == u or a in u or u in a for a in c_acros):
        return True
    for ua in u_acros:
        for ca in c_acros:
            if ua == ca or ua in ca or ca in ua:
                return True
    return False


def _parse_co_hosts(raw: Optional[str]) -> List[dict]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            valid = []
            for item in data:
                if isinstance(item, dict) and item.get("email"):
                    valid.append({
                        "email": str(item["email"]).strip().lower(),
                        "college": str(item.get("college") or "").strip(),
                        "name": str(item.get("name") or "").strip(),
                    })
            return valid
    except Exception:
        pass
    return []


def can_manage_event(event: models.Event, user: Optional[models.User]) -> bool:
    if not user:
        return False
    if event.creator_id == user.id or getattr(user, "role", None) == "admin":
        return True

    # Co-hosts are strictly for inter-college matchup events
    is_inter = bool(event.college and (" vs " in event.college or " × " in event.college or " x " in event.college))
    if not is_inter:
        return False

    user_email = (user.email or "").strip().lower()
    user_college = (user.college or "").strip().lower()

    if not user_email:
        return False

    # A co-host CANNOT belong to the same college as the event creator / host college
    creator_college = ""
    if event.creator and event.creator.college:
        creator_college = event.creator.college.strip()
    elif event.college:
        parts = re.split(r'\s+(?:vs|×|x)\s+', event.college, flags=re.IGNORECASE)
        if parts:
            creator_college = parts[0].strip()

    if creator_college and user_college and _colleges_match(user_college, creator_college):
        return False

    # Check multi co-hosts
    co_hosts = _parse_co_hosts(event.co_hosts)
    if not co_hosts and event.co_host_email:
        co_hosts = [{"email": event.co_host_email.strip().lower(), "college": ""}]

    for ch in co_hosts:
        ch_email = (ch.get("email") or "").strip().lower()
        ch_college = (ch.get("college") or "").strip()
        if ch_email and user_email == ch_email:
            # When college is assigned, BOTH email and college must match
            if ch_college:
                if _colleges_match(user_college, ch_college):
                    # Co-host college also cannot be creator/host college
                    if not (creator_college and _colleges_match(ch_college, creator_college)):
                        return True
            else:
                return True
    return False


def _event_to_dict(
    event: models.Event, 
    current_user_id: int | None = None,
    current_user: Optional[models.User] = None
) -> dict:
    raw_urls = _normalize_text_list(event.image_urls)
    urls = [url.strip() for url in raw_urls.split(",") if _is_valid_image_source(url.strip())]
    registration = None
    if current_user_id is not None:
        registration = next((item for item in event.registrations if item.user_id == current_user_id), None)

    is_creator = False
    is_admin = False
    can_manage = False
    is_co_host = False

    is_inter = bool(event.college and (" vs " in event.college or " × " in event.college or " x " in event.college))

    if current_user is not None:
        is_creator = (event.creator_id == current_user.id)
        is_admin = (getattr(current_user, "role", None) == "admin")
        can_manage = can_manage_event(event, current_user)
        # is_co_host is strictly for non-creator, non-admin users on inter-college events!
        is_co_host = can_manage and not is_creator and not is_admin and is_inter
    elif current_user_id is not None:
        is_creator = (event.creator_id == current_user_id)
        can_manage = is_creator
        is_co_host = False

    co_hosts = _parse_co_hosts(event.co_hosts)
    if not co_hosts and event.co_host_email:
        co_hosts = [{"email": event.co_host_email.strip().lower(), "college": ""}]

    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "venue": event.venue,
        "college": event.college,
        "date": _format_datetime_utc(event.date),
        "created_at": _format_datetime_utc(event.created_at),
        "category": event.category,
        "isApproved": event.is_approved,
        "organizerId": str(event.creator_id) if event.creator_id else "",
        "club_id": event.club_id,
        "registeredUsers": [str(item.user_id) for item in event.registrations],
        "image_urls": urls,
        "registration_url": event.registration_url,
        "registration_url_type": event.registration_url_type,
        "gallery_count": len(_parse_gallery(event.gallery_files)),
        "attendee_count": len(event.registrations),
        "is_registered": registration is not None,
        "qr_code": registration.qr_code if registration else None,
        "is_inter_college": is_inter,
        "co_host_email": event.co_host_email,
        "co_hosts": co_hosts,
        "can_manage": can_manage,
        "is_co_host": is_co_host,
        "is_admin": is_admin,
    }


@router.post("/", status_code=201)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        # Robust date parsing
        date_str = payload.date
        if date_str.endswith("Z"):
            date_str = date_str.replace("Z", "+00:00")
        parsed_date = datetime.fromisoformat(date_str)
        if parsed_date.tzinfo is not None:
            parsed_date = parsed_date.astimezone(timezone.utc).replace(tzinfo=None)
    except Exception as e:
        logger.error(f"DATE PARSE ERROR: {e} | Input: {payload.date}")
        raise HTTPException(status_code=422, detail=f"Invalid date format: {str(e)}")

    try:
        since = datetime.utcnow() - timedelta(days=1)
        created_today = db.query(models.Event).filter(
            models.Event.creator_id == current_user.id,
            models.Event.created_at >= since,
        ).count()
        if created_today >= MAX_EVENTS_PER_DAY:
            raise HTTPException(status_code=429, detail="You can create up to 5 events per day")

        image_urls = ",".join(url for url in (payload.image_urls or []) if _is_valid_image_source(url))
        co_host_email = payload.co_host_email.strip().lower() if payload.co_host_email and payload.co_host_email.strip() else None
        co_hosts = []
        if co_host_email:
            is_inter = bool(payload.college and (" vs " in payload.college or " × " in payload.college or " x " in payload.college))
            if not is_inter:
                raise HTTPException(status_code=400, detail="Co-hosts can only be assigned to inter-college matchup events.")
            target_user = db.query(models.User).filter(func.lower(models.User.email) == co_host_email).first()
            if not target_user:
                raise HTTPException(
                    status_code=404,
                    detail=f"User with email '{co_host_email}' is not registered on Zynkup. The student must sign up on Zynkup first."
                )
            if target_user.id == current_user.id:
                raise HTTPException(status_code=400, detail="Event creator cannot be added as a co-host.")
            target_college = (target_user.college or "").strip()
            creator_college = (current_user.college or "").strip()
            if creator_college and target_college and _colleges_match(target_college, creator_college):
                raise HTTPException(
                    status_code=400,
                    detail=f"Co-host must be from the partner college, not the creator's college ({creator_college})."
                )
            if payload.college:
                parts = re.split(r'\s+(?:vs|×|x)\s+', payload.college, flags=re.IGNORECASE)
                if len(parts) >= 2 and target_college and _colleges_match(target_college, parts[0]):
                    raise HTTPException(
                        status_code=400,
                        detail=f"Co-host must be from partner college ({parts[1].strip()}), not the host college."
                    )
            co_hosts.append({
                "email": co_host_email,
                "college": target_college,
                "name": (target_user.full_name or "").strip(),
            })

        event = models.Event(
            title=payload.title.strip(),
            description=payload.description.strip(),
            venue=payload.venue.strip(),
            college=payload.college.strip() if payload.college else None,
            co_host_email=co_host_email,
            co_hosts=json.dumps(co_hosts),
            date=parsed_date,
            category=payload.category.strip().lower(),
            is_approved=True,
            creator_id=current_user.id,
            club_id=payload.club_id,
            image_urls=image_urls,
            registration_url=payload.registration_url,
            registration_url_type=payload.registration_url_type,
            gallery_files=None,
        )
        db.add(event)
        db.commit()
        db.refresh(event)

        # Award XP for creating an event
        try:
            add_xp(db, current_user, "create_event")
        except Exception as xp_err:
            logger.warning(f"XP AWARD FAILED: {xp_err}")

        # Broadcast notification to club followers
        if event.club_id:
            try:
                from app.fcm import create_notification_helper
                club = db.query(models.Club).filter(models.Club.id == event.club_id).first()
                if club:
                    followers = db.query(models.ClubFollower).filter(
                        models.ClubFollower.club_id == event.club_id,
                        models.ClubFollower.user_id != current_user.id
                    ).all()
                    for f in followers:
                        create_notification_helper(
                            db=db,
                            user_id=f.user_id,
                            title=f"New Event: {event.title} 🎯",
                            body=f"{club.name} announced a new event. Tap to view & register!",
                            type="CLUB_NEW_EVENT",
                            data={"club_id": str(club.id), "event_id": str(event.id)}
                        )
            except Exception as notif_err:
                logger.warning(f"Follower notification broadcast failed: {notif_err}")

        return _event_to_dict(event, current_user.id, current_user)
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        error_msg = str(e)
        if "no such column" in error_msg.lower() or "column" in error_msg.lower():
            logger.critical(f"DATABASE OUT OF SYNC: {error_msg}")
            raise HTTPException(
                status_code=500, 
                detail="Database schema mismatch. Please run the SQL migration on Render."
            )
        logger.error(f"CRITICAL ERROR during event creation: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Server error: {error_msg}")


@router.get("/")
def get_events(skip: int = 0, limit: int = 20, db: Session = Depends(get_db)):
    events = db.query(models.Event).filter(models.Event.is_approved == True).order_by(models.Event.date.asc()).offset(skip).limit(limit).all()
    return [_event_to_dict(event) for event in events]


@router.get("/{event_id}")
def get_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return _event_to_dict(event, current_user.id if current_user else None, current_user)


@router.put("/{event_id}")
def update_event(
    event_id: int,
    payload: EventUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if not can_manage_event(event, current_user):
        raise HTTPException(status_code=403, detail="Only event organizers can edit this event")
    if payload.title is not None:
        event.title = payload.title.strip()
    if payload.description is not None:
        event.description = payload.description.strip()
    if payload.venue is not None:
        event.venue = payload.venue.strip()
    if payload.college is not None:
        event.college = payload.college.strip()
    if payload.date is not None:
        try:
            date_str = payload.date
            if date_str.endswith("Z"):
                date_str = date_str.replace("Z", "+00:00")
            parsed_dt = datetime.fromisoformat(date_str)
            if parsed_dt.tzinfo is not None:
                parsed_dt = parsed_dt.astimezone(timezone.utc).replace(tzinfo=None)
            event.date = parsed_dt
        except Exception as e:
            raise HTTPException(status_code=422, detail=f"Invalid date format: {str(e)}")
    if payload.category is not None:
        event.category = payload.category.strip().lower()
    if payload.image_urls is not None:
        event.image_urls = ",".join(url for url in payload.image_urls if _is_valid_image_source(url))
    if payload.registration_url is not None:
        event.registration_url = payload.registration_url.strip() if payload.registration_url.strip() else None
    if payload.registration_url_type is not None:
        event.registration_url_type = payload.registration_url_type.strip() if payload.registration_url_type.strip() else None
    if payload.co_host_email is not None:
        raw_email = payload.co_host_email.strip().lower() if payload.co_host_email.strip() else None
        if raw_email:
            effective_college = payload.college if payload.college is not None else event.college
            is_inter = bool(effective_college and (" vs " in effective_college or " × " in effective_college or " x " in effective_college))
            if not is_inter:
                raise HTTPException(status_code=400, detail="Co-hosts can only be assigned to inter-college matchup events.")
            target_user = db.query(models.User).filter(func.lower(models.User.email) == raw_email).first()
            if not target_user:
                raise HTTPException(
                    status_code=404,
                    detail=f"User with email '{raw_email}' is not registered on Zynkup. The student must sign up on Zynkup first."
                )
            if target_user.id == event.creator_id:
                raise HTTPException(status_code=400, detail="Event creator cannot be added as a co-host.")
            target_college = (target_user.college or "").strip()
            creator_college = (event.creator.college or "").strip() if event.creator else ""
            if creator_college and target_college and _colleges_match(target_college, creator_college):
                raise HTTPException(
                    status_code=400,
                    detail=f"Co-host must be from the partner college, not the creator's college ({creator_college})."
                )
            if effective_college:
                parts = re.split(r'\s+(?:vs|×|x)\s+', effective_college, flags=re.IGNORECASE)
                if len(parts) >= 2 and target_college and _colleges_match(target_college, parts[0]):
                    raise HTTPException(
                        status_code=400,
                        detail=f"Co-host must be from partner college ({parts[1].strip()}), not the host college."
                    )
            event.co_host_email = raw_email
            existing_chs = _parse_co_hosts(event.co_hosts)
            if not any(ch["email"] == raw_email for ch in existing_chs):
                existing_chs.append({
                    "email": raw_email,
                    "college": target_college,
                    "name": (target_user.full_name or "").strip(),
                })
                event.co_hosts = json.dumps(existing_chs)
        else:
            event.co_host_email = None
    db.commit()
    db.refresh(event)
    return _event_to_dict(event, current_user.id, current_user)


@router.delete("/{event_id}")
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the creator can delete this event")
    db.delete(event)
    db.commit()
    return {"message": "Event deleted"}


@router.post("/{event_id}/register")
def register_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    existing = db.query(models.Registration).filter(
        models.Registration.user_id == current_user.id,
        models.Registration.event_id == event_id,
    ).first()
    if existing:
        return {"message": "Already registered", "qr_code": existing.qr_code}
    registration = models.Registration(user_id=current_user.id, event_id=event_id)
    db.add(registration)
    db.commit()
    db.refresh(registration)

    # Award XP for registering
    add_xp(db, current_user, "register_event")

    from app.fcm import create_notification_helper, EVENT_JOINED
    create_notification_helper(
        db=db,
        user_id=current_user.id,
        title="Event Registered",
        body=f"You successfully registered for {event.title}.",
        type=EVENT_JOINED,
        data={"event_id": str(event_id)}
    )

    return {"message": "Registered successfully", "qr_code": registration.qr_code}


@router.post("/attendance/{qr_code}")
def mark_attendance(
    qr_code: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    registration = db.query(models.Registration).filter(models.Registration.qr_code == qr_code).first()
    if not registration:
        raise HTTPException(status_code=404, detail="QR pass not found")
    if not can_manage_event(registration.event, current_user):
        raise HTTPException(status_code=403, detail="Only event organizers can scan this QR")
    if not registration.attended:
        registration.attended = True
        registration.attended_at = datetime.utcnow()
        db.commit()
        
        # Award XP to the ATTEENDEE (registration.user)
        add_xp(db, registration.user, "attend_event")

        from app.fcm import create_notification_helper, ATTENDANCE_MARKED
        create_notification_helper(
            db=db,
            user_id=registration.user_id,
            title="Attendance Marked",
            body=f"You have been marked present for {registration.event.title}!",
            type=ATTENDANCE_MARKED,
            data={"event_id": str(registration.event_id)}
        )

    return {
        "message": "Attendance marked",
        "attended": registration.attended,
        "student_name": registration.user.name or registration.user.email,
    }


@router.post("/{event_id}/gallery")
async def upload_gallery(
    request: Request,
    event_id: int,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if not can_manage_event(event, current_user):
        raise HTTPException(status_code=403, detail="Only event organizers can upload gallery files")
    existing = _parse_gallery(event.gallery_files)
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
        event.gallery_files = _serialize_gallery(existing + additions)
        db.commit()
    except Exception as db_err:
        db.rollback()
        logger.error(f"GALLERY DB SAVE ERROR: {db_err}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to save gallery: {str(db_err)}")
        
    return {
        "message": f"{len(additions)} file(s) uploaded",
        "files": additions,
        "total": len(existing) + len(additions),
    }


@router.delete("/{event_id}/gallery/{index}")
def delete_gallery_file(
    event_id: int,
    index: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if not can_manage_event(event, current_user):
        raise HTTPException(status_code=403, detail="Only event organizers can delete gallery files")
    
    files = _parse_gallery(event.gallery_files)
    if index < 0 or index >= len(files):
        raise HTTPException(status_code=404, detail="File index out of range")
        
    del files[index]
    
    try:
        event.gallery_files = _serialize_gallery(files)
        db.commit()
    except Exception as db_err:
        db.rollback()
        logger.error(f"GALLERY DB SAVE ERROR: {db_err}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to save gallery: {str(db_err)}")
        
    return {"message": "File deleted successfully"}


@router.get("/{event_id}/gallery")
def get_gallery(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"event_id": event_id, "files": _parse_gallery(event.gallery_files)}

@router.get("/{event_id}/participants")
def get_event_participants(
    event_id: int, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
        
    if not can_manage_event(event, current_user):
        raise HTTPException(status_code=403, detail="Not authorized to view participants")
        
    registrations = db.query(models.Registration).filter(models.Registration.event_id == event_id).all()
    
    participants = []
    for r in registrations:
        u = r.user
        participants.append({
            "id": u.id,
            "name": u.name or u.display_name or "Unknown",
            "email": u.email,
            "avatar_url": u.resolved_avatar_url,
            "attended": r.attended,
            "registered_at": _format_datetime_utc(r.created_at),
            "attended_at": _format_datetime_utc(r.attended_at)
        })
        
    return participants


class CoHostPayload(BaseModel):
    email: str
    college: str


@router.post("/{event_id}/co-hosts")
def add_co_host(
    event_id: int,
    payload: CoHostPayload,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id != current_user.id and getattr(current_user, "role", None) != "admin":
        raise HTTPException(status_code=403, detail="Only the event creator can assign co-hosts")

    # Co-hosts can ONLY be assigned to inter-college matchup events!
    is_inter = bool(event.college and (" vs " in event.college or " × " in event.college or " x " in event.college))
    if not is_inter:
        raise HTTPException(
            status_code=400,
            detail="Co-hosts can only be assigned to inter-college matchup events."
        )

    email = payload.email.strip().lower()
    if not email or "@" not in email or "." not in email:
        raise HTTPException(status_code=422, detail="Please enter a valid email address")

    college = payload.college.strip()
    if not college:
        raise HTTPException(status_code=422, detail="College name is required for co-host access")

    # 1. Lookup user in Zynkup registered users table
    target_user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not target_user:
        raise HTTPException(
            status_code=404,
            detail=f"User with email '{email}' is not registered on Zynkup. The student must sign up on Zynkup first."
        )

    # 2. Cannot add yourself as co-host
    if target_user.id == event.creator_id:
        raise HTTPException(status_code=400, detail="Event creator cannot be added as a co-host.")

    # 3. Check registered college in user's profile
    target_college = (target_user.college or "").strip()
    if not target_college:
        student_name = target_user.full_name or email
        raise HTTPException(
            status_code=400,
            detail=f"Student '{student_name}' has not set their college in their Zynkup profile yet."
        )

    if not _colleges_match(target_college, college):
        raise HTTPException(
            status_code=400,
            detail=f"User is registered under '{target_college}', which does not match '{college}'."
        )

    # 4. Co-host CANNOT be from the creator's / host college!
    creator_college = ""
    if event.creator and event.creator.college:
        creator_college = event.creator.college.strip()
    elif event.college:
        parts = re.split(r'\s+(?:vs|×|x)\s+', event.college, flags=re.IGNORECASE)
        if parts:
            creator_college = parts[0].strip()

    if creator_college and _colleges_match(target_college, creator_college):
        raise HTTPException(
            status_code=400,
            detail=f"Co-host must be from the partner college, not the creator's college ({creator_college})."
        )

    if event.college:
        parts = re.split(r'\s+(?:vs|×|x)\s+', event.college, flags=re.IGNORECASE)
        if len(parts) >= 2 and _colleges_match(target_college, parts[0]):
            raise HTTPException(
                status_code=400,
                detail=f"Co-host must be from partner college ({parts[1].strip()}), not the host college."
            )

    co_hosts = _parse_co_hosts(event.co_hosts)
    if not co_hosts and event.co_host_email:
        co_hosts = [{"email": event.co_host_email.strip().lower(), "college": target_college, "name": target_user.full_name or ""}]

    if len(co_hosts) >= 4 and not any(ch["email"] == email for ch in co_hosts):
        raise HTTPException(status_code=400, detail="Maximum 4 co-hosts allowed per event")

    for ch in co_hosts:
        if ch["email"] == email:
            ch["college"] = target_college
            ch["name"] = target_user.full_name or ""
            break
    else:
        co_hosts.append({
            "email": email,
            "college": target_college,
            "name": target_user.full_name or "",
        })

    event.co_hosts = json.dumps(co_hosts)
    event.co_host_email = co_hosts[0]["email"] if co_hosts else None
    db.commit()
    db.refresh(event)
    return {"co_hosts": co_hosts, "event": _event_to_dict(event, current_user.id, current_user)}


@router.delete("/{event_id}/co-hosts")
def remove_co_host(
    event_id: int,
    email: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id != current_user.id and getattr(current_user, "role", None) != "admin":
        raise HTTPException(status_code=403, detail="Only the event creator can remove co-hosts")

    target_email = email.strip().lower()
    co_hosts = [ch for ch in _parse_co_hosts(event.co_hosts) if ch["email"] != target_email]
    event.co_hosts = json.dumps(co_hosts)
    event.co_host_email = co_hosts[0]["email"] if co_hosts else None
    db.commit()
    db.refresh(event)
    return {"co_hosts": co_hosts, "event": _event_to_dict(event, current_user.id, current_user)}
