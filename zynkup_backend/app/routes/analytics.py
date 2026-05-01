from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth import get_current_user
from app import models

router = APIRouter(prefix="/analytics", tags=["Analytics"])

@router.get("/")
def get_analytics(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    total_events = db.query(models.Event).count()
    total_users = db.query(models.User).count()
    approved_events = db.query(models.Event).filter(models.Event.is_approved == True).count()
    pending_events = db.query(models.Event).filter(models.Event.is_approved == False).count()
    total_registrations = db.query(models.Registration).count()
    events = db.query(models.Event).all()

    event_data = []
    for e in events:
        count = db.query(models.Registration).filter(
            models.Registration.event_id == e.id
        ).count()

        event_data.append({
            "event": e.title,
            "registrations": count
        })

    return {
        "total_events": total_events,
        "total_users": total_users,
        "approved": approved_events,
        "pending": pending_events,
        "registrations": total_registrations,
        "event_data": event_data
    }