import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import get_db
from app.auth import (
    hash_password, verify_password,
    create_access_token, get_current_user,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])

INVALID_CREDENTIALS = HTTPException(
    status_code=401, detail="Invalid email or password"
)


# ── Signup ────────────────────────────────────────────────────────────────────
@router.post("/signup", status_code=201)
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    new_user = models.User(
        email=user.email,
        password=hash_password(user.password),
        role="user",
        college="MAIT",
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    logger.info(f"New user registered: id={new_user.id}")
    return {"message": "Account created successfully"}


# ── Login ─────────────────────────────────────────────────────────────────────
@router.post("/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(
        models.User.email == user.email
    ).first()
    if not db_user or not verify_password(user.password, db_user.password):
        logger.warning("Failed login attempt")
        raise INVALID_CREDENTIALS
    token = create_access_token({"sub": str(db_user.id)})
    logger.info(f"User logged in: id={db_user.id}")
    return {
        "access_token": token,
        "token_type":   "bearer",
        "role":         db_user.role,
        "user_id":      db_user.id,
        "email":        db_user.email,
    }


# ── Create / update profile ───────────────────────────────────────────────────
@router.post("/create-profile")
def create_profile(
    data: schemas.ProfileCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    current_user.name         = data.name
    current_user.display_name = data.display_name
    current_user.phone        = data.phone
    current_user.branch       = data.branch
    current_user.year         = data.year
    current_user.enrollment   = data.enrollment
    current_user.college      = data.college or "MAIT"
    current_user.bio          = data.bio
    current_user.avatar_url   = data.avatar_url
    db.commit()
    return {"message": "Profile updated"}


# ── Me ────────────────────────────────────────────────────────────────────────
@router.get("/me", response_model=schemas.UserResponse)
def get_me(current_user: models.User = Depends(get_current_user)):
    return {
        "id":                  current_user.id,
        "email":               current_user.email,
        "name":                current_user.name,
        "display_name":        current_user.display_name,
        "phone":               current_user.phone,
        "branch":              current_user.branch,
        "year":                current_user.year,
        "enrollment":          current_user.enrollment,
        "college":             current_user.college,
        "bio":                 current_user.bio,
        "avatar_url":          current_user.avatar_url,
        "role":                current_user.role,
        "is_profile_complete": current_user.name is not None,
    }


# ── My events ─────────────────────────────────────────────────────────────────
@router.get("/my-events", response_model=List[schemas.EventResponse])
def my_events(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return (
        db.query(models.Event)
        .join(
            models.Registration,
            models.Registration.event_id == models.Event.id,
        )
        .filter(models.Registration.user_id == current_user.id)
        .all()
    )