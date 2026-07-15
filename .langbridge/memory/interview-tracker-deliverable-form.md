---
name: "interview-tracker-deliverable-form"
description: "面试管理工具最终必须交付为原生 macOS SwiftUI .app，而不是浏览器应用"
type: project
---
面试管理工具的目标交付形态是原生 macOS SwiftUI 应用（`.app`，独立窗口、Dock 图标）。浏览器中的本地 Web 应用不算完成最终需求。

**Why:** 需求确认阶段曾错误地把"Mac 上能打开的 App"理解为自动打开浏览器（FastAPI + Jinja2），导致功能完成但交付形态错误。用户明确拒绝 Electron，选择 SwiftUI 原生方案。

**Current status:** SwiftUI 代码（9 个任务，Package.swift + 全部视图）已推送到 https://github.com/chen-zhuofu/Interview-tracking.git 的 master 分支。代码在 Linux 上编写，未经编译验证。用户 MacBook Air 上已安装完整 Xcode（`xcode-select -p` 输出 `/Applications/Xcode.app/Contents/Developer`），但 `open Package.swift` 无反应，已指导使用 `open -a Xcode Package.swift` 或通过 Xcode File → Open 手动打开。下一步是 ⌘R 编译运行，遇到编译错误需修复。

**How to apply:** 评估完成度时，以 macOS 原生 `.app` 为唯一验收标准；SwiftUI 代码已于 Linux 上编写完毕，需在 macOS 14+ Xcode 上编译验证。
