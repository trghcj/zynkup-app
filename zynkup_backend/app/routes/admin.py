import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import require_role

router = APIRouter(prefix="/admin", tags=["Admin controls"])


@router.put("/set-role")
def set_role(email: str, role: str, setup_key: str, db: Session = Depends(get_db)):
    secret = os.getenv("ADMIN_SETUP_KEY", "")
    if not secret or setup_key != secret:
        raise HTTPException(status_code=403, detail="Invalid setup key")
    if role not in ("user", "organizer", "admin"):
        raise HTTPException(status_code=400, detail="Invalid role")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = role
    db.commit()
    return {"message": f"{email} -> {role}"}


@router.post("/events/{event_id}/report")
def report_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(require_role(["admin"])),
):
    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_reported = True
    event.report_count = (event.report_count or 0) + 1
    db.commit()
    return {"message": "Event reported", "report_count": event.report_count}

@router.get("/cleanup-broken-images")
def cleanup_broken_images(setup_key: str, db: Session = Depends(get_db)):
    secret = os.getenv("ADMIN_SETUP_KEY", "")
    if not secret or setup_key != secret:
        raise HTTPException(status_code=403, detail="Invalid setup key")
        
    club_cleans = 0
    post_cleans = 0
    event_cleans = 0
    user_cleans = 0
    
    # 1. Clean Club Galleries and Logos
    clubs = db.query(models.Club).all()
    for c in clubs:
        modified = False
        if c.gallery_files and "/uploads/" in c.gallery_files:
            c.gallery_files = "" # Wipe corrupted gallery
            modified = True
        if c.banner_url and "/uploads/" in c.banner_url:
            c.banner_url = None
            modified = True
        if c.logo_url and "/uploads/" in c.logo_url:
            c.logo_url = None
            modified = True
        if modified:
            club_cleans += 1
            
    # 2. Clean Feed Posts
    posts = db.query(models.FeedPost).all()
    for p in posts:
        modified = False
        if p.image_url and "/uploads/" in p.image_url:
            p.image_url = None
            modified = True
        if p.banner_url and "/uploads/" in p.banner_url:
            p.banner_url = None
            modified = True
        if modified:
            post_cleans += 1

    # 3. Clean Events
    events = db.query(models.Event).all()
    for e in events:
        if e.image_urls and "/uploads/" in e.image_urls:
            e.image_urls = ""
            event_cleans += 1
            
    # 4. Clean User Avatars
    users = db.query(models.User).all()
    for u in users:
        if u.avatar_url and "/uploads/" in u.avatar_url:
            u.avatar_url = None
            user_cleans += 1
            
    db.commit()
    return {
        "message": "Cleanup complete",
        "clubs_cleaned": club_cleans,
        "posts_cleaned": post_cleans,
        "events_cleaned": event_cleans,
        "users_cleaned": user_cleans
    }
