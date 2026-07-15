# 本地面试流程管理工具 — 开发计划

## 架构概览
- **后端**: FastAPI + SQLAlchemy + SQLite
- **前端**: Jinja2 模板 + Vanilla JS + SortableJS (CDN)
- **启动**: `python run.py` 自动启动服务器并打开浏览器
- **风格**: 中文界面，深色侧边栏，类似 Notion/Linear 的现代风格

## 数据模型
- **Company**: id, name(unique), website, city, industry, notes, created_at, updated_at
- **Application**: id, company_id(FK), position_title, salary_range, applied_date, current_stage, job_link, jd_description, notes, created_at, updated_at
- **Interview**: id, application_id(FK), interview_type(phone/video/onsite), scheduled_time, interviewer, notes, result(pending/passed/failed), created_at, updated_at
- **阶段流转**: applied → resume_screening → first_interview → second_interview → third_interview → hr_interview → offer → accepted / rejected
- **级联删除**: Company 删除 → Application 删除 → Interview 删除

---

- [x] Task 1: 项目脚手架 — 目录结构、依赖、数据库模型、FastAPI 空壳 (deps: none)
  - **Objective**: 创建项目骨架，让所有后续任务可以在此基础上构建。
  - **Detailed requirements**:
    - 创建目录: `app/`, `app/routes/`, `app/templates/`, `static/css/`, `static/js/`, `data/`
    - 编写 `requirements.txt`: fastapi, uvicorn[standard], sqlalchemy, jinja2, python-multipart
    - 编写 `app/database.py`: SQLAlchemy engine (SQLite `data/interview_tracker.db`), SessionLocal, Base, get_db
    - 编写 `app/models.py`: Company, Application, Interview 三个模型，包含所有字段、关系、级联删除配置。valid stages: applied, resume_screening, first_interview, second_interview, third_interview, hr_interview, offer, accepted, rejected
    - 编写 `app/schemas.py`: Pydantic v2 请求/响应模型，使用 `model_config = ConfigDict(from_attributes=True)`。包含 CompanyCreate/Response, ApplicationCreate/Response/StageUpdate, InterviewCreate/Response, DashboardStats
    - 编写 `app/main.py`: FastAPI app 骨架，包含 CORS、健康检查 `/api/health`，预置所有 router 占位导入和注册（stub 路由文件先在 routes 目录创建占位），Jinja2Templates 配置，StaticFiles 挂载
    - 创建占位路由文件: `app/routes/__init__.py`, `app/routes/companies.py`(空 router), `app/routes/applications.py`(空 router), `app/routes/interviews.py`(空 router), `app/routes/dashboard.py`(空 router)
  - **Acceptance spec**:
    - `pip install -r requirements.txt` 无错误完成
    - `python -c "from app.database import engine; from app.models import Base; Base.metadata.create_all(engine); print('OK')"` 打印 OK 并创建 `data/interview_tracker.db`
    - `sqlite3 data/interview_tracker.db ".schema"` 显示 3 张表及正确列
    - `python -c "from app.main import app; from fastapi.testclient import TestClient; c=TestClient(app); r=c.get('/api/health'); assert r.status_code==200; print('OK')"` 打印 OK
  - **Deliverables**:
    - Create: `requirements.txt`
    - Create: `app/__init__.py`
    - Create: `app/database.py`
    - Create: `app/models.py`
    - Create: `app/schemas.py`
    - Create: `app/main.py`
    - Create: `app/routes/__init__.py`
    - Create: `app/routes/companies.py` (stub)
    - Create: `app/routes/applications.py` (stub)
    - Create: `app/routes/interviews.py` (stub)
    - Create: `app/routes/dashboard.py` (stub)
    - Create: `data/.gitkeep`
  - **Verify**:
    ```
    pip install -r requirements.txt
    python -c "from app.database import engine; from app.models import Base; Base.metadata.create_all(engine)"
    sqlite3 data/interview_tracker.db ".schema"
    python -c "from app.main import app; from fastapi.testclient import TestClient; c=TestClient(app); r=c.get('/api/health'); assert r.status_code==200; print('OK')"
    ```
  - **Out of scope**: 路由实际实现（task 2-5），模板和静态文件（task 6-10），启动脚本（task 11）

