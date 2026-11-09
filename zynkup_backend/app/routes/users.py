# app/routes/users.py
import logging
import os
import time
import httpx
from collections import defaultdict, deque
from threading import Lock
from typing import Optional
from datetime import datetime, timezone
from app.timeutils import utcnow_naive

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.auth import (
    hash_password, verify_password,
    create_access_token, get_current_user,
)
from app.gamification import add_xp, get_user_stats
from app.validation import MAX_BIO, MAX_NAME, MAX_SHORT_TEXT, check_length, safe_url

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])

# Google OAuth client IDs whose ID tokens we accept (the token's "aud" claim).
# These are public identifiers (also shipped in the app). The audience check is
# always enforced so tokens minted for other apps can never log in here.
# Override with a comma-separated GOOGLE_CLIENT_ID env var if needed.
_DEFAULT_GOOGLE_CLIENT_IDS = (
    "659234851207-o80f3633j9f09j79d0ml7376o7v4iv58.apps.googleusercontent.com",  # web / serverClientId
    "659234851207-0do8gsdvrn7pivdd65qdgrcb8301jn2u.apps.googleusercontent.com",  # android
    "659234851207-fl9gfob5pr92m2gkjn0rthpboftgvtun.apps.googleusercontent.com",  # ios
)
GOOGLE_CLIENT_IDS = {
    cid.strip()
    for cid in (os.getenv("GOOGLE_CLIENT_ID") or ",".join(_DEFAULT_GOOGLE_CLIENT_IDS)).split(",")
    if cid.strip()
}

MIN_PASSWORD_LENGTH = 8


# ── Schemas ───────────────────────────────────────────────────────────────────

class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None
    college: Optional[str] = None

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
    avatar_seed:  Optional[str] = None
    avatar_type:  Optional[str] = None
    theme:        Optional[str] = None
    banner_url:   Optional[str] = None


def _user_response(user: models.User, token: str) -> dict:
    return {
        "access_token": token,
        "token_type":   "bearer",
        "user": {
            "id":           user.id,
            "email":        user.email,
            "name":         user.name,
            "avatar_url":   user.resolved_avatar_url,
            "banner_url":   user.banner_url,
            "role":         user.role,
            "college":      user.college,
            "branch":       user.branch,
            "year":         user.year,
            "enrollment":   user.enrollment,
            "display_name": user.display_name,
            "phone":        user.phone,
            "bio":          user.bio,
            "is_profile_complete": bool(user.name),
            "xp": user.xp,
            "level": user.level,
            "streak": user.streak,
            "avatar_seed": user.avatar_seed or user.email,
            "avatar_type": user.avatar_type,
            "theme": user.theme,
        }
    }


# ── Email Signup ──────────────────────────────────────────────────────────────

