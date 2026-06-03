import os
import logging
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

def create_notification_helper(db, user_id: int, title: str, body: str, type: str, data: dict = None):
    """
    Creates a persistent Notification record in the DB and attempts to deliver an FCM push notification.
    """
    from app import models
    try:
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

        recipient = db.query(models.User).filter(models.User.id == user_id).first()
        if recipient and recipient.fcm_token:
            payload = data or {}
            payload["notification_id"] = str(notif.id)
            payload["type"] = type
            send_fcm_notification(
                token=recipient.fcm_token,
                title=title,
                body=body,
                data=payload
            )

        # WebSocket notifications temporarily disabled due to missing ws_manager
        # (Remove this comment and restore when ws_manager is implemented)

        return notif
    except Exception as e:
        logger.error(f"Error in create_notification_helper: {e}")
        db.rollback()
        return None
