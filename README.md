# Codex Pet Usage for macOS

一个非常小的原生 macOS 用量徽章：平时完全隐藏，鼠标进入 Codex Desktop 小宠物附近时，短暂显示 5 小时和 7 天用量。

这是受 [Jimmy-asks-AI/codex-pet-usage](https://github.com/Jimmy-asks-AI/codex-pet-usage) 启发的独立 macOS 重写，采用 MIT 许可，与 OpenAI 无官方关联。

## 功能

- 鼠标进入宠物范围外加 24 pt 后显示，10 秒后自动隐藏。
- 外环显示 5 小时剩余比例，内环显示 7 天剩余比例。
- 222×88 pt 的小卡片显示百分比、刷新倒计时、数据来源和观察时间。
- 窗口透明、置顶、点击穿透，不显示 Dock 图标或菜单栏项目。
- 每 30 秒尝试读取实时用量；失败时读取本地 Codex 日志。
- 无第三方运行时、UI 框架、分析、更新器或遥测。

## 要求与构建

- macOS 14 或更高版本。
- 当前验证目标为 Apple Silicon；代码本身不依赖特定 CPU 架构。
- 构建需要 Swift 6 / Xcode Command Line Tools。

```bash
bash scripts/build-app.sh
```

构建结果位于 `dist/Codex Pet Usage.app`，使用本机 ad-hoc 签名。可双击运行，或执行：

```bash
./Start.command
./Status.command
./Stop.command
```

这些命令只管理当前仓库 `dist` 中完整路径匹配的可执行文件，不会按进程名批量终止其他程序。

## Codex 启动时触发

默认不启用。需要时手动执行：

```bash
./InstallStartup.command
./UninstallStartup.command
```

安装命令会立即登记当前用户的 LaunchAgent，并监听 `$CODEX_HOME/.codex-global-state.json`，在 Codex 更新该状态文件时尽力启动应用；若 Codex 当时已运行，也会立即尝试启动。它优先使用 `/Applications/Codex Pet Usage.app`，否则使用仓库内构建，不需要管理员权限，也没有常驻轮询助手。移动仓库或应用、或修改参数后，请重新执行安装命令。

## 可调参数

| 环境变量 | 默认值 | 说明 |
| --- | ---: | --- |
| `CODEX_HOME` | `~/.codex` | Codex 状态、认证和日志目录 |
| `CODEX_PET_USAGE_POLL_SECONDS` | `30` | 用量刷新秒数，最低 10 秒 |
| `CODEX_PET_POLL_MS` | `100` | 宠物位置和悬停轮询毫秒数，最低 50 ms |
| `CODEX_PET_HOVER_PADDING` | `24` | 宠物外扩命中范围，限制为 0–200 pt |

`CODEX_PET_APP_SUPPORT_DIR` 仅用于隔离测试运行文件；普通使用无需设置。

## 数据与隐私

应用只读取：

- `~/.codex/.codex-global-state.json`
- `~/.codex/auth.json`
- `~/.codex/logs_2.sqlite` 或 `logs_1.sqlite`

它只写入 `~/Library/Application Support/CodexPetUsageOverlay/overlay.pid` 和 `overlay.log`；明确安装登录启动时，另写入上面的 LaunchAgent plist。

实时查询只访问固定地址 `https://chatgpt.com/backend-api/wham/usage`。该地址是 ChatGPT 的私有、未承诺稳定的端点，未来可能改变或失效。访问令牌只放在这一请求的 Authorization 头中，不写日志、不持久化，也不允许重定向到其他主机。应用不会发送提示词、会话正文、仓库文件、截图或宠物图像。

不需要 Accessibility、Screen Recording、Input Monitoring、Full Disk Access、Apple Events 或管理员权限。

## 排查

- 完全不显示：先在 Codex Desktop 打开 `/pet`，再运行 `./Status.command`，确认 `PetOverlayOpen: true`。
- 显示“用量暂不可用”：网络实时接口可能不可用，本地日志中也可能还没有 `codex.rate_limits` 事件。查看 `LatestLog`，日志不会包含令牌或响应正文。
- 双击后提示无法打开：在本机重新运行 `bash scripts/build-app.sh`，再验证 `codesign --verify --deep --strict "dist/Codex Pet Usage.app"`。
- PID 陈旧：再次运行 `Start.command` 或 `Stop.command` 会在精确路径检查后清理；不会终止占用同一 PID 文件的无关进程。
- 移动仓库后登录启动失效：重新运行 `InstallStartup.command`。

## 明确边界

本项目没有设置窗口、主题市场、番茄钟、快捷启动器、菜单栏界面、自动更新或数据分析。它也不修改 Codex 文件和宠物，只读取必要状态并绘制一个临时本地徽章。

验证过程与已知限制见 [docs/verification.md](docs/verification.md)。
