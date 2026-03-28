#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Highlighter"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TARGET_BINARY="$MACOS_DIR/$APP_NAME"
INFO_PLIST_TEMPLATE="$ROOT_DIR/Packaging/Info.plist"
INFO_PLIST_TARGET="$CONTENTS_DIR/Info.plist"
ICONSET_DIR="$ROOT_DIR/Packaging/AppIcon.iconset"
ICON_FILE="$ROOT_DIR/Packaging/AppIcon.icns"
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-}"

echo "Building release binary..."
swift build -c release --product highlighter --scratch-path "$ROOT_DIR/.build/apple"

echo "Generating app icon..."
rm -rf "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

SOURCE_BINARY="$(find "$ROOT_DIR/.build/apple" -path '*/release/highlighter' -type f | head -n 1)"

if [[ -z "${SOURCE_BINARY:-}" || ! -f "$SOURCE_BINARY" ]]; then
  echo "Release binary not found under $ROOT_DIR/.build/apple" >&2
  exit 1
fi

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SOURCE_BINARY" "$TARGET_BINARY"
chmod +x "$TARGET_BINARY"
cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST_TARGET"
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"

if command -v codesign >/dev/null 2>&1; then
  if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "Applying Developer ID signature..."
    codesign \
      --force \
      --deep \
      --options runtime \
      --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$APP_DIR"
  else
    echo "Applying ad-hoc code signature..."
    codesign --force --deep --sign - "$APP_DIR"
  fi
fi

echo "Built app bundle:"
echo "  $APP_DIR"
