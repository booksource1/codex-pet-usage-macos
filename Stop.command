#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"
PID_FILE="$APP_SUPPORT_DIR/overlay.pid"

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

if test ! -f "$PID_FILE"; then
  echo "Codex Pet Usage is not running."
  exit 0
fi

pid=$(tr -d '[:space:]' < "$PID_FILE")
if ! is_expected_process "$pid"; then
  rm -f "$PID_FILE"
  echo "Removed stale PID file; no matching process was stopped."
  exit 0
fi

kill -TERM "$pid"
rm -f "$PID_FILE"
echo "Codex Pet Usage stopped (PID $pid)."
