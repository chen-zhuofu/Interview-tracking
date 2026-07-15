# 原生 macOS SwiftUI 面试流程管理应用 — 开发计划

## 架构概览
- **框架**: SwiftUI + SwiftData（macOS 14+）
- **导航**: NavigationSplitView 三栏布局（侧边栏 + 内容区）
- **数据**: SwiftData 本地持久化（@Model + @Query 自动刷新）
- **拖拽**: 原生 `.onDrag` + `.onDrop` + `Transferable`
- **风格**: 中文界面，系统原生字体，macOS 原生窗口体验

## 数据模型
- **Company**: id(UUID), name, website, contactPerson, contactEmail, notes, createdAt, →applications(cascade)
- **Application**: id(UUID), company(inverse), position, jobDescriptionURL, status(default "applied"), appliedDate, lastUpdated, notes, →interviews(cascade)
- **Interview**: id(UUID), application(inverse), interviewType(phone/video/onsite), interviewDate, interviewer, result(pending/passed/failed), notes, createdAt
- **9 阶段**: applied → resume_screening → first_interview → second_interview → third_interview → hr_interview → offer → accepted / rejected

## 重要说明
- **当前环境是 Linux**，无法编译/测试 Swift 代码。所有验证需在 macOS 14+ Xcode 上完成。
- 旧 FastAPI Web 版代码已 git 存档，不修改。
- 新项目放在 `InterviewTracker/` 独立目录。

## 执行顺序
```
Task 1 (脚手架+模型)
   ↓
Tasks 2,3,4,5,6,7 (功能视图，可并行)
   ↓
Task 8 (CSV导出，依赖 Task 3)
   ↓
Task 9 (最终集成)
```

---

- [x] Task 1: 项目脚手架 + 数据模型 + 常量 + 三栏导航外壳 (deps: none)
  - **Objective**: 创建 SPM 项目结构，定义全部 SwiftData 模型和阶段常量，搭建 App 入口和三栏导航外壳。
  - **Detailed requirements**:
    - 创建 `InterviewTracker/` 目录及所有子目录结构
    - `Package.swift`: executable target `InterviewTracker`, platforms macOS 14, 无外部依赖
    - `Sources/InterviewTracker/InterviewTrackerApp.swift`: `@main App`，配置 `ModelContainer`（含 Company, Application, Interview 三个模型），通过 `.modelContainer()` 注入到 ContentView
    - `Sources/InterviewTracker/Models/Company.swift`: `@Model final class Company`，属性: id(UUID 主键), name(String 非空), website(String?), contactPerson(String?), contactEmail(String?), notes(String?), createdAt(Date, 默认 now)。`@Relationship(deleteRule: .cascade) var applications: [Application]?`
    - `Sources/InterviewTracker/Models/Application.swift`: `@Model final class Application`，属性: id(UUID), position(String 非空), jobDescriptionURL(String?), status(String, 默认 "applied"), appliedDate(Date?), lastUpdated(Date, 默认 now), notes(String?)。Relationships: company(inverse), interviews(cascade)
    - `Sources/InterviewTracker/Models/Interview.swift`: `@Model final class Interview`，属性: id(UUID), interviewType(String 非空), interviewDate(Date?), interviewer(String?), result(String?, 默认 "pending" 或 nil), notes(String?), createdAt(Date). Relationship: application(inverse)
    - `Sources/InterviewTracker/Models/StageConstants.swift`: 定义 `STAGE_ORDER: [String]`（9 阶段顺序数组），`STAGE_LABELS: [String: String]`（key→中文映射），`INTERVIEW_TYPE_LABELS: [String: String]`（phone→电话面/video→视频面/onsite→现场面），`RESULT_LABELS: [String: String]`（pending→待定/passed→通过/failed→未通过），`INTERVIEWING_STAGES: [String]`（resume_screening ~ hr_interview 五个阶段集合）
    - `Sources/InterviewTracker/ContentView.swift`: `NavigationSplitView`，sidebar 列出 5 个导航项（带 SF Symbol：仪表盘 chart.bar / 看板 rectangle.split.3x1 / 投递管理 doc.text / 公司管理 building.2 / 面试日历 calendar），detail 区使用 `@State selection` + `switch` 切换到对应占位视图。每个占位视图只显示 `Text("功能名称")`。默认选中看板。
    - `InterviewTracker/README.md`: 说明如何在 macOS 上打开（`open Package.swift` 或 `swift build && swift run`），最低系统要求 macOS 14。
  - **Acceptance spec**:
    - `Package.swift` 能在 macOS 上 `swift build` 通过
    - 启动后显示三栏布局，点击每项切换到对应占位视图
    - 数据模型关系正确：Company→Application cascade, Application→Interview cascade
  - **Deliverables**:
    - Create: `InterviewTracker/Package.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/InterviewTrackerApp.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/ContentView.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Models/Company.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Models/Application.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Models/Interview.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Models/StageConstants.swift`
    - Create: `InterviewTracker/README.md`
  - **Verify**: macOS 上 `cd InterviewTracker && swift build` 成功；`swift run` 显示三栏布局窗口
  - **Out of scope**: 不实现任何功能视图的具体业务逻辑（占位即可）；不生成 .app bundle

