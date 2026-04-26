from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, func, Text
from sqlalchemy.orm import relationship
from .database import Base


class User(Base):
    __tablename__ = "users"

    id           = Column(Integer, primary_key=True, index=True)
    email        = Column(String, unique=True, nullable=False, index=True)
    password     = Column(String, nullable=False)
    role         = Column(String, nullable=False, default="user")
    created_at   = Column(DateTime, server_default=func.now())

    # ── Profile fields ────────────────────────────────────────────────────────
    name         = Column(String, nullable=True)
    display_name = Column(String, nullable=True)
    phone        = Column(String, nullable=True)
    branch       = Column(String, nullable=True)
    year         = Column(String, nullable=True)
    enrollment   = Column(String, nullable=True)
    college      = Column(String, nullable=True, default="MAIT")
    bio          = Column(String, nullable=True)
    avatar_url   = Column(String, nullable=True)

    # Relationships
    events        = relationship("Event", back_populates="organizer")
    registrations = relationship("Registration", back_populates="user")


class Event(Base):
    __tablename__ = "events"

    id           = Column(Integer, primary_key=True, index=True)
    title        = Column(String, nullable=False)
    description  = Column(String, nullable=False)
    venue        = Column(String, nullable=False)
    date         = Column(DateTime, nullable=False)
    category     = Column(String, nullable=False)
    is_approved  = Column(Boolean, default=False, nullable=False)
    created_at   = Column(DateTime, server_default=func.now())
    organizer_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    # ── NEW: Images & Registration QR ────────────────────────────────────────
    # Stored as comma-separated URLs (simple, no extra table needed)
    image_urls            = Column(Text, nullable=True, default="")
    registration_url      = Column(String, nullable=True)
    registration_url_type = Column(String, nullable=True)  # "googleForm" | "customUrl"

    organizer     = relationship("User", back_populates="events")
    registrations = relationship("Registration", back_populates="event")


class Registration(Base):
    __tablename__ = "registrations"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    event_id   = Column(Integer, ForeignKey("events.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    user  = relationship("User", back_populates="registrations")
    event = relationship("Event", back_populates="registrations")