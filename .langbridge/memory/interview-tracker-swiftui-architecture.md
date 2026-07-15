---
name: "interview-tracker-swiftui-architecture"
description: "SwiftUI 面试管理工具的技术架构：SwiftData + NavigationSplitView + 原生 Drag & Drop"
type: project
---
面试管理工具的第二版（SwiftUI 原生 Mac 应用）架构决策：

- **框架**: SwiftUI + SwiftData（非 Core Data，非 Electron）
- **最低系统**: macOS 14 (Sonoma)，因为 SwiftData 需要
- **导航**: NavigationSplitView 三栏布局，侧边栏 5 项（仪表盘/看板/投递/公司/日历）
- **拖拽**: 原生 `.onDrag` + `.onDrop`（非第三方库）
- **数据模型**: Company → Application(cascade) → Interview(cascade)，9 阶段常量
- **导出**: NSSavePanel + UTF-8 BOM CSV
- **仓库**: https://github.com/chen-zhuofu/Interview-tracking.git（master 分支）
- **项目目录**: `InterviewTracker/`（旧 Web 版代码 `app/` `static/` 已存档在仓库中）

**Why:** 用户拒绝 Electron 方案，要求原生 Mac 体验。SwiftData 是绿色项目中比 Core Data 更现代的选择。

**约束:** 所有代码在 Linux 上编写，未经编译验证。最终需要在 macOS 14+ Xcode 上构建。
