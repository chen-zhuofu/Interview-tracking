# Interview Tracker — macOS

Track job applications in natural language. The DeepSeek agent reads/writes companies, timelines, journals, todos, and time logs; **writes show an approval card first**.

**UI language defaults to English.** Switch to 中文 in **Settings**.  
中文版说明：[README.zh-CN.md](README.zh-CN.md) · 仓库根目录：[../README.md](../README.md) / [../README.zh-CN.md](../README.zh-CN.md)

## Install

End users do not need to clone the repository or install Xcode. Open [GitHub Releases](https://github.com/chen-zhuofu/Interview-tracking/releases/latest), download the universal DMG, then drag the app to Applications.

The current community build is ad-hoc signed. If macOS blocks the first launch, try opening it once, then use **System Settings → Privacy & Security → Open Anyway**.

## Build from source

A clone contains source code and must be compiled with Xcode.

### Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (`swift` CLI)
- DeepSeek API key
- (Optional) Gemini API key — chat images
- (Optional) Google OAuth — Calendar sync

### Clone into this folder

```bash
git clone https://github.com/chen-zhuofu/Interview-tracking.git
cd Interview-tracking/interview-tracker-swiftui
```

### Build

#### Build a local DMG / ZIP

```bash
./pack-app.sh 1.0.0
```

Creates a universal DMG, ZIP, and checksums under `dist/`.

#### Debug

```bash
swift run
# or
open Package.swift   # ⌘R in Xcode
# or double-click Run.command
```

Tests:

```bash
swift test
```

## First launch

1. Settings → paste DeepSeek API Key  
2. (Optional) Gemini / Google  
3. Chat in the bottom bar, e.g. `DeepSeek phone screen tomorrow 3pm, desire 4`  
4. Review the approval card → **Approve & run**

Keys & data: `~/Library/Application Support/InterviewTracker/`

## Google Calendar (optional)

When enabled, Google Calendar is the source of truth for linked interviews. Create a desktop OAuth client in Google Cloud, then put Client ID / Secret only in:

`~/Library/Application Support/InterviewTracker/google_oauth_client.json`

Never commit those values to git.

## UI map

| Area | Role |
|------|------|
| Dashboard | Opportunities, desire, recent journal, todos, upcoming interviews |
| Company | Intro / JD / interview notes / retrospective; link local repo → Cursor |
| Journal | Tags, time & mood, backfill |
| Todos | P0–P3, Life / Career |
| Reading / Documents | Papers, blogs, resumes… |
| Calendar | Interview schedule |
| Chat | Agent; writes need approval |

## Data

- Local SwiftData only  
- Auto backups under `…/InterviewTracker/backups/`  
- Explicit “remember / feedback” lines go to `user_feedback_memory.jsonl`

Do not commit Application Support keys, DB, or backups.

## Stack

- SwiftUI + SwiftData  
- DeepSeek tool-calling agent  
- Optional Gemini + Google Calendar  
- Charts on the dashboard  
