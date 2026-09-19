import math
import json
import threading
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app import models

_daily_login_lock = threading.Lock()
_awarded_daily_logins = set()

XP_RULES = {
    "create_event": 50,
    "create_club": 50,
    "create_post": 20,
    "create_comment": 5,
    "register_event": 10,
    "attend_event": 25,
    "accept_friend": 15,
    "join_club": 10,
    "daily_login": 5,
    "complete_profile": 20,
    "first_event_bonus": 50,
}

ACTION_NOTIFICATIONS = {
    "create_event": {
        "title": "🎉 Event Created! (+50 XP)",
        "body": "You earned 50 XP for organizing a new event on Zynkup!",
    },
    "create_club": {
        "title": "🏛️ Club Founded! (+50 XP)",
        "body": "You earned 50 XP for launching a new student club!",
    },
    "create_post": {
        "title": "📝 Post Published! (+20 XP)",
        "body": "You earned 20 XP for sharing on the campus feed!",
    },
    "create_comment": {
        "title": "💬 Discussion Sparked! (+5 XP)",
        "body": "You earned 5 XP for commenting on a feed post!",
    },
    "register_event": {
        "title": "🎟️ Event Registered! (+10 XP)",
        "body": "You earned 10 XP for signing up for an event!",
    },
    "attend_event": {
        "title": "📍 Attendance Confirmed! (+25 XP)",
        "body": "You earned 25 XP for attending the event!",
    },
    "accept_friend": {
        "title": "🤝 New Connection! (+15 XP)",
        "body": "You earned 15 XP for connecting with a new friend!",
    },
    "join_club": {
        "title": "🌟 Club Joined! (+10 XP)",
        "body": "You earned 10 XP for joining a club community!",
    },
    "daily_login": {
        "title": "⚡ Daily Check-In! (+5 XP)",
        "body": "You earned 5 XP for your daily check-in! Keep the streak going!",
    },
    "complete_profile": {
        "title": "✨ Profile Completed! (+20 XP)",
        "body": "You earned 20 XP for completing your student profile!",
    },
    "first_event_bonus": {
        "title": "🚀 First Event Bonus! (+50 XP)",
        "body": "Awesome! You earned a special 50 XP bonus for your first event!",
    },
}

BADGE_DEFINITIONS = [
    {
        "id": "first_event",
        "name": "First Event",
        "description": "Register for your first event.",
        "icon": "event_available",
        "color": "#F97316",
    },
    {
        "id": "explorer",
        "name": "Explorer",
        "description": "Register for 3 events.",
        "icon": "explore",
        "color": "#38BDF8",
    },
    {
        "id": "first_creator",
        "name": "First Creator",
        "description": "Create your first event.",
        "icon": "add_circle",
        "color": "#A78BFA",
    },
    {
        "id": "rising_star",
        "name": "Rising Star",
        "description": "Reach level 3.",
        "icon": "star",
        "color": "#FACC15",
    },
    {
        "id": "community_hero",
        "name": "Community Hero",
        "description": "Attend 5 events.",
        "icon": "volunteer_activism",
        "color": "#22C55E",
    },
    {
        "id": "seven_day_streak",
        "name": "7-Day Streak",
        "description": "Keep a 7-day activity streak.",
        "icon": "local_fire_department",
        "color": "#EF4444",
    },
    {
        "id": "verified_organizer",
        "name": "Verified Organizer",
        "description": "Become an organizer or admin.",
        "icon": "verified",
        "color": "#14B8A6",
    },
    {
        "id": "founding_member",
        "name": "Founding Member",
        "description": "Be among the first 100 Zynkup members.",
        "icon": "workspace_premium",
        "color": "#FB7185",
    },
    {
        "id": "crowd_magnet",
        "name": "Crowd Magnet",
        "description": "Bring 10 total attendees to your events.",
        "icon": "groups",
        "color": "#60A5FA",
    },
    {
        "id": "elite_member",
        "name": "Elite Member",
        "description": "Reach level 10.",
        "icon": "military_tech",
        "color": "#F59E0B",
    },
]

def calculate_level(xp: int) -> int:
    xp_val = max(0, xp or 0)
    return math.floor(math.sqrt(xp_val / 25)) + 1

