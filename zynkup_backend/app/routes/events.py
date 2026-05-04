import base64
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/events", tags=["Events"])

# ── Schemas ───────────────────────────────────────────────────────────────────

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
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None


# ── Gallery file separator ────────────────────────────────────────────────────
_SEP = "|||---|||"
_NAME_SEP = "|||"
MAX_GALLERY_FILES = 50
ALLOWED_MIME = {
    "image/jpeg", "image/jpg", "image/png", "application/pdf"
}


def _is_valid_url(s: str) -> bool:
    """Returns True only if the string is a real URL, not a base64 blob."""
    s = s.strip()
    return s.startswith("http://") or s.startswith("https://")


def _parse_gallery(raw: str) -> List[dict]:
    """Parse stored gallery string into list of {name, data, mime}"""
    if not raw or raw.strip() in ("", "{}"):
        return []
    items = []
    for entry in raw.split(_SEP):
        if not entry.strip():
            continue
        parts = entry.split(_NAME_SEP, 2)
        if len(parts) == 3:
            items.append({
                "name": parts[0],
                "mime": parts[1],
                "data": parts[2],
            })
    return items


def _serialize_gallery(items: List[dict]) -> str:
    return _SEP.join(
        f"{i['name']}{_NAME_SEP}{i['mime']}{_NAME_SEP}{i['data']}"
        for i in items
    )


def _event_to_dict(event: models.Event) -> dict:
    raw_urls = event.image_urls or ""
    # Only keep real URLs — never return base64 blobs
    urls = [u.strip() for u in raw_urls.split(",") if _is_valid_url(u.strip())]
    registered = [str(r.user_id) for r in event.registrations]
    gallery = _parse_gallery(event.gallery_files or "")

    return {
        "id":                    event.id,
        "title":                 event.title,
        "description":           event.description,
        "venue":                 event.venue,
        "date":                  event.date.isoformat() if event.date else None,
        "category":              event.category,
        "isApproved":            event.is_approved,
        "organizerId":           str(event.organizer_id) if event.organizer_id else "",
        "registeredUsers":       registered,
        "image_urls":            urls,
        "registration_url":      event.registration_url,
        "registration_url_type": event.registration_url_type,
        "approvedAt":            None,
        "gallery":               gallery,
        "gallery_count":         len(gallery),
    }


