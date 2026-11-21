import os
import logging
from concurrent.futures import ThreadPoolExecutor
import firebase_admin
from firebase_admin import credentials, messaging
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

logger = logging.getLogger(__name__)

# Constants for Notification Types
EVENT_JOINED = "EVENT_JOINED"
EVENT_REMINDER = "EVENT_REMINDER"
NEW_COMMENT = "NEW_COMMENT"
NEW_REPLY = "NEW_REPLY"
CLUB_INVITE = "CLUB_INVITE"
ATTENDANCE_MARKED = "ATTENDANCE_MARKED"
BADGE_UNLOCKED = "BADGE_UNLOCKED"
XP_GAINED = "XP_GAINED"
LEVEL_UP = "LEVEL_UP"

# Initialize Firebase Admin SDK
firebase_key_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "firebase_service_account.json")
try:
    if os.path.exists(firebase_key_path):
        cred = credentials.Certificate(firebase_key_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialized successfully.")
    else:
        logger.warning(f"Firebase service account file not found at {firebase_key_path}. FCM pushes disabled.")
except Exception as e:
    logger.error(f"Failed to initialize Firebase Admin SDK: {e}")

# Pushes go out from a small background pool. Sending them inline made a
# request (e.g. creating a club event) wait for one Firebase round trip per
# follower, which could take long enough to time out.
_push_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="fcm-push")


def queue_fcm_notification(token: str, title: str, body: str, data: dict = None) -> None:
    if not token or not firebase_admin._apps:
        return
    _push_pool.submit(send_fcm_notification, token, title, body, dict(data or {}))


def send_fcm_notification(token: str, title: str, body: str, data: dict = None):
    """
    Sends a push notification via Firebase Cloud Messaging.
    """
    if not token or not firebase_admin._apps:
        return False
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending FCM message: {e}")
        return False

def create_notification_helper(db, user_id: int, title: str, body: str, type: str, data: dict = None, send_push: bool = True):
    """
    Creates a persistent Notification record in the DB and attempts to deliver an FCM push notification.
    Deduplicates identical notifications within a 5-minute window to avoid spamming the user.
    """
    from datetime import datetime, timedelta
    from app.timeutils import utcnow_naive
    from app import models
    try:
        # Check for recent identical notification within 5 minutes to avoid duplicates
        five_mins_ago = utcnow_naive() - timedelta(minutes=5)
        existing = db.query(models.Notification).filter(
            models.Notification.user_id == user_id,
            models.Notification.type == type,
            models.Notification.title == title,
            models.Notification.created_at >= five_mins_ago
        ).first()
        if existing:
            return existing

        notif = models.Notification(
            user_id=user_id,
            title=title,
            body=body,
            type=type,
            is_read=False
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)

        if send_push:
            recipient = db.query(models.User).filter(models.User.id == user_id).first()
            if recipient and recipient.fcm_token:
                # Copy: callers may reuse the same dict for many recipients.
                payload = {k: str(v) for k, v in (data or {}).items()}
                payload["notification_id"] = str(notif.id)
                payload["type"] = type
                queue_fcm_notification(
                    token=recipient.fcm_token,
                    title=title,
                    body=body,
                    data=payload
                )

        return notif
    except Exception as e:
        logger.error(f"Error in create_notification_helper: {e}")
        db.rollback()
        return None