- [x] Task 2: 后端 API — 公司 CRUD 路由 (deps: task 1)
  - **Objective**: 公司记录的完整 REST API：列表、创建、读取、更新、删除。
  - **Detailed requirements**:
    - 实现 `app/routes/companies.py`: APIRouter(prefix="/api/companies")
    - `GET /api/companies` — 按 created_at desc 列出所有公司
    - `POST /api/companies` — 创建公司，返回 201
    - `GET /api/companies/{id}` — 按 ID 获取单个公司，或 404
    - `PUT /api/companies/{id}` — 更新公司（支持部分更新），或 404
    - `DELETE /api/companies/{id}` — 删除公司（级联删除关联的 applications 和 interviews），返回 204 或 404
    - 所有端点使用 `db: Session = Depends(get_db)`
  - **Acceptance spec**:
    - POST 创建 "字节跳动" → 201 + JSON 含 id/name/city/industry/created_at
    - GET 列表 → 200 + 包含刚创建的公司
    - GET /{id} → 200 + 单条 JSON
    - PUT /{id} 更新 name → 200 + 更新后的数据
    - DELETE /{id} → 204，再次 GET → 404
    - GET /99999 → 404
  - **Deliverables**:
    - Modify: `app/routes/companies.py` (替换 stub)
  - **Verify**:
    ```
    python -c "
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, Base
Base.metadata.create_all(engine)
c = TestClient(app)
r = c.post('/api/companies', json={'name':'测试公司','city':'上海','industry':'金融'})
assert r.status_code == 201
cid = r.json()['id']
r = c.get('/api/companies'); assert r.status_code == 200 and len(r.json()) == 1
r = c.get(f'/api/companies/{cid}'); assert r.status_code == 200
r = c.put(f'/api/companies/{cid}', json={'name':'更新公司'}); assert r.status_code == 200 and r.json()['name'] == '更新公司'
r = c.delete(f'/api/companies/{cid}'); assert r.status_code == 204
r = c.get(f'/api/companies/{cid}'); assert r.status_code == 404
print('OK')
"
    ```
  - **Out of scope**: Application/Interview 路由，Dashboard 统计，模板

- [x] Task 3: 后端 API — 投递 CRUD 路由 + 阶段流转 (deps: task 1)
  - **Objective**: 投递记录完整 REST API + 阶段更新接口。
  - **Detailed requirements**:
    - 实现 `app/routes/applications.py`: APIRouter(prefix="/api/applications")
    - `GET /api/applications` — 列出所有投递（含公司名称），支持 `?stage=xxx` 过滤
    - `POST /api/applications` — 创建投递，需要 company_id/position_title/applied_date，返回 201
    - `GET /api/applications/{id}` — 获取单条（含公司信息和面试列表）
    - `PUT /api/applications/{id}` — 全量更新
    - `DELETE /api/applications/{id}` — 删除 + 级联面试，返回 204
    - `PATCH /api/applications/{id}/stage` — 仅更新 current_stage，校验 9 个有效值，无效返回 422
  - **Acceptance spec**:
    - 先创建公司，POST 投递 → 201 + current_stage='applied'
    - `?stage=applied` 过滤正确；`?stage=first_interview` 返回空
    - PATCH stage 有效值 → 200；无效值 → 422
    - 删除公司 → 级联删除投递（验证投递消失）
  - **Deliverables**:
    - Modify: `app/routes/applications.py` (替换 stub)
  - **Verify**:
    ```
    python -c "
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, Base
Base.metadata.create_all(engine)
c = TestClient(app)
r = c.post('/api/companies', json={'name':'测试'})
cid = r.json()['id']
r = c.post('/api/applications', json={'company_id':cid,'position_title':'工程师','applied_date':'2025-01-15'})
assert r.status_code == 201 and r.json()['current_stage'] == 'applied'
aid = r.json()['id']
r = c.get('/api/applications?stage=applied'); assert r.status_code == 200 and len(r.json()) == 1
r = c.get('/api/applications?stage=first_interview'); assert r.status_code == 200 and len(r.json()) == 0
r = c.patch(f'/api/applications/{aid}/stage', json={'current_stage':'first_interview'})
assert r.status_code == 200 and r.json()['current_stage'] == 'first_interview'
r = c.patch(f'/api/applications/{aid}/stage', json={'current_stage':'bad'})
assert r.status_code == 422
print('OK')
"
    ```
  - **Out of scope**: Interview 路由，Dashboard 统计，模板

