---
name: "interview-tracker-web-architecture"
description: "当前交付的 Web 版架构：FastAPI + Jinja2 + SQLite + SortableJS"
type: project
---
面试管理工具当前版本（Web 版）的技术架构：

- **后端**: FastAPI + SQLAlchemy + SQLite（`data/interview_tracker.db`）
- **前端**: Jinja2 模板 + 原生 JS + SortableJS CDN（看板拖拽）
- **启动**: `python run.py`（自动开浏览器）或 Mac 双击 `启动.command`
- **页面**: /kanban（默认，看板拖拽）, /dashboard（仪表盘）, /applications（投递管理）, /companies（公司管理）, /calendar（面试日历）
- **API**: /api/companies, /api/applications, /api/interviews, /api/dashboard, /api/export/applications（CSV UTF-8 BOM）
- **数据模型**: 注意字段名——Application 用 `position`/`status`（非 position_title/current_stage），Interview 用 `interview_date`

**How to verify:** `python -c "from fastapi.testclient import TestClient; from app.main import app; ..."` 可自动化测试全部 API。

**SwiftUI 代码**: 在 `InterviewTracker/` 目录，因 Linux 编译限制已搁置。
