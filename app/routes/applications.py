from typing import Optional
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload
from pydantic import BaseModel

from app.database import get_db
from app.models import Application, Company

router = APIRouter()

VALID_STAGES = Application.VALID_STAGES


# ── Inline request schemas (field names match the acceptance verify script) ─

class AppCreate(BaseModel):
    company_id: int
    position_title: str
    applied_date: Optional[date] = None
    job_description_url: Optional[str] = None
    notes: Optional[str] = None


class AppUpdate(BaseModel):
    company_id: Optional[int] = None
    position_title: Optional[str] = None
    applied_date: Optional[date] = None
    job_description_url: Optional[str] = None
    notes: Optional[str] = None


class StageUpdateIn(BaseModel):
    current_stage: str


# ── Helpers ────────────────────────────────────────────────────────────────

def _app_to_dict(app: Application) -> dict:
    """Map DB model (position/status) to API field names (position_title/current_stage)."""
    return {
        "id": app.id,
        "company_id": app.company_id,
        "position_title": app.position,
        "applied_date": app.applied_date.isoformat() if app.applied_date else None,
        "current_stage": app.status,
        "job_description_url": app.job_description_url,
        "notes": app.notes,
        "last_updated": app.last_updated.isoformat() if app.last_updated else None,
    }


# ── Routes ─────────────────────────────────────────────────────────────────

@router.get("/")
def list_applications(
    stage: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(Application).options(joinedload(Application.company))
    if stage:
        query = query.filter(Application.status == stage)
    apps = query.order_by(Application.last_updated.desc()).all()
    results: list[dict] = []
    for app in apps:
        d = _app_to_dict(app)
        d["company_name"] = app.company.name if app.company else None
        results.append(d)
    return results


@router.post("/", status_code=status.HTTP_201_CREATED)
def create_application(data: AppCreate, db: Session = Depends(get_db)):
    company = db.query(Company).filter(Company.id == data.company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")

    app = Application(
        company_id=data.company_id,
        position=data.position_title,
        applied_date=data.applied_date,
        status="applied",
        job_description_url=data.job_description_url,
        notes=data.notes,
    )
    db.add(app)
    db.commit()
    db.refresh(app)
    return _app_to_dict(app)


@router.get("/{app_id}")
def get_application(app_id: int, db: Session = Depends(get_db)):
    app = (
        db.query(Application)
        .options(joinedload(Application.company), joinedload(Application.interviews))
        .filter(Application.id == app_id)
        .first()
    )
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    d = _app_to_dict(app)
    d["company_name"] = app.company.name if app.company else None
    d["interviews"] = [
        {
            "id": i.id,
            "application_id": i.application_id,
            "interview_type": i.interview_type,
            "interview_date": i.interview_date.isoformat() if i.interview_date else None,
            "interviewer": i.interviewer,
            "result": i.result,
            "notes": i.notes,
            "created_at": i.created_at.isoformat() if i.created_at else None,
        }
        for i in (app.interviews or [])
    ]
    return d


@router.put("/{app_id}")
def update_application(app_id: int, data: AppUpdate, db: Session = Depends(get_db)):
    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    update_data = data.model_dump(exclude_unset=True)
    if "position_title" in update_data:
        app.position = update_data.pop("position_title")
    for key, value in update_data.items():
        setattr(app, key, value)
    db.commit()
    db.refresh(app)
    return _app_to_dict(app)


@router.delete("/{app_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_application(app_id: int, db: Session = Depends(get_db)):
    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    db.delete(app)
    db.commit()
    return None


@router.patch("/{app_id}/stage")
def update_stage(app_id: int, data: StageUpdateIn, db: Session = Depends(get_db)):
    if data.current_stage not in VALID_STAGES:
        raise HTTPException(status_code=422, detail=f"Invalid stage: {data.current_stage}")

    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    app.status = data.current_stage
    db.commit()
    db.refresh(app)
    return _app_to_dict(app)
