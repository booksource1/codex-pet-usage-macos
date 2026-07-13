# Verification

This is a concise, reproducible record for the current source tree. Run the
commands from the repository root on macOS 14 or later with an Apple Silicon
(`arm64`) toolchain.

## Automated evidence

| Check | Evidence |
| --- | --- |
| Swift behavior | `swift run CodexPetUsageTests` — 69 tests passed, 0 failures. The harness covers usage decoding and fallback, window matching and geometry, hover timing, layout and presentation, runtime configuration, refresh serialization, and log policy. |
| Control scripts | `bash Tests/Shell/verify-control-commands.sh` — passed. It checks exact executable identity, stale or missing PID recovery, repeated starts, unrelated-process protection, late-process handoff, failure-closed discovery, and LaunchAgent isolation. |
| Build and bundle | `bash scripts/build-app.sh`, plist checks, `codesign --verify --deep --strict`, and an `arm64` binary check pass for the generated app. |
| Permission boundary | The accessory app uses metadata-only window inspection and launches without Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Apple Events, or administrator permissions. |
| LaunchAgent behavior | The isolated startup check registers exactly one Codex state-file `WatchPaths` entry, leaves `RunAtLoad` and `KeepAlive` absent, and uses the exact-label handoff when Codex is active. |
| Network and logging boundary | Request tests enforce the fixed HTTPS usage endpoint and redirect rejection. Log-policy tests reject credentials and response content; access tokens are never logged or persisted. |

## Geometry and visual checks

The metadata-only geometry check matches the overlay frame recorded in Codex state
to the live Codex frame returned by `CGWindowList`, then applies only the resulting
origin delta to the pet rectangle. This confirms stale JSON origin correction
without screenshots, Accessibility, or Screen Recording.

Human visual confirmation is still required for the real pet: hover appearance,
ten-second expiry, leave/re-entry behavior, edge placement, and the rendered usage
values and countdowns. Direct UI automation against Codex is blocked by the host
safety policy; no bypass was attempted.

See [CONTRIBUTING.md](../CONTRIBUTING.md), [SECURITY.md](../SECURITY.md), and the
[README](../README.md) for build, privacy, and usage context.