- [ ] Task 2: 公司管理视图 — 列表 + 表单 CRUD (deps: task 1)
  - **Objective**: 实现完整的公司 CRUD 界面——列表、添加（Sheet 表单）、编辑、删除确认。
  - **Detailed requirements**:
    - `CompanyListView.swift`: `@Query` 查询 Company（按 createdAt 降序）。List 显示每行：name(粗体)、website、contactPerson、applicationCount（`company.applications?.count ?? 0`）。每行有编辑/删除按钮。顶部 toolbar "添加公司" 按钮。删除使用 `.confirmationDialog` 确认。列表为空时显示 "暂无公司" 空状态。
    - `CompanyFormView.swift`: Sheet 表单，字段：name（TextField 必填）、website、contactPerson、contactEmail、notes（TextEditor）。通过传入 `var company: Company?` 区分新建/编辑模式。保存后 `modelContext.insert()` 或自动更新，dismiss。
  - **Acceptance spec**:
    - 无公司时 → 列表显示 "暂无公司"
    - 点击"添加公司" → Sheet 弹出 → 填写 name → 保存 → 列表显示新公司
    - 点击编辑 → Sheet 预填数据 → 修改 → 保存 → 列表更新
    - 删除 → 确认对话框 → 确认 → 公司及关联投递/面试级联删除
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Companies/CompanyListView.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Companies/CompanyFormView.swift`
  - **Verify**: 手动运行应用，在 ContentView 中临时替换占位为 CompanyListView → 测试 CRUD
  - **Out of scope**: 搜索/排序切换、公司详情页

- [ ] Task 3: 投递管理视图 + 阶段流转 (deps: task 1)
  - **Objective**: 投递 CRUD 列表、添加/编辑表单、阶段筛选、快速前后流转按钮。
  - **Detailed requirements**:
    - `ApplicationListView.swift`: `@Query` 查询 Application（SortDescriptor 按 lastUpdated 降序）。顶部 Picker 阶段筛选（"全部" + 9 阶段中文）。List 显示：position、company.name、status（彩色 badge，使用 STAGE_LABELS 映射）、appliedDate。每行：◀▶ 阶段流转按钮（边界阶段禁用对应方向）、编辑、删除。toolbar "添加投递" 按钮。
    - `ApplicationFormView.swift`: Sheet 表单，字段：company（Picker 从 `@Query` 加载所有 Company，显示 name）、position（TextField 必填）、appliedDate（DatePicker）、jobDescriptionURL、notes。新建时 status 默认 "applied"。
    - 阶段流转逻辑：◀ 向前一阶段（基于 STAGE_ORDER 索引-1）、▶ 向后一阶段（索引+1），修改 `app.status` 后 SwiftData 自动保存。
    - 使用 `STAGE_ORDER` 数组做边界判断（第一个元素禁用 ◀，最后一个禁用 ▶）。
    - 删除使用 confirmationDialog 确认。
    - 空状态："暂无投递记录"。
  - **Acceptance spec**:
    - 创建投递时公司列表正确显示所有公司
    - 筛选"简历筛选"→ 仅显示该阶段投递；选"全部"→ 显示所有
    - 点击 ◀ 或 ▶ → 阶段即时变化，badge 更新
    - 编辑 → 修改 position → 保存 → 列表刷新
    - 删除 → 确认 → 投递及关联面试级联删除
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Applications/ApplicationListView.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Applications/ApplicationFormView.swift`
  - **Verify**: 在 ContentView 中集成验证 CRUD + 阶段流转
  - **Out of scope**: 批量操作、投递详情页

