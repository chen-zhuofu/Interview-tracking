# Interview Tracker — 聊天式面试追踪 (macOS)

用自然语言记录面试进度。DeepSeek 自动归纳公司、岗位、面试、反馈和想去程度，并更新仪表盘与面试日历。可选同步到 Google Calendar。

## 系统要求

- macOS 14 (Sonoma) 或更高
- Xcode 15+（构建用）
- DeepSeek API Key（模型：`deepseek-v4-pro`）
- （可选）Google Cloud OAuth 客户端，用于 Calendar 同步

## 快速开始

双击桌面上的 **InterviewTracker** 图标即可打开（带独立窗口和 Dock 图标）。

重新打包最新代码到桌面：

```bash
cd InterviewTracker
./pack-app.sh
```

开发调试也可以：

```bash
cd InterviewTracker
swift run
# 或：open Package.swift   # Xcode 里 ⌘R
```

首次使用：侧边栏点「设置」，粘贴 DeepSeek Key。

## Google Calendar 同步

以 **Google Calendar 为准**：

- 已关联的面试：打开 App 或点「从 Google 同步」时，从 Google 拉时间；在 Google 里删了，App 也会清掉安排
- 新安排的面试：先写到 Google 主日历（默认 1 小时）
- 聊天里刚改的时间：会推到 Google，之后仍以 Google 上的时间为准

设置里点 **用 Google 账号登录** → 浏览器授权即可。

### 一次性开发者配置（只需做一次）

1. 打开 [Google Cloud Console](https://console.cloud.google.com/)
2. 启用 **Google Calendar API**
3. OAuth 同意屏幕 → 外部 → 把自己加到**测试用户**
4. 创建 OAuth 客户端，类型选 **桌面应用**
5. 把 Client ID / Secret 填进 `Sources/InterviewTracker/Services/GoogleOAuthConfig.swift`，或写入：

```bash
mkdir -p ~/Library/Application\ Support/InterviewTracker
cat > ~/Library/Application\ Support/InterviewTracker/google_oauth_client.json <<'EOF'
{"clientId":"你的ClientID","clientSecret":"你的ClientSecret"}
EOF
```

6. 重新打包：`./pack-app.sh`

## 怎么用

1. 打开就是 **仪表盘** / **面试日历**
2. 底部输入框随便说，例如：
   - `明天下午3点 Deepseek Agent Eng 电话面，想去程度4分，感觉团队很强`
3. 输入后聊天区展开，模型归纳并直接写入数据
4. 若已连接 Google，带时间的面试会同步到日历

## 界面

| 页面 | 说明 |
|------|------|
| 仪表盘 | 机会分布、想去程度、三类机会列表、接下来的面试、高意向 |
| 面试日历 | 今天 / 明天 / 本周 / 之后 / 未安排 / 历史 |
| 底部聊天 | 收起为输入条，输入或聚焦后展开为聊天窗口 |
| 设置 | DeepSeek Key、Google Calendar 连接 |

## 数据字段

- 公司：名称、看法、备注…
- 投递：岗位、进度、想去程度(1–5)、反馈
- 面试：类型、时间、结果、笔记、Google 事件 ID（同步后）

数据仍在本地 SwiftData。

## 技术栈

- SwiftUI + SwiftData
- DeepSeek `deepseek-v4-pro`（JSON 结构化提取）
- Google Calendar API（OAuth2 + PKCE）
- Charts（仪表盘可视化）
