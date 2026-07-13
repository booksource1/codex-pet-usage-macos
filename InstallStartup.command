#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
LABEL="ai.jimmyasks.codex-pet-usage-macos"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/$LABEL.plist"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"

if test ! -x "$EXECUTABLE"; then bash "$ROOT/scripts/build-app.sh"; fi
EXECUTABLE_PATH=$(realpath "$EXECUTABLE")
mkdir -p "$LAUNCH_AGENTS" "$APP_SUPPORT_DIR"
TEMP_PLIST="$PLIST.tmp.$$"
plutil -create xml1 "$TEMP_PLIST"
plutil -insert Label -string "$LABEL" "$TEMP_PLIST"
plutil -insert ProgramArguments -json '[]' "$TEMP_PLIST"
plutil -insert ProgramArguments.0 -string "$EXECUTABLE_PATH" "$TEMP_PLIST"
plutil -insert RunAtLoad -bool true "$TEMP_PLIST"
plutil -insert KeepAlive -bool true "$TEMP_PLIST"
plutil -insert StandardOutPath -string "$APP_SUPPORT_DIR/overlay.log" "$TEMP_PLIST"
plutil -insert StandardErrorPath -string "$APP_SUPPORT_DIR/overlay.log" "$TEMP_PLIST"
mv "$TEMP_PLIST" "$PLIST"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Login startup installed: $PLIST"
