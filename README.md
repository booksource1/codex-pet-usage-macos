# Codex Pet Usage for macOS

一个面向 Codex Desktop 的极小原生 macOS 用量浮层：平时隐藏，鼠标移到宠物附近时显示 5 小时和 7 天用量。目标平台为 macOS 14+、Apple Silicon（arm64）。这是受 [Jimmy-asks-AI/codex-pet-usage](https://github.com/Jimmy-asks-AI/codex-pet-usage) 启发的独立 macOS 重写，采用 MIT 许可，是非官方项目，与 OpenAI 无关。

![用量浮层示例](docs/images/overlay-example.png)

This is a tiny native macOS 14+ (Apple Silicon/arm64) overlay for Codex Desktop. It stays hidden until the pointer reaches the pet, then shows the five-hour and seven-day usage. It is an independent macOS rewrite inspired by [Jimmy-asks-AI/codex-pet-usage](https://github.com/Jimmy-asks-AI/codex-pet-usage), MIT-licensed, unofficial, and not affiliated with OpenAI.

## 功能概览 / Core behavior

- 鼠标进入宠物外扩 24 pt 的范围时显示，离开后最多显示 10 秒；浮层跟随宠物并在屏幕边缘调整位置。
- 外环表示 5 小时剩余比例，内环表示 7 天剩余比例；222×88 pt 卡片显示百分比、重置倒计时、数据来源和观察时间。
- 每 30 秒刷新一次用量；实时请求失败时读取本地 Codex 日志。窗口透明、置顶、点击穿透，不显示 Dock 或菜单栏图标。
- 不含第三方运行时、更新器、分析或遥测。

- Enter the pet’s 24 pt hover area to show the overlay for up to 10 seconds; it follows the pet and moves inward at a screen edge.
- The outer ring is five-hour remaining usage, the inner ring is seven-day usage; the 222×88 pt card shows percentages, reset countdowns, source, and observation time.
- Usage refreshes every 30 seconds, falling back to local Codex logs when the live request fails. The transparent, click-through window is not shown in the Dock or menu bar.
- No third-party runtime, updater, analytics, or telemetry is included.

## 下载预构建版本 / Download a release

发布后可从下面的固定地址下载最新 ZIP（在项目尚未发布 Release 前，该地址会返回 404）：

<https://github.com/Jimmy-asks-AI/codex-pet-usage-macos/releases/latest/download/Codex-Pet-Usage-macOS.zip>

ZIP 只包含 `Codex Pet Usage.app`。解压后将应用拖到 `/Applications`，首次打开时 macOS 可能因这是本地 ad-hoc 签名而显示 Gatekeeper 警告；请在 Finder 中右键应用，选择“打开”，再确认打开。项目没有 Developer ID 签名，也不会要求管理员权限。

After a Release exists, the stable URL above downloads the latest ZIP (before then it returns 404). The ZIP contains only `Codex Pet Usage.app`; unzip it, drag the app to `/Applications`, and on first launch use Finder → right-click → **Open** if Gatekeeper warns about the local ad-hoc signature. There is no Developer ID signature and no administrator prompt.

## 从源码构建 / Build from source

需要 macOS 14+、Apple Silicon（arm64）和 Swift 6 / Xcode Command Line Tools：

```bash
bash scripts/build-app.sh
```

构建产物为 `dist/Codex Pet Usage.app`，使用本机 ad-hoc 签名。源码树中的控制脚本针对这个 `dist` 路径：

```bash
./Start.command    # 启动（缺少构建产物时先构建）
./Status.command   # 查看进程、浮层和启动状态
./Stop.command     # 停止精确匹配的本项目进程
```

`InstallStartup.command` 和 `UninstallStartup.command` 也只属于源码安装流程，不在下载 ZIP 中。它们分别安装或移除当前用户的 LaunchAgent；安装时不设置 `RunAtLoad` 或 `KeepAlive`，而是监听 `$CODEX_HOME/.codex-global-state.json`（默认：`~/.codex/.codex-global-state.json`），在该文件发生 Codex 状态变化后启动浮层。若安装时 Codex 已在运行，脚本会立即对该任务执行 `kickstart`；否则等待后续状态文件变化。这不是常驻轮询助手，不需要管理员权限。移动应用或仓库后请重新安装，关闭该行为可运行：

```bash
./InstallStartup.command
./UninstallStartup.command
```

The source build requires macOS 14+, Apple Silicon (arm64), and Swift 6/Xcode Command Line Tools. It writes `dist/Codex Pet Usage.app` with an ad-hoc signature. `Start.command`, `Status.command`, and `Stop.command` manage only that exact source-built executable; `InstallStartup.command` and `UninstallStartup.command` add or remove a per-user LaunchAgent without `RunAtLoad` or `KeepAlive`. It watches `$CODEX_HOME/.codex-global-state.json` (default: `~/.codex/.codex-global-state.json`) and starts after a Codex state-file change; if Codex is already active when installation runs, the script kickstarts the job immediately, otherwise it waits for a later change. This is not a polling helper and needs no administrator permission.

## 可调运行参数 / Runtime overrides

源码控制脚本会继承这些环境变量；无效值使用默认值：

| 变量 / Variable | 默认值 / Default | 限制 / Limits |
| --- | ---: | --- |
| `CODEX_HOME` | `~/.codex` | 非空路径；支持 `~` 展开 |
| `CODEX_PET_USAGE_POLL_SECONDS` | `30` 秒 / s | 最低 `10`；非有限或无效值使用默认值 |
| `CODEX_PET_POLL_MS` | `100` 毫秒 / ms | 最低 `50`；无效值使用默认值 |
| `CODEX_PET_HOVER_PADDING` | `24` pt | 限制为 `0–200` pt；非有限或无效值使用默认值 |

The source control scripts inherit these variables. `CODEX_HOME` selects the Codex directory (default `~/.codex`); the other values control usage polling, pet polling, and hover padding with the defaults and minimums/clamp shown above.

## 可选的宠物定制 / Optional pet customization

以下只是第三方定制示例，不是本仓库的依赖、构建步骤或安装内容；运行前请自行审阅包及其权限：

```bash
npx petdex@latest install kun-like
```

This is an optional third-party example only. `petdex` and `kun-like` are not dependencies of this repository, and this project does not install or verify them. Review the package before running it.

## 隐私与权限 / Privacy and permissions

应用默认从 `~/.codex` 读取 `.codex-global-state.json`、`auth.json` 和 `logs_2.sqlite`/`logs_1.sqlite`；设置 `CODEX_HOME` 后改用该目录。为定位 Codex 宠物窗口，它还通过 `CGWindow`/`NSWorkspace` 读取窗口边界和所属进程等元数据，不读取窗口像素，也不进行 Screen Recording。它只写入 `~/Library/Application Support/CodexPetUsageOverlay/overlay.pid` 与 `overlay.log`，以及你明确安装的 LaunchAgent plist。实时请求仅访问固定的 `https://chatgpt.com/backend-api/wham/usage`；该地址是 ChatGPT 的私有、未公开文档化端点，未来可能改变或失效。访问令牌只放在该请求的 `Authorization` 头中，不写日志、不持久化，并拒绝重定向到其他主机。不会发送提示词、会话正文、仓库文件、截图或宠物图像。

不需要 Accessibility、Screen Recording、Input Monitoring、Full Disk Access、Apple Events 或管理员权限。

By default, the app reads `.codex-global-state.json`, `auth.json`, and `logs_2.sqlite`/`logs_1.sqlite` under `~/.codex`; `CODEX_HOME` overrides that directory. To locate the Codex pet window, it also reads metadata-only process and window bounds through `CGWindow`/`NSWorkspace`; it does not read window pixels or use Screen Recording. It writes only its PID/log files and, when explicitly enabled, a user LaunchAgent plist. Live usage uses the fixed HTTPS endpoint above; that ChatGPT endpoint is private and undocumented and may change or stop working. The token is sent only in that request’s `Authorization` header, never logged or persisted, and redirects to another host are rejected. Prompts, conversation text, repository files, screenshots, and pet images are not sent. No Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Apple Events, or admin permission is required.

## 排查 / Troubleshooting

- **没有浮层**：在 Codex Desktop 打开 `/pet`，然后在源码目录运行 `./Status.command`，确认 `PetOverlayOpen: true`；确认鼠标进入宠物附近。
- **用量不可用**：实时接口可能暂时失败，本地日志也可能尚无 `codex.rate_limits` 事件；查看 `Status.command` 输出的 `LatestLog`。
- **下载的应用无法打开**：Finder 中右键 `Codex Pet Usage.app` 选择“打开”；源码构建可重新运行 `bash scripts/build-app.sh` 并检查 `codesign --verify --deep --strict "dist/Codex Pet Usage.app"`。
- **启动后仍没有浮层**：源码目录运行 `./Status.command` 查看 `StartupEnabled` 和 `LaunchAgentPath`；应用或仓库移动后重新运行 `./InstallStartup.command`。
- **停止或 PID 状态异常**：运行 `./Start.command` 或 `./Stop.command`；脚本只处理路径精确匹配的本项目可执行文件。

- **No overlay:** open `/pet` in Codex Desktop, run `./Status.command` from a source checkout, confirm `PetOverlayOpen: true`, and move the pointer near the pet.
- **Usage unavailable:** the live endpoint may be unavailable and local logs may not contain a `codex.rate_limits` event yet; inspect `LatestLog` in `Status.command` output.
- **Downloaded app blocked:** in Finder, right-click `Codex Pet Usage.app` and choose **Open**. For a source build, rerun `bash scripts/build-app.sh` and verify its signature.
- **Startup stopped working:** check `StartupEnabled` and `LaunchAgentPath` with `./Status.command`; rerun `./InstallStartup.command` after moving the app or checkout.
- **Stale PID or stop issue:** run `./Start.command` or `./Stop.command`; controls target only the exact project executable path.

## 开发者 / Developers

在 macOS 14+ arm64 主机上运行：

```bash
swift run CodexPetUsageTests
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict "dist/Codex Pet Usage.app"
```

贡献、漏洞报告和验证记录： [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [docs/verification.md](docs/verification.md)。

On a macOS 14+ arm64 host, run the test harness, shell verifier, release build, and signature check shown above. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [docs/verification.md](docs/verification.md) for contribution, private security reporting, and verification details.

## 许可证 / License

[MIT](LICENSE)
