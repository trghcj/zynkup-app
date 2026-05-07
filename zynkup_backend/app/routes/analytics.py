from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/me")
def personal_analytics(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    created = db.query(models.Event).filter(models.Event.creator_id == current_user.id).all()
    registrations = db.query(models.Registration).filter(models.Registration.user_id == current_user.id).all()
    total_attendees = sum(len(event.registrations) for event in created)
    category_counts: dict[str, int] = {}
    for event in created:
        category_counts[event.category or "other"] = category_counts.get(event.category or "other", 0) + 1
    return {
        "events_created": len(created),
        "total_registered": len(registrations),
        "attended": sum(1 for item in registrations if item.attended),
        "total_attendees": total_attendees,
        "category_breakdown": category_counts,
    }