- [x] Task 4: 后端 API — 面试 CRUD 路由 (deps: task 1)
  - **Objective**: 面试事件记录的完整 REST API。
  - **Detailed requirements**:
    - 实现 `app/routes/interviews.py`: APIRouter(prefix="/api/interviews")
    - `GET /api/interviews` — 列出所有面试，按 scheduled_time desc；支持 `?upcoming=true` 只返回未来面试（按时间升序）
    - `POST /api/interviews` — 创建面试，需要 application_id/interview_type/scheduled_time，返回 201
    - `GET /api/interviews/{id}` — 获取单条（含投递信息）
    - `PUT /api/interviews/{id}` — 全量更新
    - `DELETE /api/interviews/{id}` — 删除，返回 204
    - interview_type 校验：只允许 phone/video/onsite，无效返回 422
  - **Acceptance spec**:
    - 创建未来面试 → 201 + 所有字段
    - `?upcoming=true` 只返回未来面试，按时间升序
    - PUT 更新字段正确；DELETE 删除记录
    - 无效 interview_type → 422
  - **Deliverables**:
    - Modify: `app/routes/interviews.py` (替换 stub)
  - **Verify**:
    ```
    python -c "
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, Base
from datetime import datetime, timedelta
Base.metadata.create_all(engine)
c = TestClient(app)
r = c.post('/api/companies', json={'name':'测试'})
cid = r.json()['id']
r = c.post('/api/applications', json={'company_id':cid,'position_title':'开发','applied_date':'2025-01-01'})
aid = r.json()['id']
future = (datetime.utcnow() + timedelta(days=7)).isoformat()
r = c.post('/api/interviews', json={'application_id':aid,'interview_type':'video','scheduled_time':future,'interviewer':'张三'})
assert r.status_code == 201
past = (datetime.utcnow() - timedelta(days=7)).isoformat()
r = c.post('/api/interviews', json={'application_id':aid,'interview_type':'phone','scheduled_time':past})
assert r.status_code == 201
r = c.get('/api/interviews?upcoming=true')
assert r.status_code == 200 and len(r.json()) == 1
r = c.post('/api/interviews', json={'application_id':aid,'interview_type':'email','scheduled_time':future})
assert r.status_code == 422
print('OK')
"
    ```
  - **Out of scope**: Dashboard 统计、模板

- [x] Task 5: 后端 API — Dashboard 统计端点 (deps: task 1)
  - **Objective**: 单一聚合端点返回仪表盘所有指标。
  - **Detailed requirements**:
    - 实现 `app/routes/dashboard.py`: APIRouter(prefix="/api")
    - `GET /api/dashboard/stats` 返回:
      ```json
      {
        "total_applications": 15,
        "stage_counts": {"applied": 3, ...},
        "upcoming_interviews": [{...}],
        "this_week_interviews": [{...}],
        "recent_activities": [{...}]
      }
      ```
    - stage_counts: 按 current_stage GROUP BY
    - this_week_interviews: 本周一 00:00 到周日 23:59 的面试
    - recent_activities: 最近 10 条更新的投递（按 updated_at desc）
  - **Acceptance spec**:
    - 0 条记录时返回 zeros 和空列表
    - 有数据时：总数正确，stage_counts 总和 = total_applications，upcoming/this_week 过滤正确
  - **Deliverables**:
    - Modify: `app/routes/dashboard.py` (替换 stub)
  - **Verify**:
    ```
    python -c "
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, Base
Base.metadata.create_all(engine)
c = TestClient(app)
r = c.get('/api/dashboard/stats')
assert r.status_code == 200
d = r.json()
assert d['total_applications'] == 0
assert d['stage_counts'] == {}
assert d['upcoming_interviews'] == []
print('OK')
"
    ```
  - **Out of scope**: 活动日志表、图表渲染（前端负责）

