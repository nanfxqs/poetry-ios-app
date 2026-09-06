# poetry-ios-app

这是一个以 Linux 为主要开发环境、Mac mini 负责 Xcode 编译和签名、Linux 通过 USB 向 iPhone 安装应用的 iOS 项目。

默认工程配置：

- Xcode 工程：`PoetryApp.xcodeproj`
- Scheme：`PoetryApp`
- Bundle ID：`com.nanfl.PoetryApp`
- Mac 项目路径：`/Users/nanfm/Projects/poetry-ios-app`
- 构建配置：`Debug`

## 工作流程

```text
Linux/Zed 修改并保存代码
        ↓ rsync over SSH/Tailscale
Mac mini 使用 Xcode 编译并以免费 Apple 开发账号签名
        ↓ rsync
签名后的 PoetryApp.ipa 回传 Linux
        ↓ pymobiledevice3 over USB
安装到 iPhone 并启动，可继续读取设备日志
```

Mac mini 不需要连接 iPhone，也不需要运行模拟器；iPhone 只需通过 USB 连接 Linux。免费 Apple 开发签名需要定期重新构建和安装。

## 文件作用

| 文件 | 作用 |
| --- | --- |
| `.env.ios-device` | 本机配置，包括 Mac SSH 地址、Mac 项目路径、工程名、Scheme、Bundle ID、IPA 路径和 `pymobiledevice3` 路径。该文件已被 Git 忽略。 |
| `.zed/tasks.json` | Zed 的 iOS 构建、安装、启动和日志任务。所有任务执行前都会保存当前工作区文件。 |
| `scripts/linux-ios-run.sh` | 主自动化脚本：同步到 Mac、远程构建、取回 IPA、通过 USB 安装并启动。 |
| `scripts/mac-build-ipa.sh` | 仅在 Mac 上执行：调用 `xcodebuild` 完成开发签名，并将 `.app` 封装成 IPA。 |
| `scripts/mac-signing-session.sh` | 建立持久 SSH 连接并交互式解锁 Mac 登录钥匙串；密码不会保存。 |
| `scripts/setup-linux-ios.sh` | 交互式生成或更新 `.env.ios-device`，并检查或安装 `pymobiledevice3`。 |
| `.gitignore` | 排除本机配置、构建目录、IPA、工具环境和日志。 |
| `artifacts/PoetryApp.ipa` | 构建后从 Mac 回传的签名 IPA；自动生成，不提交 Git。 |

## 首次准备

### 1. 创建 Xcode 工程

目标仓库目前尚未包含 Xcode 工程。先在 Mac 上创建 iOS App：

- Product Name：`PoetryApp`
- Interface：推荐 SwiftUI
- Language：Swift
- Team：登录的免费 Apple Personal Team
- Organization Identifier：`com.nanfl`
- Bundle Identifier：`com.nanfl.PoetryApp`
- Deployment Target：不得高于真机的 iOS 版本
- Orientation：按当前约定只启用竖屏

将工程保存在：

```text
/Users/nanfm/Projects/poetry-ios-app/PoetryApp.xcodeproj
```

### 2. Linux 依赖

需要安装 `ssh`、`rsync`、`usbmuxd` 和 `pymobiledevice3`，并配置可连接 Mac 的 SSH 别名 `macmini`。SSH 应启用 `ControlMaster` 和 `ControlPersist`，以复用已经解锁钥匙串的连接。

当前 Linux 主机已有可用依赖和默认配置。如需重新生成本机配置：

```bash
cd ~/Projects/poetry-ios-app
./scripts/setup-linux-ios.sh
```

### 3. iPhone

用 USB 将 iPhone 连接 Linux，保持解锁，并在首次连接时点击“信任”。验证连接：

```bash
pymobiledevice3 usbmux list
idevicepair validate
```

iPhone 还需要在“设置 → 隐私与安全性 → 开发者模式”中启用开发者模式。

## 每次开始开发

Mac 重启、SSH 复用连接失效或 `ControlPersist` 超时后，先执行：

```bash
cd ~/Projects/poetry-ios-app
./scripts/mac-signing-session.sh
```

输入 Mac 登录密码。成功时应显示有效的 Apple Development identity。密码只交给 macOS `security` 命令，不会写入项目文件。

## 命令行使用

构建、回传、安装并启动：

```bash
./scripts/linux-ios-run.sh run
```

完成完整流程并持续查看设备日志：

```bash
./scripts/linux-ios-run.sh logs
```

