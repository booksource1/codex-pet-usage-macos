#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"
INSTALLED_APP="${CODEX_PET_INSTALLED_APP:-/Applications/Codex Pet Usage.app}"
INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/CodexPetUsage"
LABEL="ai.jimmyasks.codex-pet-usage-macos"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/$LABEL.plist"
APP_SUPPORT_DIR="${CODEX_PET_APP_SUPPORT_DIR:-$HOME/Library/Application Support/CodexPetUsageOverlay}"
CODEX_HOME_VALUE="${CODEX_HOME:-$HOME/.codex}"
USAGE_POLL_SECONDS="${CODEX_PET_USAGE_POLL_SECONDS:-30}"
PET_POLL_MS="${CODEX_PET_POLL_MS:-100}"
HOVER_PADDING="${CODEX_PET_HOVER_PADDING:-24}"
TEMP_PLIST=""

cleanup_temp_plist() {
  if test -n "$TEMP_PLIST"; then rm -f "$TEMP_PLIST"; fi
}
trap cleanup_temp_plist EXIT

find_expected_pids() {
  local expected pid command observed
  expected=$(realpath "$EXECUTABLE" 2>/dev/null) || return 1
  ps -ax -o pid=,comm= | while read -r pid command; do
    case "$command" in
      */CodexPetUsage|CodexPetUsage)
        observed=$(realpath "$command" 2>/dev/null) || return 1
        if test "$observed" = "$expected"; then printf '%s\n' "$pid"; fi
        ;;
    esac
  done
}

stop_expected_processes() {
  local pid remaining
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if ! remaining=$(find_expected_pids); then
      echo "Codex Pet Usage exact-process discovery failed." >&2
      return 1
    fi
    if test -z "$remaining"; then return 0; fi
    while read -r pid; do
      if test -n "$pid"; then kill -TERM "$pid" 2>/dev/null || true; fi
    done <<< "$remaining"
    sleep 0.1
  done

  if ! remaining=$(find_expected_pids); then
    echo "Codex Pet Usage exact-process discovery failed." >&2
    return 1
  fi
  if test -z "$remaining"; then return 0; fi
  echo "Codex Pet Usage exact process did not stop." >&2
  return 1
}

if test -x "$INSTALLED_EXECUTABLE"; then
  APP="$INSTALLED_APP"
  EXECUTABLE="$INSTALLED_EXECUTABLE"
elif test ! -x "$EXECUTABLE"; then
  bash "$ROOT/scripts/build-app.sh"
fi
EXECUTABLE_PATH=$(realpath "$EXECUTABLE")
mkdir -p "$LAUNCH_AGENTS" "$APP_SUPPORT_DIR"
TEMP_PLIST="$PLIST.tmp.$$"
plutil -create xml1 "$TEMP_PLIST"
plutil -insert Label -string "$LABEL" "$TEMP_PLIST"
plutil -insert ProgramArguments -json '[]' "$TEMP_PLIST"
plutil -insert ProgramArguments.0 -string "$EXECUTABLE_PATH" "$TEMP_PLIST"
plutil -insert WatchPaths -json '[]' "$TEMP_PLIST"
plutil -insert WatchPaths.0 -string "$CODEX_HOME_VALUE/.codex-global-state.json" "$TEMP_PLIST"
plutil -insert EnvironmentVariables -json '{}' "$TEMP_PLIST"
plutil -insert EnvironmentVariables.CODEX_HOME -string "$CODEX_HOME_VALUE" "$TEMP_PLIST"
plutil -insert EnvironmentVariables.CODEX_PET_USAGE_POLL_SECONDS -string "$USAGE_POLL_SECONDS" "$TEMP_PLIST"
plutil -insert EnvironmentVariables.CODEX_PET_POLL_MS -string "$PET_POLL_MS" "$TEMP_PLIST"
plutil -insert EnvironmentVariables.CODEX_PET_HOVER_PADDING -string "$HOVER_PADDING" "$TEMP_PLIST"
if test -n "${CODEX_PET_APP_SUPPORT_DIR:-}"; then
  plutil -insert EnvironmentVariables.CODEX_PET_APP_SUPPORT_DIR -string "$APP_SUPPORT_DIR" "$TEMP_PLIST"
fi
plutil -insert StandardOutPath -string "$APP_SUPPORT_DIR/overlay.log" "$TEMP_PLIST"
plutil -insert StandardErrorPath -string "$APP_SUPPORT_DIR/overlay.log" "$TEMP_PLIST"
mv "$TEMP_PLIST" "$PLIST"
TEMP_PLIST=""

DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST"

CODEX_APP_INFO=$(lsappinfo find bundleID=com.openai.codex 2>/dev/null || true)
stop_expected_processes
if test -n "$CODEX_APP_INFO"; then
  launchctl kickstart "$DOMAIN/$LABEL"
fi

echo "Codex-triggered startup installed: $PLIST"
