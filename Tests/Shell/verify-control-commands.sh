#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LABEL="ai.jimmyasks.codex-pet-usage-macos"
APP="$ROOT/dist/Codex Pet Usage.app"
EXECUTABLE="$APP/Contents/MacOS/CodexPetUsage"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in scripts/build-app.sh Start.command Stop.command Status.command InstallStartup.command UninstallStartup.command; do
  test -x "$ROOT/$file" || fail "$file is missing or not executable"
done

if rg -n 'killall|(^|[^[:alnum:]_])pkill([^[:alnum:]_]|$)|(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)|spctl.*--master-disable|curl[^|]*\|[[:space:]]*(sh|bash)' \
  "$ROOT/scripts" "$ROOT"/*.command; then
  fail "control commands contain a forbidden broad or privileged operation"
fi

rg -F "$LABEL" "$ROOT/scripts/build-app.sh" "$ROOT/InstallStartup.command" "$ROOT/UninstallStartup.command" >/dev/null \
  || fail "bundle and LaunchAgent identifier must be fixed"
rg -F '"$APP"' "$ROOT/Start.command" >/dev/null || fail "Start.command must quote the app path"
rg -F '"$EXECUTABLE"' "$ROOT/Start.command" "$ROOT/Stop.command" >/dev/null \
  || fail "process identity checks must quote the executable path"
for name in CODEX_PET_USAGE_POLL_SECONDS CODEX_PET_POLL_MS CODEX_PET_HOVER_PADDING; do
  rg -F -- "--env \"$name=" "$ROOT/Start.command" >/dev/null \
    || fail "Start.command must pass $name to the app"
done

bash "$ROOT/scripts/build-app.sh"
test -x "$EXECUTABLE" || fail "bundle executable was not produced"
test "$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")" = "$LABEL" || fail "wrong bundle identifier"
test "$(plutil -extract CFBundleExecutable raw "$APP/Contents/Info.plist")" = "CodexPetUsage" || fail "wrong executable name"
test "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" = "0.1.0" || fail "wrong version"
test "$(plutil -extract LSMinimumSystemVersion raw "$APP/Contents/Info.plist")" = "14.0" || fail "wrong minimum macOS"
test "$(plutil -extract LSUIElement raw "$APP/Contents/Info.plist")" = "true" || fail "bundle must be an agent app"

TEST_ROOT=$(mktemp -d)
TEST_HOME="$TEST_ROOT/home"
APP_SUPPORT="$TEST_ROOT/support"
CODEX_HOME="$TEST_ROOT/codex"
FAKE_BIN="$TEST_ROOT/bin"
LAUNCH_LOG="$TEST_ROOT/launchctl.log"
OPEN_LOG="$TEST_ROOT/open.log"
mkdir -p "$TEST_HOME/Library/LaunchAgents" "$APP_SUPPORT" "$CODEX_HOME" "$FAKE_BIN"

cleanup() {
  if test -f "$APP_SUPPORT/overlay.pid"; then
    pid=$(tr -d '[:space:]' < "$APP_SUPPORT/overlay.pid")
    if test -n "$pid" && kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null || true; fi
  fi
  if test -n "${SLEEP_PID:-}" && kill -0 "$SLEEP_PID" 2>/dev/null; then kill -TERM "$SLEEP_PID" 2>/dev/null || true; fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

run_command() {
  HOME="$TEST_HOME" \
  CODEX_HOME="$CODEX_HOME" \
  CODEX_PET_APP_SUPPORT_DIR="$APP_SUPPORT" \
  CODEX_PET_USAGE_POLL_SECONDS=45 \
  CODEX_PET_POLL_MS=250 \
  CODEX_PET_HOVER_PADDING=42 \
  PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$@"
}

exact_process_count() {
  local expected candidate process_command observed
  expected=$(realpath "$EXECUTABLE")
  ps -ax -o pid=,comm= | while read -r candidate process_command; do
    case "$process_command" in
      */CodexPetUsage|CodexPetUsage)
        observed=$(realpath "$process_command" 2>/dev/null || true)
        if test "$observed" = "$expected"; then printf '%s\n' "$candidate"; fi
        ;;
    esac
  done | wc -l | tr -d '[:space:]'
}

