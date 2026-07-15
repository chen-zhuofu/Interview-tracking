import csv
import io

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import joinedload

from app.database import SessionLocal
from app.models import Application
from app.routes import (
    companies as companies_router,
    applications as applications_router,
    interviews as interviews_router,
    dashboard as dashboard_router,
)

app = FastAPI(title="Interview Tracker")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Jinja2 Templates
templates = Jinja2Templates(directory="app/templates")

# Static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Health check
@app.get("/api/health")
def health_check():
    return {"status": "ok"}


# ── Page routes ──────────────────────────────────────────────────────────────

@app.get("/dashboard")
def dashboard(request: Request):
    return templates.TemplateResponse(request, "dashboard.html")


@app.get("/kanban")
def kanban(request: Request):
    return templates.TemplateResponse(request, "kanban.html")


@app.get("/applications")
def applications(request: Request):
    return templates.TemplateResponse(request, "applications.html")


@app.get("/companies")
def companies(request: Request):
    return templates.TemplateResponse(request, "companies.html")


@app.get("/calendar")
def calendar(request: Request):
    return templates.TemplateResponse(request, "calendar.html")


@app.get("/")
def root():
    return RedirectResponse(url="/kanban")


# ── CSV Export ───────────────────────────────────────────────────────────────

@app.get("/api/export/applications")
def export_applications_csv():
    db = SessionLocal()
    try:
        apps = (
            db.query(Application)
            .options(joinedload(Application.company))
            .order_by(Application.last_updated.desc())
            .all()
        )

        output = io.StringIO()
        output.write("\ufeff")  # UTF-8 BOM for Excel compatibility
        writer = csv.writer(output)

        writer.writerow(["公司名称", "职位", "薪资", "投递日期", "当前阶段", "职位链接", "备注"])

        for app in apps:
            stage_labels = {
                "applied": "投递",
                "resume_screening": "简历筛选",
                "first_interview": "一面",
                "second_interview": "二面",
                "third_interview": "三面",
                "hr_interview": "HR面",
                "offer": "Offer",
                "accepted": "入职",
                "rejected": "拒绝",
            }
            stage_label = stage_labels.get(app.status, app.status)
            applied_date = app.applied_date.isoformat() if app.applied_date else ""

            writer.writerow([
                app.company.name if app.company else "",
                app.position or "",
                "",  # 薪资 — not tracked in current data model
                applied_date,
                stage_label,
                app.job_description_url or "",
                app.notes or "",
            ])

        csv_content = output.getvalue()
        output.close()

        return StreamingResponse(
            io.BytesIO(csv_content.encode("utf-8")),
            media_type="text/csv; charset=utf-8",
            headers={
                "Content-Disposition": "attachment; filename=applications.csv",
            },
        )
    finally:
        db.close()


# ── Routers ──────────────────────────────────────────────────────────────────

app.include_router(companies_router.router, prefix="/api/companies", tags=["companies"])
app.include_router(applications_router.router, prefix="/api/applications", tags=["applications"])
app.include_router(interviews_router.router, prefix="/api/interviews", tags=["interviews"])
app.include_router(dashboard_router.router, prefix="/api/dashboard", tags=["dashboard"])
