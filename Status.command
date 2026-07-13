#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"
PID_FILE="$APP_SUPPORT_DIR/overlay.pid"
LOG_FILE="$APP_SUPPORT_DIR/overlay.log"
LABEL="ai.jimmyasks.codex-pet-usage-macos"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
CODEX_HOME_VALUE="${CODEX_HOME:-$HOME/.codex}"
STATE_FILE="$CODEX_HOME_VALUE/.codex-global-state.json"

running=false
pid=""
if test -f "$PID_FILE"; then
  candidate=$(tr -d '[:space:]' < "$PID_FILE")
  if case "$candidate" in *[!0-9]*|'') false ;; *) true ;; esac && kill -0 "$candidate" 2>/dev/null; then
    observed=$(ps -p "$candidate" -o comm= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    observed=$(realpath "$observed" 2>/dev/null || true)
    expected=$(realpath "$EXECUTABLE" 2>/dev/null || true)
    if test -n "$observed" && test "$observed" = "$expected"; then
      running=true
      pid="$candidate"
    fi
  fi
fi

pet_open=false
if test -f "$STATE_FILE"; then
  pet_open=$(plutil -extract electron-avatar-overlay-open raw "$STATE_FILE" 2>/dev/null || echo false)
fi
latest_log=""
if test -f "$LOG_FILE"; then latest_log=$(tail -n 1 "$LOG_FILE"); fi

printf 'Running: %s\n' "$running"
printf 'ProcessId: %s\n' "$pid"
printf 'PidFile: %s\n' "$PID_FILE"
printf 'LogFile: %s\n' "$LOG_FILE"
printf 'StartupEnabled: %s\n' "$(test -f "$LAUNCH_AGENT" && echo true || echo false)"
printf 'LaunchAgentPath: %s\n' "$LAUNCH_AGENT"
printf 'CodexHome: %s\n' "$CODEX_HOME_VALUE"
printf 'CodexStateFile: %s\n' "$(test -f "$STATE_FILE" && echo true || echo false)"
printf 'PetOverlayOpen: %s\n' "$pet_open"
printf 'LatestLog: %s\n' "$latest_log"
