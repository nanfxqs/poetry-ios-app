# 个人诗词服务：最小方案调研

日期：2026-09-05。范围：约 30 首精选内容、一个人使用；只读核实与方案建议，没有部署。

## 推荐方向

采用 **iPhone 本地 SQLite 阅读库 + Mac mini 独立轻量 HTTP API 与 SQLite + Tailscale 私网 HTTPS**。App 随包提供首批内容，更新成功后写入本地；收藏先本地保存，联网且服务可达时上传备份。Mac 不在线时仍可阅读、筛选、查看已下载人物资料和收藏。

SQLite 官方支持设备本地存储、缓存及由应用服务器封装的服务端用途；其主要并发约束是同一数据库同时只有一个写者。对单人、小型、以读为主的内容库，额外运维一个 PostgreSQL 服务暂无明显收益。[SQLite 适用场景](https://sqlite.org/whentouse.html)

| 决策 | 理由 |
| --- | --- |
| Mac 先用 SQLite | 少一个常驻数据库服务，单个应用进程处理写入；通过 API 提供数据，不让 iPhone 远程打开数据库文件。 |
| 暂不选独立 PostgreSQL | 多人高频并发写入、多应用共享库等需求出现后再评估；约 30 首与单人收藏不构成这些需求。 |
| iPhone 先用 SQLite | 内容、标签、人物和关系可稳定查询；SwiftData 是 Apple 原生持久化候选，但暂不同时叠加两套存储。后续真机版本核实后可再评估 SwiftData，且不能把其持久化文件当成 Mac SQLite 的公共交换协议。[SwiftData](https://developer.apple.com/documentation/swiftdata) |

上述取舍是针对当前规模的工程建议，不是吞吐或功耗实测结果。现有星图候选 Grape 最低 iOS 17；工程建立前统一核实真实 iPhone 系统版本。[Grape 平台声明](https://raw.githubusercontent.com/li3zhen1/Grape/main/Package.swift)

## 已核实的机器事实

本轮通过 `ssh macmini` 只读检查：arm64、内存 17,179,869,184 字节（16 GiB）、存在 OrbStack.app、Docker Server 报告版本 29.4.0。运行中的容器包含 Immich server、machine learning、PostgreSQL 和 Redis。

Mac 镜像 `/Users/nanfm/Projects/poetry-ios-app/PoetryApp.xcodeproj` 不存在。本轮没有 iOS 构建和 USB 安装验证；不能将服务器条件具备表述为 App 已可运行。

没有读取密码环境文件。只探测常见 Tailscale 可执行路径并不能确定其安装状态；Linux 的 `tailscale ping macmini` 普通及提权运行均报告短名解析失败，受限环境的 status 未能连接本地 daemon。这些结果不能证明 Mac 的 Tailscale 不可用。**iPhone 到 Mac 的私网服务连接仍未实测。**

## 在外更新的条件

iPhone 与 Mac 需要安装并登录可相互访问的 Tailscale 网络，iPhone 的 VPN 连接须开启、访问策略须允许；Mac、OrbStack、API 与家庭网络须在线。Tailscale Serve 可以把本机服务以 HTTPS 提供给 tailnet，并受访问控制规则约束；启用 HTTPS 证书是其要求。方案采用 Serve 的本地端口代理，具体 Mac 客户端兼容性在部署前核实。[iOS 安装](https://tailscale.com/docs/install/ios)、[Serve 官方文档](https://tailscale.com/docs/features/tailscale-serve)

收藏备份建议显示“待备份/最近备份成功时间”，成功收到服务端确认后才算完成。首版在 App 打开和回到前台时尝试同步，失败保留本地待同步记录；不承诺 iOS 在后台随时完成备份。此段是建议的产品契约，尚未实现。

## 离线边界

诗词正文、标签、人物节点和关系数据本地化可以独立于服务使用；图片、音乐也须随包或下载完成后才能纳入离线承诺。

**不承诺 MapKit 底图离线完整可用。** Apple 的离线地图支持页描述的是系统 Maps App 的下载能力，并说明地区限制，不能据此推断我们的 MapKit App 自动获得相同离线保证。断网时应保留可离线的地点列表、诗词卡片和人物路线信息；底图是否可用以真机验证为准。[Apple 离线地图说明](https://support.apple.com/en-us/105084)、[MapKit](https://developer.apple.com/documentation/mapkit/)

## 持久化、备份与 Immich 隔离

建议一个独立 Compose 项目、独立 SQLite 数据卷和备份目录。不要挂载、连接或修改 Immich 数据库与数据卷，也不借用它的 PostgreSQL 用户。若未来改用 PostgreSQL，仍建立独立实例或经明确隔离设计的服务，不因机器已有数据库就默认共用。

数据库放在持久化卷中，不能只留在容器可写层；Docker 卷可以独立于容器生命周期保留数据，但卷不是备份。[Docker volumes](https://docs.docker.com/engine/storage/volumes/)

运行中的 SQLite 用官方 Online Backup API 生成一致快照；不要直接复制可能正在写入的单个 `.db` 文件。备份应定期复制到另一台设备或独立存储，并实际恢复验证；只存在同一 Mac 磁盘的副本不能覆盖整机丢失。[SQLite Online Backup API](https://www.sqlite.org/backup.html)

## 待实际验证

- 真机系统版本、首批内容首次安装即离线可读。
- iPhone 在蜂窝网络通过 Tailscale/HTTPS 拉取更新，服务离线时不影响阅读。
- 收藏离线写入、重试上传与恢复时不丢失、不重复。
- Mac 重启/睡眠后的服务可用性、独立卷保留、SQLite 备份恢复。
- MapKit 在目标地区与断网状态下的降级表现。

这些检查属于后续实现验收，不是本轮已完成的工作。
