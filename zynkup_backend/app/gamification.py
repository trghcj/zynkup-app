import math
import json
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app import models

XP_RULES = {
    "create_event": 10,
    "register_event": 5,
    "attend_event": 15,
    "daily_login": 2,
    "complete_profile": 10,
    "first_event_bonus": 50,
}

def calculate_level(xp: int) -> int:
    
    return math.floor(math.sqrt(xp / 25)) + 1

def add_xp(db: Session, user: models.User, action: str, amount: int = None):
    try:
        if amount is None:
            amount = XP_RULES.get(action, 0)
        
        # Check for first event bonus
        if action == "create_event":
            event_count = db.query(models.Event).filter(models.Event.creator_id == user.id).count()
            if event_count <= 1: # If it's the first one (already committed in events.py)
                amount += XP_RULES["first_event_bonus"]
                log_activity(db, user, "first_event_bonus", XP_RULES["first_event_bonus"])

        user.xp += amount
        user.level = calculate_level(user.xp)
        
        log_activity(db, user, action, amount)
        db.commit()
    except Exception as e:
        db.rollback()
        # We don't raise here — gamification should not break the core app
        print(f"GAMIFICATION ERROR (Likely missing columns): {e}")

def log_activity(db: Session, user: models.User, action: str, xp_gained: int):
    try:
        activity = models.ActivityLog(
            user_id=user.id,
            action=action,
            xp_gained=xp_gained
        )
        db.add(activity)
        # Update last_active and streak logic
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        if user.last_active:
            delta = now - user.last_active
            if delta.days == 1:
                user.streak += 1
            elif delta.days > 1:
                user.streak = 1 # Reset to 1 if more than a day missed
        else:
            user.streak = 1
        
        user.last_active = now
    except Exception as e:
        print(f"LOG ACTIVITY ERROR: {e}")

def get_user_stats(db: Session, user: models.User):
    # Total stats for profile
    events_created = db.query(models.Event).filter(models.Event.creator_id == user.id).count()
    total_registered = db.query(models.Registration).filter(models.Registration.user_id == user.id).count()
    attended = db.query(models.Registration).filter(
        models.Registration.user_id == user.id,
        models.Registration.attended == True
    ).count()
    
    return {
        "xp": user.xp,
        "level": user.level,
        "streak": user.streak,
        "events_created": events_created,
        "total_registered": total_registered,
        "attended": attended,
        "achievements": json.loads(user.achievements or "[]"),
        "avatar_seed": user.avatar_seed or user.email,
        "avatar_type": user.avatar_type,
        "theme": user.theme,
    }
