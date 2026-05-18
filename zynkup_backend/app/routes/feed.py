from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import FeedPost, User
from ..auth import get_current_user

router = APIRouter(prefix="/feed", tags=["Feed"])

class FeedPostCreate(BaseModel):
    content: str
    image_url: Optional[str] = None

class FeedPostResponse(BaseModel):
    id: int
    author_id: int
    author_name: Optional[str]
    author_avatar: Optional[str]
    content: str
    image_url: Optional[str]
    likes: int
    created_at: datetime

    class Config:
        orm_mode = True

@router.post("/", response_model=FeedPostResponse)
def create_post(post_data: FeedPostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    new_post = FeedPost(
        author_id=current_user.id,
        content=post_data.content,
        image_url=post_data.image_url
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
