---
name: "interview-tracker-swiftui-architecture"
description: "SwiftUI 版本的架构参考（已搁置，Web 版为当前交付）"
type: project
---
SwiftUI 原生 Mac 应用的第二版架构（已搁置）：

- **框架**: SwiftUI + SwiftData（macOS 14+）
- **导航**: NavigationSplitView 三栏布局，侧边栏 5 项
- **拖拽**: 原生 `.onDrag` + `.onDrop`
- **数据模型**: Company → Application(cascade) → Interview(cascade)，9 阶段常量
- **导出**: NSSavePanel + UTF-8 BOM CSV

**Why shelved:** 代码在 Linux 上编写，无法编译测试。用户 Mac 上编译时发现大量 bug。用户选择回到 Web 版。

**代码位置:** `InterviewTracker/` 目录，保留供以后参考。仓库：https://github.com/chen-zhuofu/Interview-tracking.git
