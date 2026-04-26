import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/events", tags=["Events"])


# ── Schemas (inline — move to schemas.py if you prefer) ───────────────────────

class EventCreate(BaseModel):
    title: str
    description: str
    venue: str
    date: str                          # ISO string from Flutter
    category: str
    image_urls: Optional[List[str]] = []
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None   # "googleForm" | "customUrl"


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    venue: Optional[str] = None
    date: Optional[str] = None
    category: Optional[str] = None
    image_urls: Optional[List[str]] = None
    registration_url: Optional[str] = None
    registration_url_type: Optional[str] = None


def _event_to_dict(event: models.Event) -> dict:
    """Serialize Event model → dict Flutter expects."""
    # image_urls stored as comma-separated string in DB
    raw_urls = event.image_urls or ""
    urls = [u.strip() for u in raw_urls.split(",") if u.strip()]

    # registered users count list
    registered = [str(r.user_id) for r in event.registrations]

    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "venue": event.venue,
        "date": event.date.isoformat() if event.date else None,
        "category": event.category,
        "isApproved": event.is_approved,
        "organizerId": str(event.organizer_id) if event.organizer_id else "",
        "registeredUsers": registered,
        "image_urls": urls,
        "registration_url": event.registration_url,
        "registration_url_type": event.registration_url_type,
        "approvedAt": None,
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

    # Store image_urls as comma-separated string
    image_urls_str = ",".join(event.image_urls) if event.image_urls else ""

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
    )
    db.add(new_event)
    db.commit()
    db.refresh(new_event)

    logger.info(f"Event created: id={new_event.id} by user={current_user.id}")
    return _event_to_dict(new_event)


# ── List approved events ──────────────────────────────────────────────────────

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

    if payload.title is not None:
        event.title = payload.title
    if payload.description is not None:
        event.description = payload.description
    if payload.venue is not None:
        event.venue = payload.venue
    if payload.date is not None:
        from datetime import datetime
        event.date = datetime.fromisoformat(payload.date)
    if payload.category is not None:
        event.category = payload.category
    if payload.image_urls is not None:
        event.image_urls = ",".join(payload.image_urls)
    if payload.registration_url is not None:
        event.registration_url = payload.registration_url
    if payload.registration_url_type is not None:
        event.registration_url_type = payload.registration_url_type

    db.commit()
    db.refresh(event)
    return _event_to_dict(event)


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
    logger.info(f"Event {event_id} approved by admin {current_user.id}")
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
    logger.info(f"Event {event_id} deleted by user {current_user.id}")
    return {"message": "Event deleted"}


# ── Register for an event ─────────────────────────────────────────────────────

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
        raise HTTPException(status_code=400, detail="Event is not approved yet")

    existing = db.query(models.Registration).filter(
        models.Registration.user_id == current_user.id,
        models.Registration.event_id == event_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already registered")

    registration = models.Registration(
        user_id=current_user.id,
        event_id=event_id,
    )
    db.add(registration)
    db.commit()

    logger.info(f"User {current_user.id} registered for event {event_id}")
    return {"message": "Registered successfully"}