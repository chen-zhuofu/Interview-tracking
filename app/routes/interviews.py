from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models import Application, Interview
from app.schemas import InterviewCreate, InterviewResponse

router = APIRouter()

VALID_INTERVIEW_TYPES = {"phone", "video", "onsite"}


def _validate_interview_type(itype: str) -> None:
    if itype not in VALID_INTERVIEW_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid interview_type: '{itype}'. "
            f"Must be one of: {', '.join(sorted(VALID_INTERVIEW_TYPES))}",
        )


class InterviewUpdate(BaseModel):
    application_id: Optional[int] = None
    interview_type: Optional[str] = None
    scheduled_time: Optional[datetime] = None
    interviewer: Optional[str] = None
    result: Optional[str] = None
    notes: Optional[str] = None


@router.get("/", response_model=List[InterviewResponse])
def list_interviews(
    upcoming: bool = Query(False),
    db: Session = Depends(get_db),
):
    query = db.query(Interview).options(joinedload(Interview.application))

    if upcoming:
        query = query.filter(
            Interview.interview_date >= datetime.utcnow()
        ).order_by(Interview.interview_date.asc())
    else:
        query = query.order_by(Interview.interview_date.desc())

    return query.all()


@router.post("/", response_model=InterviewResponse, status_code=status.HTTP_201_CREATED)
def create_interview(data: InterviewCreate, db: Session = Depends(get_db)):
    _validate_interview_type(data.interview_type)

    interview = Interview(
        application_id=data.application_id,
        interview_type=data.interview_type,
        interview_date=data.scheduled_time,
        interviewer=data.interviewer,
        result=data.result,
        notes=data.notes,
    )
    db.add(interview)
    db.commit()
    db.refresh(interview)
    return interview


@router.get("/{interview_id}")
def get_interview(interview_id: int, db: Session = Depends(get_db)):
    interview = (
        db.query(Interview)
        .options(joinedload(Interview.application).joinedload(Application.company))
        .filter(Interview.id == interview_id)
        .first()
    )
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    result = InterviewResponse.model_validate(interview).model_dump()
    app = interview.application
    if app:
        result["application"] = {
            "id": app.id,
            "company_id": app.company_id,
            "position": app.position,
            "status": app.status,
        }
        if app.company:
            result["application"]["company"] = {
                "id": app.company.id,
                "name": app.company.name,
            }

    return result


@router.put("/{interview_id}", response_model=InterviewResponse)
def update_interview(
    interview_id: int, data: InterviewUpdate, db: Session = Depends(get_db)
):
    interview = db.query(Interview).filter(Interview.id == interview_id).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    if data.interview_type is not None:
        _validate_interview_type(data.interview_type)

    update_data = data.model_dump(exclude_unset=True)
    if "scheduled_time" in update_data:
        update_data["interview_date"] = update_data.pop("scheduled_time")

    for key, value in update_data.items():
        setattr(interview, key, value)

    db.commit()
    db.refresh(interview)
    return interview


@router.delete("/{interview_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_interview(interview_id: int, db: Session = Depends(get_db)):
    interview = db.query(Interview).filter(Interview.id == interview_id).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    db.delete(interview)
    db.commit()
    return None
