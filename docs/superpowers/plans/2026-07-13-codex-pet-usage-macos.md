# Codex Pet Usage for macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tiny native macOS overlay that strictly reproduces the behavior of `Jimmy-asks-AI/codex-pet-usage` without adding a settings UI, marketplace, menu bar item, or third-party runtime.

**Architecture:** A dependency-free Swift package separates pure parsing/state/layout logic from AppKit rendering and process lifecycle. The executable runs as an accessory app, polls Codex state at 100 ms, refreshes usage every 30 seconds, and shows one click-through `NSPanel`; small shell entry points provide build/start/stop/status/login-startup parity with the Windows reference.

**Tech Stack:** Swift 6.3, Swift Package Manager, Foundation, AppKit/Core Animation, system SQLite3, POSIX shell, XCTest/Swift Testing.

---

## File map

- `Package.swift` — package, core library, executable, and test targets.
- `Sources/CodexPetUsageCore/Models.swift` — shared value types and defaults.
- `Sources/CodexPetUsageCore/UsageDecoder.swift` — usage JSON conversion and countdown formatting.
- `Sources/CodexPetUsageCore/LogUsageReader.swift` — balanced JSON extraction and read-only SQLite query.
- `Sources/CodexPetUsageCore/LiveUsageClient.swift` — auth reading, fixed-host HTTP call, and live→log fallback.
- `Sources/CodexPetUsageCore/CodexStateReader.swift` — pet state decoding and top-left→AppKit coordinate conversion.
- `Sources/CodexPetUsageCore/HoverState.swift` — pure 10-second hover state machine.
- `Sources/CodexPetUsageCore/OverlayLayout.swift` — reference ring/card geometry.
- `Sources/CodexPetUsageCore/OverlayPresentation.swift` — exact Chinese display strings derived from snapshots.
- `Sources/CodexPetUsageCore/RuntimeConfiguration.swift` — clamped environment settings and log-sanitization policy.
- `Sources/CodexPetUsageApp/OverlayView.swift` — exact ring and card drawing.
- `Sources/CodexPetUsageApp/OverlayPanel.swift` — transparent, click-through, non-activating panel.
- `Sources/CodexPetUsageApp/AppLogger.swift` — privacy-safe local logging.
- `Sources/CodexPetUsageApp/AppCoordinator.swift` — timers, data refresh, PID lifecycle, and overlay orchestration.
- `Sources/CodexPetUsageApp/main.swift` — accessory-app entry point and argument defaults.
- `Tests/CodexPetUsageCoreTests/*.swift` — behavior-first unit and fixture tests.
- `Tests/Fixtures/` — sanitized Codex state/auth/log data only.
- `scripts/build-app.sh` — reproducibly create an ad-hoc-signed `.app` without Xcode.
- `Start.command`, `Stop.command`, `Status.command` — process controls matching the reference.
- `InstallStartup.command`, `UninstallStartup.command` — current-user LaunchAgent controls.
- `README.md`, `LICENSE`, `.gitignore` — usage, safety, attribution, and repository hygiene.

Every Swift Testing file declares a named `@Suite` whose type name matches the
`swift test --filter ...` commands below. This ensures each RED/GREEN command
runs the intended tests rather than silently selecting zero tests.

## Task 1: Create the minimal Swift package and build proof

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/CodexPetUsageCore/Models.swift`
- Create: `Sources/CodexPetUsageApp/main.swift`
- Create: `Tests/CodexPetUsageCoreTests/PackageSmokeTests.swift`

- [ ] **Step 1: Write the failing package smoke test**

```swift
import Testing
@testable import CodexPetUsageCore

