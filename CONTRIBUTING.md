# Contributing

Thanks for helping improve Codex Pet Usage for macOS. This repository is a small,
native Swift overlay; please keep changes easy to review and verify.

## Prerequisites

- macOS 14 or later on Apple Silicon (`arm64`)
- Swift 6 and the Xcode Command Line Tools
- Codex Desktop only for manual checks of the real pet and hover behavior

Run the commands below from the repository root:

```bash
swift run CodexPetUsageTests
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict "dist/Codex Pet Usage.app"
```

The shell verifier builds a release bundle and exercises the control scripts with
isolated temporary fixtures. The build script writes the ad-hoc-signed app to
`dist/Codex Pet Usage.app`.

## Local controls

The source checkout provides these controls:

- `./Start.command` builds when needed and starts the source-built app.
- `./Status.command` reports the exact source executable and optional startup state.
- `./Stop.command` stops only the exact source executable and removes stale PID state.
- `./InstallStartup.command` optionally installs a user LaunchAgent that watches the
  Codex state file; `./UninstallStartup.command` removes it.

The controls are for a source checkout and are not included in the release ZIP.
They do not require administrator privileges.

## Pull requests

- Keep each PR focused on one behavior, fix, or documentation change; avoid unrelated
  refactors and formatting churn.
- Preserve the native dependency set, existing permission boundary, and absence of
  analytics, telemetry, and an updater unless a change is explicitly discussed.
- Add or update deterministic tests for behavior changes. Include the commands you ran
  and call out any manual visual checks that remain pending.
- Never commit Codex credentials, prompts, conversation text, private logs, or other
  personal data. Redact local paths and sensitive output in issue and PR descriptions.

For vulnerability reports, follow [SECURITY.md](SECURITY.md) rather than opening a
public issue.
