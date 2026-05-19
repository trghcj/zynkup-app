from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import FeedPost, User, FeedComment
from ..auth import get_current_user

router = APIRouter(prefix="/feed", tags=["Feed"])

class FeedPostCreate(BaseModel):
    content: str
    image_url: Optional[str] = None
    banner_url: Optional[str] = None

class FeedPostResponse(BaseModel):
    id: int
    author_id: int
    author_name: Optional[str]
    author_avatar: Optional[str]
    content: str
    image_url: Optional[str]
    banner_url: Optional[str]
    likes: int
    created_at: datetime

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

@router.post("/", response_model=FeedPostResponse)
def create_post(post_data: FeedPostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    new_post = FeedPost(
        author_id=current_user.id,
        content=post_data.content,
        image_url=post_data.image_url,
        banner_url=post_data.banner_url
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    
    return FeedPostResponse(
        id=new_post.id,
        author_id=new_post.author_id,
        author_name=current_user.name or current_user.display_name,
        author_avatar=current_user.avatar_url,
        content=new_post.content,
        image_url=new_post.image_url,
        banner_url=new_post.banner_url,
        likes=new_post.likes,
        created_at=new_post.created_at
    )

@router.get("/", response_model=List[FeedPostResponse])
def get_feed(db: Session = Depends(get_db)):
    posts = db.query(FeedPost).order_by(FeedPost.created_at.desc()).all()
    result = []
    for p in posts:
        result.append(FeedPostResponse(
            id=p.id,
            author_id=p.author_id,
            author_name=p.author.name or p.author.display_name,
            author_avatar=p.author.avatar_url,
            content=p.content,
            image_url=p.image_url,
            banner_url=p.banner_url,
            likes=p.likes,
            created_at=p.created_at
        ))
    return result

@router.post("/{post_id}/like")
def like_post(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(FeedPost).filter(FeedPost.id == post_id).first()
    if post:
        post.likes += 1
        db.commit()
    return {"message": "Liked"}

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

    return FeedCommentResponse(
        id=new_comment.id,
        post_id=new_comment.post_id,
        author_id=new_comment.author_id,
        author_name=current_user.name or current_user.display_name,
        author_avatar=current_user.avatar_url,
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
            author_avatar=c.author.avatar_url,
            content=c.content,
            created_at=c.created_at
        ))
    return result
