# Interview Tracker — macOS

用自然语言记录求职进度。DeepSeek Agent 通过工具读写公司、面试时间线、日志、待办、时间记录等；**写入前会弹出批准卡**。

**界面默认英文**，可在 **设置** 里切到中文。

从仓库根目录 clone 后的完整步骤见：[仓库根中文 README](../README.zh-CN.md)。英文：[README.md](README.md) · [../README.md](../README.md)。

## 直接安装

普通用户无需 clone 或 Xcode。前往 [GitHub Releases](https://github.com/chen-zhuofu/Interview-tracking/releases/latest)，下载通用版 DMG，打开后把 App 拖入「应用程序」。

当前社区构建使用 ad-hoc 签名。首次打开若被 macOS 拦截，请尝试打开一次，再到 **系统设置 → 隐私与安全性 → 仍要打开**。

## 从源码构建

Clone 得到的是源码，需要 Xcode 编译后才能运行。

### 系统要求

- macOS 14 (Sonoma) 或更高
- Xcode 15+（提供 `swift` 命令行）
- DeepSeek API Key
- （可选）Gemini API Key — 聊天发图
- （可选）Google OAuth — Calendar 同步

### Clone 后进入本目录

```bash
git clone https://github.com/chen-zhuofu/Interview-tracking.git
cd Interview-tracking/interview-tracker-swiftui
```

### Build

#### 生成本地 DMG / ZIP

```bash
./pack-app.sh 1.0.0
```

成品位于 `dist/`。双击 DMG，把 `InterviewTracker` 拖到「应用程序」。

#### 开发调试

```bash
swift run
# 或
open Package.swift   # Xcode 里 ⌘R
# 或双击 Run.command
```

跑测试：

```bash
swift test
```

## 首次使用

1. 打开 App → 设置 → 粘贴 DeepSeek API Key  
2. （可选）Gemini Key、Google 登录  
3. 底部聊天框直接说话，例如：  
   `明天下午3点 DeepSeek Phone Interview，想去程度4`  
4. 有写操作时检查批准卡，再点「批准并执行」

Key 与数据都在本机：

`~/Library/Application Support/InterviewTracker/`

## Google Calendar（可选）

以 **Google Calendar 为准**：

- 已关联的面试：打开 App 或点同步时，从 Google 拉时间
- 新安排：写入 Google 主日历
- 聊天里改的时间：会推到 Google

设置里点 **用 Google 账号登录** → 浏览器授权。

### 开发者一次性配置

1. [Google Cloud Console](https://console.cloud.google.com/) 启用 Calendar API  
2. OAuth 同意屏幕 → 把自己加为测试用户  
3. 创建「桌面应用」OAuth 客户端  
4. 把 Client ID / Secret 写入：

```bash
mkdir -p ~/Library/Application\ Support/InterviewTracker
cat > ~/Library/Application\ Support/InterviewTracker/google_oauth_client.json <<'EOF'
{"clientId":"你的ClientID","clientSecret":"你的ClientSecret"}
EOF
```

不要把 Client ID / Secret 写进源码或提交到 Git。

## 界面一览

| 区域 | 说明 |
|------|------|
| 仪表盘 | 机会分布、想去程度、最近日志、待办、接下来的面试 |
| 公司详情 | 介绍 / JD / 面经 / 复盘；可 link 本地 repo 并用 Cursor 打开 |
| 日志 | tag、时间与状态、补记 |
| 待办 | P0–P3，生活 / 职业 |
| 阅读收藏 / 求职资料 | 论文、博客、简历等 |
| 日历 | 面试安排 |
| 底部聊天 | Agent；写操作需批准 |

## 数据

- 本地 SwiftData，不上传
- 启动与写入后会自动备份到 `…/InterviewTracker/backups/`
- 用户明确说「记住 / feedback」会写入 `user_feedback_memory.jsonl`

**不要把** `Application Support` 里的库、Key、备份提交进 git。

## 技术栈

- SwiftUI + SwiftData
- DeepSeek（tool-calling Agent）
- 可选 Gemini（识图）、Google Calendar（OAuth2 + PKCE）
- Charts（仪表盘）
