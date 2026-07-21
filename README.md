# Codex Pet Usage for macOS

[中文 README](README.zh-CN.md)

![Overlay example](docs/images/overlay-example.png)

This is a tiny native macOS 14+ (Apple Silicon/arm64) overlay for Codex Desktop. It stays hidden until the pointer reaches the pet, then shows the five-hour and seven-day usage. It is an independent macOS rewrite inspired by [Jimmy-asks-AI/codex-pet-usage](https://github.com/Jimmy-asks-AI/codex-pet-usage), MIT-licensed, unofficial, and not affiliated with OpenAI.

## Core behavior

- Enter the pet’s 24 pt hover area to show the overlay for up to 10 seconds; it follows the pet and moves inward at a screen edge.
- The outer ring is five-hour remaining usage, and the inner ring is seven-day remaining usage. The 222×88 pt card shows percentages, reset countdowns, source, and observation time.
- Usage refreshes every 30 seconds, falling back to local Codex logs when the live request fails.
- The transparent, click-through window is not shown in the Dock or menu bar.
- No third-party runtime, updater, analytics, or telemetry is included.

## Download a release

After a Release exists, this stable URL downloads the latest ZIP (before then it returns 404):

<https://github.com/booksource1/codex-pet-usage-macos/releases/latest/download/Codex-Pet-Usage-macOS.zip>

The ZIP contains only `Codex Pet Usage.app`. Unzip it, drag the app to `/Applications`, and on first launch use Finder → right-click → **Open** if Gatekeeper warns about the local ad-hoc signature. There is no Developer ID signature and no administrator prompt.

## Build from source

The source build requires macOS 14+, Apple Silicon (arm64), and Swift 6/Xcode Command Line Tools:

```bash
bash scripts/build-app.sh
```

The output is `dist/Codex Pet Usage.app`, signed with the local ad-hoc identity. The source-tree control scripts manage that exact executable:

```bash
./Start.command    # Start; build first if the app is missing
./Status.command   # Show process, overlay, and startup status
./Stop.command     # Stop only the exact project executable
```

`InstallStartup.command` and `UninstallStartup.command` belong to the source installation flow and are not included in the download ZIP. They add or remove a per-user LaunchAgent without `RunAtLoad` or `KeepAlive`. The agent watches `$CODEX_HOME/.codex-global-state.json` (default: `~/.codex/.codex-global-state.json`) and starts after a Codex state-file change. If Codex is already active when installation runs, the script kickstarts the job immediately; otherwise it waits for a later state-file change. This is not a polling helper and needs no administrator permission.

After moving the app or repository, run `./InstallStartup.command` again. To disable this behavior, run:

```bash
./InstallStartup.command
./UninstallStartup.command
```

## Runtime overrides

The source control scripts inherit these environment variables. Invalid values use the defaults:

| Variable | Default | Limits |
| --- | ---: | --- |
| `CODEX_HOME` | `~/.codex` | Non-empty absolute path; do not use a literal `~` |
| `CODEX_PET_USAGE_POLL_SECONDS` | `30` s | Minimum `10`; invalid or non-finite values use the default |
| `CODEX_PET_POLL_MS` | `100` ms | Minimum `50`; invalid values use the default |
| `CODEX_PET_HOVER_PADDING` | `24` pt | Clamped to `0–200` pt; invalid or non-finite values use the default |

## Optional pet customization

The following is only a third-party customization example. It is not a dependency, build step, or installation component of this repository. Review the package and its permissions before running it:

```bash
npx petdex@latest install kun-like
```

`petdex` and `kun-like` are not dependencies of this repository, and this project does not install or verify them.

## Privacy and permissions

By default, the app reads `.codex-global-state.json`, `auth.json`, and `logs_2.sqlite`/`logs_1.sqlite` under `~/.codex`; `CODEX_HOME` overrides that directory. To locate the Codex pet, it reads metadata-only process and window bounds through `CGWindow`/`NSWorkspace`; it does not read window pixels or use Screen Recording.

It writes only `~/Library/Application Support/CodexPetUsageOverlay/overlay.pid` and `overlay.log`, plus the user LaunchAgent plist when you explicitly install startup. Live usage uses the fixed HTTPS endpoint `https://chatgpt.com/backend-api/wham/usage`; this is a private, undocumented ChatGPT endpoint and may change or stop working. The token is sent only in that request’s `Authorization` header, never logged or persisted, and redirects to another host are rejected.

Prompts, conversation text, repository files, screenshots, and pet images are not sent. No Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Apple Events, or administrator permission is required.

## Troubleshooting

- **No overlay:** open `/pet` in Codex Desktop, run `./Status.command` from a source checkout, confirm `PetOverlayOpen: true`, and move the pointer near the pet.
- **Usage unavailable:** the live endpoint may be unavailable and local logs may not contain a `codex.rate_limits` event yet; inspect `LatestLog` in `./Status.command` output.
- **Downloaded app blocked:** in Finder, right-click `Codex Pet Usage.app` and choose **Open**. For a source build, rerun `bash scripts/build-app.sh` and verify its signature.
- **Startup stopped working:** check `StartupEnabled` and `LaunchAgentPath` with `./Status.command`; rerun `./InstallStartup.command` after moving the app or repository.
- **Stale PID or stop issue:** run `./Start.command` or `./Stop.command`; controls target only the exact project executable path.

## Developers

On a macOS 14+ arm64 host, run:

```bash
swift run CodexPetUsageTests
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict "dist/Codex Pet Usage.app"
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [docs/verification.md](docs/verification.md).

## License

[MIT](LICENSE)
