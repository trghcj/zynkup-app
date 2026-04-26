from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from typing import Optional, List


# ── User ──────────────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


# ── Profile ───────────────────────────────────────────────────────────────────

class ProfileCreate(BaseModel):
    name:         str
    display_name: Optional[str] = None
    phone:        Optional[str] = None
    branch:       Optional[str] = None
    year:         Optional[str] = None
    enrollment:   Optional[str] = None
    college:      Optional[str] = "MAIT"
    bio:          Optional[str] = None
    avatar_url:   Optional[str] = None


# ── Event ─────────────────────────────────────────────────────────────────────

class EventCreate(BaseModel):
    title:                 str
    description:           str
    venue:                 str
    date:                  datetime
    category:              str
    image_urls:            Optional[List[str]] = []
    registration_url:      Optional[str] = None
    registration_url_type: Optional[str] = None

    @field_validator("title", "venue", "category")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Field cannot be blank")
        return v.strip()


# ── Response schemas ──────────────────────────────────────────────────────────

class UserResponse(BaseModel):
    id:                  int
    email:               str
    name:                Optional[str]
    display_name:        Optional[str]
    phone:               Optional[str]
    branch:              Optional[str]
    year:                Optional[str]
    enrollment:          Optional[str]
    college:             Optional[str]
    bio:                 Optional[str]
    avatar_url:          Optional[str]
    role:                str
    is_profile_complete: bool = False

    model_config = {"from_attributes": True}


class EventResponse(BaseModel):
    id:                    int
    title:                 str
    description:           str
    venue:                 str
    date:                  datetime
    category:              str
    is_approved:           bool
    organizer_id:          Optional[int]
    image_urls:            Optional[str] = ""       # stored as comma-separated
    registration_url:      Optional[str] = None
    registration_url_type: Optional[str] = None

    model_config = {"from_attributes": True}