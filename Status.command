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

is_expected_process() {
  local pid="$1" observed expected
  case "$pid" in *[!0-9]*|'') return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  observed=$(ps -p "$pid" -o comm= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  test -n "$observed" || return 1
  observed=$(realpath "$observed" 2>/dev/null) || return 1
  expected=$(realpath "$EXECUTABLE" 2>/dev/null) || return 1
  test "$observed" = "$expected"
}

find_expected_pids() {
  local expected pid command observed
  expected=$(realpath "$EXECUTABLE" 2>/dev/null) || return 0
  ps -ax -o pid=,comm= | while read -r pid command; do
    case "$command" in
      */CodexPetUsage|CodexPetUsage)
        observed=$(realpath "$command" 2>/dev/null || true)
        if test -n "$observed" && test "$observed" = "$expected"; then printf '%s\n' "$pid"; fi
        ;;
    esac
  done
}

running=false
pid=""
if test -f "$PID_FILE"; then
  candidate=$(tr -d '[:space:]' < "$PID_FILE")
  if is_expected_process "$candidate"; then
    running=true
    pid="$candidate"
  fi
fi
if test "$running" = false; then
  candidate=$(find_expected_pids | sed -n '1p')
  if test -n "$candidate"; then
    running=true
    pid="$candidate"
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
