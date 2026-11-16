#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PromptPal"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

echo "Building $APP_NAME (release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built $APP_DIR"
