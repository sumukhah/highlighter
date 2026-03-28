#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Highlighter.app"
ZIP_PATH="$ROOT_DIR/dist/Highlighter-macOS.zip"

"$ROOT_DIR/scripts/build-app.sh"

echo "Creating release archive..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built release archive:"
echo "  $ZIP_PATH"
