# PromptPal

**English** | [简体中文](README.md)

[![CI](https://github.com/doom-9/prompt-pal/actions/workflows/ci.yml/badge.svg)](https://github.com/doom-9/prompt-pal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/doom-9/prompt-pal)](https://github.com/doom-9/prompt-pal/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://github.com/doom-9/prompt-pal)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A lightweight native macOS menu bar utility for storing and picking prompts at the speed of thought. Built for CLI coding workflows like Claude Code—press a global hotkey to summon a floating picker, select a prompt by keyboard, copy it to the clipboard, and automatically return focus to your terminal.

## Features

- **Instant Global Hotkey**: Press `⌥ Space` (configurable) from any app—including full-screen or tiled terminals—to open a Spotlight-style floating panel.
- **High-Frequency First**: Pin your favorite prompts to the top; remaining prompts are automatically sorted by usage count and recency.
- **Keyboard-First Selection**: Fuzzy search by title or content, navigate with `↑` / `↓` + `Enter`, or press `⌘1`–`⌘5` to copy the top 5 prompts immediately. IME-safe (`hasMarkedText()` guarded) so CJK input composition never triggers accidental selection.
- **In-App Management**: Split-view editor for creating, editing (with debounced auto-save), pinning, and deleting multi-line prompts, plus a Launch at Login toggle (`SMAppService`).
- **Zero Extra Permissions**: Built with native Swift (`SwiftUI` + `AppKit` `NSPanel`) and Carbon `RegisterEventHotKey`. Copies to the clipboard only—no Accessibility permissions required.

## Download & Install

Download the latest Universal Binary (Apple Silicon & Intel) from [GitHub Releases](https://github.com/doom-9/prompt-pal/releases/latest):

- **DMG Installer** (Recommended): Download `PromptPal-*-macos-universal.dmg`, open it, and drag `PromptPal.app` into `Applications`.
- **ZIP Archive**: Download `PromptPal-*-macos-universal.zip`, unzip it, and move `PromptPal.app` to `/Applications`.

> **Gatekeeper Notice on First Launch**  
> Open-source builds are ad-hoc signed without Apple Notarization. If macOS blocks the app on first launch, remove the quarantine attribute in Terminal:
>
> ```bash
> xattr -cr /Applications/PromptPal.app
> open /Applications/PromptPal.app
> ```

## Keyboard Shortcuts

| Shortcut | Scope | Action |
| --- | --- | --- |
| `⌥ Space` (customizable) | Global | Toggle the floating prompt picker |
| `↑` / `↓` | Picker | Move selection up / down |
| `Enter` | Picker | Copy selected prompt and return focus to previous app |
| `⌘1` – `⌘5` | Picker | Copy the 1st–5th visible prompt and return focus |
| `⌘N` | Picker / Menu Bar | Open Management window with a new prompt |
| `⌘,` | Picker / Menu Bar | Open Management & Settings window |
| `Esc` | Picker | Dismiss without copying |

## Data Storage

- Prompts are stored locally at `~/Library/Application Support/PromptPal/prompts.json`.
- If `prompts.json` is ever corrupted, PromptPal automatically rotates it to a timestamped `.bak` file in the same directory and notifies you in the UI.
- First launch seeds 3 starter prompts so you can test the workflow right away.

## Build from Source & Package

Requirements: macOS 14.0+, Xcode / Swift 6.0+.

```bash
# Run unit tests
swift test

# Build .app for the current architecture (outputs to dist/PromptPal.app)
./scripts/build-app.sh

# Build universal binary (arm64 + x86_64) and package .dmg / .zip / .sha256
./scripts/build-app.sh --universal --package
```

### Releasing a New Version

GitHub Actions ([release.yml](.github/workflows/release.yml)) automatically runs tests, builds universal `.dmg` / `.zip` / `.sha256` artifacts, and publishes a GitHub Release when a `v*` tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
