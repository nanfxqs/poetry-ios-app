# 原生阅读 UI 验收入口

`PoetryAppUITests/OfflineReaderUITests.swift` 使用实际页面控件与随包数据，不清空数据库、不注入替代内容。测试覆盖四句完整正文、离线来源说明、进入另一首长诗及返回、重启可读、最大辅助字号滚动与底部导航可操作。

首次安装验收使用新安装的应用，并在运行前关闭 Wi-Fi 和蜂窝网络（USB 开发连接保留）。测试本身不改变设备网络设置；仅通过测试成功不能证明设备当时断网。测试不会点击来源网页链接。

Mac 构建测试 runner：

```bash
xcodebuild -project PoetryApp.xcodeproj -scheme PoetryApp -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build/UITests \
  -allowProvisioningUpdates build-for-testing
```

将生成的 `PoetryApp.app` 和 `PoetryAppUITests-Runner.app` 按现有 Linux USB 工具安装到同一台 iPhone，保持解锁并启动开发隧道，然后运行：

```bash
pymobiledevice3 developer dvt xcuitest com.nanfl.PoetryAppUITests.xctrunner \
  --target-bundle-id com.nanfl.PoetryApp
```

实际命令选项以本机 `pymobiledevice3` 已安装版本为准。保存终端结果、设备型号与系统版本、网络状态、日期及截图；Mac 编译成功不等于设备测试成功。最大字号测试使用系统启动参数 `UIPreferredContentSizeCategoryName`，不添加生产专用测试分支。当前 UI 测试以首次种子阅读入口为基准；后续推荐和搜索交付时应同步从稳定作品入口定位同一验收样本。
