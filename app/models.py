from datetime import datetime

from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Company(Base):
    __tablename__ = "companies"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    website = Column(String(500), nullable=True)
    contact_person = Column(String(255), nullable=True)
    contact_email = Column(String(255), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    applications = relationship(
        "Application", back_populates="company", cascade="all, delete-orphan"
    )


class Application(Base):
    __tablename__ = "applications"

    VALID_STAGES = [
        "applied",
        "resume_screening",
        "first_interview",
        "second_interview",
        "third_interview",
        "hr_interview",
        "offer",
        "accepted",
        "rejected",
    ]

    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, ForeignKey("companies.id"), nullable=False)
    position = Column(String(255), nullable=False)
    job_description_url = Column(String(1000), nullable=True)
    status = Column(String(50), nullable=False, default="applied")
    applied_date = Column(Date, nullable=True)
    last_updated = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    notes = Column(Text, nullable=True)

    company = relationship("Company", back_populates="applications")
    interviews = relationship(
        "Interview", back_populates="application", cascade="all, delete-orphan"
    )


class Interview(Base):
    __tablename__ = "interviews"

    id = Column(Integer, primary_key=True, index=True)
    application_id = Column(Integer, ForeignKey("applications.id"), nullable=False)
    interview_type = Column(String(255), nullable=False)
    interview_date = Column(DateTime, nullable=True)
    interviewer = Column(String(255), nullable=True)
    result = Column(String(255), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    application = relationship("Application", back_populates="interviews")