- [ ] Task 4: 面试事件管理视图 (deps: task 1)
  - **Objective**: 面试事件 CRUD 列表 + 添加/编辑 Sheet 表单，关联投递。
  - **Detailed requirements**:
    - `InterviewListView.swift`: `@Query` 查询 Interview（按 interviewDate 降序）。List 每行显示：interviewType(中文标签)、关联投递的 companyName + position、interviewDate(格式化)、interviewer、result(中文 badge)。每行编辑/删除按钮。toolbar "添加面试" 按钮。删除 confirmationDialog。
    - `InterviewFormView.swift`: Sheet 表单，字段：application（Picker 列出所有投递，显示"公司名 — 职位"）、interviewType（Picker：电话面/视频面/现场面，值 phone/video/onsite）、interviewDate（DatePicker 含时间）、interviewer（TextField）、result（Picker：待定/通过/未通过）、notes（TextEditor）。
    - 空状态："暂无面试记录"。
  - **Acceptance spec**:
    - 创建面试 → 选择投递/类型/时间 → 保存 → 列表显示新面试
    - 编辑 → 修改时间 → 保存 → 列表更新
    - 删除 → 确认 → 列表刷新
    - 无面试时 → 显示 "暂无面试记录"
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Interviews/InterviewListView.swift`
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Interviews/InterviewFormView.swift`
  - **Verify**: 集成验证 CRUD 流程
  - **Out of scope**: 面试类型自定义

- [ ] Task 5: 看板视图 + 原生拖拽流转 (deps: task 1)
  - **Objective**: 9 列看板，投递卡片按阶段分列展示，支持原生 Drag & Drop 改变阶段，点击查看详情。
  - **Detailed requirements**:
    - `KanbanView.swift`: 水平 ScrollView（`ScrollView(.horizontal)`），内含 HStack 排列 9 个 `KanbanColumnView`。每列头部：中文阶段名 + 卡片数量 badge。
    - `KanbanColumnView`: VStack，头部固定 + ScrollView 卡片列表。支持 `.onDrop` 接收拖入的卡片。
    - `KanbanCardView`: 显示 company.name(粗体)、position、appliedDate(格式化)、面试次数 badge。支持 `.onDrag` 导出 `application.id.uuidString`（使用 `String` 作为 Transferable 类型）。
    - 拖拽逻辑：`.onDrop` 的 DropDelegate 中通过 `application.id` 查找对应 Application，更新其 `status` 为目标阶段。SwiftData 自动持久化 + `@Query` 自动刷新列。
    - 点击卡片 → Sheet 弹出投递详情：company、position、stage badge、appliedDate、JD link、notes、面试历史列表（关联 interviews）。
    - 空列显示 "暂无"。
  - **Acceptance spec**:
    - 投递按阶段正确分列显示
    - 拖拽卡片到新列 → 卡片移动 + 计数更新 + 持久化（重启后保持）
    - 点击卡片 → Sheet 显示详情含面试历史
    - 空列显示 "暂无"，计数 0
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Kanban/KanbanView.swift`（含 KanbanColumnView、KanbanCardView、详情 Sheet）
  - **Verify**: 集成到看板视图 → 拖拽 → 关闭重开验证持久化
  - **Out of scope**: 跨列排序、列内排序、快捷键拖拽、多卡片同时拖拽

- [ ] Task 6: 仪表盘视图 (deps: task 1)
  - **Objective**: 仪表盘：统计卡片、阶段分布条形图、本周面试列表、近期活动。
  - **Detailed requirements**:
    - `DashboardView.swift`: `@Query` 查询 Application 和 Interview，在 `computed` 属性中计算统计。
    - 统计卡片行（LazyVGrid 4 列）：
      - 总投递数 = applications.count
      - 面试中 = applications.filter { INTERVIEWING_STAGES.contains($0.status) }.count
      - Offer = applications.filter { $0.status == "offer" }.count
      - 本周面试 = 本周一到周日的面试数量
    - 阶段分布条形图：遍历 STAGE_ORDER，每阶段一行（中文标签 + 比例条 Rectangle + 数量）。最大值 = max stage count，每行宽度 = count/max × 100%。
    - 本周面试列表：当前周（周一 00:00 → 周日 23:59）的面试卡片，显示 company/position/interviewType badge/时间。
    - 近期活动列表：Application 按 lastUpdated 降序取前 10，每行显示 position @ company — 阶段。
    - 各区块为空时 "暂无数据"。
  - **Acceptance spec**:
    - 统计数字与实际数据一致
    - 条形图比例正确（最长条 100% 宽度）
    - 本周面试列表过滤正确
    - 无数据时所有区域 "暂无数据"
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Dashboard/DashboardView.swift`
  - **Verify**: 集成到仪表盘 → 对比原始数据验证
  - **Out of scope**: Swift Charts 框架（用原生 Rectangle），点击下钻