@Suite struct PackageSmokeTests {
  @Test func defaultsMatchJimmyReference() {
      #expect(OverlayDefaults.usagePollSeconds == 30)
      #expect(OverlayDefaults.petPollMilliseconds == 100)
      #expect(OverlayDefaults.hoverPadding == 24)
      #expect(OverlayDefaults.hoverShowSeconds == 10)
  }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `swift test --filter defaultsMatchJimmyReference`

Expected: FAIL because `Package.swift`/`OverlayDefaults` do not exist.

- [ ] **Step 3: Add the minimal package and defaults**

`Package.swift` defines macOS 14+, library `CodexPetUsageCore`, executable
`CodexPetUsage`, and test target. Link the core target with `sqlite3`.

```swift
// Models.swift
import Foundation

public enum OverlayDefaults {
    public static let usagePollSeconds: TimeInterval = 30
    public static let petPollMilliseconds = 100
    public static let hoverPadding: CGFloat = 24
    public static let hoverShowSeconds: TimeInterval = 10
}
```

`main.swift` temporarily prints `Codex Pet Usage scaffold`; it contains no
production behavior yet. `.gitignore` ignores `.build/`, `dist/`, `.DS_Store`,
and local runtime logs.

- [ ] **Step 4: Run tests and executable and verify GREEN**

Run: `swift test && swift run CodexPetUsage`

Expected: all tests PASS and stdout contains `Codex Pet Usage scaffold`.

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "build: create minimal Swift package"
```

## Task 2: Decode usage payloads and format reset countdowns

**Files:**
- Modify: `Sources/CodexPetUsageCore/Models.swift`
- Create: `Sources/CodexPetUsageCore/UsageDecoder.swift`
- Create: `Tests/CodexPetUsageCoreTests/UsageDecoderTests.swift`

- [ ] **Step 1: Write failing payload tests**

Tests must use real JSON data and cover separately:

```swift
@Test func usedPercentBecomesRemaining() throws {
    let usage = try #require(UsageDecoder.decode(data: fixtureJSON(
      #"{"rate_limit":{"primary_window":{"used_percent":37,"limit_window_seconds":18000,"reset_after_seconds":90},"secondary_window":{"used_percent":52,"limit_window_seconds":604800,"reset_after_seconds":120}}}"#),
      source: .test, now: fixedNow))
    #expect(usage.primaryRemaining == 63)
    #expect(usage.secondaryRemaining == 48)
}

@Test func remainingPercentAndAlternativeNamesAreAccepted() throws { /* rate_limits/primary */ }
@Test func percentagesClampToZeroThroughOneHundred() throws { /* -4 and 140 */ }
@Test func absentWindowsReturnNil() { /* empty payload */ }
@Test func resetVariantsNormalize() throws { /* relative, Unix numeric, ISO string */ }
@Test func durationRoundsUpLikeReference() { /* 61s -> 1分钟 1秒 */ }
```

- [ ] **Step 2: Run decoder tests and verify RED**

Run: `swift test --filter UsageDecoderTests`

Expected: FAIL because `UsageDecoder`, `UsageSnapshot`, and formatting APIs are missing.

- [ ] **Step 3: Implement the minimal decoder**

Define `UsageSource` (`live`, `log`, `test`, `none`) and `UsageSnapshot` with available,
remaining percentages, reset dates, window seconds, source, and observed date.
Parse with `JSONSerialization` so alternative field names remain small and
explicit. Implement these exact choices:

```swift
let rate = root["rate_limit"] ?? root["rate_limits"]
let primary = rate["primary_window"] ?? rate["primary"]
let secondary = rate["secondary_window"] ?? rate["secondary"]
remaining = bucket["remaining_percent"] ?? (100 - bucket["used_percent"])
remaining = min(100, max(0, remaining))
```

Reset precedence is `reset_after_seconds`, `seconds_until_reset`, then
`reset_at`, `resets_at`, `reset_time`, `expires_at`, `window_reset_at`.
`formatDuration(resetAt:now:)` uses `ceil`, then the same day/hour/minute/second
branches and Chinese units as the reference.

- [ ] **Step 4: Verify GREEN and regression suite**

Run: `swift test`

Expected: all tests PASS with no warnings.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexPetUsageCore Tests/CodexPetUsageCoreTests
git commit -m "feat: decode Codex usage windows"
```

## Task 3: Extract log events and query SQLite read-only

**Files:**
- Create: `Sources/CodexPetUsageCore/LogUsageReader.swift`
- Create: `Tests/CodexPetUsageCoreTests/LogUsageReaderTests.swift`

- [ ] **Step 1: Write failing balanced-JSON tests**

