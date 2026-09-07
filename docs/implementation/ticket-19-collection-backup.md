# 收藏备份与主动恢复

收藏变更与 `collection_backup` 修订在同一 SQLite 事务提交，重复保存与不存在的取消不增加修订。旧安装已有收藏首次初始化为待备份；全新空库修订为 0，不上传。启动、回前台、收藏操作与保存连接后由根共享 `CollectionStore` 尝试备份；单个进行中操作锁排除重复上传和恢复。上传期间的新收藏会使已确认修订落后，循环继续上传最新快照。失败留下待备份状态及手动重试入口，只有匹配已发送快照的服务确认才记成功时间。不承诺任意后台备份。

个人服务设置复用 #17 的 Keychain 地址和凭据。主动「查看远端备份」显示设备标识、修订、服务接收时间和首数，说明替换本机收藏后才允许确认。恢复校验后事务替换收藏和备份状态，按原始新到旧顺序恢复并刷新跨页共享状态。失败保留原收藏。新安装通过授权读取后显式恢复服务的原设备标识，后续修订继续递增；新身份不能自动抢占旧备份。凭据轮换需同时更新服务与本机 Keychain。

## HTTP 与持久化协议

`GET /v1/backup` 与 `PUT /v1/backup` 使用 #17 相同 bearer 鉴权和 HTTPS 地址。无备份 GET 返回 404，未授权 401，非法/冲突修订 PUT 返回 409，超限 413。PUT 为 `{deviceID, revision, favorites}`：小写 UUID、正 Int64（小于最大值）、按新到旧排列的完整 `FavoritePoem` 数组。`savedAt` 遵循 Swift Codable Date 的 2001-01-01 参考时刻秒数。响应为 `{snapshot: <完整快照>, receivedAt: <Unix 秒数>}`。最大请求 8 MB；服务不记录 URL、正文或凭据。

服务模块 `service/collection_backup.py` 使用共享 `database(path)`，表为 `collection_snapshots(revision INTEGER PRIMARY KEY, device_id TEXT NOT NULL, snapshot TEXT NOT NULL, received_at REAL NOT NULL)`。第一笔授权写入确立唯一设备；以后设备不变且修订递增，完整快照含取消结果。精确重复最新请求返回原接收时间，不新增记录；旧或同修订异内容拒绝覆盖。历史行不可变，GET 返回最高修订。维护备份工具应快照整个 SQLite 数据库，包含此表；无独立备份凭据或数据库下载路径。

## 验证

Linux 已通过 `python3 -m unittest discover -s service -p 'test_*.py'`：真实 HTTP 授权拒绝、重复写入、设备冲突、旧/冲突修订、取消收藏、服务重启与读取恢复（共 3 个测试，含原内容服务测试）。`git diff --check` 通过。

新增 `CollectionBackupTests` 使用真实 SQLite 覆盖持久修订、重复收藏、上传期间的新修改、确认后待备份、Codable 契约、恢复顺序/身份、损坏恢复和插入失败回滚。Linux 无 Swift，交由集成分支在 Mac 执行。实际 iPhone 断网收藏→重连备份、主动恢复及安装启动仍由集成分支验收，不以单元测试替代。
