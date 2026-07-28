# Interview Tracker

A macOS app for tracking job applications in natural language.  
Say something in chat and the agent can read/write companies, interview timelines, journals, todos, and time logs — **writes require your approval first**.

The repo is the macOS app under `interview-tracker-swiftui/`.

**Language:** the UI defaults to **English**. Switch to 中文 in **Settings**.  
中文说明见 [README.zh-CN.md](README.zh-CN.md).

---

## Download & install (recommended)

No clone or Xcode installation is required:

1. Open [GitHub Releases](https://github.com/chen-zhuofu/Interview-tracking/releases/latest)
2. Download `InterviewTracker-<version>-macos-universal.dmg`
3. Open the DMG and drag `InterviewTracker` to `Applications`
4. Launch it from Applications

The installer supports both Apple Silicon and Intel Macs. The current community build is ad-hoc signed. If macOS blocks the first launch, try opening the app once, then use **System Settings → Privacy & Security → Open Anyway**.

> A maintainer can publish an installer from **Actions → Release macOS app → Run workflow** by entering a version, or by pushing a tag such as `v1.0.0`.

---

## Run from source

A clone is source code, not a ready-to-open app. Building it requires Xcode.

### Requirements

- macOS 14 (Sonoma) or later
- [Xcode](https://developer.apple.com/xcode/) 15+ (provides the `swift` CLI)
- DeepSeek API key (required for the chat agent)
- (Optional) Gemini API key — for images in chat
- (Optional) Google Calendar — interview sync

---

### 1. Clone

```bash
git clone https://github.com/chen-zhuofu/Interview-tracking.git
cd Interview-tracking/interview-tracker-swiftui
```

---

### 2. Build & run

#### Option A: Build a local installer

```bash
./pack-app.sh 1.0.0
```

This creates a universal DMG, a ZIP, and checksums under `dist/`. Open the DMG and drag the app to Applications.

#### Option B: Dev / debug

```bash
swift run
```

Or:

```bash
open Package.swift   # then ⌘R in Xcode
```

You can also double-click `Run.command` (`swift build` + launch debug binary).

---

## First-time setup

1. Open the app  
2. Open **Settings** (gear) → paste your **DeepSeek API Key**  
3. (Optional) Gemini key for screenshots in chat  
4. (Optional) Google sign-in for calendar sync  
5. Language defaults to English; change it in **Settings**

Keys stay on this Mac only:

`~/Library/Application Support/InterviewTracker/`

They are not committed to git.

---

## How to use

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

## Where data lives

All local, nothing uploaded:

- SwiftData store under Application Support  
- Auto backups: `~/Library/Application Support/InterviewTracker/backups/`  
- Feedback memory: `~/Library/Application Support/InterviewTracker/user_feedback_memory.jsonl`

---

## Troubleshooting

**`swift: command not found`**  
Install Xcode, then:

```bash
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**The downloaded app is blocked on first launch**

The Release package has not yet been notarized with an Apple Developer ID. Try opening it once, then use **System Settings → Privacy & Security → Open Anyway**.

**Rebuild after code changes**

```bash
cd interview-tracker-swiftui
./pack-app.sh 1.0.0
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
