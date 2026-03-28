#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Highlighter.app"
INSTALL_DIR="/Applications/Highlighter.app"

"$ROOT_DIR/scripts/build-app.sh"

echo "Installing to /Applications..."
rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"

if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true
fi

echo "Installed:"
echo "  $INSTALL_DIR"
echo "You can launch it from Applications, Spotlight, or Launchpad."
