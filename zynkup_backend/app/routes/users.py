# app/routes/users.py
import logging
import os
import httpx
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import (
    hash_password, verify_password,
    create_access_token, get_current_user,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")


# ── Schemas ───────────────────────────────────────────────────────────────────

class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class GoogleAuthRequest(BaseModel):
    id_token: str   # Google ID token from Flutter google_sign_in

class ProfileUpdate(BaseModel):
    name:         Optional[str] = None
    display_name: Optional[str] = None
    phone:        Optional[str] = None
    branch:       Optional[str] = None
    year:         Optional[str] = None
    enrollment:   Optional[str] = None
    college:      Optional[str] = None
    bio:          Optional[str] = None
    avatar_url:   Optional[str] = None


def _user_response(user: models.User, token: str) -> dict:
    return {
        "access_token": token,
        "token_type":   "bearer",
        "user": {
            "id":           user.id,
            "email":        user.email,
            "name":         user.name,
            "avatar_url":   user.avatar_url,
            "role":         user.role,
            "college":      user.college,
            "branch":       user.branch,
            "year":         user.year,
            "enrollment":   user.enrollment,
            "display_name": user.display_name,
            "phone":        user.phone,
            "bio":          user.bio,
            "is_profile_complete": bool(user.name),
        }
    }


# ── Email Signup ──────────────────────────────────────────────────────────────

@router.post("/signup", status_code=201)
def signup(req: SignupRequest, db: Session = Depends(get_db)):
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    if db.query(models.User).filter(models.User.email == req.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        email    = req.email,
        password = hash_password(req.password),
        name     = req.name,
        college  = "MAIT",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    logger.info(f"New user: id={user.id}")
    return _user_response(user, token)


# ── Email Login ───────────────────────────────────────────────────────────────

@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user or not user.password or not verify_password(req.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_access_token({"sub": str(user.id)})
    logger.info(f"Login: id={user.id}")
    return _user_response(user, token)


# ── Google OAuth ──────────────────────────────────────────────────────────────

@router.post("/google")
async def google_auth(req: GoogleAuthRequest, db: Session = Depends(get_db)):
    """
    Verify Google ID token, create or find user, return JWT.
    Flutter sends the idToken from google_sign_in package.
    """
    try:
        async with httpx.AsyncClient() as client:
            res = await client.get(
                f"https://oauth2.googleapis.com/tokeninfo?id_token={req.id_token}"
            )
        if res.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid Google token")

        payload = res.json()

        # Verify audience if GOOGLE_CLIENT_ID is set
        if GOOGLE_CLIENT_ID and payload.get("aud") != GOOGLE_CLIENT_ID:
            raise HTTPException(status_code=401, detail="Token audience mismatch")

        google_id = payload.get("sub")
        email     = payload.get("email")
        name      = payload.get("name")
        avatar    = payload.get("picture")

        if not google_id or not email:
            raise HTTPException(status_code=400, detail="Invalid Google payload")

        # Find or create user
        user = db.query(models.User).filter(
            (models.User.google_id == google_id) |
            (models.User.email == email)
        ).first()

        if user:
            # Link google_id if missing
            if not user.google_id:
                user.google_id = google_id
            if not user.avatar_url and avatar:
                user.avatar_url = avatar
            if not user.name and name:
                user.name = name
            db.commit()
        else:
            user = models.User(
                email     = email,
                google_id = google_id,
                name      = name,
                avatar_url= avatar,
                college   = "MAIT",
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            logger.info(f"New Google user: id={user.id}")

        token = create_access_token({"sub": str(user.id)})
        return _user_response(user, token)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Google auth error: {e}")
        raise HTTPException(status_code=500, detail="Google authentication failed")


# ── Get current user ──────────────────────────────────────────────────────────

@router.get("/me")
def get_me(current_user: models.User = Depends(get_current_user)):
    return {
        "id":           current_user.id,
        "email":        current_user.email,
        "name":         current_user.name,
        "avatar_url":   current_user.avatar_url,
        "role":         current_user.role,
        "college":      current_user.college,
        "branch":       current_user.branch,
        "year":         current_user.year,
        "enrollment":   current_user.enrollment,
        "display_name": current_user.display_name,
        "phone":        current_user.phone,
        "bio":          current_user.bio,
        "is_profile_complete": bool(current_user.name),
    }


# ── Update profile ────────────────────────────────────────────────────────────

@router.put("/me")
def update_profile(
    data: ProfileUpdate,
    db:   Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if data.name         is not None: current_user.name         = data.name
    if data.display_name is not None: current_user.display_name = data.display_name
    if data.phone        is not None: current_user.phone        = data.phone
    if data.branch       is not None: current_user.branch       = data.branch
    if data.year         is not None: current_user.year         = data.year
    if data.enrollment   is not None: current_user.enrollment   = data.enrollment
    if data.college      is not None: current_user.college      = data.college
    if data.bio          is not None: current_user.bio          = data.bio
    if data.avatar_url   is not None: current_user.avatar_url   = data.avatar_url
    db.commit()
    db.refresh(current_user)
    return {"message": "Profile updated", "name": current_user.name}


# ── Legacy create-profile (backward compat) ───────────────────────────────────

@router.post("/create-profile")
def create_profile(
    data: ProfileUpdate,
    db:   Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return update_profile(data, db, current_user)


# ── My events (created) ───────────────────────────────────────────────────────

@router.get("/my-events")
def my_created_events(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    from app.routes.events import _event_to_dict
    events = db.query(models.Event).filter(
        models.Event.creator_id == current_user.id
    ).order_by(models.Event.created_at.desc()).all()
    return [_event_to_dict(e, current_user.id) for e in events]


# ── My registrations ──────────────────────────────────────────────────────────

@router.get("/my-registrations")
def my_registrations(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    from app.routes.events import _event_to_dict
    regs = db.query(models.Registration).filter(
        models.Registration.user_id == current_user.id
    ).all()
    return [
        {
            "qr_code":   r.qr_code,
            "attended":  r.attended,
            "registered_at": r.created_at.isoformat() if r.created_at else None,
            "event": _event_to_dict(r.event, current_user.id),
        }
        for r in regs
    ]


# ── Admin: promote user ───────────────────────────────────────────────────────

@router.put("/set-role")
def set_role(
    email: str,
    role:  str,
    setup_key: str,
    db: Session = Depends(get_db),
):
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
    return {"message": f"{email} → {role}"}