# PromptPal Design Document

## 1. Intent & Why
Developers using CLI coding tools (such as Claude Code) often reuse dozens of prompts—with 3 to 5 high-frequency prompts used repeatedly throughout the day. Switching windows or hunting through notes breaks flow. PromptPal is a lightweight, keyboard-first macOS menu bar utility that lets the user summon a floating picker via a global hotkey, pick a prompt in a couple of keystrokes, copy it to the clipboard, and immediately paste it back into the terminal.

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Instant global summon**: Press a configurable global hotkey from any app (including full-screen or tiled terminals) to open a centered Spotlight-style floating panel.
- **Zero-friction keyboard selection**:
  - Search box is auto-focused on open; typing filters prompts by title and content.
  - `↑` / `↓` navigates the list; `Enter` copies the selected prompt to the clipboard and hides the panel.
  - `⌘1`–`⌘5` immediately copies the top 1st–5th prompt and hides the panel.
  - `Esc` dismisses the panel without copying.
- **Surface high-frequency prompts**: Pinned prompts appear first, followed by prompts sorted by usage frequency and recency.
- **In-app management**: Add, edit, delete, and pin/unpin multi-line plain-text prompts directly inside a clean management window.
- **Local persistence**: Store prompts locally in Application Support (`prompts.json`) with no external backend or account required.
- **Standalone macOS `.app`**: Built with Swift Package Manager and packaged into a standard `PromptPal.app` bundle.

### Non-Goals
- Dynamic template variables / interactive placeholder forms (prompts are plain multi-line text).
- Automatic pasting via Accessibility permissions / synthetic `⌘V` events (copies to clipboard only).
- External Markdown/JSON directory syncing or cloud/iCloud sync.
- Cross-platform support (macOS only).

### Anti-Goals
- Stealing focus permanently or failing to return focus to the terminal after copying or dismissing.
- Heavy memory/CPU footprint or requiring Xcode IDE GUI / third-party runtimes to build.

## 3. Constraints
- **Platform & Toolchain**: macOS arm64 (built on macOS with Swift 6.4.2 via Swift Package Manager, targeting macOS 14.0+).
- **Zero external dependencies**: Rely on Apple system frameworks (`SwiftUI`, `AppKit`, `Carbon` for `RegisterEventHotKey`, `ServiceManagement` for Launch at Login) so builds are fast, offline-safe, and self-contained.

## 4. Approaches Considered

| Approach | Trade-offs | Decision |
| --- | --- | --- |
| **A. Native Swift (SwiftUI + AppKit `NSPanel`)** | Smallest binary, lowest memory (~20–30 MB), fastest hotkey wakeup, native `NSPanel` Space/focus behavior over terminals; requires a small amount of AppKit/Carbon glue code. | **Chosen** |
| **B. Tauri (Rust + Web UI)** | Flexible HTML/CSS UI and easier cross-platform path; higher memory via WebView, heavier build chain, and trickier macOS floating-panel focus restoration. | Rejected |
| **C. Electron** | Far too heavy in bundle size and idle RAM for a small always-on utility. | Rejected |

## 5. User Experience & UI Sketch

### 5.1 Quick Picker (`NSPanel`)
Triggered by the global hotkey (default: `⌥ Space`, configurable in Settings).

```text
+----------------------------------------------------------+
| 🔍 搜索 Prompt...                                        |
+----------------------------------------------------------+
| 📌  [⌘1]  Code Review - 严格检查边界条件与并发问题       |
|           请仔细审查当前 diff，重点检查空值、并发...     |
| 📌  [⌘2]  Plan Mode - 先出方案再写代码                   |
|           先不要修改任何文件，列出你的实现思路...        |
|     [⌘3]  Commit Message - 生成规范提交信息              |
|           根据 git diff 生成简洁的中文 commit...         |
|     [⌘4]  Debug Root Cause - 定位根因                    |
|           不要猜测，先收集日志并给出最小复现...          |
+----------------------------------------------------------+
| ↵ 复制并关闭  ·  ⌘1-5 快捷复制  ·  ⌘N 新建  ·  ⌘, 管理   |
+----------------------------------------------------------+
```

