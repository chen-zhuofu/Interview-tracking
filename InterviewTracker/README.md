# Interview Tracker — 面试流程管理 (macOS)

原生 macOS SwiftUI 应用，帮助你管理求职面试全流程。

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- Xcode 15 或更高版本（用于构建）

## 快速开始

### 方式一：Xcode 打开

```bash
open Package.swift
```

Xcode 会自动解析包并打开项目，按 ⌘R 运行。

### 方式二：命令行

```bash
swift build
swift run
```

## 功能

| 功能 | 说明 |
|------|------|
| 仪表盘 | 统计概览：投递总数、各阶段分布、本周面试 |
| 看板视图 | 9列看板，拖拽卡片流转阶段 |
| 投递管理 | 投递CRUD、阶段筛选、快速前后流转 |
| 公司管理 | 公司CRUD、级联删除 |
| 面试日历 | 近期面试分组（今天/明天/本周/之后）、历史记录 |

## 数据

所有数据存储在本地 SwiftData 数据库中，无需网络连接，无需注册账号。

## 技术栈

- SwiftUI — 原生 macOS 界面
- SwiftData — 本地数据持久化
- NavigationSplitView — 三栏导航布局