echo 999999 > "$APP_SUPPORT/overlay.pid"
run_command "$ROOT/Start.command" >/dev/null
RUNNING_PID=$(tr -d '[:space:]' < "$APP_SUPPORT/overlay.pid")
test "$RUNNING_PID" != "999999" && kill -0 "$RUNNING_PID" 2>/dev/null || fail "stale PID blocked start"

run_command "$ROOT/Start.command" >/dev/null
test "$(tr -d '[:space:]' < "$APP_SUPPORT/overlay.pid")" = "$RUNNING_PID" || fail "repeated start did not reuse the process"

open -n -g "$APP" \
  --env "HOME=$TEST_HOME" \
  --env "CODEX_HOME=$CODEX_HOME" \
  --env "CODEX_PET_APP_SUPPORT_DIR=$APP_SUPPORT"
sleep 0.5
EXACT_PROCESS_COUNT=$(exact_process_count)
test "$EXACT_PROCESS_COUNT" = "1" || fail "the app allowed a second exact executable instance"
test "$(tr -d '[:space:]' < "$APP_SUPPORT/overlay.pid")" = "$RUNNING_PID" || fail "a duplicate launch replaced the owner PID"

rm -f "$APP_SUPPORT/overlay.pid"
STATUS_WITHOUT_PID=$(run_command "$ROOT/Status.command")
printf '%s\n' "$STATUS_WITHOUT_PID" | rg -F 'Running: true' >/dev/null || fail "status did not find a running app without its PID file"
printf '%s\n' "$STATUS_WITHOUT_PID" | rg -F "ProcessId: $RUNNING_PID" >/dev/null || fail "status recovered the wrong process"
run_command "$ROOT/Start.command" >/dev/null
test "$(tr -d '[:space:]' < "$APP_SUPPORT/overlay.pid")" = "$RUNNING_PID" || fail "start did not recover the exact process after PID loss"

rm -f "$APP_SUPPORT/overlay.pid"
run_command "$ROOT/Stop.command" >/dev/null
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  kill -0 "$RUNNING_PID" 2>/dev/null || break
  sleep 0.1
done
kill -0 "$RUNNING_PID" 2>/dev/null && fail "stop did not terminate the matching executable"

sleep 30 &
SLEEP_PID=$!
echo "$SLEEP_PID" > "$APP_SUPPORT/overlay.pid"
run_command "$ROOT/Stop.command" >/dev/null
kill -0 "$SLEEP_PID" 2>/dev/null || fail "stop killed an unrelated process"
test ! -f "$APP_SUPPORT/overlay.pid" || fail "unrelated stale PID was not removed"
kill -TERM "$SLEEP_PID"
wait "$SLEEP_PID" 2>/dev/null || true
SLEEP_PID=""

cat > "$FAKE_BIN/launchctl" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$LAUNCH_LOG"
exit 0
SH
chmod +x "$FAKE_BIN/launchctl"
cat > "$FAKE_BIN/lsappinfo" <<'SH'
#!/bin/bash
if test "${LSAPPINFO_ACTIVE:-0}" = "1"; then
  printf '%s\n' 'ASN:0x0-0x12345:com.openai.codex'
fi
exit 0
SH
chmod +x "$FAKE_BIN/lsappinfo"
cat > "$FAKE_BIN/open" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$OPEN_LOG"
exit 0
SH
chmod +x "$FAKE_BIN/open"
export LAUNCH_LOG OPEN_LOG

LOCAL_ONLY_APP="$TEST_ROOT/nonexistent/Codex Pet Usage.app"
CODEX_PET_INSTALLED_APP="$LOCAL_ONLY_APP" LSAPPINFO_ACTIVE=0 run_command "$ROOT/InstallStartup.command" >/dev/null
CODEX_PET_INSTALLED_APP="$LOCAL_ONLY_APP" LSAPPINFO_ACTIVE=0 run_command "$ROOT/InstallStartup.command" >/dev/null
PLIST="$TEST_HOME/Library/LaunchAgents/$LABEL.plist"
test -f "$PLIST" || fail "startup plist was not written"
test "$(plutil -extract Label raw "$PLIST")" = "$LABEL" || fail "startup label is wrong"
test "$(plutil -extract ProgramArguments.0 raw "$PLIST")" = "$(realpath "$EXECUTABLE")" || fail "startup executable path is wrong"
test "$(plutil -extract WatchPaths.0 raw "$PLIST")" = "$CODEX_HOME/.codex-global-state.json" || fail "startup watch path is wrong"
if plutil -extract ProgramArguments.1 raw "$PLIST" >/dev/null 2>&1; then
  fail "startup must not use a polling helper argument"
