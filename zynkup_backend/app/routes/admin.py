import logging
import os
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin"])

# ── Secret key for first-time admin setup ─────────────────────────────────────

ADMIN_SETUP_KEY = os.getenv("ADMIN_SETUP_KEY", "")


def admin_only(current_user: models.User = Depends(get_current_user)) -> models.User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


# ── One-time admin setup — no auth needed, protected by secret key ────────────
@router.post("/setup")
def setup_first_admin(
    email: str,
    setup_key: str,
    db: Session = Depends(get_db),
):
    """
    Promote a user to admin using a secret key.
    Set ADMIN_SETUP_KEY environment variable on Render.
    Call: POST /admin/setup?email=you@email.com&setup_key=YOUR_SECRET
    Can be called anytime to promote any user — protected by secret key.
    """
    if not ADMIN_SETUP_KEY:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_SETUP_KEY not configured on server"
        )

    if setup_key != ADMIN_SETUP_KEY:
        raise HTTPException(status_code=403, detail="Invalid setup key")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=404,
            detail=f"User {email} not found. Register first via the app."
        )

    user.role = "admin"
    db.commit()
    logger.info(f"User {email} promoted to admin via setup endpoint")
    return {"message": f"✅ {email} is now an admin!", "role": user.role}

def _event_to_dict(event: models.Event) -> dict:
    """Same serializer as events.py — returns Flutter-compatible dict."""
    raw_urls = event.image_urls or ""
    urls = [u.strip() for u in raw_urls.split(",") if u.strip()]
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


# ── Pending events ────────────────────────────────────────────────────────────

@router.get("/events/pending")
def get_pending_events(
    db: Session = Depends(get_db),
    _: models.User = Depends(admin_only),
):
    events = db.query(models.Event).filter(models.Event.is_approved == False).all()
    return [_event_to_dict(e) for e in events]


# ── Approve ───────────────────────────────────────────────────────────────────

@router.put("/approve/{event_id}")
def approve_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_approved = True
    db.commit()
    db.refresh(event)
    logger.info(f"Event {event_id} approved by admin {current_user.id}")
    return {"message": "Event approved"}


# ── Approve via events path ───────────────────────────────────────────────────

@router.put("/events/{event_id}/approve")
def approve_event_alt(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_approved = True
    db.commit()
    logger.info(f"Event {event_id} approved by admin {current_user.id}")
    return {"message": "Event approved"}


# ── Reject / delete ───────────────────────────────────────────────────────────

@router.delete("/reject/{event_id}")
def reject_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    db.delete(event)
    db.commit()
    logger.info(f"Event {event_id} rejected by admin {current_user.id}")
    return {"message": "Event rejected and removed"}


@router.delete("/events/{event_id}")
def delete_event_alt(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    db.delete(event)
    db.commit()
    return {"message": "Event deleted"}


# ── Set user role ─────────────────────────────────────────────────────────────

@router.put("/set-role/{user_id}")
def set_user_role(
    user_id: int,
    role: str,
    db: Session = Depends(get_db),
    _: models.User = Depends(admin_only),
):
    if role not in ("user", "organizer", "admin"):
        raise HTTPException(status_code=400, detail="Invalid role")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = role
    db.commit()
    return {"message": f"Role updated to '{role}' for user {user_id}"}