```swift
@Test func extractsRateLimitObjectFromMixedLogBody() throws {
    let body = #"prefix {"type":"codex.rate_limits","rate_limits":{"primary":{"remaining_percent":75}}} suffix"#
    let usage = try #require(LogUsageReader.decode(body: body, now: fixedNow))
    #expect(usage.primaryRemaining == 75)
    #expect(usage.source == .log)
}

@Test func bracesInsideStringsDoNotBreakExtraction() { /* escaped quote and brace */ }
@Test func unrelatedOrMalformedBodiesReturnNil() { /* no marker / incomplete JSON */ }
```

- [ ] **Step 2: Run extraction tests and verify RED**

Run: `swift test --filter LogUsageReaderTests`

Expected: FAIL because `LogUsageReader` is missing.

- [ ] **Step 3: Implement balanced extraction and verify GREEN**

Port the reference depth/string/escape scanner directly into a pure Swift
function. Search backward from each `codex.rate_limits` marker for candidate
opening braces and accept the first candidate decoded by `UsageDecoder`.

Run: `swift test --filter LogUsageReaderTests`

Expected: extraction tests PASS.

- [ ] **Step 4: Write the failing read-only SQLite fixture test**

Create a temporary database through the same SQLite3 C API, add the reference
`logs(id, ts, ts_nanos, feedback_log_body)` schema, insert old/new matching rows,
and assert `read(paths:)` returns the newest. Add a test proving path 1 is used
when path 2 is absent and that missing/corrupt databases return `nil`.

- [ ] **Step 5: Run SQLite tests and verify RED**

Run: `swift test --filter sqlite`

Expected: FAIL because database querying is not implemented.

- [ ] **Step 6: Implement minimal read-only SQLite access**

Use `sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)` and
the exact parameter-free query:

```sql
SELECT feedback_log_body
FROM logs
WHERE feedback_log_body LIKE '%codex.rate_limits%'
ORDER BY ts DESC, ts_nanos DESC, id DESC
LIMIT 1
```

Always finalize statements and close each database with `defer`; never mutate a
Codex database.

- [ ] **Step 7: Verify GREEN and commit**

Run: `swift test`

Expected: all tests PASS.

```bash
git add Sources/CodexPetUsageCore/LogUsageReader.swift Tests/CodexPetUsageCoreTests/LogUsageReaderTests.swift
git commit -m "feat: read usage fallback from Codex logs"
```

## Task 4: Implement the fixed-host live client and fallback service

**Files:**
- Create: `Sources/CodexPetUsageCore/LiveUsageClient.swift`
- Create: `Tests/CodexPetUsageCoreTests/LiveUsageClientTests.swift`
- Create: `Tests/Fixtures/auth-valid.json`

- [ ] **Step 1: Write failing auth and request-construction tests**

Test through injected `URLSessionProtocol` and file loader, not the real network.
The suite must also simulate a 302 response and verify the redirect delegate
returns `nil`, makes no second request, and never sends Authorization to the
redirect target; simulate 401/500 and verify they fail before JSON decoding:

```swift
@Test func requestUsesOnlyFixedChatGPTUsageEndpoint() throws {
    let request = try LiveUsageClient.makeRequest(accessToken: "secret")
    #expect(request.url?.absoluteString == "https://chatgpt.com/backend-api/wham/usage")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    #expect(request.timeoutInterval == 20)
}

@Test func readsNestedAccessTokenWithoutPersistingIt() throws { /* fixture auth */ }
@Test func missingOrBlankTokenReturnsNil() { /* no request */ }
@Test func redirectsAreRejectedBeforeTokenCanReachAnotherHost() { /* 302 */ }
@Test func nonSuccessHTTPStatusIsRejected() { /* 401 and 500 */ }
```

- [ ] **Step 2: Run live-client tests and verify RED**

Run: `swift test --filter LiveUsageClientTests`

Expected: FAIL because the client does not exist.

- [ ] **Step 3: Implement request/auth parsing and verify GREEN**

Use `URLSession.data(for:)` and `UsageDecoder`; expose only the fixed endpoint.
Create the session with a delegate whose
`urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`
always calls `completionHandler(nil)`. After the request, require
`response.url?.scheme == "https"`, `response.url?.host == "chatgpt.com"`, the
exact `/backend-api/wham/usage` path, and status 200...299 before decoding. The
implementation must never interpolate a URL from auth/log data and must not
include token/response body text in errors.