- **Focus & Window Behavior**:
  - Uses a borderless/HUD-style `NSPanel` (`floating` window level, `canJoinAllSpaces`, `fullScreenAuxiliary`) with translucent `NSVisualEffectView` background.
  - Before showing, records the currently active `NSRunningApplication`.
  - When copying (`Enter`, `⌘1`–`⌘5`, or row click) or dismissing (`Esc`, clicking outside), hides the panel and reactivates the previous app so the user can press `⌘V` immediately in their terminal.
- **Shortcuts inside Picker**:
  - `↑` / `↓`: Move selection.
  - `Enter`: Copy selected prompt, increment `useCount`, update `lastUsedAt`, dismiss.
  - `⌘1`–`⌘5`: Copy the 1st–5th visible prompt directly, increment `useCount`, update `lastUsedAt`, dismiss.
  - `⌘N`: Open the Management window focused on creating a new prompt.
  - `⌘,`: Open the Management / Settings window.
  - `Esc`: Dismiss without copying.

### 5.2 Menu Bar Item (`NSStatusItem`)
A compact SF Symbol icon in the macOS menu bar with a menu:
- 打开快速选择 (`⌥ Space`)
- 管理 Prompt... (`⌘,`)
- 新建 Prompt... (`⌘N`)
- 偏好设置...
- 退出 PromptPal (`⌘Q`)

### 5.3 Management & Settings Window (`NSWindow` + SwiftUI)
- **Prompts View**: Two-column layout (`NavigationSplitView` or `HSplitView`):
  - **Left**: Search filter + `+ 新建` button + prompt list showing pin indicator, title, and usage count.
  - **Right**: Title `TextField`, `置顶` toggle, `删除` button, and multi-line `TextEditor` for prompt content (auto-saved on edit).
- **Settings View** (tab or sheet):
  - Global hotkey recorder (default `⌥ Space`, persisted in `UserDefaults`).
  - Launch at Login toggle (`SMAppService.mainApp`).

## 6. Architecture & Data Model

### Data Model (`PromptItem`)
```swift
struct PromptItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var isPinned: Bool
    var useCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date
}
```

### Persistence & Sorting (`PromptStore`)
- Persisted as JSON in `~/Library/Application Support/PromptPal/prompts.json`.
- On first launch (when no file exists), seeds 2–3 starter prompts so the user can test the hotkey flow immediately.
- **Sorting order**:
  1. `isPinned == true` before `false`
  2. Higher `useCount` first
  3. More recent `lastUsedAt` (or `updatedAt`) first
- **Search**: Case-insensitive matching against `title` and `content` (title matches prioritized if desired).

### Core Components
1. `PromptStore`: `@MainActor ObservableObject` managing CRUD, persistence, search, and usage tracking.
2. `HotKeyManager`: Registers/unregisters the global hotkey via Carbon `RegisterEventHotKey` and invokes a callback on press.
3. `FloatingPanelController`: Owns the `NSPanel`, handles `NSRunningApplication` capture/restoration, outside-click dismissal, and keyboard event handling.
4. `ManagementWindowController`: Manages the SwiftUI management & settings window.
5. `AppDelegate`: Bootstraps `NSStatusItem`, `PromptStore`, `HotKeyManager`, and `FloatingPanelController` (`LSUIElement = true` so no Dock icon appears).
6. **Build & Packaging**: `Package.swift` + a `scripts/build-app.sh` script that runs `swift build -c release` and assembles `PromptPal.app` (`Contents/MacOS/PromptPal`, `Contents/Info.plist` with `LSUIElement = YES`).

## 7. Left to the Builder
- Exact visual spacing, typography, dark/light mode refinements, and SF Symbol choices.
- Hotkey recorder UI details and error handling if a user chooses a conflicting system shortcut.
- Unit tests for `PromptStore` (persistence, sorting, search, usage count updates).
