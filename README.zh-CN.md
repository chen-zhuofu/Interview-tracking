# Interview Tracker

用自然语言管理求职进度的 macOS App。  
聊天说一句，Agent 会读写公司、面试时间线、日志、待办、时间记录等，改动前会先给你批准。

仓库内容就是 macOS 主程序：`interview-tracker-swiftui/`。

**界面默认英文。** 可随时在顶栏 `EN` / `中` 或设置里切到中文。  
English README: [README.md](README.md)

---

## 系统要求

- macOS 14（Sonoma）或更高
- [Xcode](https://developer.apple.com/xcode/) 15+（装好后命令行会有 `swift`）
- DeepSeek API Key（聊天 Agent 必需）
- （可选）Gemini API Key：聊天里贴图片时用
- （可选）Google Calendar：同步面试时间

---

## 1. Clone

```bash
git clone https://github.com/chen-zhuofu/Interview-tracking.git
cd Interview-tracking/interview-tracker-swiftui
```

---

## 2. Build 并运行

### 方式 A：打成桌面 App（推荐）

```bash
./pack-app.sh
```

完成后桌面会出现 `InterviewTracker.app`，双击打开。

### 方式 B：开发调试

```bash
swift run
```

或：

```bash
open Package.swift   # 用 Xcode 打开后 ⌘R
```

也可双击 `Run.command`（会 `swift build` 再启动 debug 构建）。

---

## 3. 首次设置

1. 打开 App
2. 点设置（齿轮），填入 **DeepSeek API Key**
3. （可选）填 Gemini Key，才能在聊天里发截图
4. （可选）点「用 Google 账号登录」，同步日历

Key 只存在本机：

`~/Library/Application Support/InterviewTracker/`

不会进 git。

---

## 4. 怎么用

底部聊天框直接说自然语言，例如：

- `明天 15:00 DeepSeek Phone Interview，想去 5 分`
- `添加 todo：继续复盘 Sycamore 面试，P1`
- `9 点开始干活` / `收工了`
- `看看 Sierra 面经`

**写操作会先弹出批准卡**，你点「批准并执行」后才落库。

常用入口：

| 入口 | 作用 |
|------|------|
| 仪表盘 | 机会分布、想去程度、最近日志、待办摘要、接下来的面试 |
| 公司详情 | 公司介绍 / JD / 面经 / 复盘；可拖入本地代码仓库，一点用 Cursor 打开 |
| 日志 | 打 tag、时间与状态记录、补记过去的天 |
| 待办清单 | P0–P3、生活 / 职业分类，可勾选完成 |
| 阅读收藏 / 求职资料 | 论文、博客、简历等 |
| 日历 | 看面试安排；可与 Google Calendar 同步 |

想让 Agent 长期记住某条规则，在话里加上「记住」或「记住 feedback」，例如：

`我说的「现在」就是当下真实时间，记住 feedback`

---

## 5. 数据在哪

全部在本地，不上传：

- SwiftData 数据库：系统 Application Support
- 自动备份快照：`~/Library/Application Support/InterviewTracker/backups/`
- 反馈记忆：`~/Library/Application Support/InterviewTracker/user_feedback_memory.jsonl`

---

## 6. 常见问题

**`swift: command not found`**  
先装 Xcode，再执行一次：

```bash
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**打不开 / 提示损坏**  
打包脚本会清 quarantine；若仍有问题：

```bash
xattr -cr ~/Desktop/InterviewTracker.app
```

**改完代码怎么更新桌面图标**  
再跑一次：

```bash
cd interview-tracker-swiftui
./pack-app.sh
```

**Release 打包很慢**  
正常，首次 / 大改后可能要一两分钟。日常调试用 `swift run` 更快。

---

## 技术栈（简要）

- SwiftUI + SwiftData
- DeepSeek（工具调用 Agent）
- 可选 Gemini（识图）+ Google Calendar（OAuth）
- 本地自动备份，防止 schema 变更误清空

更细的说明见：[`interview-tracker-swiftui/README.md`](interview-tracker-swiftui/README.md)
