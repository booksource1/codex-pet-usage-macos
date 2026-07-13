# Codex Pet Usage for macOS — Design

## Goal

Build a minimal native macOS rewrite of
[`Jimmy-asks-AI/codex-pet-usage`](https://github.com/Jimmy-asks-AI/codex-pet-usage).
The macOS version must preserve the original project's visible behavior, data
flow, and operational simplicity while replacing Windows PowerShell/WPF APIs
with Swift/AppKit equivalents.

This is a small local utility, not a general pet platform. It must not grow a
settings window, theme system, marketplace, Pomodoro timer, shortcut launcher,
analytics, updater, or other unrelated features.

## User-visible behavior

The utility runs without a Dock icon and normally draws nothing. It reads the
Codex Desktop pet bounds from `~/.codex/.codex-global-state.json` every 100 ms.
When the pointer first enters the pet rectangle plus 24 points of padding, a
click-through overlay appears for 10 seconds. Remaining over the pet or leaving
and re-entering while the overlay is still visible does not extend that period.
After the overlay expires, a later leave-and-re-enter starts a new 10-second
period. If the Codex pet overlay is closed, the usage overlay hides immediately.

The overlay matches the Windows reference:

- A translucent outer ring shows the five-hour window remaining percentage.
- A translucent inner ring shows the seven-day window remaining percentage.
- The outer ring uses `#3CEBBD` at approximately 84% opacity and 7-point width.
- The inner ring uses `#56B2FF` at approximately 80% opacity and 5-point width.
- Inactive tracks are white at low opacity.
- A 222×88-point dark translucent information card appears 10 points from the
  ring, on the right unless that would exceed the active display boundary.
- Chinese text shows the five-hour percentage/reset countdown, seven-day
  percentage/reset countdown, data source, and observation time.
- Unavailable data produces the same two unavailable messages and waiting
  status as the reference.

The overlay is transparent, topmost, excluded from normal app switching, does
not activate the app, and does not intercept pointer events.

## Runtime and packaging

Use Swift Package Manager with Swift and Apple-provided system frameworks only:
Foundation for files, JSON, timers, and networking; AppKit/Core Animation for
the overlay; and the system SQLite library for read-only log access. The executable is wrapped
in a minimal `.app` bundle for double-click launching, but the repository also
provides small `start`, `stop`, `status`, `install-startup`, and
`uninstall-startup` commands analogous to the reference `.bat` entry points.
No Node.js, Electron, Python runtime, Tauri, third-party UI framework, or package
dependency is allowed.

The application targets macOS 14 or later. Apple Silicon is the required first
target; the code should remain architecture-neutral so an Intel build can be
produced if the toolchain supports it.

Login startup is optional and disabled by default. Installation uses a
user-scoped LaunchAgent that runs the app at its current absolute path without
administrator privileges, matching the reference project's in-place startup
registration. `install-startup` does not copy or relocate the bundle. If the
bundle is moved, the user reruns `install-startup` to update the path.
Uninstallation removes only files created by this project.

## Components

### Codex state reader

Decode only the fields needed from `.codex-global-state.json`:
`electron-avatar-overlay-open`, the top-level overlay origin, mascot-relative
bounds, and display bounds. Convert the stored top-left screen coordinates into
AppKit's bottom-left global coordinate system. A malformed, missing, or
partially-written state file is treated as temporarily unavailable rather than
fatal.

### Hover state machine

Accept the current time, pointer-in-expanded-pet state, previous pointer state,
and current show-until time. It implements the reference behavior as a pure,
unit-tested component. If no pet rectangle is available for any tick, it clears
both the show-until value and the previous-pointer state before hiding the
window, exactly as the reference does. This avoids coupling timing semantics to
AppKit timers.

### Usage client

Every 30 seconds, read `~/.codex/auth.json`, extract
`tokens.access_token`, and request only
`https://chatgpt.com/backend-api/wham/usage` with the token in an Authorization
header. Use a 20-second timeout. Decode either `rate_limit` or `rate_limits`,
and the alternative primary/secondary field names supported by the reference.
Convert `used_percent` to remaining percentage, accept `remaining_percent`
directly, clamp values to 0–100, and normalize reset time variants.

The token is never logged, persisted, displayed, or sent to another host.

### Local log fallback

If live usage is unavailable, open `logs_2.sqlite` and then `logs_1.sqlite` in
read-only mode. Query the newest `feedback_log_body` containing
`codex.rate_limits`, extract the balanced JSON object surrounding the marker,
and pass it through the same usage decoder. Use the system SQLite library
directly; do not shell out to Python.

### Overlay controller and renderer

An AppKit controller owns two timers: 30 seconds for usage and 100 ms for pet
position/hover updates. It refreshes usage and overlay state immediately at
launch before starting normal timer-driven updates. A borderless `NSPanel`
renders the rings and text card with Core Animation/AppKit drawing. Layout is
recomputed from the current pet bounds so movement, multiple displays, and
display-edge placement follow the reference behavior.

The ring diameter is `max(104, max(petWidth, petHeight) + 52)`. The outer radius
is half that diameter minus 7 points; the inner radius is 13 points smaller.
Arcs start at −90 degrees, proceed clockwise, have round line caps, and clamp a
visible full value to 99.99% to avoid a degenerate 360-degree path. The card has
a 6-point corner radius, `#0D181E` background at approximately 80% opacity,
10/8-point horizontal/vertical padding, 12-point primary text, 10-point status
text, and the exact Chinese strings from the reference. Countdown values round
remaining seconds upward before formatting days/hours/minutes/seconds.

### Process and startup commands

Thin shell commands launch the app, find only this bundle's process, report
running/startup state, stop only matching processes, and install/remove the
user LaunchAgent. They must quote all paths and avoid broad process termination.

## Data, privacy, and permissions

The utility reads:

- `~/.codex/.codex-global-state.json`
- `~/.codex/auth.json`
- `~/.codex/logs_2.sqlite` or `logs_1.sqlite`

It writes only its PID/log files under
`~/Library/Application Support/CodexPetUsageOverlay/` and, when explicitly
requested, its LaunchAgent plist under `~/Library/LaunchAgents/`.

It requires no administrator, Accessibility, Screen Recording, Input
Monitoring, Full Disk Access, Apple Events, or browser permissions. It sends no
prompts, session content, repository content, screenshots, pet images, or log
bodies. The only network destination is the fixed ChatGPT usage endpoint.

## Error handling

All polling failures are recoverable. A state read failure hides the overlay
for that tick. A live usage failure falls back to local logs. If both sources
fail, the overlay remains functional and shows unavailable text. Logs contain
short error descriptions but no authorization headers, tokens, response bodies,
or Codex log bodies. Repeated start commands reuse the existing instance.

## Tests and verification

Tests are written before production behavior and cover:

- remaining/used percentage conversion and clamping;
- reset time variants and countdown formatting;
- balanced JSON extraction from mixed log text;
- read-only SQLite fallback selection;
- pet bounds and macOS coordinate conversion;
- hit testing with 24-point padding;
- the exact 10-second hover/re-entry state machine;
- left/right card placement at display boundaries;
- malformed or temporarily partial state/auth files;
- command scripts targeting only this process and LaunchAgent.

Integration tests use a temporary `CODEX_HOME` and fixture databases and never
read the real access token. Final verification builds the `.app`, runs the full
test suite, checks bundle metadata and architecture, and manually exercises the
overlay against the real Codex `/pet` on this Mac.

## Repository and delivery

The local Git repository is named `codex-pet-usage-macos`. It uses the MIT
license and documents the Windows reference project as inspiration while making
clear that this is an independent macOS rewrite. The README includes build,
run, status, startup installation, privacy, troubleshooting, and uninstall
instructions.

Creating or pushing a remote GitHub repository is a separate publication step.
Before that external write, confirm the destination account and whether the
repository should be public or private.

## Explicit non-goals

- No large persistent panel or nest.
- No menu bar UI unless later proven necessary for macOS lifecycle reliability.
- No settings screen.
- No pet/theme marketplace or package installer.
- No pet switching or modification of Codex files.
- No arbitrary commands or quick actions.
- No analytics, crash reporting, advertisements, or tracking.
- No automatic updater.
- No privilege escalation.