Run: `swift test --filter LiveUsageClientTests`

Expected: request and auth tests PASS.

- [ ] **Step 4: Write failing live→log→unavailable orchestration tests**

Use small injected closures to assert:

- a successful live result skips logs;
- a thrown/empty live result tries logs;
- both failures produce `UsageSnapshot.unavailable(now:)`;
- observed source is `live`, `log`, or `none` correctly.

- [ ] **Step 5: Implement `UsageService` minimally**

`UsageService.refresh()` reads `<codexHome>/auth.json`, tries the live client,
then invokes `LogUsageReader` for `logs_2.sqlite`, `logs_1.sqlite`. `codexHome`
is a constructor argument defaulting to `~/.codex`; tests pass a temporary path.

- [ ] **Step 6: Verify GREEN and commit**

Run: `swift test`

Expected: all tests PASS and no real network request is made.

```bash
git add Sources/CodexPetUsageCore/LiveUsageClient.swift Tests/CodexPetUsageCoreTests/LiveUsageClientTests.swift Tests/Fixtures
git commit -m "feat: refresh usage with local fallback"
```

## Task 5: Parse Codex pet bounds and convert coordinates

**Files:**
- Create: `Sources/CodexPetUsageCore/CodexStateReader.swift`
- Create: `Tests/CodexPetUsageCoreTests/CodexStateReaderTests.swift`
- Create: `Tests/Fixtures/state-pet-open.json`

- [ ] **Step 1: Write failing state-reader tests**

Fixture uses the actual field shape but sanitized coordinates. Test:

```swift
@Test func openPetProducesGlobalTopLeftRect() throws {
    let pet = try #require(CodexStateReader.decode(data: fixture, mainDisplayHeight: 1080))
    #expect(pet.topLeftRect == CGRect(x: 1775, y: 13, width: 77, height: 83))
    #expect(pet.appKitRect == CGRect(x: 1775, y: 984, width: 77, height: 83))
}
```

Also test closed overlay, missing mascot, malformed/partial JSON, default display
bounds, negative display origins, and an atomic file rewrite race returning nil.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter CodexStateReaderTests`

Expected: FAIL because reader/types are missing.

- [ ] **Step 3: Implement minimal decoding and conversion**

Keep both reference top-left coordinates (for matching placement logic) and
AppKit global coordinates (for panel placement/hit testing). Convert using the
primary screen returned by `NSScreen.screens.first`, which is macOS's stable
menu-bar/reference screen and corresponds to Electron's top-left global origin;
do not use the dynamically changing `NSScreen.main`. Supply that primary frame's
`maxY` to core: `appKitY = primaryMaxY - top - height`.

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift test`

Expected: all state and regression tests PASS.

```bash
git add Sources/CodexPetUsageCore/CodexStateReader.swift Tests/CodexPetUsageCoreTests/CodexStateReaderTests.swift Tests/Fixtures/state-pet-open.json
git commit -m "feat: locate Codex pet on macOS displays"
```

## Task 6: Reproduce the hover state machine and layout geometry

**Files:**
- Create: `Sources/CodexPetUsageCore/HoverState.swift`
- Create: `Sources/CodexPetUsageCore/OverlayLayout.swift`
- Create: `Tests/CodexPetUsageCoreTests/HoverStateTests.swift`
- Create: `Tests/CodexPetUsageCoreTests/OverlayLayoutTests.swift`

- [ ] **Step 1: Write failing hit-test and hover tests**

Port every reference self-test as a separate test: inside/outside, 24-point
padding, first entry visible at +9 seconds, expired at +11, staying does not
extend, re-entering while visible does not extend, re-entering after expiration
does extend, and missing pet resets `showUntil`, `cursorWasInPet`, and visibility.

- [ ] **Step 2: Run hover tests and verify RED**

Run: `swift test --filter HoverStateTests`

Expected: FAIL because the state machine is missing.

- [ ] **Step 3: Implement the pure state machine and verify GREEN**

Use one value type:

```swift
struct HoverState {
    var showUntil: Date?
    var cursorWasInPet = false
    var overlayWasVisible = false
    mutating func update(pet: PetGeometry?, cursor: CGPoint, now: Date) -> Bool
}
```