@router.post("/signup", status_code=201)
def signup(req: SignupRequest, db: Session = Depends(get_db)):
    if len(req.password) < MIN_PASSWORD_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Password must be at least {MIN_PASSWORD_LENGTH} characters",
        )
    check_length(req.password, 128, "Password")
    check_length(req.name, MAX_NAME, "Name")
    check_length(req.college, MAX_SHORT_TEXT, "College")

    if db.query(models.User).filter(models.User.email == req.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        email    = req.email,
        password = hash_password(req.password),
        name     = req.name,
        college  = req.college if req.college else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    logger.info(f"New user: id={user.id}")
    return _user_response(user, token)


# ── Email Login ───────────────────────────────────────────────────────────────

# Simple in-process brute-force guard: max failed attempts per (client IP, email)
# within a sliding window. Good enough for a single backend instance.
_LOGIN_MAX_FAILURES = 10
_LOGIN_WINDOW_SECONDS = 15 * 60
_login_failures: dict[tuple[str, str], deque] = defaultdict(deque)
_login_lock = Lock()


def _recent_failures(key: tuple[str, str], now: float) -> deque:
    attempts = _login_failures[key]
    while attempts and now - attempts[0] > _LOGIN_WINDOW_SECONDS:
        attempts.popleft()
    return attempts


@router.post("/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    key = (client_ip, req.email.lower())
    now = time.monotonic()
    with _login_lock:
        if len(_recent_failures(key, now)) >= _LOGIN_MAX_FAILURES:
            raise HTTPException(
                status_code=429,
                detail="Too many failed login attempts. Try again in a few minutes.",
            )

    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user or not user.password or not verify_password(req.password, user.password):
        with _login_lock:
            _recent_failures(key, now).append(now)
        raise HTTPException(status_code=401, detail="Invalid email or password")

    with _login_lock:
        _login_failures.pop(key, None)

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
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(
                "https://oauth2.googleapis.com/tokeninfo",
                params={"id_token": req.id_token},
            )
        if res.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid Google token")

        payload = res.json()

        # Always verify the token was issued for this app.
        if payload.get("aud") not in GOOGLE_CLIENT_IDS:
            raise HTTPException(status_code=401, detail="Token audience mismatch")
        if payload.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
            raise HTTPException(status_code=401, detail="Invalid token issuer")
        # Only trust (and link accounts by) emails Google has verified.
        if str(payload.get("email_verified", "")).lower() != "true":
            raise HTTPException(status_code=401, detail="Google email not verified")

        google_id = payload.get("sub")
        email     = payload.get("email")
        name      = payload.get("name")
        avatar    = payload.get("picture")

        if not google_id or not email:
            raise HTTPException(status_code=400, detail="Invalid Google payload")

        # Find or create user
        user = db.query(models.User).filter(
            (models.User.google_id == google_id) |
            (func.lower(models.User.email) == email.lower())
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
                college   = None,
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
def get_me(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        from app.gamification import add_xp
        add_xp(db, current_user, "daily_login")
    except Exception:
        pass

    stats = get_user_stats(db, current_user)
    return {
        "id":           current_user.id,
        "email":        current_user.email,
        "name":         current_user.name,
        "avatar_url":   current_user.resolved_avatar_url,
        "banner_url":   current_user.banner_url,
        "role":         current_user.role,
        "college":      current_user.college,
        "branch":       current_user.branch,
        "year":         current_user.year,
        "enrollment":   current_user.enrollment,
        "display_name": current_user.display_name,
        "phone":        current_user.phone,
        "bio":          current_user.bio,
        "xp":           current_user.xp,
        "level":        current_user.level,
        "streak":       current_user.streak,
        "avatar_seed":  current_user.avatar_seed or current_user.email,
        "avatar_type":  current_user.avatar_type,
        "theme":        current_user.theme,
        "is_profile_complete": bool(current_user.name),
        **stats,
    }

@router.get("/me/gamification")
def get_gamification_details(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    return get_user_stats(db, current_user)



# ── Update profile ────────────────────────────────────────────────────────────

@router.put("/me")
def update_profile(
    data: ProfileUpdate,
    db:   Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    check_length(data.name, MAX_NAME, "Name")
    check_length(data.display_name, MAX_NAME, "Display name")
    check_length(data.bio, MAX_BIO, "Bio")
    for field in ("phone", "branch", "year", "enrollment", "college", "avatar_seed", "avatar_type", "theme"):
        check_length(getattr(data, field), MAX_SHORT_TEXT, field.replace("_", " ").capitalize())
    # "" is how the app clears an image, so only validate non-empty values.
    if data.avatar_url:
        data.avatar_url = safe_url(data.avatar_url, "Avatar URL")
    if data.banner_url:
        data.banner_url = safe_url(data.banner_url, "Banner URL")

    if data.name         is not None: current_user.name         = data.name
    if data.display_name is not None: current_user.display_name = data.display_name
    if data.phone        is not None: current_user.phone        = data.phone
    if data.branch       is not None: current_user.branch       = data.branch
    if data.year         is not None: current_user.year         = data.year
    if data.enrollment   is not None: current_user.enrollment   = data.enrollment
    if data.college      is not None:
        c_val = data.college.strip()
        current_user.college = c_val if c_val else None
    if data.bio          is not None: current_user.bio          = data.bio
    if data.avatar_url   is not None:
        current_user.avatar_url = data.avatar_url
    elif data.avatar_seed is not None or data.avatar_type is not None:
        current_user.avatar_url = None

    if data.banner_url   is not None:
        current_user.banner_url = data.banner_url if data.banner_url != "" else None

    if data.avatar_seed  is not None: current_user.avatar_seed  = data.avatar_seed
    if data.avatar_type  is not None: current_user.avatar_type  = data.avatar_type
    if data.theme        is not None: current_user.theme        = data.theme

    # Bonus XP for completing profile (first time)
    if data.name and not current_user.name:
        add_xp(db, current_user, "complete_profile")

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
    import re
    from app.routes.events import _event_to_dict, _parse_co_hosts, _colleges_match
    events = db.query(models.Event).order_by(models.Event.created_at.desc()).all()
    user_email = (current_user.email or "").strip().lower()
    user_college = (current_user.college or "").strip().lower()

    def _is_my_managed_event(e: models.Event) -> bool:
        if e.creator_id == current_user.id:
            return True
        co_hosts = _parse_co_hosts(e.co_hosts)
        if not co_hosts and e.co_host_email:
            co_hosts = [{"email": e.co_host_email.strip().lower(), "college": ""}]
        for ch in co_hosts:
            ch_email = (ch.get("email") or "").strip().lower()
            ch_col = (ch.get("college") or "").strip()
            if ch_email and ch_email == user_email:
                if not ch_col or (user_college and _colleges_match(user_college, ch_col)):
                    return True
        return False

    managed_events = [e for e in events if _is_my_managed_event(e)]
    return [_event_to_dict(e, current_user.id, current_user) for e in managed_events]


# ── My registrations ──────────────────────────────────────────────────────────

def _format_datetime_utc(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


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
            "registered_at": _format_datetime_utc(r.created_at),
            "event": _event_to_dict(r.event, current_user.id),
        }
        for r in regs
    ]

# ── Profile Activity Timeline ─────────────────────────────────────────────────

@router.get("/me/timeline")
def get_timeline(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    timeline = []

    # Events Registered
    regs = db.query(models.Registration).filter(models.Registration.user_id == current_user.id).all()
    for r in regs:
        timeline.append({
            "type": "event_registration",
            "title": f"Registered for {r.event.title}",
            "date": _format_datetime_utc(r.created_at or utcnow_naive()),
            "target_id": r.event_id
        })

    # Events Created
    created_events = db.query(models.Event).filter(models.Event.creator_id == current_user.id).all()
    for e in created_events:
        timeline.append({
            "type": "event_created",
            "title": f"Created {e.title}",
            "date": _format_datetime_utc(e.created_at or utcnow_naive()),
            "target_id": e.id
        })

    # Clubs (Created vs Joined)
    memberships = db.query(models.ClubMember).filter(models.ClubMember.user_id == current_user.id).all()
    for m in memberships:
        if m.club and m.club.creator_id == current_user.id:
            timeline.append({
                "type": "club_created",
                "title": f"Created {m.club.name}",
                "date": _format_datetime_utc(m.joined_at or m.club.created_at or utcnow_naive()),
                "target_id": m.club_id
            })
        elif m.club:
            timeline.append({
                "type": "club_join",
                "title": f"Joined {m.club.name}",
                "date": _format_datetime_utc(m.joined_at or utcnow_naive()),
                "target_id": m.club_id
            })

    # Posts
    posts = db.query(models.FeedPost).filter(models.FeedPost.author_id == current_user.id).all()
    for p in posts:
        timeline.append({
            "type": "post_created",
            "title": "Shared a new campus update",
            "date": _format_datetime_utc(p.created_at or utcnow_naive()),
            "target_id": p.id
        })

    timeline.sort(key=lambda x: x["date"], reverse=True)
    return timeline[:50]

# Role changes live in app/routes/admin.py (PUT /admin/set-role).


@router.get("/{user_id}")
def get_user_by_id(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    stats = get_user_stats(db, user)
    
    # check friendship status
    friendship = db.query(models.FriendRequest).filter(
        ((models.FriendRequest.sender_id == current_user.id) & (models.FriendRequest.receiver_id == user.id)) |
        ((models.FriendRequest.sender_id == user.id) & (models.FriendRequest.receiver_id == current_user.id))
    ).first()
    
    friend_status = "none"
    request_id = None
    if friendship:
        request_id = friendship.id
        if friendship.status == "accepted":
            friend_status = "friends"
        elif friendship.status == "pending":
            if friendship.sender_id == current_user.id:
                friend_status = "pending_sent"
            else:
                friend_status = "pending_received"

    # Contact details are private: only the user themselves, accepted friends and
    # admins can see email / phone / enrollment. Everyone else gets the public handle.
    can_see_private = (
        user.id == current_user.id
        or friend_status == "friends"
        or current_user.role == "admin"
    )
    username = (user.email or "").split("@")[0] or "user"

    return {
        "id":           user.id,
        "username":     username,
        "email":        user.email if can_see_private else None,
        "name":         user.name,
        "avatar_url":   user.resolved_avatar_url,
        "banner_url":   user.banner_url,
        "role":         user.role,
        "college":      user.college,
        "branch":       user.branch,
        "year":         user.year,
        "enrollment":   user.enrollment if can_see_private else None,
        "display_name": user.display_name,
        "phone":        user.phone if can_see_private else None,
        "bio":          user.bio,
        "xp":           user.xp,
        "level":        user.level,
        "streak":       user.streak,
        "avatar_seed":  user.avatar_seed or user.email,
        "avatar_type":  user.avatar_type,
        "theme":        user.theme,
        "friend_status": friend_status,
        "friend_request_id": request_id,
        **stats,
    }
