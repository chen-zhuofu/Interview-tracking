---
name: "interview-tracker-deliverable-form"
description: "面试管理工具当前交付为 Web 版（FastAPI），SwiftUI 版因编译 bug 搁置"
type: project
---
面试管理工具经历了三次迭代：

1. **FastAPI Web 版**（第一版）：完整功能、全部自动化测试通过。`python run.py` 或 Mac 双击 `启动.command` 启动，浏览器打开。功能：看板拖拽、仪表盘、日历、CSV 导出。
2. **SwiftUI 原生版**（第二版）：代码在 Linux 上编写，推送到 Mac 编译时发现大量 bug。用户放弃此版本，回到 Web 版。
3. **Web 版（当前）**：回退到第一版，添加了 `启动.command` 双击启动脚本。代码已验证全部通过。

**Why:** SwiftUI 代码在 Linux 上无法编译测试，导致大量编译错误。用户选择回到有测试能力的 Web 版。

**Current status:** Web 版（FastAPI + Jinja2 + SQLite）是功能完整的可交付版本。SwiftUI 代码保留在 `InterviewTracker/` 目录供以后参考。

**User verified on Mac:** 用户在 MacBook Air（hostname `MacBook-Air-10`）上成功运行 Web 版。遇到两个常见问题并已解决：\n- `ModuleNotFoundError: uvicorn` → 需要先 `pip install -r requirements.txt`\n- `address already in use` (port 8000) → `lsof -ti:8000 | xargs kill` 关掉残留进程\n\n**How to apply:** 以 Web 版为当前交付物。启动方式：Mac 上双击 `启动.command` 或 `python run.py`。SwiftUI 代码暂不维护。