- [x] Task 6: 前端 — 基础模板、CSS 设计系统和导航框架 (deps: none)
  - **Objective**: 创建所有页面共享的视觉基础：CSS 设计变量、布局框架、侧边栏导航。
  - **Detailed requirements**:
    - 编写 `static/css/style.css`:
      - CSS 自定义属性：`--color-bg`, `--color-surface`, `--color-primary`(#4F46E5), `--color-text`, `--color-border`, `--radius-md`, `--shadow-sm`
      - 系统字体栈（macOS 优先）：`-apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif`
      - 深色侧边栏（240px 固定左侧）+ 白色主内容区（右侧滚动）
      - 导航链接：仪表盘、看板视图、投递管理、公司管理、面试日历
      - 工具类：`.btn`, `.btn-primary`, `.btn-danger`, `.btn-sm`, `.card`, `.badge`, `.modal-overlay`, `.modal`, `.form-group`, `.form-label`, `.form-input`
      - 阶段 badge 颜色：applied=gray, resume_screening=blue, first_interview=indigo, second_interview=purple, third_interview=violet, hr_interview=orange, offer=green, accepted=emerald, rejected=red
      - 响应式：768px 以下侧边栏折叠为顶部导航
    - 编写 `app/templates/base.html`:
      - HTML5 骨架，UTF-8，viewport meta
      - 引入 `/static/css/style.css`
      - 模板 block：`title`, `head`, `content`, `scripts`
      - 侧边栏导航，`request.path` 高亮当前页
      - 所有链接使用 `url_for`
  - **Acceptance spec**:
    - 浏览器打开 → 侧边栏深色、内容区白色
    - 中文字体渲染为 PingFang SC / 系统字体
    - 9 种阶段 badge 各有不同颜色
    - 768px 以下侧边栏折叠
  - **Deliverables**:
    - Create: `static/css/style.css`
    - Create: `app/templates/base.html`
  - **Verify**:
    - 启动 `uvicorn app.main:app --port 8000`，访问任意页面（即使 404），检查侧边栏和样式
    - DevTools 检查各 badge class 颜色
    - 调整窗口大小验证响应式
  - **Out of scope**: 任何页面具体内容（task 7-10），main.py 路由注册（task 11 统一处理）

- [x] Task 7: 前端 — 仪表盘页面 (deps: task 6)
  - **Objective**: 仪表盘页面：统计卡片、阶段分布条、本周面试、近期活动。
  - **Detailed requirements**:
    - 编写 `app/templates/dashboard.html`: extends `base.html`
    - 四张统计卡片：投递总数、面试中、已发 Offer、本周面试
    - 阶段分布：纯 CSS 横向条形图（div 宽度按比例）
    - 本周面试列表：卡片显示公司名、职位、面试类型 badge、时间（MM-DD HH:mm）
    - 近期活动列表
    - 编写 `static/js/dashboard.js`: fetch `/api/dashboard/stats`，渲染所有区块
    - 阶段中文映射：applied=投递, resume_screening=简历筛选, first_interview=一面, second_interview=二面, third_interview=三面, hr_interview=HR面, offer=Offer, accepted=入职, rejected=拒绝
    - 空状态显示"暂无数据"
  - **Acceptance spec**:
    - 无数据时各区块显示"暂无数据"
    - 有数据时统计数字正确、条形图比例正确
    - 本周面试过滤正确（3天后显示在"本周"，10天后不显示）
  - **Deliverables**:
    - Create: `app/templates/dashboard.html`
    - Create: `static/js/dashboard.js`
  - **Verify**:
    - 通过 API 种子数据，打开 `/dashboard`（task 11 后路由生效）
    - 检查统计卡片数字、条形图比例、面试类型中文标签
    - 验证空状态占位符
  - **Out of scope**: 图表库、实时更新、从仪表盘下钻

- [x] Task 8: 前端 — 公司管理和投递管理页面 (deps: task 6)
  - **Objective**: 公司和投递的完整 CRUD 界面，含表格、模态表单、阶段快速切换。
  - **Detailed requirements**:
    - 编写 `app/templates/companies.html`: 公司表格（名称、城市、行业、官网、备注、操作），"添加公司"模态表单，编辑/删除按钮
    - 编写 `app/templates/applications.html`: 投递表格（职位、公司、阶段badge、投递日期、操作），阶段过滤下拉，"添加投递"模态表单（公司下拉从 API 获取），快速阶段切换按钮
    - 编写 `static/js/companies.js`: 公司 CRUD API 调用
    - 编写 `static/js/applications.js`: 投递 CRUD、阶段过滤、阶段快速切换
    - 中文阶段标签、面试类型标签
  - **Acceptance spec**:
    - 公司 CRUD 完整流程：添加 → 列表显示 → 编辑 → 删除
    - 投递 CRUD：添加时公司下拉正确填充 → 阶段过滤有效 → 快速切换阶段 → 删除
    - 表单验证：必填字段为空时阻止提交
  - **Deliverables**:
    - Create: `app/templates/companies.html`
    - Create: `app/templates/applications.html`
    - Create: `static/js/companies.js`
    - Create: `static/js/applications.js`
  - **Verify**:
    - 完整 CRUD 走查：公司 → 投递 → 编辑 → 过滤 → 删除
    - 阶段过滤下拉功能验证
    - 模态表单必填验证
  - **Out of scope**: 看板拖拽（task 9）、面试管理（task 10）

- [x] Task 9: 前端 — 看板视图页面 (deps: task 6)
  - **Objective**: 默认视图 — 按阶段分列的看板，可拖拽投递卡片。
  - **Detailed requirements**:
    - 编写 `app/templates/kanban.html`: 9 列对应 9 个阶段，每列有阶段标题 + 计数 badge + 可滚动卡片列表
    - 投递卡片：公司名（粗体）、职位、投递日期、面试计数 badge
    - 点击卡片 → 详情模态框（完整投递信息 + 面试历史）
    - 拖拽功能：SortableJS CDN 加载，卡片可在列间拖拽，drop 时调用 `PATCH /api/applications/{id}/stage`，乐观更新，失败回滚
    - 编写 `static/js/kanban.js`: fetch 投递、按阶段分组、渲染列、初始化 SortableJS（group: 'stages'）
  - **Acceptance spec**:
    - 9 列渲染，每列有阶段标题
    - 不同阶段投递出现在正确列
    - 拖拽卡片到新列 → 视觉移动 + API 调用 + 持久化
    - 刷新后卡片保留在新列
    - 网络错误时卡片弹回原位
  - **Deliverables**:
    - Create: `app/templates/kanban.html`
    - Create: `static/js/kanban.js`
  - **Verify**:
    - 种子 5+ 条不同阶段投递 → 打开看板 → 验证各列正确
    - 拖拽卡片 → 检查 PATCH 请求 → 刷新验证持久化
    - DevTools Network throttle Offline → 拖拽 → 验证弹回
  - **Out of scope**: 多卡片拖拽、列内排序、移动端触摸拖拽

- [x] Task 10: 前端 — 面试日历页面 (deps: task 6)
  - **Objective**: 面试日历/列表视图，展示即将到来的面试，支持增删改。
  - **Detailed requirements**:
    - 编写 `app/templates/calendar.html`: "近期面试"和"历史面试"两个区域
    - 面试卡片：公司名、职位、面试类型 badge（电话面/视频面/现场面）、时间（YYYY-MM-DD HH:mm）、面试官、结果 badge（pending=待定/灰色, passed=通过/绿色, failed=未通过/红色）
    - "添加面试"模态表单：投递下拉（显示公司+职位）、类型选择、时间输入、面试官、备注
    - 编辑/删除按钮
    - 近期面试按日期分组（今天、明天、本周、之后）
    - 编写 `static/js/calendar.js`: fetch 面试、分割过去/未来、按日期分组、CRUD
  - **Acceptance spec**:
    - 无面试时显示"暂无近期面试"
    - 明天面试显示在"明天"分组下
    - 上周面试显示在"历史面试"
    - 编辑/删除功能正常
    - 结果 badge 颜色正确
  - **Deliverables**:
    - Create: `app/templates/calendar.html`
    - Create: `static/js/calendar.js`
  - **Verify**:
    - 种子 3 条面试（明天、下周、上周）
    - 打开日历 → 验证分组和过去/未来分割
    - CRUD 走查
  - **Out of scope**: 月视图日历网格、Google Calendar 集成

- [x] Task 11: 集成 — 启动脚本、路由注册、CSV 导出、整体串联 (deps: tasks 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  - **Objective**: 将所有组件串联，创建 `run.py` 启动器，实现 CSV 导出，确保端到端可用。
  - **Detailed requirements**:
    - 编写 `run.py`: 初始化数据库 → 启动 uvicorn → 自动打开浏览器到 `http://127.0.0.1:8000`
    - 更新 `app/main.py`: 注册所有页面路由（/dashboard, /kanban, /applications, /companies, /calendar），/ 重定向到 /kanban
    - 添加 CSV 导出端点 `GET /api/export/applications`: 返回带 BOM 的 UTF-8 CSV 文件，列：公司名称、职位、薪资、投递日期、当前阶段、职位链接、备注
    - 在看板和投递管理页面添加"导出CSV"按钮
    - 验证级联删除：删除公司 → 投递消失 → 面试消失
    - 确保所有导航链接可用
  - **Acceptance spec**:
    - `python run.py` 启动服务器，浏览器自动打开到看板页
    - 5 个导航链接全部可用
    - 完整流程：公司 → 投递 → 阶段拖拽 → 面试 → 仪表盘 → CSV 导出
    - CSV 文件 UTF-8 中文在 Excel 中正确显示
    - 删除公司 → 关联投递和面试全部清除
  - **Deliverables**:
    - Create: `run.py`
    - Modify: `app/main.py` — 所有路由注册、/ 重定向、CSV 导出端点
    - Modify: `app/templates/kanban.html` — 添加导出按钮
    - Modify: `app/templates/applications.html` — 添加导出按钮
  - **Verify**:
    - `python run.py` → 服务器启动，浏览器打开
    - 完整手动走查
    - `curl http://127.0.0.1:8000/api/export/applications` → 有效 CSV + UTF-8 BOM
  - **Out of scope**: PDF 导出、JSON 导出、导入功能

- [x] Task 12: 集成验证与收尾 (deps: task 11)
  - **Objective**: 完整端到端验证，确认所有功能正常。
  - **Detailed requirements**:
    - 启动应用，执行完整用户工作流：
      1. 创建 3 家公司（字节跳动/北京/互联网, 腾讯/深圳/互联网, 华为/深圳/通信）
      2. 创建 5 条投递分布在 3 家公司、不同阶段
      3. 看板拖拽 2 张卡片到新阶段
      4. 添加 3 条面试（一条过去、一条明天、一条下周）
      5. 验证仪表盘：total=5, stage_counts 匹配, upcoming=2, this_week=1
      6. 验证日历：近期面试 2 条分组正确，历史面试 1 条
      7. 导出 CSV 验证内容
      8. 删除一家公司，验证级联
      9. 浏览器 DevTools 无 console 错误
      10. 中文显示正常
  - **Acceptance spec**: 10 步工作流全部通过，无 500 错误，无 JS 错误，CSV 中文正确
  - **Deliverables**: None（仅验证）
  - **Verify**: 手动执行 10 步工作流
  - **Out of scope**: 性能分析、无障碍审计、跨浏览器测试

---

## 执行顺序
```
Task 1 (脚手架)          Task 6 (基础前端)
   ↓                       ↓
Tasks 2→3→4→5 (后端API)   Tasks 7,8,9,10 (前端页面，可并行)
   ↓                       ↓
   └──────────┬────────────┘
              ↓
         Task 11 (集成)
              ↓
         Task 12 (验证)
```

- Task 1 必须先完成（定义数据模型 + main.py 骨架）
- Tasks 2-5 依序执行（后端 API，每步改动小，串行避免 main.py 冲突）
- Task 6 与 Task 1 可同时启动（纯前端，无依赖）
- Tasks 7-10 在 Task 6 完成后可并行（各自独立的模板 + JS 文件）
- Task 11 在所有前后端任务完成后执行
- Task 12 最终验证
