import base64
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

router = APIRouter(prefix="/events", tags=["Events"])

_SEP = "|||---|||"
_NAME_SEP = "|||"
MAX_GALLERY_FILES = 50
MAX_EVENTS_PER_DAY = 5
ALLOWED_MIME = {"image/jpeg", "image/jpg", "image/png", "image/webp", "application/pdf"}


class EventCreate(BaseModel):
    title: str
    description: str
    venue: str
    date: str
    category: str
    image_urls: Optional[List[str]] = []
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None


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


def _parse_gallery(raw: str) -> List[dict]:
    if not raw:
        return []
    items = []
    for entry in raw.split(_SEP):
        if not entry.strip():
            continue
        parts = entry.split(_NAME_SEP, 2)
        if len(parts) == 3:
            items.append({"name": parts[0], "mime": parts[1], "data": parts[2]})
    return items


def _serialize_gallery(items: List[dict]) -> str:
    return _SEP.join(f"{item['name']}{_NAME_SEP}{item['mime']}{_NAME_SEP}{item['data']}" for item in items)


def _event_to_dict(event: models.Event, current_user_id: int | None = None) -> dict:
    raw_urls = event.image_urls or ""
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
        "registeredUsers": [str(item.user_id) for item in event.registrations],
        "image_urls": urls,
        "registration_url": event.registration_url,
        "registration_url_type": event.registration_url_type,
        "gallery_count": len(_parse_gallery(event.gallery_files or "")),
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
    try:
        parsed_date = datetime.fromisoformat(payload.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid date format")

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
        image_urls=image_urls,
        registration_url=payload.registration_url,
        registration_url_type=payload.registration_url_type,
        gallery_files=None,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return _event_to_dict(event, current_user.id)


@router.get("/")
def get_events(skip: int = 0, limit: int = 20, db: Session = Depends(get_db)):
    events = db.query(models.Event).filter(models.Event.is_approved == True).order_by(models.Event.date.asc()).offset(skip).limit(limit).all()
    return [_event_to_dict(event) for event in events]


@router.get("/{event_id}")
def get_event(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return _event_to_dict(event)


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
    if event.creator_id != current_user.id:
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
    if not registration.attended:
        registration.attended = True
        registration.attended_at = datetime.utcnow()
        db.commit()
    return {
        "message": "Attendance marked",
        "attended": registration.attended,
        "student_name": registration.user.name or registration.user.email,
    }


@router.post("/{event_id}/gallery")
async def upload_gallery(
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
    existing = _parse_gallery(event.gallery_files or "")
    if len(existing) + len(files) > MAX_GALLERY_FILES:
        raise HTTPException(status_code=400, detail=f"Max {MAX_GALLERY_FILES} gallery files allowed")
    additions = []
    for file in files:
        mime = (file.content_type or "").lower()
        if mime not in ALLOWED_MIME:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        contents = await file.read()
        if len(contents) > 15 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large. Max 15MB")
        additions.append({
            "name": file.filename or "gallery-file",
            "mime": mime,
            "data": base64.b64encode(contents).decode("utf-8"),
        })
    event.gallery_files = _serialize_gallery(existing + additions)
    db.commit()
    return {"message": f"{len(additions)} file(s) uploaded", "total": len(existing) + len(additions)}


@router.get("/{event_id}/gallery")
def get_gallery(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"event_id": event_id, "files": _parse_gallery(event.gallery_files or "")}