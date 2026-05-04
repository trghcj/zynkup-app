# app/routes/events.py
import base64
import logging
import uuid
from datetime import datetime, date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user, get_optional_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/events", tags=["Events"])

_SEP      = "|||---|||"
_NAME_SEP = "|||"
MAX_GALLERY = 50
MAX_EVENTS_PER_DAY = 5


# ── Serializer ────────────────────────────────────────────────────────────────

def _parse_gallery(raw: str) -> List[dict]:
    if not raw: return []
    items = []
    for entry in raw.split(_SEP):
        if not entry.strip(): continue
        parts = entry.split(_NAME_SEP, 2)
        if len(parts) == 3:
            items.append({"name": parts[0], "mime": parts[1], "data": parts[2]})
    return items


def _serialize_gallery(items: List[dict]) -> str:
    return _SEP.join(
        f"{i['name']}{_NAME_SEP}{i['mime']}{_NAME_SEP}{i['data']}" for i in items)


def _event_to_dict(event: models.Event, viewer_id: Optional[int] = None) -> dict:
    urls = [u.strip() for u in (event.image_urls or "").split(",") if u.strip()]
    registered_ids = [r.user_id for r in event.registrations]
    gallery = _parse_gallery(event.gallery_files or "")

    # Check if viewer is registered
    viewer_registered = viewer_id in registered_ids if viewer_id else False
    viewer_qr = None
    if viewer_id and viewer_registered:
        reg = next((r for r in event.registrations if r.user_id == viewer_id), None)
        if reg:
            viewer_qr = reg.qr_code

    is_past = event.date < datetime.now() if event.date else False

    return {
        "id":               event.id,
        "title":            event.title,
        "description":      event.description,
        "venue":            event.venue,
        "date":             event.date.isoformat() if event.date else None,
        "category":         event.category,
        "isApproved":       event.is_approved,
        "creatorId":        event.creator_id,
        "creator_name":     event.creator.name if event.creator else None,
        "registeredCount":  len(registered_ids),
        "image_urls":       urls,
        "registration_url": event.registration_url,
        "registration_url_type": event.registration_url_type,
        "gallery":          gallery,
        "gallery_count":    len(gallery),
        "is_past":          is_past,
        "is_reported":      event.is_reported,
        # Viewer-specific
        "viewer_registered": viewer_registered,
        "viewer_qr":        viewer_qr,
    }


# ── Schemas ───────────────────────────────────────────────────────────────────

class EventCreate(BaseModel):
    title:                 str
    description:           str
    venue:                 str
    date:                  str
    category:              str
    image_urls:            Optional[List[str]] = []
    registration_url:      Optional[str] = None
    registration_url_type: Optional[str] = None


class EventUpdate(BaseModel):
    title:                 Optional[str] = None
    description:           Optional[str] = None
    venue:                 Optional[str] = None
    date:                  Optional[str] = None
    category:              Optional[str] = None
    image_urls:            Optional[List[str]] = None
    registration_url:      Optional[str] = None
    registration_url_type: Optional[str] = None


# ── List events (guests can view) ─────────────────────────────────────────────

@router.get("/")
def get_events(
    skip:     int = 0,
    limit:    int = 20,
    category: Optional[str] = None,
    search:   Optional[str] = None,
    filter:   Optional[str] = None,  # upcoming | past | today | trending
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
):
    query = db.query(models.Event).filter(
        models.Event.is_approved == True,
        models.Event.is_reported == False,
    )

    if category:
        query = query.filter(models.Event.category == category)

    if search:
        query = query.filter(
            models.Event.title.ilike(f"%{search}%") |
            models.Event.description.ilike(f"%{search}%") |
            models.Event.venue.ilike(f"%{search}%")
        )

    now = datetime.now()
    today_start = datetime(now.year, now.month, now.day)
    today_end   = datetime(now.year, now.month, now.day, 23, 59, 59)

    if filter == "upcoming":
        query = query.filter(models.Event.date > now)
    elif filter == "past":
        query = query.filter(models.Event.date < now)
    elif filter == "today":
        query = query.filter(models.Event.date.between(today_start, today_end))
    elif filter == "trending":
        # Most registrations in last 7 days
        from sqlalchemy import func
        query = query.outerjoin(models.Registration).group_by(
            models.Event.id).order_by(func.count(models.Registration.id).desc())

    query = query.order_by(models.Event.date.desc())
    events = query.offset(skip).limit(limit).all()

    viewer_id = current_user.id if current_user else None
    return [_event_to_dict(e, viewer_id) for e in events]


# ── Featured events (for home screen hero) ────────────────────────────────────

@router.get("/featured")
def get_featured(db: Session = Depends(get_db)):
    """Returns upcoming events with images — used for home screen banners."""
    from sqlalchemy import func
    events = (
        db.query(models.Event)
        .filter(
            models.Event.is_approved == True,
            models.Event.is_reported == False,
            models.Event.date > datetime.now(),
        )
        .order_by(models.Event.date.asc())
        .limit(5)
        .all()
    )
    return [_event_to_dict(e) for e in events]


# ── Get single event ──────────────────────────────────────────────────────────

@router.get("/{event_id}")
def get_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    viewer_id = current_user.id if current_user else None
    return _event_to_dict(event, viewer_id)


# ── Create event (auto-approved) ──────────────────────────────────────────────

