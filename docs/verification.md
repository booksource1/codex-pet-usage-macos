# Verification record

Date: 2026-07-13  
Host: macOS 26.5.1, Apple Silicon arm64  
Toolchain: Swift 6.3.2, Xcode Command Line Tools

Reference basis: `Jimmy-asks-AI/codex-pet-usage` commit
`48d8cf7a39296bb86219f65f58062801e8e8014a` (2026-07-08). The Swift behavior,
constants, strings, process recovery, and startup parameter propagation were
audited against `CodexPetUsageOverlay.ps1` at that revision.

## Automated evidence

| Area | Evidence | Result |
| --- | --- | --- |
| Usage parsing, duration-based window classification, fallback, coordinates, live-frame correction, window matching, hover timing, layout, presentation, configuration, refresh serialization, log policy | `swift run CodexPetUsageTests` | 69 tests passed, 0 failures |
| Process identity, missing/stale PID recovery, unrelated-process protection, single-instance behavior, repeated start, exact-process startup handoff, stable-empty/late-arrival races, discovery failure, and LaunchAgent isolation | `bash Tests/Shell/verify-control-commands.sh` | Passed; handoff required three consecutive empty scans, stopped a process arriving after an initially empty scan plus initial and late exact processes, preserved a same-basename different-path process, failed closed on process discovery error, and never used `open` |
| Codex-triggered startup | Isolated verifier plus `launchctl print gui/501/ai.jimmyasks.codex-pet-usage-macos` | Passed; registered with exactly one state-file watch path, with `RunAtLoad` and `KeepAlive` absent; active Codex used exact-label launchd `kickstart` after process handoff |
| Bundle metadata | `plutil -lint` and exact-key checks | Passed |
| Code signature | `codesign --verify --deep --strict --verbose=2` | Valid on disk |
| Architecture | `file dist/Codex Pet Usage.app/Contents/MacOS/CodexPetUsage` | Mach-O 64-bit arm64 |
| Shell syntax and prohibited operations | `bash -n` plus verifier scan | Passed |
| Local installation | Release build copied to `/Applications/Codex Pet Usage.app`; installed signature, plist, executable architecture, launchd job ownership, and exact-process count checked | Passed; launchd job PID 91334 remained running and all 50 samples over 8.826 seconds observed exactly one installed process with the same PID |

## Real-device checklist

The following checks are recorded only after exercising the installed bundle with the real Codex Desktop pet. Items without direct evidence remain incomplete.

| Check | Result | Evidence or note |
| --- | --- | --- |
| Accessory app runs without Dock/menu-bar item or permission prompt | Passed | Installed process ran; `LSUIElement=true`; metadata-only `CGWindowList` access returned Codex frames while Accessibility and Screen Capture preflights were both false |
| Hidden before hover; pet+24 pt entry shows the badge | Partial | `CGWindowList` reported zero on-screen app windows before hover; direct hover still needs human visual confirmation |
| Badge expires after 10 seconds without extension | Pending | — |
| Leave and re-enter after expiry triggers again | Pending | — |
| Closing `/pet` hides immediately and clears hover state | Pending | — |
| Badge tracks pet and moves card left at the display edge | Partial | Live-frame origin correction and right-edge card placement pass deterministic tests. Current metadata-only evidence matched JSON overlay `(0, 0, 356, 320)` to the live `com.openai.codex` frame `(2119, 30, 356, 320)`, for delta `(2119, 30)` and corrected pet rectangle `(2119, 96, 80, 87)`; Accessibility and Screen Capture preflights were false; human visual confirmation remains pending |
| 5-hour/7-day values, countdowns, and source render correctly | Partial | All 763 operational log lines matched approved summary formats, including 576 usage summaries; the latest was `source=live, 5h=--, 7d=64`. The log scan found no Authorization, bearer-token, access-token-value, request-body, response-body, cookie, or URL fragments; exact Chinese strings pass presentation tests; visual confirmation pending |
| Offline live failure falls back to local logs | Automated only | Deterministic live-failure/log-success test passed; the machine network was not disconnected |
| No Accessibility, Screen Recording, or admin permission | Passed | No sensitive entitlement or plist permission usage string; app launched without a prompt |
| Live outbound connection is limited to `chatgpt.com` | Passed by code and request tests | Fixed URL and redirect rejection tests passed; no other network construction exists |
| `Stop.command` stops only the exact process and cleans the PID | Passed | Real Start/Status/Stop run ended PID 18306 and removed `overlay.pid`; unrelated-process behavior also passed verifier |

Direct UI automation against `com.openai.codex` was denied by the host safety policy. No bypass was attempted. The remaining visual-only checks therefore require the user to hover the real pet and report the result or provide a pet-only screenshot.

## Completion audit

| Design requirement | Evidence |
| --- | --- |
| 30 s usage and 100 ms pet polling; 24 pt/10 s hover behavior | Runtime/configuration and hover-state tests |
| Exact ring/card dimensions, edge placement, percentages, and Chinese text | Layout and presentation tests; AppKit renderer inspection |
| Live usage, fixed-host redirect protection, and log fallback | Live client, decoder, and SQLite tests; real `source=live` refresh |
| Transparent accessory panel that ignores pointer events | Panel code, `LSUIElement`, and zero-window pre-hover runtime check |
| Minimal native dependency set | Swift package manifest and clean Release build |
| PID/log privacy and exact process targeting | Log-policy tests, real lifecycle run, and shell verifier |
| User-scoped Codex-triggered startup | Real `gui/501` registration points to the exact `/Applications` executable and one `~/.codex/.codex-global-state.json` `WatchPaths` trigger; `RunAtLoad`/`KeepAlive` are absent. With Codex active, launchd owned PID 91334 after exact-process handoff; 50 consecutive samples over 8.826 seconds found the job running and exactly one installed process with that PID. The isolated verifier covers three-scan stable-empty handoff, a process arriving after an initially empty scan, initial and late exact-process termination, same-basename decoy preservation, fail-closed discovery, inactive `WatchPaths` waiting, and exact-label kickstart without `open` |
| Signed `.app`, macOS 14 metadata, arm64 binary | `codesign`, `plutil`, and `file` output |
| Real pet alignment | Metadata-only JSON/CGWindow comparison confirms live-frame selection and corrected pet coordinates; hover appearance and timing still await human visual confirmation because direct Codex UI control is blocked |

## Security boundary

The app does not include analytics, an updater, arbitrary command execution, browser automation, or privilege escalation. Network code constructs only the fixed HTTPS usage URL, rejects redirects, and never logs Authorization values or response/log bodies. The live ChatGPT usage endpoint is private and may change without notice.
