import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import require_role

router = APIRouter(prefix="/admin", tags=["Admin controls"])


@router.put("/set-role")
def set_role(email: str, role: str, setup_key: str, db: Session = Depends(get_db)):
    secret = os.getenv("ADMIN_SETUP_KEY", "")
    if not secret or setup_key != secret:
        raise HTTPException(status_code=403, detail="Invalid setup key")
    if role not in ("user", "organizer", "admin"):
        raise HTTPException(status_code=400, detail="Invalid role")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = role
    db.commit()
    return {"message": f"{email} -> {role}"}


@router.post("/events/{event_id}/report")
def report_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(require_role(["admin"])),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_reported = True
    event.report_count = (event.report_count or 0) + 1
    db.commit()
    return {"message": "Event reported", "report_count": event.report_count}