- [ ] Task 7: 面试日历视图 (deps: task 1)
  - **Objective**: 日历视图：近期面试按日期分组（今天/明天/本周/之后），历史面试独立区域。
  - **Detailed requirements**:
    - `CalendarView.swift`: `@Query` 查询 Interview（关联 Application > Company 数据）。
    - 分割为"近期面试"和"历史记录"两个 Section。
    - 近期面试分组：today（今天 00:00-23:59）、tomorrow（明天 00:00-23:59）、thisWeek（本周剩余）、later（本周之后或无日期），每组标题 + 面试卡片列表。
    - 历史记录：interviewDate < 今天 00:00 的面试，按时间倒序。
    - 面试卡片：companyName(通过 interview.application?.company?.name 获取)、position、interviewType badge(中文)、时间(格式化)、interviewer、result badge(待定/通过/未通过)。
    - 无日期面试归入 "later" 分组。
    - 无数据时 "暂无面试安排"。
  - **Acceptance spec**:
    - 面试按日期正确分组到 today/tomorrow/thisWeek/later/history
    - 今天面试 → "今天" 组显示
    - 上周面试 → "历史记录" 区倒序显示
    - 无数据 → 空状态
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Views/Calendar/CalendarView.swift`
  - **Verify**: 集成验证分组逻辑
  - **Out of scope**: 月历网格视图、日历内编辑/删除

- [ ] Task 8: CSV 导出功能 (deps: tasks 1, 3)
  - **Objective**: CSV 导出：UTF-8 BOM 中文 CSV 文件，NSSavePanel 保存对话框。
  - **Detailed requirements**:
    - `CSVExporter.swift`: 工具结构体，静态方法 `exportApplications(_ applications: [Application])`。
    - 使用 `NSSavePanel`：弹出保存对话框，默认文件名 `applications.csv`，允许的文件类型 `.csv`。
    - CSV 内容：UTF-8 BOM `\u{FEFF}` + 中文列头（公司名称, 职位, 薪资, 投递日期, 当前阶段, 职位链接, 备注）+ 数据行。
    - 阶段列输出中文标签（STAGE_LABELS 映射）。
    - 薪资列留空。
    - 投递日期格式 `yyyy-MM-dd`，空日期输出空字符串。
    - 修改 `ApplicationListView.swift`：toolbar 添加 "导出 CSV" 按钮，触发导出。
  - **Acceptance spec**:
    - 点击"导出 CSV" → NSSavePanel 弹出
    - 选择路径 → 生成 CSV 文件
    - Excel/Numbers 打开 → 中文正确（BOM 生效）、列头和数据完整
  - **Deliverables**:
    - Create: `InterviewTracker/Sources/InterviewTracker/Utilities/CSVExporter.swift`
    - Modify: `InterviewTracker/Sources/InterviewTracker/Views/Applications/ApplicationListView.swift` — 添加导出按钮
  - **Verify**: 运行应用 → 投递管理 → 导出 → 用 Excel 验证
  - **Out of scope**: JSON/PDF 导出、导入功能

- [ ] Task 9: 最终集成 — 导航接线 + 端到端验证 (deps: tasks 1, 2, 3, 4, 5, 6, 7, 8)
  - **Objective**: 将所有功能视图接入 ContentView 导航系统，端到端验证整个应用。
  - **Detailed requirements**:
    - 修改 `ContentView.swift`：
      - sidebar 导航 5 项带 SF Symbol：仪表盘(chart.bar)、看板(rectangle.split.3x1)、投递管理(doc.text)、公司管理(building.2)、面试日历(calendar)
      - 每项对应 `NavigationLink` 或 `@State selection` + `switch`
      - detail 区根据选择渲染：`DashboardView()` / `KanbanView()` / `ApplicationListView()` / `CompanyListView()` / `CalendarView()`
    - 各视图内部 toolbar 按钮保持独立，不冲突。
    - 默认选中看板视图。
  - **Acceptance spec** (10 步验证清单):
    1. 启动 → 默认显示看板视图
    2. 侧边栏 5 项全部可点击切换，无崩溃
    3. 公司管理 → 添加公司 → 成功
    4. 投递管理 → 选择公司创建投递 → 成功
    5. 看板 → 拖拽卡片到新列 → 视觉移动 + 计数更新
    6. 面试管理 → 创建面试 → 成功
    7. 面试日历 → 面试按日期正确分组
    8. 仪表盘 → 统计数字与实际数据一致
    9. 导出 CSV → 文件内容完整、中文正确
    10. 关闭重开 → 所有数据持久化
  - **Deliverables**:
    - Modify: `InterviewTracker/Sources/InterviewTracker/ContentView.swift`
  - **Verify**: macOS 上运行完整应用，按 10 步清单逐项检查
  - **Out of scope**: 多窗口支持、快捷键、深色模式适配（使用系统默认）
