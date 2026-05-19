from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import get_current_user
from app.gamification import get_user_stats
from sqlalchemy import func
from datetime import datetime, timedelta

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/me")
def personal_analytics(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    created = db.query(models.Event).filter(models.Event.creator_id == current_user.id).all()
    category_counts: dict[str, int] = {}
    for event in created:
        category_counts[event.category or "other"] = category_counts.get(event.category or "other", 0) + 1
    stats = get_user_stats(db, current_user)
    return {
        **stats,
        "category_breakdown": category_counts,
    }

@router.get("/heatmap")
def get_heatmap_data(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # Get last 90 days of activity
    ninety_days_ago = datetime.utcnow() - timedelta(days=90)
    
    activities = db.query(
        func.date(models.ActivityLog.created_at).label("date"),
        func.count(models.ActivityLog.id).label("count")
    ).filter(
        models.ActivityLog.user_id == current_user.id,
        models.ActivityLog.created_at >= ninety_days_ago
    ).group_by(func.date(models.ActivityLog.created_at)).all()
    
    return {str(a.date): a.count for a in activities}

@router.get("/campus-stats")
def get_campus_stats(db: Session = Depends(get_db)):
    now = datetime.utcnow()
    one_day_ago = now - timedelta(days=1)
    seven_days_later = now + timedelta(days=7)

    # Active students: users active in the last 24 hours, or fallback to total users if 0
    active_count = db.query(models.User).filter(models.User.last_active >= one_day_ago).count()
    if active_count == 0:
        active_count = db.query(models.User).count()
    
    # Events this week
    events_count = db.query(models.Event).filter(
        models.Event.date >= now,
        models.Event.date <= seven_days_later
    ).count()

    # Avatars of recently active users
    recent_users = db.query(models.User).filter(
        models.User.avatar_url.isnot(None),
        models.User.avatar_url != ""
    ).order_by(models.User.last_active.desc().nullslast()).limit(3).all()

    avatars = [u.avatar_url for u in recent_users]
    # Fallback to random seeds if not enough avatars
    fallbacks = ["Alex", "Sam", "Jordan"]
    for i in range(len(avatars), 3):
        avatars.append(f"https://api.dicebear.com/7.x/avataaars/png?seed={fallbacks[i]}")

    return {
        "active_students": active_count,
        "events_this_week": events_count,
        "active_avatars": avatars
    }

