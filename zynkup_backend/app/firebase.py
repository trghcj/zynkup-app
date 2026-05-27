import os
import logging
from firebase_admin import credentials, initialize_app, messaging
from sqlalchemy.orm import Session
from app import models
from app.database import SessionLocal

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK if service account key exists
_service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
if _service_account_path and os.path.isfile(_service_account_path):
    try:
        cred = credentials.Certificate(_service_account_path)
        initialize_app(cred)
        logger.info("Firebase Admin initialized.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin: {e}")
else:
    logger.warning("Firebase service account not found; FCM disabled.")

def send_fcm_notification(user_id: int, title: str, body: str, data: dict | None = None) -> bool:
    """Send a push notification via FCM to the device token stored for a user.
    Returns True on success, False otherwise.
    """
    db: Session = SessionLocal()
    try:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user or not user.fcm_token:
            logger.info(f"No FCM token for user {user_id}; skipping notification.")
            return False
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=user.fcm_token,
            data=data or {},
        )
        response = messaging.send(message)
        logger.info(f"FCM sent to user {user_id}: {response}")
        return True
    except Exception as exc:
        logger.error(f"Error sending FCM to user {user_id}: {exc}")
        return False
    finally:
        db.close()
