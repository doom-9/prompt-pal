# PromptPal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build PromptPal, a lightweight native macOS menu bar utility that summons a Spotlight-style floating panel via a global hotkey to search, select, and copy stored prompts to the clipboard.

**Architecture:** Split into a testable `PromptPalCore` library target (data model, JSON persistence/sorting/search, clipboard abstraction, Carbon hotkey config/manager) and a `PromptPal` executable target (AppKit `NSStatusItem`, `NSPanel` floating picker with focus restoration, and SwiftUI management/settings windows). Built with Swift Package Manager and packaged into `PromptPal.app` via a shell script.

**Tech Stack:** Swift 6.4.2, SwiftUI, AppKit (`NSPanel`, `NSStatusItem`, `NSPasteboard`, `NSVisualEffectView`), Carbon (`RegisterEventHotKey`), `ServiceManagement` (`SMAppService`), XCTest.

**Spec:** [2026-11-16-prompt-pal-design.md](file:///Users/xiaofei/orca/projects/prompt-pal/docs/superpowers/specs/2026-11-16-prompt-pal-design.md)

## Global Constraints

- Target platform: macOS 14.0+ (arm64), built with Swift Package Manager (`swift build` / `swift test`), no Xcode IDE project required.
- Zero external package dependencies (Apple system frameworks only).
- Pure in-app UI management; prompts persisted as JSON in `~/Library/Application Support/PromptPal/prompts.json`.
- Copy to clipboard only (no synthetic `⌘V` / Accessibility permissions); must restore focus to the previous frontmost `NSRunningApplication` on copy or dismiss.
- Default global hotkey: `⌥ Space` (configurable in Settings, persisted in `UserDefaults`).
- Background agent app (`LSUIElement = true`, no Dock icon).

## Review Focus

1. Corrupted `prompts.json` on disk: `PromptStore` must back up the corrupted file and recover cleanly instead of crashing or silently losing data.
2. Whitespace-only or unmatched search queries: `PromptStore.filteredPrompts(query:)` treats whitespace-only as unfiltered; `PickerView` clamps selection index and shows an empty state without crashing on `Enter`.
3. `⌘1`–`⌘5` pressed when fewer than 5 prompts are visible: safely no-ops without an index-out-of-bounds crash.
4. Prompts with blank titles or multi-line content: `PromptStore` and UI display a fallback title (`未命名 Prompt`) and preserve multi-line content verbatim when copied.
5. Conflicting/failed global hotkey registration: `HotKeyManager.register(_:)` returns a `Result<Void, HotKeyError>` so `SettingsView` can display an inline error instead of failing silently.

---

### Task 1: Package Scaffolding, `PromptItem`, and `PromptStore`

**Files:**
- Create: `Package.swift`
- Create: `Sources/PromptPalCore/Models/PromptItem.swift`
- Create: `Sources/PromptPalCore/Services/PromptStore.swift`
- Test: `Tests/PromptPalTests/PromptStoreTests.swift`

**Interfaces:**
- Produces:
  - `PromptItem` (`id: UUID`, `title: String`, `content: String`, `isPinned: Bool`, `useCount: Int`, `lastUsedAt: Date?`, `createdAt: Date`, `updatedAt: Date`)
  - `PromptStore` (`@MainActor ObservableObject`):
    - `init(fileURL: URL? = nil, seedIfMissing: Bool = true)`
    - `@Published private(set) var prompts: [PromptItem]`
    - `@Published private(set) var lastLoadError: String?`
    - `func filteredPrompts(query: String) -> [PromptItem]`
    - `func addPrompt(title: String, content: String, isPinned: Bool = false) -> PromptItem`
    - `func updatePrompt(_ item: PromptItem)`
    - `func deletePrompt(id: UUID)`
    - `func togglePin(id: UUID)`
    - `func recordUsage(id: UUID)`

- [ ] **Step 1: Create `Package.swift` and stub types so tests compile**

Define `Package.swift` (`swift-tools-version: 6.0`, `.macOS(.v14)`), library `PromptPalCore`, executable `PromptPal`, and testTarget `PromptPalTests` depending on `PromptPalCore`.

- [ ] **Step 2: Write failing tests in `Tests/PromptPalTests/PromptStoreTests.swift`**

Write XCTest cases covering:
1. `testSeedingOnFirstLaunch`: temp directory with no `prompts.json` seeds 3 starter prompts and writes `prompts.json`.
2. `testSortingPinnedThenUsageCountThenRecency`: pinned items sort before unpinned; within each group, higher `useCount` sorts first, then newer `lastUsedAt`/`updatedAt`.
3. `testSearchMatchesTitleAndContentAndIgnoresWhitespace`: `filteredPrompts(query: "  ")` returns all; `filteredPrompts(query: "diff")` matches title or content case-insensitively.
4. `testRecordUsageIncrementsCountAndPersists`: `recordUsage(id:)` increments `useCount` by 1, sets `lastUsedAt`, and persists across a new `PromptStore(fileURL:)` instance.
5. `testCorruptedJSONBacksUpAndRecovers`: writing invalid JSON to `prompts.json` before `init` sets `lastLoadError != nil`, creates a `.bak` file alongside `prompts.json`, and leaves `prompts` valid.

- [ ] **Step 3: Run `swift test` to verify tests fail**

Run: `swift test --filter PromptStoreTests`
Expected: FAIL (missing or unimplemented `PromptItem` / `PromptStore`).

- [ ] **Step 4: Implement `PromptItem.swift` and `PromptStore.swift`**

Implement `PromptItem` (`Identifiable, Codable, Equatable, Sendable`) and `PromptStore` (`@MainActor ObservableObject`). Use atomic JSON writes (`Data.write(to:options:.atomic)`), default file URL `~/Library/Application Support/PromptPal/prompts.json`, and sorting: `isPinned` desc -> `useCount` desc -> `lastUsedAt ?? updatedAt` desc.

- [ ] **Step 5: Run `swift test` to verify all `PromptStoreTests` pass**

Run: `swift test --filter PromptStoreTests`
Expected: PASS (5 tests, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/PromptPalCore/Models/PromptItem.swift Sources/PromptPalCore/Services/PromptStore.swift Tests/PromptPalTests/PromptStoreTests.swift
git commit -m "feat: add PromptItem model and PromptStore persistence/search/sorting"
```

---

### Task 2: `ClipboardService`, `HotKeyConfig`, and `HotKeyManager`

**Files:**
- Create: `Sources/PromptPalCore/Services/ClipboardService.swift`
- Create: `Sources/PromptPalCore/Services/HotKeyConfig.swift`
- Create: `Sources/PromptPalCore/Services/HotKeyManager.swift`
- Test: `Tests/PromptPalTests/HotKeyConfigTests.swift`

**Interfaces:**
- Produces:
  - `ClipboardService`: `static func copy(_ text: String)` (writes to `NSPasteboard.general` after `clearContents()`)
  - `HotKeyConfig: Codable, Equatable, Sendable`:
    - `var keyCode: UInt32`
    - `var carbonModifiers: UInt32`
    - `static let defaultHotKey: HotKeyConfig` (`⌥ Space`: `keyCode = 49`, `carbonModifiers = optionKey`)
    - `var displayString: String` (e.g. `"⌥ Space"`, `"⌘⇧ P"`)
    - `static func load(from defaults: UserDefaults = .standard) -> HotKeyConfig`
    - `func save(to defaults: UserDefaults = .standard)`
  - `HotKeyError: Error, LocalizedError`
  - `HotKeyManager`:
    - `init(onHotKeyPressed: @escaping @MainActor () -> Void)`
    - `func register(_ config: HotKeyConfig) -> Result<Void, HotKeyError>`
    - `func unregister()`

- [ ] **Step 1: Write failing tests in `Tests/PromptPalTests/HotKeyConfigTests.swift`**

Write XCTest cases covering:
1. `testDefaultHotKeyIsOptionSpace`: `HotKeyConfig.defaultHotKey.displayString == "⌥ Space"` and `keyCode == 49`.
2. `testSaveAndLoadRoundTrip`: saving a custom `HotKeyConfig` to an isolated `UserDefaults(suiteName:)` and loading it back returns an equal `HotKeyConfig`.
3. `testDisplayStringFormatsModifiersAndKey`: verifies `"⌘⇧ P"` (or expected symbol order `⌃⌥⇧⌘`) for a sample keyCode + modifier mask.

- [ ] **Step 2: Run `swift test` to verify tests fail**

Run: `swift test --filter HotKeyConfigTests`
Expected: FAIL.

- [ ] **Step 3: Implement `ClipboardService.swift`, `HotKeyConfig.swift`, and `HotKeyManager.swift`**

Implement `ClipboardService` using `AppKit.NSPasteboard`, `HotKeyConfig` using `Carbon.HIToolbox` keycode/modifier constants, and `HotKeyManager` wrapping `InstallEventHandler` + `RegisterEventHotKey` / `UnregisterEventHotKey` (dispatching `onHotKeyPressed` on `MainActor`).

- [ ] **Step 4: Run `swift test` to verify all tests pass**

Run: `swift test`
Expected: PASS (all `PromptStoreTests` and `HotKeyConfigTests`).

- [ ] **Step 5: Commit**

```bash
git add Sources/PromptPalCore/Services/ClipboardService.swift Sources/PromptPalCore/Services/HotKeyConfig.swift Sources/PromptPalCore/Services/HotKeyManager.swift Tests/PromptPalTests/HotKeyConfigTests.swift
git commit -m "feat: add ClipboardService, HotKeyConfig, and Carbon HotKeyManager"
```

---

### Task 3: Floating Picker Panel (`FloatingPanelController` & `PickerView`)

**Files:**
- Create: `Sources/PromptPal/UI/FloatingPanelController.swift`
- Create: `Sources/PromptPal/UI/PickerView.swift`

**Interfaces:**
- Consumes: `PromptStore`, `ClipboardService`
- Produces:
  - `PickerViewModel` (`@MainActor ObservableObject`):
    - `@Published var query: String`
    - `@Published var selectedIndex: Int`
    - `func moveSelection(delta: Int, count: Int)`
    - `func clampSelection(count: Int)`
  - `FloatingPanelController`:
    - `init(store: PromptStore, onOpenManagement: @escaping () -> Void, onCreateNewPrompt: @escaping () -> Void)`
    - `func toggle()`
    - `func show()`
    - `func hide(restorePreviousApp: Bool)`

- [ ] **Step 1: Implement `FloatingPanelController.swift` and `PickerView.swift`**

- `FloatingPanelController`:
  - Subclass or configure `NSPanel` with `.borderless`, `.nonactivatingPanel`? Note: to allow the search `TextField` to receive keyboard input while floating over full-screen apps, use `.borderless` + `canBecomeKey = true` + `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `isMovableByWindowBackground = true`, and `NSVisualEffectView` (`.hudWindow` / `.popover` material, rounded corners `12pt`).
  - Capture `NSWorkspace.shared.frontmostApplication` right before `show()` (ignoring self).
  - Dismiss on `resignKey` (clicking outside) and restore focus to `previousApp?.activate()` on `hide(restorePreviousApp: true)`.
  - Handle local key monitor or SwiftUI `.onKeyPress` / `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` for `↑`, `↓`, `Enter`, `Esc`, `⌘1`–`⌘5`, `⌘N`, `⌘,` reliably without `NSTextField` swallowing `↑`/`↓`/`Esc`/`Enter`.
- `PickerView`:
  - Auto-focused search field at top (`🔍 搜索 Prompt...`).
  - Scrollable list of `store.filteredPrompts(query:)` rows: pin icon (`📌` / SF Symbol `pin.fill`), `[⌘1]`–`[⌘5]` badge for first 5 visible rows, bold title (fallback `未命名 Prompt`), 1-line truncated content preview.
  - Clicking a row or pressing `Enter` / `⌘1`–`⌘5` (safely bounds-checked) copies `item.content` via `ClipboardService.copy`, calls `store.recordUsage(id:)`, and calls `hide(restorePreviousApp: true)`.
  - Empty state when no prompts match.
  - Footer hint bar: `↵ 复制并关闭 · ⌘1-5 快捷复制 · ⌘N 新建 · ⌘, 管理 · Esc 关闭`.

- [ ] **Step 2: Verify `PromptPal` target compiles**

Run: `swift build`
Expected: PASS (note: `main.swift` in Task 5 will wire the app entry point; if `PromptPal` executable needs a temporary stub `main.swift` or we build after Task 5, verify `swift build` at Task 5 or add minimal `main.swift` now). Let's check `swift build` once Task 4 & 5 are in place, or keep a minimal `main.swift` stub if needed.

- [ ] **Step 3: Commit**

```bash
git add Sources/PromptPal/UI/FloatingPanelController.swift Sources/PromptPal/UI/PickerView.swift
git commit -m "feat: add FloatingPanelController and SwiftUI PickerView"
```

---

### Task 4: Management & Settings Windows (`ManagementWindowController`, `ManagementView`, `SettingsView`, `HotKeyRecorderView`)

**Files:**
- Create: `Sources/PromptPal/UI/ManagementWindowController.swift`
- Create: `Sources/PromptPal/UI/ManagementView.swift`
- Create: `Sources/PromptPal/UI/SettingsView.swift`
- Create: `Sources/PromptPal/UI/HotKeyRecorderView.swift`

**Interfaces:**
- Consumes: `PromptStore`, `HotKeyConfig`, `HotKeyManager`
- Produces:
  - `ManagementWindowController`:
    - `init(store: PromptStore, hotKeyManager: HotKeyManager)`
    - `func show(initialTab: ManagementTab = .prompts, createNew: Bool = false)`

- [ ] **Step 1: Implement `HotKeyRecorderView.swift` and `SettingsView.swift`**

- `HotKeyRecorderView`: interactive button that enters "recording" mode, captures the next keyDown with at least one modifier (`⌘`, `⌥`, `⌃`, `⇧`), maps `NSEvent` modifier flags + `keyCode` to `HotKeyConfig`, and passes it to a callback. `Esc` cancels recording.
- `SettingsView`:
  - Global hotkey row with `HotKeyRecorderView`, "恢复默认 (`⌥ Space`)" button, and inline error message if `hotKeyManager.register(_:)` returns `.failure`.
  - Launch at Login toggle backed by `SMAppService.mainApp` (handles status read and `register()`/`unregister()` with error display if needed).

- [ ] **Step 2: Implement `ManagementView.swift` and `ManagementWindowController.swift`**

- `ManagementView`:
  - Toolbar/tab switcher between `Prompts` and `设置`.
  - `NavigationSplitView` (or `HSplitView`):
    - Left sidebar: search field, `+ 新建` button, list of prompts showing pin icon, title, and `useCount` badge.
    - Right detail pane: Title `TextField`, `置顶` toggle, `删除` button (with confirmation or immediate delete + next selection), and multi-line `TextEditor` bound directly to `store.updatePrompt(...)`.
- `ManagementWindowController`:
  - Manages an `NSWindow` (`760x500`, resizable, `NSApp.activate(ignoringOtherApps: true)` when shown).
  - Supports `createNew: true` (adds a blank prompt and selects it immediately for editing).

- [ ] **Step 3: Commit**

```bash
git add Sources/PromptPal/UI/ManagementWindowController.swift Sources/PromptPal/UI/ManagementView.swift Sources/PromptPal/UI/SettingsView.swift Sources/PromptPal/UI/HotKeyRecorderView.swift
git commit -m "feat: add Prompt management and settings windows"
```

---

### Task 5: App Entry Point, Menu Bar Item, and `.app` Packaging

**Files:**
- Create: `Sources/PromptPal/AppDelegate.swift`
- Create: `Sources/PromptPal/main.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`

**Interfaces:**
- Consumes: `PromptStore`, `HotKeyConfig`, `HotKeyManager`, `FloatingPanelController`, `ManagementWindowController`

- [ ] **Step 1: Implement `AppDelegate.swift` and `main.swift`**

- `main.swift`: initializes `NSApplication.shared`, sets `delegate`, and calls `app.run()`.
- `AppDelegate`:
  - Sets `NSApp.setActivationPolicy(.accessory)` (pairs with `LSUIElement = true`).
  - Creates `PromptStore`, `HotKeyManager`, `FloatingPanelController`, `ManagementWindowController`.
  - Registers saved `HotKeyConfig` on launch.
  - Creates `NSStatusItem` with SF Symbol (`text.quote` or `sparkles.rectangle.stack` / `doc.on.clipboard`) and menu:
    - `打开快速选择` (shows current hotkey hint)
    - `管理 Prompt...` (`⌘,`)
    - `新建 Prompt...` (`⌘N`)
    - `偏好设置...`
    - `退出 PromptPal` (`⌘Q`)

- [ ] **Step 2: Create `Resources/Info.plist` and `scripts/build-app.sh`**

- `Resources/Info.plist`: `CFBundleIdentifier` (`com.promptpal.app`), `CFBundleName` (`PromptPal`), `CFBundleExecutable` (`PromptPal`), `LSMinimumSystemVersion` (`14.0`), `LSUIElement` (`true`).
- `scripts/build-app.sh`: runs `swift build -c release`, creates `dist/PromptPal.app/Contents/MacOS/` and copies binary + `Info.plist`, optionally ad-hoc signs with `codesign --force --deep --sign - dist/PromptPal.app` so macOS runs it cleanly without Gatekeeper quarantine issues locally.

- [ ] **Step 3: Run full test suite and build `.app` bundle**

Run: `swift test && ./scripts/build-app.sh`
Expected: `swift test` passes with 0 failures; `dist/PromptPal.app` is created and executable.

- [ ] **Step 4: Commit**

```bash
git add Sources/PromptPal/AppDelegate.swift Sources/PromptPal/main.swift Resources/Info.plist scripts/build-app.sh
git commit -m "feat: add AppDelegate status bar integration and .app build script"
```

---

## Self-Review Checklist
- Spec coverage: Global hotkey (`Task 2`, `Task 5`), floating `NSPanel` + focus restoration + `Enter`/`⌘1-5`/`Esc`/`⌘N`/`⌘,` (`Task 3`), in-app CRUD + pinning + usage sorting + JSON persistence (`Task 1`, `Task 4`), menu bar item + Launch at Login + `.app` packaging (`Task 4`, `Task 5`).
- All Review Focus cases have explicit tests or safe-handling requirements in their owning tasks.
