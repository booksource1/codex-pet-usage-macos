# Codex Pet Usage for macOS

[English README](README.md)

![用量浮层示例](docs/images/overlay-example.png)

这是一个面向 Codex Desktop 的极小原生 macOS 用量浮层：平时隐藏，鼠标移到宠物附近时显示 5 小时和 7 天用量。目标平台为 macOS 14+、Apple Silicon（arm64）。这是受 [Jimmy-asks-AI/codex-pet-usage](https://github.com/Jimmy-asks-AI/codex-pet-usage) 启发的独立 macOS 重写，采用 MIT 许可证，是非官方项目，与 OpenAI 无关。

## 功能概览

- 鼠标进入宠物外扩 24 pt 的范围时显示，离开后最多显示 10 秒；浮层跟随宠物并在屏幕边缘调整位置。
- 外环表示 5 小时剩余比例，内环表示 7 天剩余比例；222×88 pt 卡片显示百分比、重置倒计时、数据来源和观察时间。
- 每 30 秒刷新一次用量；实时请求失败时读取本地 Codex 日志。
- 窗口透明、置顶、点击穿透，不显示 Dock 或菜单栏图标。
- 不包含第三方运行时、更新器、分析或遥测。

## 下载预构建版本

发布后可从下面的固定地址下载最新 ZIP（在项目尚未发布 Release 前，该地址会返回 404）：

<https://github.com/booksource1/codex-pet-usage-macos/releases/latest/download/Codex-Pet-Usage-macOS.zip>

ZIP 只包含 `Codex Pet Usage.app`。解压后将应用拖到 `/Applications`；首次打开时，如果 macOS 因本地 ad-hoc 签名显示 Gatekeeper 警告，请在 Finder 中右键应用，选择“打开”。项目没有 Developer ID 签名，也不会要求管理员权限。

## 从源码构建

需要 macOS 14+、Apple Silicon（arm64）和 Swift 6 / Xcode Command Line Tools：

```bash
bash scripts/build-app.sh
```

构建产物为 `dist/Codex Pet Usage.app`，使用本机 ad-hoc 签名。源码树中的控制脚本只管理这个精确的可执行文件：

```bash
./Start.command    # 启动；缺少构建产物时先构建
./Status.command   # 查看进程、浮层和启动状态
./Stop.command     # 停止精确匹配的本项目进程
```

`InstallStartup.command` 和 `UninstallStartup.command` 属于源码安装流程，不在下载 ZIP 中。它们分别安装或移除当前用户的 LaunchAgent，不设置 `RunAtLoad` 或 `KeepAlive`，而是监听 `$CODEX_HOME/.codex-global-state.json`（默认：`~/.codex/.codex-global-state.json`），在 Codex 状态文件发生变化后启动浮层。如果安装时 Codex 已在运行，脚本会立即对该任务执行 `kickstart`；否则等待后续状态文件变化。这不是常驻轮询助手，不需要管理员权限。

移动应用或仓库后请重新运行 `./InstallStartup.command`。如需关闭该行为，运行：

```bash
./InstallStartup.command
./UninstallStartup.command
```

## 可调运行参数

源码控制脚本会继承这些环境变量；无效值使用默认值：

| 变量 | 默认值 | 限制 |
| --- | ---: | --- |
| `CODEX_HOME` | `~/.codex` | 非空绝对路径；自定义时不要使用字面 `~` |
| `CODEX_PET_USAGE_POLL_SECONDS` | `30` 秒 | 最低 `10`；非有限或无效值使用默认值 |
| `CODEX_PET_POLL_MS` | `100` 毫秒 | 最低 `50`；无效值使用默认值 |
| `CODEX_PET_HOVER_PADDING` | `24` pt | 限制为 `0–200` pt；非有限或无效值使用默认值 |

## 可选的宠物定制

以下只是第三方定制示例，不是本仓库的依赖、构建步骤或安装内容；运行前请自行审阅包及其权限：

```bash
npx petdex@latest install kun-like
```

`petdex` 和 `kun-like` 不是本仓库的依赖，本项目不会安装或验证它们。

## 隐私与权限

应用默认从 `~/.codex` 读取 `.codex-global-state.json`、`auth.json` 和 `logs_2.sqlite`/`logs_1.sqlite`；设置 `CODEX_HOME` 后改用该目录。为定位 Codex 宠物，它通过 `CGWindow`/`NSWorkspace` 读取进程和窗口边界等元数据，不读取窗口像素，也不使用 Screen Recording。

应用只写入 `~/Library/Application Support/CodexPetUsageOverlay/overlay.pid` 和 `overlay.log`，以及你明确安装启动项时的用户 LaunchAgent plist。实时用量使用固定 HTTPS 地址 `https://chatgpt.com/backend-api/wham/usage`；这是 ChatGPT 的私有、未公开文档化端点，未来可能改变或失效。访问令牌只放在该请求的 `Authorization` 头中，不写日志、不持久化，并拒绝重定向到其他主机。

不会发送提示词、会话正文、仓库文件、截图或宠物图像。不需要 Accessibility、Screen Recording、Input Monitoring、Full Disk Access、Apple Events 或管理员权限。

## 排查

- **没有浮层：** 在 Codex Desktop 打开 `/pet`，然后在源码目录运行 `./Status.command`，确认 `PetOverlayOpen: true`，并将鼠标移到宠物附近。
- **用量不可用：** 实时接口可能暂时失败，本地日志也可能尚无 `codex.rate_limits` 事件；查看 `./Status.command` 输出的 `LatestLog`。
- **下载的应用无法打开：** 在 Finder 中右键 `Codex Pet Usage.app`，选择“打开”。源码构建可重新运行 `bash scripts/build-app.sh` 并检查签名。
- **启动后仍没有浮层：** 运行 `./Status.command` 查看 `StartupEnabled` 和 `LaunchAgentPath`；移动应用或仓库后重新运行 `./InstallStartup.command`。
- **停止或 PID 状态异常：** 运行 `./Start.command` 或 `./Stop.command`；控制脚本只处理路径精确匹配的本项目可执行文件。

## 开发者

在 macOS 14+ arm64 主机上运行：

```bash
swift run CodexPetUsageTests
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict "dist/Codex Pet Usage.app"
```

参见 [CONTRIBUTING.md](CONTRIBUTING.md)、[SECURITY.md](SECURITY.md) 和 [docs/verification.md](docs/verification.md)。

## 许可证

[MIT](LICENSE)
