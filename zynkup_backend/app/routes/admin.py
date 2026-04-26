import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import get_db
from app.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin"])


def admin_only(current_user: models.User = Depends(get_current_user)) -> models.User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


# ── Pending events ────────────────────────────────────────────────────────────
@router.get("/events/pending", response_model=List[schemas.EventResponse])
def get_pending_events(
    db: Session = Depends(get_db),
    _: models.User = Depends(admin_only),
):
    return db.query(models.Event).filter(models.Event.is_approved == False).all()


# ── Approve — /admin/approve/{id}  (used by api_service.dart) ─────────────────
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
    logger.info(f"Event {event_id} approved by admin {current_user.id}")
    return {"message": "Event approved"}


# ── Approve via events path — /events/{id}/approve  (used by old screens) ─────
# This fixes the 404 on /events/3/approve from your frontend screens
@router.put("/events/{event_id}/approve")
def approve_event_alt(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    """Alias so both /admin/approve/{id} and /events/{id}/approve work."""
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


# ── Delete via events path — /events/{id}  (used by old screens) ──────────────
@router.delete("/events/{event_id}")
def delete_event_alt(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(admin_only),
):
    """Alias so DELETE /events/{id} also works for admin."""
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
    if role not in ("user", "admin"):
        raise HTTPException(status_code=400, detail="Role must be 'user' or 'admin'")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = role
    db.commit()
    return {"message": f"Role updated to '{role}' for user {user_id}"}