def add_xp(db: Session, user: models.User, action: str, amount: int = None):
    user_key = None
    try:
        if amount is None:
            amount = XP_RULES.get(action, 0)

        # De-duplicate daily login XP (strictly once per calendar day in UTC)
        if action == "daily_login":
            today_date = datetime.now(timezone.utc).date()
            user_key = (user.id, str(today_date))
            with _daily_login_lock:
                if user_key in _awarded_daily_logins:
                    return
                # Check DB under lock
                today_start = datetime.combine(today_date, datetime.min.time())
                already_awarded = db.query(models.ActivityLog).filter(
                    models.ActivityLog.user_id == user.id,
                    models.ActivityLog.action == "daily_login",
                    models.ActivityLog.created_at >= today_start
                ).first()
                if already_awarded:
                    _awarded_daily_logins.add(user_key)
                    return
                # Reserve immediately to block parallel thread race conditions
                _awarded_daily_logins.add(user_key)

        # Check for first event bonus
        bonus_awarded = False
        if action == "create_event":
            event_count = db.query(models.Event).filter(models.Event.creator_id == user.id).count()
            if event_count <= 1: # If it's the first one
                bonus_amount = XP_RULES.get("first_event_bonus", 50)
                amount += bonus_amount
                bonus_awarded = True

        if amount <= 0:
            return

        old_xp = user.xp or 0
        old_level = user.level or calculate_level(old_xp)

        user.xp = old_xp + amount
        new_level = calculate_level(user.xp)
        user.level = new_level
        
        log_activity(db, user, action, amount)
        if bonus_awarded:
            log_activity(db, user, "first_event_bonus", XP_RULES.get("first_event_bonus", 50))
        
        db.commit()

        try:
            from app.fcm import create_notification_helper, XP_GAINED, LEVEL_UP
            
            action_info = ACTION_NOTIFICATIONS.get(action)
            if action_info:
                title = action_info["title"]
                body = action_info["body"]
            else:
                title = f"⚡ XP Gained! (+{amount} XP)"
                body = f"You gained {amount} XP from {action.replace('_', ' ')}."

            # Suppress OS push notifications on device lock screen for self-initiated actions
            # (they will still appear cleanly in the in-app notification center)
            SELF_ACTIONS_NO_PUSH = {"daily_login", "create_post", "create_comment", "register_event", "complete_profile"}
            should_push = action not in SELF_ACTIONS_NO_PUSH

            create_notification_helper(
                db=db,
                user_id=user.id,
                title=title,
                body=body,
                type=XP_GAINED,
                data={"xp_gained": str(amount), "action": action, "total_xp": str(user.xp)},
                send_push=should_push
            )

            # Check if user leveled up (major achievement — always push!)
            if new_level > old_level:
                create_notification_helper(
                    db=db,
                    user_id=user.id,
                    title=f"🎖️ Level Up! You're now Level {new_level}!",
                    body=f"Congratulations! You've reached Level {new_level}. Keep participating to unlock more badges and rank up!",
                    type=LEVEL_UP,
                    data={"new_level": str(new_level), "old_level": str(old_level), "total_xp": str(user.xp)},
                    send_push=True
                )
        except Exception as e_xp:
            print(f"Failed to create XP notification: {e_xp}")
    except Exception as e:
        if user_key and user_key in _awarded_daily_logins:
            _awarded_daily_logins.discard(user_key)
        db.rollback()
        # We don't raise here — gamification should not break the core app
        print(f"GAMIFICATION ERROR: {e}")

def log_activity(db: Session, user: models.User, action: str, xp_gained: int):
    try:
        activity = models.ActivityLog(
            user_id=user.id,
            action=action,
            xp_gained=xp_gained
        )
        db.add(activity)
        # Update last_active and streak logic
        user.streak = user.streak or 0
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

def _profile_counts(db: Session, user: models.User):
    # Total stats for profile
    events_created = db.query(models.Event).filter(models.Event.creator_id == user.id).count()
    total_registered = db.query(models.Registration).filter(models.Registration.user_id == user.id).count()
    attended = db.query(models.Registration).filter(
        models.Registration.user_id == user.id,
        models.Registration.attended == True
    ).count()
    total_attendees = (
        db.query(models.Registration)
        .join(models.Event, models.Registration.event_id == models.Event.id)
        .filter(models.Event.creator_id == user.id)
        .count()
    )
    rank = db.query(models.User).filter(models.User.xp > user.xp).count() + 1
    return {
        "events_created": events_created,
        "total_registered": total_registered,
        "attended": attended,
        "total_attendees": total_attendees,
        "rank": rank,
    }


def get_profile_badges(user: models.User, stats: dict):
    unlocked = {
        "first_event": stats["total_registered"] >= 1,
        "explorer": stats["total_registered"] >= 3,
        "first_creator": stats["events_created"] >= 1,
        "rising_star": user.level >= 3,
        "community_hero": stats["attended"] >= 5,
        "seven_day_streak": user.streak >= 7,
        "verified_organizer": user.role in {"organizer", "admin"},
        "founding_member": user.id <= 100,
        "crowd_magnet": stats["total_attendees"] >= 10,
        "elite_member": user.level >= 10,
    }
    return [
        {
            **badge,
            "unlocked": unlocked.get(badge["id"], False),
        }
        for badge in BADGE_DEFINITIONS
    ]


def get_user_stats(db: Session, user: models.User):
    stats = _profile_counts(db, user)
    badges = get_profile_badges(user, stats)
    unlocked_badges = [badge["id"] for badge in badges if badge["unlocked"]]
    try:
        old_badges = set(json.loads(user.achievements or "[]"))
        new_badges = set(unlocked_badges)
        unlocked_new = new_badges - old_badges
        if unlocked_new:
            user.achievements = json.dumps(unlocked_badges)
            db.commit()
            for b_id in unlocked_new:
                badge_def = next((b for b in BADGE_DEFINITIONS if b["id"] == b_id), None)
                badge_name = badge_def["name"] if badge_def else b_id
                try:
                    from app.fcm import create_notification_helper, BADGE_UNLOCKED
                    create_notification_helper(
                        db=db,
                        user_id=user.id,
                        title="Badge Unlocked!",
                        body=f"Congratulations! You unlocked the '{badge_name}' badge.",
                        type=BADGE_UNLOCKED,
                        data={"badge_id": b_id}
                    )
                except Exception as e_bd:
                    print(f"Failed to create badge notification: {e_bd}")
        elif json.loads(user.achievements or "[]") != unlocked_badges:
            user.achievements = json.dumps(unlocked_badges)
            db.commit()
    except Exception:
        db.rollback()
    
    return {
        "xp": user.xp,
        "level": user.level,
        "streak": user.streak,
        **stats,
        "achievements": unlocked_badges,
        "badges": badges,
        "avatar_seed": user.avatar_seed or user.email,
        "avatar_type": user.avatar_type,
        "theme": user.theme,
    }
