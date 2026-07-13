# Codex Launch and Pet Follow Fix — Design

## Goal

Make Codex Pet Usage start on a best-effort basis when Codex Desktop starts,
and keep the usage ring/card aligned with the visible pet while the Codex pet
window moves.

The implementation must remain a small native local utility. It must not add a
permanent polling helper, Accessibility permission, Screen Recording permission,
Apple Events automation, or a hard-coded screen offset.

## Confirmed alignment root cause

The Codex state JSON and the actual Electron window can temporarily disagree
after the pet moves. For the reported screenshot, the state file declared the
overlay origin as `(1498, 0)`, while `CGWindowListCopyWindowInfo` reported the
live `356×320` Codex pet window at `(1498, 30)`. The 30-point vertical difference
matches the visible ring offset.

The existing ring geometry is correct relative to the state file's mascot
rectangle. Adding a fixed `+30` correction would only hide this instance of the
problem and would fail for other window positions or displays.

## Live pet-window correction

The JSON remains the source for:

- whether the pet overlay is open;
- the overlay window's expected size and position;
- mascot-relative bounds;
- display bounds.

On every existing 100 ms pet poll, the app also queries on-screen Core Graphics
window metadata. It obtains the process identifiers of running applications
whose bundle identifier is `com.openai.codex`, then considers only windows owned
by those processes. Among those windows, it selects a candidate whose width and
height each match the JSON overlay window within one point. If more than one
candidate matches, it chooses the frame whose origin is closest to the JSON
origin; equal-distance candidates retain their Core Graphics input order.

The selected live window origin replaces only the JSON overlay origin. Mascot
relative coordinates, dimensions, display selection, hover timing, and visual
layout remain unchanged. This produces a corrected global mascot rectangle and
corresponding AppKit rectangle on every poll.

If Codex is not running, Core Graphics returns no usable metadata, or no window
matches the expected overlay size, the app falls back to the JSON geometry. The
query uses window metadata only and must not request screen contents or trigger
a privacy permission prompt.

## Codex-triggered startup

`InstallStartup.command` registers the existing user LaunchAgent immediately
with `launchctl bootstrap`. The plist watches
`$CODEX_HOME/.codex-global-state.json`. Opening Codex normally changes this
state file, causing launchd to attempt to start Codex Pet Usage. Once started,
the usage app continues running as the same lightweight invisible accessory app.

The LaunchAgent does not use `RunAtLoad` and does not run a shell polling loop.
This is deliberately best-effort: if a future Codex version stops writing the
state file during launch, no invisible watcher process is added to compensate.

The installer prefers the verified installed executable at
`/Applications/Codex Pet Usage.app/Contents/MacOS/CodexPetUsage`; if it is not
present, it builds and uses the repository-local app. After registering the
LaunchAgent, the installer repeatedly discovers and terminates only processes
whose resolved executable is the exact selected executable. It rescans to catch
late arrivals during handoff, requires three consecutive empty scans before
declaring the handoff stable, and fails closed if exact-process discovery fails.
Same-basename processes at other paths are left untouched.

When `com.openai.codex` is already active, the installer asks launchd to
`kickstart` the exact service label only after that handoff. This makes launchd,
rather than an `open`-launched process, the startup owner and avoids a transient
duplicate when the newly bootstrapped job races an independently opened app.
When Codex is inactive, the installer does not launch the app; the LaunchAgent
waits for its `WatchPaths` state-file trigger. Repeated installation remains
idempotent and must not create duplicate app instances.

`UninstallStartup.command` continues to unload and remove only this project's
LaunchAgent. No Codex files are modified.

## Components

### Window-frame matching

A small pure core helper selects the closest size-matching frame from supplied
candidate frames. It has no AppKit dependency and is unit tested for exact
matches, multiple candidates, negative display origins, size mismatch, and no
candidate.

### macOS window metadata reader

The app target obtains Codex process identifiers through `NSWorkspace` and
on-screen window frames through Core Graphics. It converts metadata into plain
frames, delegates selection to the pure matcher, and returns an optional live
overlay frame.

### Geometry correction

`PetGeometry` retains the JSON overlay frame in addition to the mascot and
display rectangles. A pure correction method offsets the mascot rectangle by
the difference between the live and JSON origins and recomputes its AppKit
coordinates. Existing callers that have no live frame retain current behavior.

## Error handling and privacy

Window lookup failure is a normal fallback condition and is not logged every
100 ms. Malformed or partially written JSON continues to hide the overlay for
that tick. No window title, screenshot, pet image, process command line, prompt,
or Codex content is persisted.

Startup installation writes only the existing LaunchAgent plist and operational
log paths. It remains user-scoped and requires no administrator privileges.

## Verification

Tests are written before production changes and must prove:

- the live `(1498, 30)` frame corrects a JSON `(1498, 0)` origin by 30 points;
- x/y movement, negative origins, and multiple matching windows are handled;
- mismatched or missing live windows preserve JSON geometry;
- the overlay layout center moves by exactly the live-origin delta;
- startup plist uses `WatchPaths`, omits `RunAtLoad`, points at the installed app
  when available, and is bootstrapped idempotently;
- startup handoff stops only the exact selected executable, catches a late exact
  process even after an initially empty scan, requires three consecutive empty
  scans, preserves same-basename decoys, and fails before kickstart if process
  discovery fails;
- active-Codex installation uses launchd `kickstart` for the exact service label,
  while inactive installation waits for `WatchPaths` and never calls `open`;
- uninstall remains isolated and idempotent;
- all existing usage, hover, layout, lifecycle, and security tests still pass.

Final verification builds and signs the app, installs it in `/Applications`,
registers the LaunchAgent on this Mac, confirms only one usage process runs, and
compares the corrected geometry with current Core Graphics window metadata.

## Non-goals

- No fixed coordinate offset.
- No modification of Codex, ChatGPT, or CodexPet Nest bundles.
- No always-running shell/process watcher.
- No attempt to close the usage app automatically when Codex quits.
- No new settings window, menu-bar item, updater, analytics, or permissions.
