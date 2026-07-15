from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from pydantic import BaseModel

from app.database import get_db
from app.models import Company
from app.schemas import CompanyCreate, CompanyResponse

router = APIRouter()


class CompanyUpdate(BaseModel):
    name: Optional[str] = None
    website: Optional[str] = None
    contact_person: Optional[str] = None
    contact_email: Optional[str] = None
    notes: Optional[str] = None


def _build_response(company: Company) -> CompanyResponse:
    resp = CompanyResponse.model_validate(company)
    resp.application_count = len(company.applications)
    return resp


@router.get("/", response_model=List[CompanyResponse])
def list_companies(db: Session = Depends(get_db)):
    companies = (
        db.query(Company)
        .options(joinedload(Company.applications))
        .order_by(Company.created_at.desc())
        .all()
    )
    return [_build_response(c) for c in companies]


@router.post("/", response_model=CompanyResponse, status_code=status.HTTP_201_CREATED)
def create_company(data: CompanyCreate, db: Session = Depends(get_db)):
    company = Company(**data.model_dump())
    db.add(company)
    db.commit()
    db.refresh(company)
    return _build_response(company)


@router.get("/{company_id}", response_model=CompanyResponse)
def get_company(company_id: int, db: Session = Depends(get_db)):
    company = (
        db.query(Company)
        .options(joinedload(Company.applications))
        .filter(Company.id == company_id)
        .first()
    )
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    return _build_response(company)


@router.put("/{company_id}", response_model=CompanyResponse)
def update_company(company_id: int, data: CompanyUpdate, db: Session = Depends(get_db)):
    company = (
        db.query(Company)
        .options(joinedload(Company.applications))
        .filter(Company.id == company_id)
        .first()
    )
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(company, key, value)
    db.commit()
    db.refresh(company)
    return _build_response(company)


@router.delete("/{company_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_company(company_id: int, db: Session = Depends(get_db)):
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    db.delete(company)
    db.commit()
    return None
