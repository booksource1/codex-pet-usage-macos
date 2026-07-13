#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"
PID_FILE="$APP_SUPPORT_DIR/overlay.pid"

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

matching_pids=$(find_expected_pids)
if test -z "$matching_pids"; then
  rm -f "$PID_FILE"
  echo "Codex Pet Usage is not running; stale PID state was removed."
  exit 0
fi

while read -r pid; do
  test -n "$pid" || continue
  kill -TERM "$pid" 2>/dev/null || true
  echo "Codex Pet Usage stopped (PID $pid)."
done <<< "$matching_pids"
rm -f "$PID_FILE"