只在 Mac 构建并将 IPA 下载到 Linux：

```bash
./scripts/linux-ios-run.sh build-only
```

不重新构建，只安装 `artifacts/PoetryApp.ipa`：

```bash
./scripts/linux-ios-run.sh install-only
```

## Zed 使用

在 Zed 中打开 `~/Projects/poetry-ios-app`，运行任务选择器并选择：

- `iOS: Start Mac Signing Session`：解锁签名钥匙串。
- `iOS: Build + Install + Run`：完整构建、安装和启动。
- `iOS: Build + Install + Run + Logs`：完整流程后持续输出日志；按 `Ctrl-C` 停止。
- `iOS: Install Existing IPA`：安装上次已回传的 IPA，不重新编译。
- `iOS: Mac Build IPA Only`：只构建并回传 IPA。

## 修改配置

工程名、Scheme、Bundle ID 或 Mac 路径变化时，编辑 `.env.ios-device`，或者重新运行：

```bash
./scripts/setup-linux-ios.sh
```

`.env.ios-device` 是当前唯一配置来源；需要 Release 构建时，将其中的
`IOS_CONFIGURATION=Debug` 改为 `IOS_CONFIGURATION=Release`。

## 常见问题

### `no usable signing identity`

运行 `./scripts/mac-signing-session.sh`，输入 Mac 密码后重试，并确认 SSH 配置启用了连接复用。

### `Xcode project not found`

确认 Mac 上存在 `/Users/nanfm/Projects/poetry-ios-app/PoetryApp.xcodeproj`，并检查 `.env.ios-device` 中的 `IOS_MAC_PROJECT` 和 `IOS_PROJECT_NAME`。

### Linux 找不到 iPhone

确认 USB 线支持数据传输、iPhone 已解锁并信任 Linux，然后检查：

```bash
systemctl status usbmuxd
pymobiledevice3 usbmux list
```

### 描述文件过期

免费 Apple 账号签名有效期较短。保持 Xcode 账号有效，重新执行构建和安装即可刷新应用。

## 调试范围

当前自动化覆盖构建、签名、安装、启动和日志读取，但尚未配置 Zed 内的源码断点或 LLDB 远程调试。

## Stitch 连接与防重复提交

当前设计为 R3 五页原型。页面、高清截图、完成范围与限制见 [当前设计状态](docs/design/current-design.md)，配色与布局见 [.stitch/DESIGN.md](.stitch/DESIGN.md)。旧版本地 HTML 和图片已清理。

Stitch 页面设计使用同一个私有项目。当前会话如未暴露原生 Stitch MCP 工具，可使用仓库内的备用客户端：

```bash
python3 scripts/stitch-client.py get_project /tmp/stitch-args/project.json /tmp/stitch-project.json
```

参数依次为工具名、参数 JSON 路径、响应 JSON 路径。API Key 从 `$CODEX_HOME/config.toml`（默认 `~/.codex/config.toml`）的 Stitch 配置读取，不放进命令参数、仓库或输出日志。

- 当前本机 Stitch 配置：`startup_timeout_sec = 30`、`tool_timeout_sec = 600`。原生 MCP 需要重新加载配置后才采用新值；备用客户端每次读取。
- 备用客户端优先使用 HTTP/2，启用 TCP keepalive，正确区分 SSE 进度通知和匹配请求 ID 的最终响应。不自动重试 HTTP 请求。
- 同项目修改使用互斥锁。提交前写入持久状态；连接中断后状态为 `unknown`，其他修改会被拦截，即使改写提示词也不重发。完全相同的已完成请求复用已保存响应。
- 状态放在 `$XDG_STATE_HOME/poetry-stitch/`（默认 `~/.local/state/poetry-stitch/`），每次调用在输出旁保存 `.receipt.json`，记录阶段、耗时和 HTTP 状态，不记录密钥。
- `unknown` 时只允许查询项目/页面。根据已有请求、生成文件与项目结果核对，不将“查询暂未出现”理解为生成失败。核对清楚后再归档该项目的 `pending.json`，并记录处理依据；不要仅为绕过拦截而删除它。
- API 返回成功不代表画布已同步。必须核对实际 screen ID、HTML 和画布。不要用另一种生成工具或重新上传来代替状态核对。

回归验证：`python3 -m unittest discover -s tests -p test_stitch_client.py`。
详细排查结论见 `docs/design/stitch-connection-diagnosis.md`。