# ── Create event ──────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
def create_event(
    event: EventCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    from datetime import datetime
    try:
        parsed_date = datetime.fromisoformat(event.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid date format")

    # Only store real URLs — reject base64 blobs silently
    valid_urls = [u for u in (event.image_urls or []) if _is_valid_url(u)]
    image_urls_str = ",".join(valid_urls)

    new_event = models.Event(
        title=event.title,
        description=event.description,
        venue=event.venue,
        date=parsed_date,
        category=event.category,
        is_approved=False,
        organizer_id=current_user.id,
        image_urls=image_urls_str,
        registration_url=event.registration_url,
        registration_url_type=event.registration_url_type,
        gallery_files=None,   # FIX: use None instead of "" to avoid PostgreSQL array type conflict
    )
    db.add(new_event)
    db.commit()
    db.refresh(new_event)
    logger.info(f"Event created: id={new_event.id} by user={current_user.id}")
    return _event_to_dict(new_event)


# ── List events ───────────────────────────────────────────────────────────────

@router.get("/")
def get_events(
    skip: int = 0,
    limit: int = 20,
    approved: Optional[bool] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Event)
    if approved is not None:
        query = query.filter(models.Event.is_approved == approved)
    else:
        query = query.filter(models.Event.is_approved == True)
    events = query.offset(skip).limit(limit).all()
    return [_event_to_dict(e) for e in events]


# ── Get single event ──────────────────────────────────────────────────────────

@router.get("/{event_id}")
def get_event(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return _event_to_dict(event)


# ── Update event ──────────────────────────────────────────────────────────────

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

    if payload.title is not None:        event.title = payload.title
    if payload.description is not None:  event.description = payload.description
    if payload.venue is not None:        event.venue = payload.venue
    if payload.date is not None:
        from datetime import datetime
        event.date = datetime.fromisoformat(payload.date)
    if payload.category is not None:     event.category = payload.category
    if payload.image_urls is not None:
        valid_urls = [u for u in payload.image_urls if _is_valid_url(u)]
        event.image_urls = ",".join(valid_urls)
    if payload.registration_url is not None:
        event.registration_url = payload.registration_url
    if payload.registration_url_type is not None:
        event.registration_url_type = payload.registration_url_type

    db.commit()
    db.refresh(event)
    return _event_to_dict(event)


# ── Upload gallery files (admin only, after event ends) ───────────────────────

@router.post("/{event_id}/gallery")
async def upload_gallery(
    event_id: int,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin uploads post-event gallery (JPEG, PNG, PDF). Max 50 files."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admins only")

    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    existing = _parse_gallery(event.gallery_files or "")

    if len(existing) + len(files) > MAX_GALLERY_FILES:
        raise HTTPException(
            status_code=400,
            detail=f"Max {MAX_GALLERY_FILES} gallery files allowed. "
                   f"Currently have {len(existing)}, trying to add {len(files)}."
        )

    new_items = []
    for f in files:
        mime = (f.content_type or "").lower()
        ext  = (f.filename or "").split(".")[-1].lower()

        valid_exts  = {"jpg", "jpeg", "png", "pdf"}
        valid_mimes = ALLOWED_MIME

        if mime not in valid_mimes and ext not in valid_exts:
            raise HTTPException(
                status_code=400,
                detail=f"'{f.filename}' is not allowed. Use JPEG, PNG, or PDF."
            )

        contents = await f.read()
        if len(contents) > 15 * 1024 * 1024:
            raise HTTPException(
                status_code=400,
                detail=f"'{f.filename}' exceeds 15MB limit."
            )

        b64 = base64.b64encode(contents).decode("utf-8")
        if ext == "pdf" or mime == "application/pdf":
            final_mime = "application/pdf"
        elif ext == "png" or mime == "image/png":
            final_mime = "image/png"
        else:
            final_mime = "image/jpeg"

        new_items.append({
            "name": f.filename or f"file_{len(existing)+len(new_items)+1}",
            "mime": final_mime,
            "data": b64,
        })

    all_items = existing + new_items
    event.gallery_files = _serialize_gallery(all_items)
    db.commit()

    logger.info(f"Gallery: {len(new_items)} files added to event {event_id} by admin {current_user.id}")
    return {
        "message": f"{len(new_items)} file(s) added to gallery",
        "total":   len(all_items),
    }


# ── Delete gallery file ───────────────────────────────────────────────────────

@router.delete("/{event_id}/gallery/{file_index}")
def delete_gallery_file(
    event_id: int,
    file_index: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admins only")

    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    items = _parse_gallery(event.gallery_files or "")
    if file_index < 0 or file_index >= len(items):
        raise HTTPException(status_code=404, detail="File not found")

    items.pop(file_index)
    event.gallery_files = _serialize_gallery(items) if items else None
    db.commit()
    return {"message": "File deleted", "remaining": len(items)}


# ── Get gallery ───────────────────────────────────────────────────────────────

@router.get("/{event_id}/gallery")
def get_gallery(event_id: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    files = _parse_gallery(event.gallery_files or "")
    return {
        "event_id": event_id,
        "files":    files,
        "total":    len(files),
    }


# ── Approve event ─────────────────────────────────────────────────────────────

@router.put("/{event_id}/approve")
def approve_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admins only")
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_approved = True
    db.commit()
    db.refresh(event)
    return _event_to_dict(event)


# ── Delete event ──────────────────────────────────────────────────────────────

@router.delete("/{event_id}")
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
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
    if not event.is_approved:
        raise HTTPException(status_code=400, detail="Event not approved yet")

    existing = db.query(models.Registration).filter(
        models.Registration.user_id == current_user.id,
        models.Registration.event_id == event_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already registered")

    db.add(models.Registration(user_id=current_user.id, event_id=event_id))
    db.commit()
    return {"message": "Registered successfully"}