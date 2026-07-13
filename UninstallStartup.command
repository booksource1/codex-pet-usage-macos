#!/bin/bash
set -euo pipefail

LABEL="ai.jimmyasks.codex-pet-usage-macos"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if test ! -f "$PLIST"; then
  echo "Login startup is not installed."
  exit 0
fi

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
echo "Login startup removed: $PLIST"
