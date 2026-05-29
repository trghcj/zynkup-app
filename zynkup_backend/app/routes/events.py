import json
import logging
import os
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request
from pydantic import BaseModel
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
ALLOWED_MIME = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp"}
EXT_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


class EventCreate(BaseModel):
    title: str
    description: str
    venue: str
    date: str
    category: str
    image_urls: Optional[List[str]] = []
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None
    club_id: Optional[int] = None


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    venue: Optional[str] = None
    date: Optional[str] = None
    category: Optional[str] = None
    image_urls: Optional[List[str]] = None


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


def _event_to_dict(event: models.Event, current_user_id: int | None = None) -> dict:
    raw_urls = _normalize_text_list(event.image_urls)
    urls = [url.strip() for url in raw_urls.split(",") if _is_valid_image_source(url.strip())]
    registration = None
    if current_user_id is not None:
        registration = next((item for item in event.registrations if item.user_id == current_user_id), None)
    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "venue": event.venue,
        "date": event.date.isoformat() if event.date else None,
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
    }


@router.post("/", status_code=201)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role not in ("ROLE_ORGANIZER", "ROLE_ADMIN", "organizer", "admin"):
        raise HTTPException(status_code=403, detail="Only organizers or admins can create events")
    try:
        # Robust date parsing
        date_str = payload.date
        if date_str.endswith("Z"):
            date_str = date_str.replace("Z", "+00:00")
        parsed_date = datetime.fromisoformat(date_str)
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
        event = models.Event(
            title=payload.title.strip(),
            description=payload.description.strip(),
            venue=payload.venue.strip(),
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

        return _event_to_dict(event, current_user.id)
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
    return _event_to_dict(event, current_user.id if current_user else None)


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
    if event.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the creator can edit this event")
    if payload.title is not None:
        event.title = payload.title.strip()
    if payload.description is not None:
        event.description = payload.description.strip()
    if payload.venue is not None:
        event.venue = payload.venue.strip()
    if payload.date is not None:
        event.date = datetime.fromisoformat(payload.date)
    if payload.category is not None:
        event.category = payload.category.strip().lower()
    if payload.image_urls is not None:
        event.image_urls = ",".join(url for url in payload.image_urls if _is_valid_image_source(url))
    db.commit()
    db.refresh(event)
    return _event_to_dict(event, current_user.id)


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
    if registration.event.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the event creator can scan this QR")
    if current_user.role not in ("ROLE_ORGANIZER", "ROLE_ADMIN", "organizer", "admin"):
        raise HTTPException(status_code=403, detail="Only organizers or admins can scan QR passes")
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
    if event.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the event creator can upload gallery files")
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


@router.get("/{event_id}/gallery")
def get_gallery(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"event_id": event_id, "files": _parse_gallery(event.gallery_files)}
