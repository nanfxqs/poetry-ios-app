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