Only set `showUntil = now + 10` when `inside && !cursorWasInPet &&
(showUntil == nil || now > showUntil!)`.

- [ ] **Step 4: Write failing exact-layout tests**

Assert ring size `max(104, max(width,height)+52)`, panel 222×88, 10-point gap,
minimum window height 96, outer/inner radii, right placement with room, left
placement at the right edge, and panel vertical centering.

- [ ] **Step 5: Implement `OverlayLayout.compute` and verify GREEN**

Return a value containing panel frame, ring center/radii, and global panel frame;
keep all constants named and equal to the reference.

Run: `swift test`

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexPetUsageCore/HoverState.swift Sources/CodexPetUsageCore/OverlayLayout.swift Tests/CodexPetUsageCoreTests
git commit -m "feat: match hover and overlay layout behavior"
```

## Task 7: Render the exact click-through AppKit overlay

**Files:**
- Create: `Sources/CodexPetUsageCore/OverlayPresentation.swift`
- Create: `Sources/CodexPetUsageApp/OverlayView.swift`
- Create: `Sources/CodexPetUsageApp/OverlayPanel.swift`
- Create: `Tests/CodexPetUsageCoreTests/OverlayPresentationTests.swift`

- [ ] **Step 1: Write failing presentation-model tests**

Keep strings testable in core/presentation data. Assert exact unavailable strings
and deterministic available strings:

```swift
#expect(model.title == "Codex 用量")
#expect(model.primary == "5小时 剩余 63% · 1分钟 30秒后刷新")
#expect(model.secondary == "7天 剩余 48% · 2分钟 0秒后刷新")
#expect(model.status == "来源 test · 12:00:00")
```

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter OverlayPresentationTests`

Expected: FAIL because presentation model is missing.

- [ ] **Step 3: Implement presentation model and verify GREEN**

Use fixed `Locale(identifier: "zh_CN")` only for stable integer/time formatting;
do not localize or alter reference wording.

- [ ] **Step 4: Implement the panel and view from tested values**

`OverlayPanel` uses `.borderless`, transparent background, `.nonactivatingPanel`,
`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `level = .floating`,
`ignoresMouseEvents = true`, `hidesOnDeactivate = false`, and no shadow.

`OverlayView` overrides `isFlipped` to return `true`, matching the reference's
top-left drawing coordinate system. `OverlayView.draw(_:)` uses `NSBezierPath`
for two low-opacity full-circle tracks
and two clockwise arcs starting at −90° with round caps. It draws the 222×88
rounded card and exact colors/alpha/font sizes from the spec. For missing values,
arc percentage is zero, matching the reference's display behavior.

- [ ] **Step 5: Build and run the full test suite**

Run: `swift test && swift build -c release`

Expected: tests PASS; release executable links AppKit and SQLite3 successfully.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexPetUsageApp Sources/CodexPetUsageCore Tests/CodexPetUsageCoreTests
git commit -m "feat: draw the minimal usage badge"
```

## Task 8: Wire timers, logging, PID lifecycle, and the app entry point

**Files:**
- Create: `Sources/CodexPetUsageCore/RuntimeConfiguration.swift`
- Create: `Sources/CodexPetUsageApp/AppLogger.swift`
- Create: `Sources/CodexPetUsageApp/AppCoordinator.swift`
- Modify: `Sources/CodexPetUsageApp/main.swift`
- Create: `Tests/CodexPetUsageCoreTests/RuntimeConfigurationTests.swift`

- [ ] **Step 1: Write failing runtime configuration tests**

