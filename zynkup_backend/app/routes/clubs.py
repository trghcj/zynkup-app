from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import Club, ClubMember, User
from ..auth import get_current_user

router = APIRouter(prefix="/clubs", tags=["Clubs"])

class ClubCreate(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = "general"
    banner_url: Optional[str] = None
    logo_url: Optional[str] = None

class ClubResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    category: Optional[str]
    banner_url: Optional[str]
    logo_url: Optional[str]
    member_count: int
    created_at: datetime
    is_member: bool = False

    class Config:
        orm_mode = True

@router.post("/", response_model=ClubResponse)
def create_club(club_data: ClubCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    existing = db.query(Club).filter(Club.name == club_data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Club name already taken")

    new_club = Club(
        name=club_data.name,
        description=club_data.description,
        category=club_data.category,
        banner_url=club_data.banner_url,
        logo_url=club_data.logo_url,
        creator_id=current_user.id
    )
    db.add(new_club)
    db.commit()
    db.refresh(new_club)

    # Creator is automatically an admin member
    member = ClubMember(club_id=new_club.id, user_id=current_user.id, role="admin")
    db.add(member)
    db.commit()

    return ClubResponse(
        id=new_club.id,
        name=new_club.name,
        description=new_club.description,
        category=new_club.category,
        banner_url=new_club.banner_url,
        logo_url=new_club.logo_url,
        member_count=1,
        created_at=new_club.created_at,
        is_member=True
    )

@router.get("/", response_model=List[ClubResponse])
def get_clubs(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    clubs = db.query(Club).all()
    user_memberships = {m.club_id for m in db.query(ClubMember).filter(ClubMember.user_id == current_user.id).all()}
    
    result = []
    for c in clubs:
        count = db.query(ClubMember).filter(ClubMember.club_id == c.id).count()
        result.append(ClubResponse(
            id=c.id,
            name=c.name,
            description=c.description,
            category=c.category,
            banner_url=c.banner_url,
            logo_url=c.logo_url,
            member_count=count,
            created_at=c.created_at,
            is_member=(c.id in user_memberships)
        ))
    return result

@router.post("/{club_id}/join")
def join_club(club_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    club = db.query(Club).filter(Club.id == club_id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
        
    existing = db.query(ClubMember).filter(ClubMember.club_id == club_id, ClubMember.user_id == current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already a member")
        
    member = ClubMember(club_id=club_id, user_id=current_user.id, role="member")
    db.add(member)
    db.commit()
    return {"message": "Joined club successfully"}
