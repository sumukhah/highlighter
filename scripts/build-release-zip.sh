#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Highlighter.app"
ZIP_PATH="$ROOT_DIR/dist/Highlighter-macOS.zip"
TEMP_ZIP_PATH="$ROOT_DIR/dist/Highlighter-macOS-notarization.zip"

"$ROOT_DIR/scripts/build-app.sh"

echo "Creating release archive..."
rm -f "$ZIP_PATH" "$TEMP_ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$TEMP_ZIP_PATH"

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  "$ROOT_DIR/scripts/notarize-app.sh" "$APP_DIR" "$TEMP_ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
else
  cp "$TEMP_ZIP_PATH" "$ZIP_PATH"
fi

rm -f "$TEMP_ZIP_PATH"

echo "Built release archive:"
echo "  $ZIP_PATH"
