# 首版规格 #8 实施与验收

规格：[GitHub #8](https://github.com/nanfxqs/poetry-ios-app/issues/8)。实施 PR：[#22](https://github.com/nanfxqs/poetry-ios-app/pull/22)。

## 工单依赖

- #9 首次离线阅读 → #10 推荐、#11 收藏、#12 搜索、#14 诗人。
- #12 → #13 地图；#14 → #15 生平、#16 关系。
- #10 + #11 → #17 内容更新 → #18 声音、#19 备份 → #20 快照恢复。
- #13 + #15 + #16 + #18 + #20 → #21 内容扩充与完整真机验收。

工单完成包括各自测试与设备验收；实现代码不等于已完成真机验收。PR 在完整规格完成前保留草稿。

## 2026-09-07 前置检查

- Linux USB 实机报告 `iPhone16,1`、iOS `26.4.1`，`idevicepair validate` 成功；开发者 DVT 信息查询成功。
- Mac `xcodebuild -version`：Xcode 26.6，build 17F113；Swift 6.3.3。
- Mac 存在有效 Apple Development 签名身份。已有描述文件仅用于另一个 App，PoetryApp 仍需通过自动签名生成自己的描述文件。
- 实施开始时 Linux 和 Mac 尚无 `PoetryApp.xcodeproj`；由 #9 建立。此时没有 PoetryApp 构建、安装或启动结果。
- Mac Docker Compose v5.1.2 可用，运行 Immich 独立容器。
- Mac Tailscale Serve 已将 HTTPS 默认入口代理到 Immich 的 `127.0.0.1:2283`。诗词服务部署必须采用独立端口或路径，保留该映射；尚未部署诗词服务。
- 手机蜂窝私网更新、断网收藏重试、恢复、声音试听和 Mac 重启持久化尚未验收。

## 验收证据规则

自动化记录命令与结果；设备验收分别记录安装、启动和具体操作。不能从 DVT 可连接推断 App 已启动，也不能以桌面或模拟器结果替代实体 iPhone 验收。人工操作尚未执行时保持待验收。

## #9 首轮构建结果

- `swift test` 在 Mac 通过两项应用层测试：六首随包作品首次写入与重启读取、长标题长正文返回完整。
- 自动签名构建失败：Xcode 报告 `No Accounts`，且缺少 `com.nanfl.PoetryApp` 的描述文件。用户确认 Xcode 界面已登录；后续发现命令行读取的持久账号列表为空，正在诊断状态不一致。未改用其他 App 的标识或描述文件。
- 独立未签名 iOS 构建发现 SQLite pkg-config 引入 Homebrew 的 macOS 动态库；已在 `438c1b1` 移除主机库搜索路径，使用 iOS SDK 的系统 SQLite；未签名 `build-for-testing` 已通过。
- 当前尚未生成可安装 IPA。

## 签名诊断（进行中）

- 相同签名命令在 SSH 可重复得到 `No Accounts`；关闭签名后应用和 XCUITest runner 编译通过。
- SSH 与桌面均为 `nanfm`（UID 501），使用同一套 Xcode，工程 Team 与缓存 Personal Team 一致。
- SSH `Background` 上下文访问 login 钥匙串设置报 `User interaction is not allowed`；临时桌面 `Aqua` 任务可读取相同设置。
- 同一工程在 Aqua 任务中签名仍报 `No Accounts`，因此不能仅凭钥匙串上下文差异确认根因。
- `DVTDeveloperAccountManagerAppleIDLists` 的 `IDE.Identifiers.Prod` 列表数量为 0；Team 缓存仍存在。已请用户保存并正常退出、重开 Xcode，核对持久登录状态。未删除账号、修改钥匙串 ACL 或读取凭据。
- 两个一次性 launchd 诊断任务已卸载，临时脚本和日志保留在 Mac `/tmp/poetry-signing-*` 供排查；没有创建开机任务。
