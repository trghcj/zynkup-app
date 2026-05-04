# app/models.py
import uuid
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import relationship
from .database import Base


class User(Base):
    __tablename__ = "users"

    id           = Column(Integer, primary_key=True, index=True)
    email        = Column(String, unique=True, nullable=False, index=True)
    password     = Column(String, nullable=True)   # nullable for Google OAuth users
    google_id    = Column(String, unique=True, nullable=True, index=True)
    name         = Column(String, nullable=True)
    avatar_url   = Column(Text, nullable=True)
    role         = Column(String, nullable=False, default="user")
    created_at   = Column(DateTime, server_default=func.now())

    # Profile extras
    display_name = Column(String, nullable=True)
    phone        = Column(String, nullable=True)
    branch       = Column(String, nullable=True)
    year         = Column(String, nullable=True)
    enrollment   = Column(String, nullable=True)
    college      = Column(String, nullable=True, default="MAIT")
    bio          = Column(String, nullable=True)

    events        = relationship("Event", back_populates="creator")
    registrations = relationship("Registration", back_populates="user")


class Event(Base):
    __tablename__ = "events"

    id                    = Column(Integer, primary_key=True, index=True)
    title                 = Column(String, nullable=False)
    description           = Column(String, nullable=False)
    venue                 = Column(String, nullable=False)
    date                  = Column(DateTime, nullable=False)
    category              = Column(String, nullable=False)
    # Auto-approved — no admin needed
    is_approved           = Column(Boolean, default=True, nullable=False)
    created_at            = Column(DateTime, server_default=func.now())
    creator_id            = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Media
    image_urls            = Column(Text, nullable=True, default="")
    # Post-event gallery
    gallery_files         = Column(Text, nullable=True, default="")

    # Registration link / QR
    registration_url      = Column(String, nullable=True)
    registration_url_type = Column(String, nullable=True)

    # Spam control: max events per day per user enforced in route
    is_reported           = Column(Boolean, default=False, nullable=False)
    report_count          = Column(Integer, default=0, nullable=False)

    creator       = relationship("User", back_populates="events")
    registrations = relationship("Registration", back_populates="event",
                                 cascade="all, delete-orphan")


class Registration(Base):
    __tablename__ = "registrations"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    event_id   = Column(Integer, ForeignKey("events.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    # QR code — unique per registration
    qr_code    = Column(String, unique=True, nullable=False,
                        default=lambda: str(uuid.uuid4()))
    # Attendance tracking
    attended   = Column(Boolean, default=False, nullable=False)
    attended_at = Column(DateTime, nullable=True)

    user  = relationship("User", back_populates="registrations")
    event = relationship("Event", back_populates="registrations")