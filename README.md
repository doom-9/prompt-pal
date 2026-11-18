# PromptPal

[English](README.en.md) | **简体中文**

[![CI](https://github.com/doom-9/prompt-pal/actions/workflows/ci.yml/badge.svg)](https://github.com/doom-9/prompt-pal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/doom-9/prompt-pal)](https://github.com/doom-9/prompt-pal/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://github.com/doom-9/prompt-pal)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

一个为 macOS 打造的轻量级菜单栏 Prompt 速取工具。配合 Claude Code 等 CLI 编程工具使用时，只需按下全局快捷键即可呼出悬浮面板，用键盘选中一条 Prompt 并复制到剪贴板。浮窗打开时，原应用保持在前台。关闭浮窗后，可以在原输入框继续输入。

## 特性

- **全局快捷键秒开**：默认 `⌥ Space` 呼出 Spotlight 风格悬浮窗，支持在全屏或分屏终端上方浮动，可在设置中自定义。
- **高频优先排序**：支持手动**置顶**常用 Prompt，其余按**使用次数**与**最近使用时间**自动靠前。
- **纯键盘流操作**：支持关键词模糊搜索、`↑` / `↓` + `Enter` 选择、`⌘1`–`⌘5` 一键复制前 5 条，支持中文输入法选词不误触。
- **纯界面内管理**：内置分栏管理窗口，支持多行编辑、实时防抖保存、置顶、删除，以及开机自启（`SMAppService`）。
- **零额外权限与依赖**：原生 Swift（SwiftUI + AppKit `NSPanel`）编写，只写入剪贴板、不模拟按键，无需申请辅助功能权限。

## 下载与安装

前往 [GitHub Releases](https://github.com/doom-9/prompt-pal/releases/latest) 下载最新版本（Universal Binary，同时支持 Apple Silicon 与 Intel Mac）：

- **DMG 安装包**（推荐）：下载 `PromptPal-*-macos-universal.dmg`，双击打开后将 `PromptPal.app` 拖入 `Applications`。
- **ZIP 压缩包**：下载 `PromptPal-*-macos-universal.zip` 解压后移入 `/Applications`。

> **首次打开提示「无法验证开发者」或「已损坏」？**  
> 由于开源版本使用本地 ad-hoc 签名、未经过 Apple 公证（Notarization），首次从浏览器下载打开时可能被 macOS Gatekeeper 拦截。可在终端执行以下命令移除隔离属性后打开：
>
> ```bash
> xattr -cr /Applications/PromptPal.app
> open /Applications/PromptPal.app
> ```

## 快捷键

| 快捷键 | 作用域 | 说明 |
| --- | --- | --- |
| `⌥ Space`（可自定义） | 全局 | 呼出 / 隐藏快速选择面板 |
| `↑` / `↓` | 悬浮面板 | 上下移动选中项 |
| `Enter` | 悬浮面板 | 复制当前选中 Prompt 并回到原应用 |
| `⌘1` – `⌘5` | 悬浮面板 | 直接复制排在前 5 的 Prompt 并回到原应用 |
| `⌘N` | 悬浮面板 / 菜单栏 | 打开管理窗口并新建 Prompt |
| `⌘,` | 悬浮面板 / 菜单栏 | 打开管理 / 设置窗口 |
| `Esc` | 悬浮面板 | 关闭面板并回到原应用 |

## 数据存储

- Prompt 数据保存在：`~/Library/Application Support/PromptPal/prompts.json`
- 若文件意外损坏，启动时会自动备份为同目录下的 `.bak` 文件并在界面给出提示。
- 首次启动会自动预置 3 条常用编程 Prompt 示例，可随时修改或删除。

## 从源码构建与打包

环境要求：macOS 14.0+、Xcode / Swift 6.0+。

```bash
# 运行单元测试
swift test

# 仅构建当前架构的 .app（输出到 dist/PromptPal.app）
./scripts/build-app.sh

# 构建通用二进制（arm64 + x86_64）并打包 .dmg / .zip / .sha256
./scripts/build-app.sh --universal --package
```

### 发布新版本

仓库已配置 GitHub Actions（[release.yml](.github/workflows/release.yml)），推送形如 `v*` 的标签即可自动跑测试、构建通用二进制并发布 `.dmg` / `.zip` / `.sha256` 到 GitHub Releases：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
