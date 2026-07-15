---
name: "interview-tracker-deliverable-form"
description: "面试管理工具最终必须交付为可双击启动的 Mac .app，而不是浏览器应用"
type: project
---
面试管理工具的目标交付形态是有独立窗口、Dock 图标、可双击启动的 Mac `.app`。浏览器中的本地 Web 应用不算完成最终需求。

**Why:** 需求确认阶段曾错误地把“Mac 上能打开的 App”理解为自动打开浏览器，导致功能完成但交付形态错误。

**How to apply:** 评估完成度和后续方案时，把桌面应用外壳及 Mac 打包视为必要验收条件；具体使用 Electron、SwiftUI 或其他方案仍需结合约束确认。
