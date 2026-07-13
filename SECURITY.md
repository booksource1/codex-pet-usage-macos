# Security

## Data and permission boundary

Codex Pet Usage is a local macOS overlay. It reads only the following Codex files
under `$CODEX_HOME` (which defaults to `~/.codex`):
`$CODEX_HOME/.codex-global-state.json`, `$CODEX_HOME/auth.json`, and the
`$CODEX_HOME/logs_2.sqlite`/`$CODEX_HOME/logs_1.sqlite` usage databases. In
addition, it reads metadata-only window and process bounds to locate Codex; it
does not read pixels or use Screen Recording. It writes only its user-scoped PID
and operational log files, plus a per-user LaunchAgent plist when startup
integration is explicitly installed.

Live usage requests use the fixed HTTPS endpoint
`https://chatgpt.com/backend-api/wham/usage`. The access token is sent only in
that request's `Authorization` header. Credentials, request or response bodies,
and authorization headers are not logged or persisted, and redirects to another
host are rejected. Prompts, conversation text, repository files, screenshots,
and pet images are not sent.

The app does not request Accessibility, Screen Recording, Input Monitoring, Full
Disk Access, Apple Events, or administrator access.

## Reporting a vulnerability

Please do not open a public issue or include secrets in a pull request. Use the
repository's GitHub **Security** tab and choose **Report a vulnerability** to
start a private Security Advisory. Include the affected version or commit, a
minimal reproduction, impact, and any relevant redacted logs. Never include an
access token, `auth.json`, private Codex logs, prompts, or conversation content.

This project does not publish a separate security-report email address; use the
private GitHub advisory flow instead.
