from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ── Company ──────────────────────────────────────────────────────────────────

class CompanyCreate(BaseModel):
    name: str
    website: Optional[str] = None
    contact_person: Optional[str] = None
    contact_email: Optional[str] = None
    notes: Optional[str] = None


class CompanyResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    website: Optional[str] = None
    contact_person: Optional[str] = None
    contact_email: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    application_count: int = 0


# ── Application ──────────────────────────────────────────────────────────────

class ApplicationCreate(BaseModel):
    company_id: int
    position: str
    job_description_url: Optional[str] = None
    status: str = "applied"
    applied_date: Optional[date] = None
    notes: Optional[str] = None


class ApplicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    company_id: int
    position: str
    job_description_url: Optional[str] = None
    status: str
    applied_date: Optional[date] = None
    last_updated: datetime
    notes: Optional[str] = None
    interview_count: int = 0


class StageUpdate(BaseModel):
    status: str


# ── Interview ────────────────────────────────────────────────────────────────

class InterviewCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    application_id: int
    interview_type: str
    scheduled_time: datetime = Field(..., alias="interview_date")
    interviewer: Optional[str] = None
    result: Optional[str] = None
    notes: Optional[str] = None


class InterviewUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    application_id: Optional[int] = None
    interview_type: Optional[str] = None
    scheduled_time: Optional[datetime] = Field(None, alias="interview_date")
    interviewer: Optional[str] = None
    result: Optional[str] = None
    notes: Optional[str] = None


class InterviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    application_id: int
    interview_type: str
    interview_date: Optional[datetime] = None
    interviewer: Optional[str] = None
    result: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime


class InterviewDetailCompany(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class InterviewDetailApplication(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    company_id: int
    position: str
    status: str
    company: Optional[InterviewDetailCompany] = None


class InterviewDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    application_id: int
    interview_type: str
    interview_date: Optional[datetime] = None
    interviewer: Optional[str] = None
    result: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    application: Optional[InterviewDetailApplication] = None


# ── Dashboard ────────────────────────────────────────────────────────────────

class DashboardStats(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    total_applications: int = 0
    active_applications: int = 0
    interviews_scheduled: int = 0
    offers_received: int = 0
    by_stage: dict[str, int] = Field(default_factory=dict)
    recent_applications: list["ApplicationResponse"] = Field(default_factory=list)
    upcoming_interviews: list["InterviewResponse"] = Field(default_factory=list)
