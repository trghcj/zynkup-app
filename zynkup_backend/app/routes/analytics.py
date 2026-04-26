# app/routes/analytics.py
import logging
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app import models

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/")
def get_analytics(db: Session = Depends(get_db)):
    """
    Public analytics endpoint — no auth required.
    Admin dashboard calls this without a token context.
    """
    total_users     = db.query(models.User).count()
    total_events    = db.query(models.Event).count()
    approved_events = db.query(models.Event).filter(
        models.Event.is_approved == True
    ).count()
    pending_events  = db.query(models.Event).filter(
        models.Event.is_approved == False
    ).count()

    return {
        "total_users":     total_users,
        "total_events":    total_events,
        "approved_events": approved_events,
        "pending_events":  pending_events,
    }