fi
if plutil -extract WatchPaths.1 raw "$PLIST" >/dev/null 2>&1; then
  fail "startup must watch exactly one path"
fi
test "$(plutil -extract EnvironmentVariables.CODEX_HOME raw "$PLIST")" = "$CODEX_HOME" || fail "startup CODEX_HOME is wrong"
test "$(plutil -extract EnvironmentVariables.CODEX_PET_USAGE_POLL_SECONDS raw "$PLIST")" = "45" || fail "startup usage polling value is wrong"
test "$(plutil -extract EnvironmentVariables.CODEX_PET_POLL_MS raw "$PLIST")" = "250" || fail "startup pet polling value is wrong"
test "$(plutil -extract EnvironmentVariables.CODEX_PET_HOVER_PADDING raw "$PLIST")" = "42" || fail "startup hover padding is wrong"
test "$(plutil -extract EnvironmentVariables.CODEX_PET_APP_SUPPORT_DIR raw "$PLIST")" = "$APP_SUPPORT" || fail "startup app support override is wrong"
if plutil -extract KeepAlive raw "$PLIST" >/dev/null 2>&1; then
  fail "startup must not have KeepAlive"
fi
if plutil -extract RunAtLoad raw "$PLIST" >/dev/null 2>&1; then
  fail "startup must not have RunAtLoad"
fi
test "$(find "$TEST_HOME/Library/LaunchAgents" -type f -name '*.plist' | wc -l | tr -d '[:space:]')" = "1" || fail "startup wrote more than one plist"
test "$(rg -Fxc "bootout gui/$(id -u) $PLIST" "$LAUNCH_LOG")" = "2" || fail "local startup install did not bootout the exact plist twice"
test "$(rg -Fxc "bootstrap gui/$(id -u) $PLIST" "$LAUNCH_LOG")" = "2" || fail "local startup install did not bootstrap the exact plist twice"
test "$(wc -l < "$LAUNCH_LOG" | tr -d '[:space:]')" = "4" || fail "local startup install made unexpected launchctl calls"
test ! -e "$OPEN_LOG" || fail "inactive Codex caused the app to open"

INSTALLED_APP="$TEST_ROOT/Applications/Codex Pet Usage.app"
INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/CodexPetUsage"
mkdir -p "$(dirname "$INSTALLED_EXECUTABLE")"
cp "$EXECUTABLE" "$INSTALLED_EXECUTABLE"
chmod +x "$INSTALLED_EXECUTABLE"
CODEX_PET_INSTALLED_APP="$INSTALLED_APP" LSAPPINFO_ACTIVE=1 run_command "$ROOT/InstallStartup.command" >/dev/null
CODEX_PET_INSTALLED_APP="$INSTALLED_APP" LSAPPINFO_ACTIVE=1 run_command "$ROOT/InstallStartup.command" >/dev/null
test "$(plutil -extract ProgramArguments.0 raw "$PLIST")" = "$(realpath "$INSTALLED_EXECUTABLE")" || fail "startup did not prefer the installed executable"
test "$(find "$TEST_HOME/Library/LaunchAgents" -type f -name '*.plist' | wc -l | tr -d '[:space:]')" = "1" || fail "switching startup executable wrote more than one plist"
test "$(rg -Fxc "bootout gui/$(id -u) $PLIST" "$LAUNCH_LOG")" = "4" || fail "repeated startup installs did not bootout exactly once each"
test "$(rg -Fxc "bootstrap gui/$(id -u) $PLIST" "$LAUNCH_LOG")" = "4" || fail "repeated startup installs did not bootstrap exactly once each"
test "$(wc -l < "$LAUNCH_LOG" | tr -d '[:space:]')" = "8" || fail "repeated startup installs made unexpected launchctl calls"
test "$(rg -Fxc -- "-g $INSTALLED_APP" "$OPEN_LOG")" = "2" || fail "active Codex did not open the installed app exactly with -g"

run_command "$ROOT/UninstallStartup.command" >/dev/null
run_command "$ROOT/UninstallStartup.command" >/dev/null
test ! -e "$PLIST" || fail "startup plist was not removed"
rg -F "bootout gui/$(id -u) $PLIST" "$LAUNCH_LOG" >/dev/null || fail "startup did not bootout the exact plist"

echo "PASS: control commands and app bundle verified"
