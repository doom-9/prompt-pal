#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PromptPal"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

UNIVERSAL=0
PACKAGE=0

for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        --package) PACKAGE=1 ;;
        -h|--help)
            echo "Usage: $0 [--universal] [--package]"
            echo "  --universal  Build arm64 + x86_64 universal binary"
            echo "  --package    Create .zip, .dmg, and .sha256 archives in dist/"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

cd "$ROOT_DIR"

BUILD_ARGS=(-c release)
ARCH_LABEL="$(uname -m)"
if [[ "$UNIVERSAL" -eq 1 ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
    ARCH_LABEL="universal"
fi

echo "Building $APP_NAME (${ARCH_LABEL})..."
swift build "${BUILD_ARGS[@]}"

BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

RAW_VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")}"
CLEAN_VERSION="${RAW_VERSION#v}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $CLEAN_VERSION" "$APP_DIR/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built $APP_DIR (version $CLEAN_VERSION)"

if [[ "$PACKAGE" -eq 1 ]]; then
    ARCHIVE_BASE="$APP_NAME-$CLEAN_VERSION-macos-$ARCH_LABEL"
    ZIP_PATH="$DIST_DIR/$ARCHIVE_BASE.zip"
    DMG_PATH="$DIST_DIR/$ARCHIVE_BASE.dmg"
    SHA_PATH="$DIST_DIR/$ARCHIVE_BASE.sha256"
    DMG_STAGING="$DIST_DIR/.dmg-staging"

    rm -f "$ZIP_PATH" "$DMG_PATH" "$SHA_PATH"
    rm -rf "$DMG_STAGING"

    echo "Creating $ZIP_PATH..."
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

    echo "Creating $DMG_PATH..."
    mkdir -p "$DMG_STAGING"
    cp -R "$APP_DIR" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null
    rm -rf "$DMG_STAGING"

    (cd "$DIST_DIR" && shasum -a 256 "$ARCHIVE_BASE.zip" "$ARCHIVE_BASE.dmg" > "$ARCHIVE_BASE.sha256")
    echo "Packaged:"
    echo "  $ZIP_PATH"
    echo "  $DMG_PATH"
    echo "  $SHA_PATH"
fi
