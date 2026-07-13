#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"
PID_FILE="$APP_SUPPORT_DIR/overlay.pid"
CODEX_HOME_VALUE="${CODEX_HOME:-$HOME/.codex}"

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

if test ! -x "$EXECUTABLE"; then
  bash "$ROOT/scripts/build-app.sh"
fi
mkdir -p "$APP_SUPPORT_DIR"

if test -f "$PID_FILE"; then
  pid=$(tr -d '[:space:]' < "$PID_FILE")
  if is_expected_process "$pid"; then
    echo "Codex Pet Usage is already running (PID $pid)."
    exit 0
  fi
  rm -f "$PID_FILE"
fi

open -n -g "$APP" \
  --env "HOME=$HOME" \
  --env "CODEX_HOME=$CODEX_HOME_VALUE" \
  --env "CODEX_PET_APP_SUPPORT_DIR=$APP_SUPPORT_DIR"

for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50; do
  if test -f "$PID_FILE"; then
    pid=$(tr -d '[:space:]' < "$PID_FILE")
    if is_expected_process "$pid"; then
      echo "Codex Pet Usage started (PID $pid)."
      exit 0
    fi
  fi
  sleep 0.1
done

echo "Codex Pet Usage did not start." >&2
exit 1
