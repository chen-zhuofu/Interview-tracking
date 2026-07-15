from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Application, Company, Interview
from app.schemas import DashboardActivityItem, DashboardInterviewItem, DashboardStats

router = APIRouter()


@router.get("/stats", response_model=DashboardStats)
def get_dashboard_stats(db: Session = Depends(get_db)):
    # total_applications
    total = db.query(func.count(Application.id)).scalar() or 0

    # stage_counts: GROUP BY current_stage (status column)
    stage_rows = (
        db.query(Application.status, func.count(Application.id))
        .group_by(Application.status)
        .all()
    )
    stage_counts = {row[0]: row[1] for row in stage_rows}

    # upcoming_interviews: interview_date >= now, ordered by interview_date asc
    now = datetime.utcnow()
    upcoming_rows = (
        db.query(Interview, Company.name, Application.position)
        .join(Application, Interview.application_id == Application.id)
        .join(Company, Application.company_id == Company.id)
        .filter(Interview.interview_date >= now)
        .order_by(Interview.interview_date.asc())
        .all()
    )
    upcoming_interviews = [
        DashboardInterviewItem(
            id=iv.id,
            application_id=iv.application_id,
            interview_type=iv.interview_type,
            interview_date=iv.interview_date,
            interviewer=iv.interviewer,
            result=iv.result,
            notes=iv.notes,
            created_at=iv.created_at,
            company_name=company_name,
            position_title=position,
        )
        for iv, company_name, position in upcoming_rows
    ]

    # this_week_interviews: Monday 00:00 – Sunday 23:59
    today = now.date()
    monday = today - timedelta(days=today.weekday())
    sunday = monday + timedelta(days=6)
    week_start = datetime.combine(monday, datetime.min.time())
    week_end = datetime.combine(sunday, datetime.max.time())

    this_week_rows = (
        db.query(Interview, Company.name, Application.position)
        .join(Application, Interview.application_id == Application.id)
        .join(Company, Application.company_id == Company.id)
        .filter(
            Interview.interview_date >= week_start,
            Interview.interview_date <= week_end,
        )
        .order_by(Interview.interview_date.asc())
        .all()
    )
    this_week_interviews = [
        DashboardInterviewItem(
            id=iv.id,
            application_id=iv.application_id,
            interview_type=iv.interview_type,
            interview_date=iv.interview_date,
            interviewer=iv.interviewer,
            result=iv.result,
            notes=iv.notes,
            created_at=iv.created_at,
            company_name=company_name,
            position_title=position,
        )
        for iv, company_name, position in this_week_rows
    ]

    # recent_activities: latest 10 updated applications (JOIN company name)
    recent_rows = (
        db.query(Application, Company.name)
        .join(Company, Application.company_id == Company.id)
        .order_by(Application.last_updated.desc())
        .limit(10)
        .all()
    )
    recent_activities = [
        DashboardActivityItem(
            application_id=app.id,
            position_title=app.position,
            company_name=company_name,
            current_stage=app.status,
            updated_at=app.last_updated,
        )
        for app, company_name in recent_rows
    ]

    return DashboardStats(
        total_applications=total,
        stage_counts=stage_counts,
        upcoming_interviews=upcoming_interviews,
        this_week_interviews=this_week_interviews,
        recent_activities=recent_activities,
    )
