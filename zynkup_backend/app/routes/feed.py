from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime
import json

from ..database import get_db
from ..models import FeedPost, User, FeedComment, FeedLike
from ..auth import get_current_user, get_optional_current_user

router = APIRouter(prefix="/feed", tags=["Feed"])

class FeedPostCreate(BaseModel):
    content: str
    image_url: Optional[str] = None
    banner_url: Optional[str] = None
    link_url: Optional[str] = None
    link_title: Optional[str] = None
    link_type: Optional[str] = None
    poll_question: Optional[str] = None
    poll_options: Optional[List[str]] = None
    club_id: Optional[int] = None

class FeedPostUpdate(BaseModel):
    content: Optional[str] = None
    image_url: Optional[str] = None
    banner_url: Optional[str] = None
    link_url: Optional[str] = None
    link_title: Optional[str] = None
    link_type: Optional[str] = None

class FeedPostResponse(BaseModel):
    id: int
    author_id: int
    author_name: Optional[str]
    author_avatar: Optional[str]
    club_id: Optional[int] = None
    club_name: Optional[str] = None
    club_logo: Optional[str] = None
    content: str
    image_url: Optional[str]
    banner_url: Optional[str]
    link_url: Optional[str] = None
    link_title: Optional[str] = None
    link_type: Optional[str] = None
    likes: int
    is_liked: bool = False
    created_at: datetime
    reactions: Dict[str, int] = {}
    user_reaction: Optional[str] = None
    poll: Optional[Dict[str, Any]] = None

    class Config:
        orm_mode = True

class FeedCommentCreate(BaseModel):
    content: str

class FeedCommentResponse(BaseModel):
    id: int
    post_id: int
    author_id: int
    author_name: Optional[str]
    author_avatar: Optional[str]
    content: str
    created_at: datetime

    class Config:
        orm_mode = True

def _detect_link_type(url: Optional[str], provided_type: Optional[str] = None) -> Optional[str]:
    if not url or not url.strip():
        return None
    if provided_type and provided_type.strip():
        return provided_type.strip().lower()
    u = url.lower()
    if "youtube.com" in u or "youtu.be" in u:
        return "youtube"
    if "instagram.com" in u:
        return "instagram"
    if "twitter.com" in u or "x.com" in u:
        return "twitter"
    if "spotify.com" in u:
        return "spotify"
    if "github.com" in u:
        return "github"
    return "general"