Test the pure `RuntimeConfiguration` and `LogMessagePolicy` types in the core
target. Test clamping parity: usage polling minimum 10 seconds, pet polling minimum 50
ms, hover padding clamped 0–200. Use these exact environment names:
`CODEX_HOME`, `CODEX_PET_USAGE_POLL_SECONDS`, `CODEX_PET_POLL_MS`, and
`CODEX_PET_HOVER_PADDING`. Test the default and explicit temporary values. Test
log redaction rejects values matching bearer/token/response-body content.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter RuntimeConfigurationTests`

Expected: FAIL because configuration/logger policy is missing.

- [ ] **Step 3: Implement configuration and privacy-safe logger**

Implement environment parsing and log-message allowlisting/redaction in
`CodexPetUsageCore/RuntimeConfiguration.swift`. `AppLogger` remains a thin file
writer in the executable target and accepts only messages already produced by
`LogMessagePolicy`. Write `overlay.pid` and `overlay.log` under
`~/Library/Application Support/CodexPetUsageOverlay/`; log only fixed event names,
source, percentages, timestamps, safe numeric geometry, and sanitized error type.

- [ ] **Step 4: Implement coordinator behavior**

On launch: create app directory/PID, create hidden panel, start the 30-second and
100-ms timers, immediately refresh usage, immediately update the overlay, then
run `NSApplication`. Usage refresh is async; UI mutation returns to the main
actor. Every pet tick rereads state, samples `NSEvent.mouseLocation`, updates the
hover state, recomputes layout/text, and orders the panel front or out.

On termination: invalidate timers and remove the PID only if it contains the
current PID. Set activation policy `.accessory`; create no menu bar item or Dock
window.

- [ ] **Step 5: Verify tests, launch briefly, and inspect process files**

Run:

```bash
swift test
CODEX_HOME="$PWD/Tests/Fixtures/runtime-home" swift run CodexPetUsage & pid=$!
sleep 2
test -f "$HOME/Library/Application Support/CodexPetUsageOverlay/overlay.pid"
kill "$pid"; wait "$pid" || true
```

Expected: tests PASS; exactly one process runs; PID/log exist; log contains no
fixture token or JSON body.

- [ ] **Step 6: Commit**

```bash
git add Sources Tests
git commit -m "feat: run overlay as a local accessory app"
```

## Task 9: Package the `.app` and add minimal control commands

**Files:**
- Create: `scripts/build-app.sh`
- Create: `Start.command`
- Create: `Stop.command`
- Create: `Status.command`
- Create: `InstallStartup.command`
- Create: `UninstallStartup.command`
- Create: `Tests/Shell/verify-control-commands.sh`

- [ ] **Step 1: Write a failing dependency-free shell verification script**

The verifier first asserts scripts use quoted paths, the fixed bundle identifier
`ai.jimmyasks.codex-pet-usage-macos`, a unique LaunchAgent label, and never use
`killall`, broad `pkill`, `sudo`, `curl|sh`, or global Gatekeeper changes. It
also asserts the build script produces Info.plist keys `LSUIElement=true`,
`LSMinimumSystemVersion=14.0`, correct executable, version, and identifier.

It then runs behavioral tests with a temporary `HOME`, isolated
`CODEX_PET_APP_SUPPORT_DIR`, and a fake `launchctl` earlier on `PATH` that records
arguments. Tests must prove:

- a stale PID is removed and does not block start;
- a PID belonging to an unrelated `sleep` process is never killed;
- repeated start reuses the exact existing bundled executable process;
- stop terminates only a PID whose resolved executable path matches the bundle;
- startup install writes one plist under the isolated HOME with the exact current
  app executable path and calls bootstrap for only its label/domain;
- startup uninstall calls bootout for only that plist and removes only that file;
- running install/uninstall twice is idempotent.

- [ ] **Step 2: Run shell verifier and verify RED**

Run: `bash Tests/Shell/verify-control-commands.sh`

Expected: FAIL because scripts/bundle are missing.

- [ ] **Step 3: Implement the reproducible app builder**

`scripts/build-app.sh` runs `swift build -c release`, recreates
`dist/Codex Pet Usage.app/Contents/{MacOS,Resources}`, copies the one executable,
writes the minimal Info.plist, and runs
`codesign --force --deep --sign - "$APP"`. It does not download anything.

- [ ] **Step 4: Implement control commands**

- All control scripts allow `CODEX_PET_APP_SUPPORT_DIR` as a test isolation
  override; production defaults to the specified Application Support directory.
- `Start.command`: build if needed, validate a PID belongs to the exact bundled
  executable path, otherwise `open -n "$APP"` and report its PID.
- `Stop.command`: read PID and send TERM only after exact executable-path check;
  remove stale PID.
- `Status.command`: report Running, ProcessId, PidFile, LogFile,
  StartupEnabled, LaunchAgentPath, CodexHome, CodexStateFile, PetOverlayOpen, and
  LatestLog.
- `InstallStartup.command`: write
  `~/Library/LaunchAgents/ai.jimmyasks.codex-pet-usage-macos.plist` pointing to
  the app's current absolute executable and load it with `launchctl bootstrap`.
- `UninstallStartup.command`: `bootout` only this label/path and remove only its
  plist.

For executable identity, resolve both expected and observed paths with
`realpath` and compare exact strings; do not accept substring or basename
matches. The behavioral verifier builds the real app and exercises these paths.

- [ ] **Step 5: Verify GREEN, bundle integrity, and architecture**

Run:

```bash
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Pet Usage.app"
file "dist/Codex Pet Usage.app/Contents/MacOS/CodexPetUsage"
plutil -lint "dist/Codex Pet Usage.app/Contents/Info.plist"
```

Expected: verifier PASS; signature valid on disk; Mach-O arm64 executable;
Info.plist OK.

- [ ] **Step 6: Commit**

```bash
git add scripts *.command Tests/Shell
git commit -m "feat: package and manage the macOS overlay"
```

## Task 10: Document, install, and verify against the real Codex pet

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Modify: `.gitignore`
- Create: `docs/verification.md`

- [ ] **Step 1: Write README and MIT license**

README must mirror the reference sections: features, run commands, adjustable
environment/configuration, login startup, data/privacy, runtime files,
troubleshooting, and known boundaries. State that the live endpoint is private
and unstable; identify the project as an independent macOS rewrite inspired by
Jimmy's MIT project. Do not claim official OpenAI affiliation.

- [ ] **Step 2: Run all automated verification from a clean build**

Run:

```bash
rm -rf .build dist
swift test
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict "dist/Codex Pet Usage.app"
```

Expected: clean build succeeds and every test/verifier passes.

- [ ] **Step 3: Install the verified app locally without enabling startup**

Copy the built bundle to `/Applications/Codex Pet Usage.app` only after checking
no unrelated app will be overwritten. Do not install the LaunchAgent yet.

- [ ] **Step 4: Perform real-device behavior verification**

With Codex `/pet` open, verify and record in `docs/verification.md`:

1. app runs with no Dock/menu-bar item and no permission prompt;
2. no overlay appears before hover;
3. entering pet+24 pt shows rings/card;
4. display expires after 10 seconds and is not extended by staying/re-entry;
5. leaving then entering after expiry triggers again;
6. closing `/pet` hides immediately and clears hover state;
7. ring/card track pet movement and choose the left side at the right edge;
8. text shows 5-hour/7-day values, countdowns, and source;
9. disconnecting the network falls back to local logs;
10. process uses no Accessibility/Screen Recording/Admin permission;
11. outbound connections are limited to `chatgpt.com` during live refresh;
12. PID/log cleanup works after `Stop.command`.

Capture a screenshot only of the pet and overlay, avoiding prompts or repository
content, and compare dimensions/colors/text visually with the reference spec.

- [ ] **Step 5: Run the completion audit**

Map every design-spec bullet to test output, script verifier output, bundle
inspection, or recorded manual evidence. Any missing/indirect evidence remains
incomplete and must be fixed before claiming success.

- [ ] **Step 6: Commit final documentation**

```bash
git add README.md LICENSE .gitignore docs/verification.md
git commit -m "docs: explain and verify the macOS overlay"
```

- [ ] **Step 7: Review repository state**

Run: `git status --short && git log --oneline --decorate -12`

Expected: clean working tree and focused commits for all ten tasks.

## Task 11: Prepare remote repository publication (do not publish yet)

**Files:**
- No code changes unless the user requests metadata updates.

- [ ] **Step 1: Ask for the destination and visibility**

Confirm the GitHub owner/account and whether `codex-pet-usage-macos` should be
public or private. This is the required external-write gate.

- [ ] **Step 2: Confirm GitHub authentication without exposing credentials**

Run: `gh auth status`

Expected: authenticated account matches the user-approved destination.

- [ ] **Step 3: Create and push only after explicit approval**

Run the exact visibility chosen by the user, for example:

```bash
gh repo create OWNER/codex-pet-usage-macos --public --source=. --remote=origin --push
```

Expected: GitHub reports the repository URL and `git remote -v` points to the
approved owner. Do not create or push anything if destination/visibility is not
confirmed.
