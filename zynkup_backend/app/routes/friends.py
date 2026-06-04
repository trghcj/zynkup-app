from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional

from app import models
from app.database import get_db
from app.auth import get_current_user

router = APIRouter(prefix="/friends", tags=["Friends"])

class FriendRequestResponse(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    status: str
    sender_name: Optional[str]
    sender_avatar: Optional[str]
    receiver_name: Optional[str]
    receiver_avatar: Optional[str]
    
    class Config:
        orm_mode = True

class FriendResponse(BaseModel):
    user_id: int
    name: Optional[str]
    avatar_url: Optional[str]
    bio: Optional[str]

@router.post("/request/{user_id}")
def send_friend_request(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot send friend request to yourself")
        
    target_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    existing = db.query(models.FriendRequest).filter(
        ((models.FriendRequest.sender_id == current_user.id) & (models.FriendRequest.receiver_id == user_id)) |
        ((models.FriendRequest.sender_id == user_id) & (models.FriendRequest.receiver_id == current_user.id))
    ).first()
    
    if existing:
        if existing.status == "pending":
            raise HTTPException(status_code=400, detail="Friend request already pending")
        if existing.status == "accepted":
            raise HTTPException(status_code=400, detail="Already friends")
        existing.status = "pending"
        existing.sender_id = current_user.id
        existing.receiver_id = user_id
        db.commit()
        return {"message": "Friend request sent"}
        
    freq = models.FriendRequest(sender_id=current_user.id, receiver_id=user_id, status="pending")
    db.add(freq)
    db.commit()
    return {"message": "Friend request sent"}

@router.put("/request/{request_id}/accept")
def accept_friend_request(request_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    freq = db.query(models.FriendRequest).filter(models.FriendRequest.id == request_id).first()
    if not freq:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if freq.receiver_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    if freq.status != "pending":
        raise HTTPException(status_code=400, detail="Request is not pending")
        
    freq.status = "accepted"
    
    sender = db.query(models.User).filter(models.User.id == freq.sender_id).first()
    if sender:
        sender.xp = (sender.xp or 0) + 5
    current_user.xp = (current_user.xp or 0) + 5
    
    db.commit()
    return {"message": "Friend request accepted"}

@router.put("/request/{request_id}/decline")
def decline_friend_request(request_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    freq = db.query(models.FriendRequest).filter(models.FriendRequest.id == request_id).first()
    if not freq:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if freq.receiver_id != current_user.id and freq.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    db.delete(freq)
    db.commit()
    return {"message": "Friend request declined/canceled"}

@router.get("/pending", response_model=List[FriendRequestResponse])
def get_pending_requests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    requests = db.query(models.FriendRequest).filter(
        (models.FriendRequest.receiver_id == current_user.id) & 
        (models.FriendRequest.status == "pending")
    ).all()
    
    res = []
    for r in requests:
        res.append({
            "id": r.id,
            "sender_id": r.sender_id,
            "receiver_id": r.receiver_id,
            "status": r.status,
            "sender_name": r.sender.name or r.sender.display_name,
            "sender_avatar": r.sender.resolved_avatar_url,
            "receiver_name": r.receiver.name or r.receiver.display_name,
            "receiver_avatar": r.receiver.resolved_avatar_url
        })
    return res

@router.get("/", response_model=List[FriendResponse])
def get_friends(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    friendships = db.query(models.FriendRequest).filter(
        ((models.FriendRequest.sender_id == current_user.id) | (models.FriendRequest.receiver_id == current_user.id)) & 
        (models.FriendRequest.status == "accepted")
    ).all()
    
    res = []
    for f in friendships:
        friend_user = f.receiver if f.sender_id == current_user.id else f.sender
        res.append({
            "user_id": friend_user.id,
            "name": friend_user.name or friend_user.display_name,
            "avatar_url": friend_user.resolved_avatar_url,
            "bio": friend_user.bio
        })
    return res