@router.post("/", response_model=FeedPostResponse)
def create_post(post_data: FeedPostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    detected_type = _detect_link_type(post_data.link_url, post_data.link_type)
    new_post = FeedPost(
        author_id=current_user.id,
        content=post_data.content,
        image_url=post_data.image_url,
        banner_url=post_data.banner_url,
        link_url=post_data.link_url.strip() if post_data.link_url else None,
        link_title=post_data.link_title.strip() if post_data.link_title else None,
        link_type=detected_type,
        club_id=post_data.club_id
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    if post_data.poll_question and post_data.poll_options:
        from ..models import FeedPoll
        poll = FeedPoll(
            post_id=new_post.id,
            question=post_data.poll_question,
            options=json.dumps(post_data.poll_options),
            votes="{}"
        )
        db.add(poll)
        db.commit()
        db.refresh(new_post)

    poll_dict = None
    if getattr(new_post, 'poll', None):
        poll_dict = {
            "question": new_post.poll.question,
            "options": json.loads(new_post.poll.options),
            "votes": json.loads(new_post.poll.votes) if new_post.poll.votes else {}
        }
        
    club_name = None
    club_logo = None
    if new_post.club_id:
        from ..models import Club
        club = db.query(Club).filter(Club.id == new_post.club_id).first()
        if club:
            club_name = club.name
            club_logo = club.logo_url

        # Broadcast notification to club followers
        try:
            from app.fcm import create_notification_helper
            from app.models import ClubFollower
            followers = db.query(ClubFollower).filter(
                ClubFollower.club_id == new_post.club_id,
                ClubFollower.user_id != current_user.id
            ).all()
            for f in followers:
                create_notification_helper(
                    db=db,
                    user_id=f.user_id,
                    title=f"{club_name or 'Club'} posted an update 📢",
                    body=f"{new_post.content[:80]}...",
                    type="CLUB_NEW_POST",
                    data={"club_id": str(new_post.club_id), "post_id": str(new_post.id)}
                )
        except Exception as notif_err:
            logger.warning(f"Club follower feed notification failed: {notif_err}")

    # Award XP for creating a feed post
    try:
        from app.gamification import add_xp
        add_xp(db, current_user, "create_post")
    except Exception as xp_err:
        pass

    return FeedPostResponse(
        id=new_post.id,
        author_id=new_post.author_id,
        author_name=current_user.name or current_user.display_name,
        author_avatar=current_user.resolved_avatar_url,
        club_id=new_post.club_id,
        club_name=club_name,
        club_logo=club_logo,
        content=new_post.content,
        image_url=new_post.image_url,
        banner_url=new_post.banner_url,
        link_url=new_post.link_url,
        link_title=new_post.link_title,
        link_type=new_post.link_type,
        likes=new_post.likes,
        is_liked=False,
        created_at=new_post.created_at,
        reactions={},
        poll=poll_dict
    )

@router.get("/", response_model=List[FeedPostResponse])
def get_feed(db: Session = Depends(get_db), current_user: Optional[User] = Depends(get_optional_current_user)):
    posts = db.query(FeedPost).filter(FeedPost.report_count < 10).order_by(FeedPost.created_at.desc()).limit(100).all()

    now = datetime.utcnow()
    user_memberships = set()
    interacted_authors = set()
    if current_user:
        from app.models import ClubMember
        user_memberships = {m.club_id for m in db.query(ClubMember).filter(ClubMember.user_id == current_user.id).all()}
        # Authors user liked or commented on
        interacted_authors = {l.post.author_id for l in db.query(FeedLike).filter(FeedLike.user_id == current_user.id).all()}

    def get_score(p):
        age_hours = (now - p.created_at).total_seconds() / 3600
        age_hours = max(0.1, age_hours)
        comments_count = len(p.comments)
        score = (p.likes * 2) + (comments_count * 3)
        
        # Affinity boosts
        if current_user:
            if p.club_id and p.club_id in user_memberships:
                score *= 1.5
            if p.author_id in interacted_authors:
                score *= 1.2
                
        decay = (age_hours + 2) ** 1.5
        return score / decay

    posts.sort(key=get_score, reverse=True)

    liked_post_ids = set()
    if current_user:
        liked_post_ids = {like.post_id for like in db.query(FeedLike).filter(FeedLike.user_id == current_user.id).all()}

    result = []
    for p in posts:
        react_counts = {}
        user_react = None
        for r in p.reactions:
            react_counts[r.emoji] = react_counts.get(r.emoji, 0) + 1
            if current_user and r.user_id == current_user.id:
                user_react = r.emoji

        poll_dict = None
        if p.poll:
            poll_dict = {
                "question": p.poll.question,
                "options": json.loads(p.poll.options),
                "votes": json.loads(p.poll.votes) if p.poll.votes else {}
            }

        result.append(FeedPostResponse(
            id=p.id,
            author_id=p.author_id,
            author_name=p.author.name or p.author.display_name,
            author_avatar=p.author.resolved_avatar_url,
            club_id=p.club_id,
            club_name=p.club.name if p.club else None,
            club_logo=p.club.logo_url if p.club else None,
            content=p.content,
            image_url=p.image_url,
            banner_url=p.banner_url,
            link_url=p.link_url,
            link_title=p.link_title,
            link_type=p.link_type,
            likes=p.likes,
            is_liked=(p.id in liked_post_ids),
            created_at=p.created_at,
            reactions=react_counts,
            user_reaction=user_react,
            poll=poll_dict
        ))
    return result

@router.get("/{post_id}", response_model=FeedPostResponse)
def get_post(post_id: int, db: Session = Depends(get_db), current_user: Optional[User] = Depends(get_optional_current_user)):
    p = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Feed post not found")

    is_liked = False
    if current_user:
        is_liked = db.query(FeedLike).filter(FeedLike.post_id == post_id, FeedLike.user_id == current_user.id).first() is not None

    react_counts = {}
    user_react = None
    for r in p.reactions:
        react_counts[r.emoji] = react_counts.get(r.emoji, 0) + 1
        if current_user and r.user_id == current_user.id:
            user_react = r.emoji

    poll_dict = None
    if p.poll:
        poll_dict = {
            "question": p.poll.question,
            "options": json.loads(p.poll.options),
            "votes": json.loads(p.poll.votes) if p.poll.votes else {}
        }

    return FeedPostResponse(
        id=p.id,
        author_id=p.author_id,
        author_name=p.author.name or p.author.display_name if p.author else None,
        author_avatar=p.author.resolved_avatar_url if p.author else None,
        club_id=p.club_id,
        club_name=p.club.name if p.club else None,
        club_logo=p.club.logo_url if p.club else None,
        content=p.content,
        image_url=p.image_url,
        banner_url=p.banner_url,
        link_url=p.link_url,
        link_title=p.link_title,
        link_type=p.link_type,
        likes=p.likes,
        is_liked=is_liked,
        created_at=p.created_at,
        reactions=react_counts,
        user_reaction=user_react,
        poll=poll_dict
    )

@router.post("/{post_id}/like")
def like_post(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")

    existing_like = db.query(FeedLike).filter(FeedLike.post_id == post_id, FeedLike.user_id == current_user.id).first()
    if existing_like:
        # Unlike
        db.delete(existing_like)
        post.likes = max(0, post.likes - 1)
        db.commit()
        return {"message": "Unliked", "is_liked": False, "likes": post.likes}
    else:
        # Like
        new_like = FeedLike(post_id=post_id, user_id=current_user.id)
        db.add(new_like)
        post.likes += 1
        db.commit()
        return {"message": "Liked", "is_liked": True, "likes": post.likes}

@router.patch("/{post_id}", response_model=FeedPostResponse)
def update_post(post_id: int, post_data: FeedPostUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")
    if post.author_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this post")

    if post_data.content is not None:
        post.content = post_data.content
    if post_data.image_url is not None:
        post.image_url = None if post_data.image_url == "" else post_data.image_url
    if post_data.banner_url is not None:
        post.banner_url = None if post_data.banner_url == "" else post_data.banner_url
    if post_data.link_url is not None:
        clean_link = post_data.link_url.strip() if post_data.link_url else ""
        post.link_url = None if clean_link == "" else clean_link
        post.link_type = _detect_link_type(post.link_url, post_data.link_type) if post.link_url else None
    if post_data.link_title is not None:
        clean_title = post_data.link_title.strip() if post_data.link_title else ""
        post.link_title = None if clean_title == "" else clean_title

    db.commit()
    db.refresh(post)

    club_name = post.club.name if post.club else None
    club_logo = post.club.logo_url if post.club else None

    return FeedPostResponse(
        id=post.id,
        author_id=post.author_id,
        author_name=post.author.name or post.author.display_name if post.author else None,
        author_avatar=post.author.resolved_avatar_url if post.author else None,
        club_id=post.club_id,
        club_name=club_name,
        club_logo=club_logo,
        content=post.content,
        image_url=post.image_url,
        banner_url=post.banner_url,
        link_url=post.link_url,
        link_title=post.link_title,
        link_type=post.link_type,
        likes=post.likes,
        is_liked=False,
        created_at=post.created_at
    )

@router.delete("/{post_id}")
def delete_post(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")
    if post.author_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to delete this post")

    db.delete(post)
    db.commit()
    return {"message": "Post deleted"}

@router.post("/{post_id}/report")
def report_post(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")

    post.is_reported = True
    post.report_count += 1
    db.commit()
    return {"message": "Post reported successfully", "report_count": post.report_count}

@router.post("/{post_id}/comments", response_model=FeedCommentResponse)
def create_comment(post_id: int, comment_data: FeedCommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")

    new_comment = FeedComment(
        post_id=post_id,
        author_id=current_user.id,
        content=comment_data.content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)

    if post.author_id != current_user.id:
        from app.fcm import create_notification_helper, NEW_COMMENT
        create_notification_helper(
            db=db,
            user_id=post.author_id,
            title="New Comment",
            body=f"{current_user.name or current_user.display_name or 'Someone'} commented on your post.",
            type=NEW_COMMENT,
            data={"post_id": str(post_id)}
        )

    # Award XP for commenting on a feed post
    try:
        from app.gamification import add_xp
        add_xp(db, current_user, "create_comment")
    except Exception as xp_err:
        pass

    return FeedCommentResponse(
        id=new_comment.id,
        post_id=new_comment.post_id,
        author_id=new_comment.author_id,
        author_name=current_user.name or current_user.display_name,
        author_avatar=current_user.resolved_avatar_url,
        content=new_comment.content,
        created_at=new_comment.created_at
    )

@router.get("/{post_id}/comments", response_model=List[FeedCommentResponse])
def get_comments(post_id: int, db: Session = Depends(get_db)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Feed post not found")

    comments = db.query(FeedComment).filter(FeedComment.post_id == post_id).order_by(FeedComment.created_at.asc()).all()
    result = []
    for c in comments:
        result.append(FeedCommentResponse(
            id=c.id,
            post_id=c.post_id,
            author_id=c.author_id,
            author_name=c.author.name or c.author.display_name,
            author_avatar=c.author.resolved_avatar_url,
            content=c.content,
            created_at=c.created_at
        ))
    return result

class ReactionCreate(BaseModel):
    emoji: str

@router.post("/{post_id}/react")
def react_post(post_id: int, data: ReactionCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from ..models import FeedReaction
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    existing = db.query(FeedReaction).filter(FeedReaction.post_id == post_id, FeedReaction.user_id == current_user.id).first()
    if existing:
        if existing.emoji == data.emoji:
            db.delete(existing)
            db.commit()
            return {"message": "Reaction removed"}
        else:
            existing.emoji = data.emoji
            db.commit()
            return {"message": "Reaction updated"}

    new_react = FeedReaction(post_id=post_id, user_id=current_user.id, emoji=data.emoji)
    db.add(new_react)
    db.commit()
    return {"message": "Reaction added"}

class VoteCreate(BaseModel):
    option_index: int

@router.post("/{post_id}/poll/vote")
def vote_poll(post_id: int, data: VoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from ..models import FeedPoll
    poll = db.query(FeedPoll).filter(FeedPoll.post_id == post_id).first()
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")

    votes = json.loads(poll.votes) if poll.votes else {}
    votes[str(current_user.id)] = data.option_index
    poll.votes = json.dumps(votes)
    db.commit()
    return {"message": "Vote recorded"}
