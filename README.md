# Interview Tracker

A macOS app for tracking job applications in natural language.  
Say something in chat and the agent can read/write companies, interview timelines, journals, todos, and time logs — **writes require your approval first**.

The repo is the macOS app under `interview-tracker-swiftui/`.

**Language:** the UI defaults to **English**. Switch to 中文 anytime from the top bar (`EN` / `中`) or Settings.  
中文说明见 [README.zh-CN.md](README.zh-CN.md).

---

## Requirements

- macOS 14 (Sonoma) or later
- [Xcode](https://developer.apple.com/xcode/) 15+ (provides the `swift` CLI)
- DeepSeek API key (required for the chat agent)
- (Optional) Gemini API key — for images in chat
- (Optional) Google Calendar — interview sync

---

## 1. Clone

```bash
git clone https://github.com/chen-zhuofu/Interview-tracking.git
cd Interview-tracking/interview-tracker-swiftui
```

---

## 2. Build & run

### Option A: Desktop app (recommended)

```bash
./pack-app.sh
```

This creates `InterviewTracker.app` on your Desktop. Double-click to open.

### Option B: Dev / debug

```bash
swift run
```

Or:

```bash
open Package.swift   # then ⌘R in Xcode
```

You can also double-click `Run.command` (`swift build` + launch debug binary).

---

## 3. First-time setup

1. Open the app  
2. Open **Settings** (gear) → paste your **DeepSeek API Key**  
3. (Optional) Gemini key for screenshots in chat  
4. (Optional) Google sign-in for calendar sync  
5. Language defaults to English; change with the **EN / 中** control in the top bar

Keys stay on this Mac only:

`~/Library/Application Support/InterviewTracker/`

They are not committed to git.

---

## 4. How to use

Type natural language in the bottom chat, for example:

- `DeepSeek phone interview tomorrow 3pm, desire 5`
- `add todo: keep reviewing Sycamore interview, P1`
- `start work at 9` / `done for today`
- `check Sierra interview notes`

**Writes show an approval card** — tap **Approve & run** to commit.

| Area | What it does |
|------|----------------|
| Dashboard | Opportunity mix, desire levels, recent journal, todos, upcoming interviews |
| Company detail | Intro / JD / interview notes / retrospective; link a local repo and open it in Cursor |
| Journal | Tags, time & mood log, backfill past days |
| Todos | P0–P3, Life / Career, check off |
| Reading / Documents | Papers, blogs, resumes, etc. |
| Calendar | Interview schedule; optional Google sync |

To persist a preference for the agent, say **remember** or **remember feedback**, e.g.:

`when I say "now", use the real current time — remember feedback`

---

## 5. Where data lives

All local, nothing uploaded:

- SwiftData store under Application Support  
- Auto backups: `~/Library/Application Support/InterviewTracker/backups/`  
- Feedback memory: `~/Library/Application Support/InterviewTracker/user_feedback_memory.jsonl`

---

## 6. Troubleshooting

**`swift: command not found`**  
Install Xcode, then:

```bash
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**App won’t open / “damaged”**  
The pack script clears quarantine; if needed:

```bash
xattr -cr ~/Desktop/InterviewTracker.app
```

**Update the Desktop icon after code changes**

```bash
cd interview-tracker-swiftui
./pack-app.sh
```

**Release builds feel slow**  
Normal after big changes (a couple of minutes). Day-to-day, use `swift run`.

---

## Stack (short)

- SwiftUI + SwiftData  
- DeepSeek (tool-calling agent)  
- Optional Gemini (vision) + Google Calendar (OAuth)  
- Local auto-backup against silent schema wipes  

More detail: [`interview-tracker-swiftui/README.md`](interview-tracker-swiftui/README.md) · 中文：[README.zh-CN.md](README.zh-CN.md)
