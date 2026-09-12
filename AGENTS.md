# 项目入口

个人自用的中国古诗词 iOS App，以阅读、诗中地点和诗人经历传达诗意。内容范围为中国古诗词，底部入口为「今日／探索／诗集」。

当前交付以 HTML 设计原型和 Linux↔Mac 构建工具为主。原型交互与原生功能分别验收；具体进度以当前设计状态文档和实际工程文件为准。

## 按任务读取

- **领域与代码**：探索代码或修改领域术语前，读 [领域文档约定](docs/agents/domain.md)，按其中指引读取 `CONTEXT.md` 与相关决策。
- **页面设计或原生实现**：先读 [当前设计状态](docs/design/current-design.md)，确认已交付与待实现范围；视觉规则读 [DESIGN.md](.stitch/DESIGN.md)，当前页面路径和 Stitch ID 查 [metadata.json](.stitch/metadata.json)。历史轮次仅供回溯。
- **内容与素材**：采集诗词、建立人物／地点关联或选择素材前，读 [种子样本及证据边界](docs/research/first-content-sample.md)、[诗词数据来源](docs/research/poetry-data-sources.md) 或 [媒体来源](docs/research/poetry-media-sources.md) 中对应部分。
- **Stitch 操作**：提交生成、编辑或导入前，读 [README 的连接与防重复提交规则](README.md#stitch-连接与防重复提交)。响应中断时先按规则核对远程结果。
- **构建与设备**：修改同步、签名、USB 安装或 Zed 任务前，读 [README](README.md)；操作步骤和配置默认值集中维护在那里。
- **议题与规格**：操作 GitHub Issues 前，读 [议题约定](docs/agents/issue-tracker.md)；分类或修改分诊标签前，读 [分诊标签](docs/agents/triage-labels.md)。

## 工作区与设备约定

- Linux 主工作区 `/home/nanfl/Projects/poetry-ios-app` 是源码权威来源；Mac 镜像为 `/Users/nanfm/Projects/poetry-ios-app`，SSH 主机名 `macmini`。
- Mac 编译、签名；iPhone 通过 USB 连接 Linux，由 Linux 安装、启动和读取日志。验证流程以这台实体设备为目标。
- 项目参数通过 `.env.ios-device` 配置；该文件保持 Git 忽略，凭据和钥匙串密码不得提交。
- 保留 `scripts/mac-signing-session.sh` 建立的 SSH ControlMaster 会话，远程签名依赖该会话解锁的钥匙串。

## 完成标准

- **设计变更**：按当前设计状态文档的同步规则更新规范、元数据与完成范围；受影响页面的可试用 HTML、静态导入稿及高清图一致，本地链接有效。
- **脚本／任务变更**：逐个对 `scripts/*.sh` 执行 `bash -n`，运行 `jq empty .zed/tasks.json`；Stitch 客户端变更还需通过 `python3 -m unittest discover -s tests -p test_stitch_client.py`。
- **原生构建**：先确认 `PoetryApp.xcodeproj` 存在；缺失时报告该前置条件。完整流水线验收以 USB 连接的 iPhone 成功安装并启动 IPA 为完成标准。
- **所有变更**：运行 `git diff --check`，说明实际验证结果与剩余限制。
