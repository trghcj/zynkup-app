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
