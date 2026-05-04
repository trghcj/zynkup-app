# app/routes/analytics.py
import logging
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/me")
def personal_analytics(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Personal stats for the logged-in user."""
    # Events created
    created = db.query(models.Event).filter(
        models.Event.creator_id == current_user.id
    ).all()

    # Registrations made by this user
    registrations = db.query(models.Registration).filter(
        models.Registration.user_id == current_user.id
    ).all()

    attended_count = sum(1 for r in registrations if r.attended)

    # Total attendees across all events this user created
    total_attendees = 0
    for event in created:
        total_attendees += db.query(models.Registration).filter(
            models.Registration.event_id == event.id
        ).count()

    # Category breakdown of created events
    category_counts: dict = {}
    for event in created:
        cat = event.category or "other"
        category_counts[cat] = category_counts.get(cat, 0) + 1

    # Monthly activity (last 6 months of events created)
    from datetime import datetime, timedelta
    six_months_ago = datetime.now() - timedelta(days=180)
    recent_created = [
        e for e in created if e.created_at and e.created_at >= six_months_ago
    ]

    monthly: dict = {}
    for event in recent_created:
        key = event.created_at.strftime("%b %Y")
        monthly[key] = monthly.get(key, 0) + 1

    return {
        "events_created":    len(created),
        "total_registered":  len(registrations),
        "attended":          attended_count,
        "total_attendees":   total_attendees,
        "category_breakdown": category_counts,
        "monthly_activity":  monthly,
    }


@router.get("/")
def global_analytics(db: Session = Depends(get_db)):
    """Public platform stats."""
    total_events = db.query(models.Event).filter(
        models.Event.is_approved == True
    ).count()
    total_users = db.query(models.User).count()
    total_registrations = db.query(models.Registration).count()

    return {
        "total_events":        total_events,
        "total_users":         total_users,
        "total_registrations": total_registrations,
    }