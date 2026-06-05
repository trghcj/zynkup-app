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
    role         = Column(String, nullable=False, default="ROLE_USER")
    fcm_token    = Column(String, nullable=True)
    created_at   = Column(DateTime, server_default=func.now())

    # Profile extras
    display_name = Column(String, nullable=True)
    phone        = Column(String, nullable=True)
    branch       = Column(String, nullable=True)
    year         = Column(String, nullable=True)
    enrollment   = Column(String, nullable=True)
    college      = Column(String, nullable=True, default="MAIT")
    bio          = Column(String, nullable=True)

    # ── Gamification ──────────────────────────────────────────────────────────
    xp           = Column(Integer, default=0, nullable=False)
    level        = Column(Integer, default=1, nullable=False)
    streak       = Column(Integer, default=0, nullable=False)
    last_active  = Column(DateTime, nullable=True)
    achievements = Column(Text, nullable=True, default="[]") # JSON list of IDs
    avatar_seed  = Column(String, nullable=True)
    avatar_type  = Column(String, nullable=True, default="rings") # rings, neon, etc.
    theme        = Column(String, nullable=True, default="midnight_orange")

    events        = relationship("Event", back_populates="creator")
    registrations = relationship("Registration", back_populates="user")
    activities    = relationship("ActivityLog", back_populates="user")

    @property
    def resolved_avatar_url(self) -> str:
        if self.avatar_url:
            return self.avatar_url
            
        seed = self.avatar_seed or self.email or "User"
        type_str = self.avatar_type or "rings"
        
        collection = 'adventurer'
        type_lower = type_str.lower()
        if type_lower == 'neon':
            collection = 'bottts'
        elif type_lower in ['cyber', 'cyberpunk']:
            collection = 'avataaars'
        elif type_lower == 'anime':
            collection = 'pixel-art'
        elif type_lower == 'space':
            collection = 'big-smile'
            
        return f"https://api.dicebear.com/7.x/{collection}/png?seed={seed}&backgroundColor=b6e3f4,c0aede,d1d4f9"


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
    club_id               = Column(Integer, ForeignKey("clubs.id"), nullable=True)

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
    club          = relationship("Club")
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


class ActivityLog(Base):
    __tablename__ = "activities"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    action     = Column(String, nullable=False) # create_event, register, attend, login
    xp_gained  = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="activities")


# ── Phase 3: Major Platform Expansion ───────────────────────────────────────

class Club(Base):
    __tablename__ = "clubs"

    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String, unique=True, nullable=False)
    description = Column(Text, nullable=True)
    category    = Column(String, nullable=True, default="general")
    banner_url  = Column(Text, nullable=True)
    logo_url    = Column(Text, nullable=True)
    gallery_files = Column(Text, nullable=True, default="")
    created_at  = Column(DateTime, server_default=func.now())
    creator_id  = Column(Integer, ForeignKey("users.id"), nullable=False)

    creator = relationship("User")
    members = relationship("ClubMember", back_populates="club", cascade="all, delete-orphan")


class ClubMember(Base):
    __tablename__ = "club_members"

    id         = Column(Integer, primary_key=True, index=True)
    club_id    = Column(Integer, ForeignKey("clubs.id"), nullable=False)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    role       = Column(String, default="member", nullable=False) # owner, moderator, member
    joined_at  = Column(DateTime, server_default=func.now())

    club = relationship("Club", back_populates="members")
    user = relationship("User")


class Notification(Base):
    __tablename__ = "notifications"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    title      = Column(String, nullable=False)
    body       = Column(String, nullable=False)
    type       = Column(String, nullable=False) # system, event, club, level_up
    is_read    = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User")


class FeedPost(Base):
    __tablename__ = "feed_posts"

    id         = Column(Integer, primary_key=True, index=True)
    author_id  = Column(Integer, ForeignKey("users.id"), nullable=False)
    content    = Column(Text, nullable=False)
    image_url  = Column(Text, nullable=True)
    banner_url = Column(Text, nullable=True)
    likes      = Column(Integer, default=0)
    is_reported = Column(Boolean, default=False, nullable=False)
    report_count = Column(Integer, default=0, nullable=False)
    club_id    = Column(Integer, ForeignKey("clubs.id"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    author = relationship("User")
    comments = relationship("FeedComment", back_populates="post", cascade="all, delete-orphan")
    like_records = relationship("FeedLike", back_populates="post", cascade="all, delete-orphan")
    reactions = relationship("FeedReaction", back_populates="post", cascade="all, delete-orphan")
    poll = relationship("FeedPoll", back_populates="post", uselist=False, cascade="all, delete-orphan")
    club = relationship("Club")


class FeedComment(Base):
    __tablename__ = "feed_comments"

    id         = Column(Integer, primary_key=True, index=True)
    post_id    = Column(Integer, ForeignKey("feed_posts.id"), nullable=False)
    author_id  = Column(Integer, ForeignKey("users.id"), nullable=False)
    content    = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    post   = relationship("FeedPost", back_populates="comments")
    author = relationship("User")


class FeedLike(Base):
    __tablename__ = "feed_likes"

    id         = Column(Integer, primary_key=True, index=True)
    post_id    = Column(Integer, ForeignKey("feed_posts.id"), nullable=False)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    post   = relationship("FeedPost", back_populates="like_records")
    user   = relationship("User")


class FeedReaction(Base):
    __tablename__ = "feed_reactions"

    id         = Column(Integer, primary_key=True, index=True)
    post_id    = Column(Integer, ForeignKey("feed_posts.id"), nullable=False)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    emoji      = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    post = relationship("FeedPost", back_populates="reactions")
    user = relationship("User")


class FeedPoll(Base):
    __tablename__ = "feed_polls"

    id         = Column(Integer, primary_key=True, index=True)
    post_id    = Column(Integer, ForeignKey("feed_posts.id"), nullable=False, unique=True)
    question   = Column(Text, nullable=False)
    options    = Column(Text, nullable=False, default="[]")
    votes      = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, server_default=func.now())

    post = relationship("FeedPost", back_populates="poll")


class FriendRequest(Base):
    __tablename__ = "friend_requests"

    id          = Column(Integer, primary_key=True, index=True)
    sender_id   = Column(Integer, ForeignKey("users.id"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status      = Column(String, default="pending", nullable=False) # pending, accepted, declined
    created_at  = Column(DateTime, server_default=func.now())

    sender   = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])


class ClubMessage(Base):
    __tablename__ = "club_messages"

    id         = Column(Integer, primary_key=True, index=True)
    club_id    = Column(Integer, ForeignKey("clubs.id"), nullable=False)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    content    = Column(Text, nullable=True) # made nullable for attachment only messages
    attachment_url = Column(Text, nullable=True)
    attachment_type = Column(String, nullable=True) # image, pdf, doc, sticker, gif
    is_edited  = Column(Boolean, default=False)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    club = relationship("Club")
    user = relationship("User")

class UserHiddenMessage(Base):
    __tablename__ = "user_hidden_messages"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message_id = Column(Integer, ForeignKey("club_messages.id", ondelete="CASCADE"), nullable=False)
    hidden_at  = Column(DateTime, server_default=func.now())