@router.post("/", status_code=201)
def create_event(
    event: EventCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Spam control: max 5 events per day per user
    today_start = datetime.combine(date.today(), datetime.min.time())
    today_count = db.query(models.Event).filter(
        models.Event.creator_id == current_user.id,
        models.Event.created_at >= today_start,
    ).count()

    if today_count >= MAX_EVENTS_PER_DAY:
        raise HTTPException(
            status_code=429,
            detail=f"Maximum {MAX_EVENTS_PER_DAY} events per day reached. Try again tomorrow."
        )

    try:
        parsed_date = datetime.fromisoformat(event.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid date format")

    new_event = models.Event(
        title                 = event.title,
        description           = event.description,
        venue                 = event.venue,
        date                  = parsed_date,
        category              = event.category,
        is_approved           = True,   # ✅ Auto-approved
        creator_id            = current_user.id,
        image_urls            = ",".join(event.image_urls) if event.image_urls else "",
        registration_url      = event.registration_url,
        registration_url_type = event.registration_url_type,
        gallery_files         = "",
    )
    db.add(new_event)
    db.commit()
    db.refresh(new_event)
    logger.info(f"Event created: id={new_event.id} by user={current_user.id}")
    return _event_to_dict(new_event, current_user.id)


# ── Update event (creator only) ───────────────────────────────────────────────

@router.put("/{event_id}")
def update_event(
    event_id: int,
    payload:  EventUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not your event")

    if payload.title       is not None: event.title       = payload.title
    if payload.description is not None: event.description = payload.description
    if payload.venue       is not None: event.venue       = payload.venue
    if payload.category    is not None: event.category    = payload.category
    if payload.date        is not None:
        event.date = datetime.fromisoformat(payload.date)
    if payload.image_urls  is not None:
        event.image_urls = ",".join(payload.image_urls)
    if payload.registration_url is not None:
        event.registration_url = payload.registration_url
    if payload.registration_url_type is not None:
        event.registration_url_type = payload.registration_url_type

    db.commit()
    db.refresh(event)
    return _event_to_dict(event, current_user.id)


# ── Delete event (creator or admin) ──────────────────────────────────────────

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
        raise HTTPException(status_code=403, detail="Not your event")
    db.delete(event)
    db.commit()
    return {"message": "Event deleted"}


# ── Register for event ────────────────────────────────────────────────────────

@router.post("/{event_id}/register")
def register_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.date < datetime.now():
        raise HTTPException(status_code=400, detail="This event has already ended")

    existing = db.query(models.Registration).filter(
        models.Registration.user_id  == current_user.id,
        models.Registration.event_id == event_id,
    ).first()
    if existing:
        # Return existing QR instead of error
        return {
            "message":  "Already registered",
            "qr_code":  existing.qr_code,
            "attended": existing.attended,
        }

    qr = str(uuid.uuid4())
    reg = models.Registration(
        user_id  = current_user.id,
        event_id = event_id,
        qr_code  = qr,
    )
    db.add(reg)
    db.commit()
    logger.info(f"User {current_user.id} registered for event {event_id}, QR={qr}")
    return {"message": "Registered! 🎉", "qr_code": qr, "attended": False}


# ── Mark attendance via QR scan ───────────────────────────────────────────────

@router.post("/attend/{qr_code}")
def mark_attendance(
    qr_code: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Event creator scans attendee QR to mark attendance."""
    reg = db.query(models.Registration).filter(
        models.Registration.qr_code == qr_code
    ).first()
    if not reg:
        raise HTTPException(status_code=404, detail="Invalid QR code")

    # Only event creator or admin can mark attendance
    if reg.event.creator_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the event creator can mark attendance")

    if reg.attended:
        return {
            "message":  "Already marked as attended",
            "attended": True,
            "user_name": reg.user.name or reg.user.email,
        }

    reg.attended    = True
    reg.attended_at = datetime.now()
    db.commit()

    return {
        "message":   "Attendance marked ✅",
        "attended":  True,
        "user_name": reg.user.name or reg.user.email,
        "event":     reg.event.title,
    }


# ── Report event ──────────────────────────────────────────────────────────────

@router.post("/{event_id}/report")
def report_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot report your own event")

    event.report_count += 1
    # Auto-hide if reported 5+ times
    if event.report_count >= 5:
        event.is_reported = True
    db.commit()
    return {"message": "Event reported. Thank you for keeping Zynkup safe 🛡️"}


# ── Gallery upload (event creator, after event ends) ──────────────────────────

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
    if event.creator_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the event creator can upload gallery")

    existing = _parse_gallery(event.gallery_files or "")
    if len(existing) + len(files) > MAX_GALLERY:
        raise HTTPException(status_code=400,
            detail=f"Max {MAX_GALLERY} files. Currently {len(existing)}.")

    new_items = []
    for f in files:
        ext  = (f.filename or "").split(".")[-1].lower()
        mime = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                "png": "image/png",  "pdf": "application/pdf"}.get(ext, "image/jpeg")
        contents = await f.read()
        if len(contents) > 15 * 1024 * 1024:
            raise HTTPException(status_code=400, detail=f"'{f.filename}' > 15MB")
        new_items.append({
            "name": f.filename or f"file_{len(existing)+len(new_items)+1}",
            "mime": mime,
            "data": base64.b64encode(contents).decode("utf-8"),
        })

    all_items = existing + new_items
    event.gallery_files = _serialize_gallery(all_items)
    db.commit()
    return {"message": f"{len(new_items)} files added", "total": len(all_items)}


@router.get("/{event_id}/gallery")
def get_gallery(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    files = _parse_gallery(event.gallery_files or "")
    return {"event_id": event_id, "files": files, "total": len(files)}


@router.delete("/{event_id}/gallery/{index}")
def delete_gallery_file(
    event_id: int, index: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.creator_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not your event")
    items = _parse_gallery(event.gallery_files or "")
    if index < 0 or index >= len(items):
        raise HTTPException(status_code=404, detail="File not found")
    items.pop(index)
    event.gallery_files = _serialize_gallery(items)
    db.commit()
    return {"message": "Deleted", "remaining": len(items)}