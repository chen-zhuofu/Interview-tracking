from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.routes import companies, applications, interviews, dashboard

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

# Routers
app.include_router(companies.router, prefix="/api/companies", tags=["companies"])
app.include_router(applications.router, prefix="/api/applications", tags=["applications"])
app.include_router(interviews.router, prefix="/api/interviews", tags=["interviews"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["dashboard"])
