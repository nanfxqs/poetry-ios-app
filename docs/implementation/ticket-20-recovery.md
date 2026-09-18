# SQLite 快照与灾后恢复（#20）

## 数据边界

`poetry-private` Compose 的 `poetry_data` 保存内容包及不可变收藏修订；独立 `poetry_snapshots` 卷保存 SQLite Online Backup API 生成的一致快照。快照切成 DELETE journal 的自包含文件，经 `integrity_check` 后原子发布，成功后才轮换最近七个有成功快照的 UTC 自然日，每日仅保留最新成功快照。任何源读取、磁盘写入或验证失败均不启动轮换；错误五分钟后重试。每日侧车按 UTC 自然日每天一次，重启不额外消耗每日保留份数。同日手动 snapshot 成功后替换当日旧快照，不挤占前六日快照；当地时区不影响分日。

这两个 Docker 卷可能在 Mac 同一块物理磁盘，不能抵御整机或磁盘损坏。手动导出 Linux 才增加另一台机器的副本，仍建议把验证过的文件另存离线介质。原始数据库及 WAL 禁止直接复制。工具无需访问 Immich，不修改其 Compose、数据库或 Tailscale Serve 映射。

## 日常操作

在 Mac 的 `service/` 下使用已配置的 `POETRY_TOKEN_FILE`，启动 `docker compose up -d --build`。`snapshots` 没有端口、不挂载 API token；与 API 共用数据库卷，以 SQLite 锁协议协调在线读写。首次内容发布前可能报告重试，内容表建立后恢复。

```sh
docker compose exec -T snapshots python snapshots.py snapshot /data/poetry.sqlite /snapshots
docker compose exec -T snapshots ls /snapshots
```

在 Linux 项目根目录导出选定的 `poetry-日期-标识.sqlite`：

```sh
./scripts/export-poetry-snapshot.sh poetry-实际文件名.sqlite /tmp/poetry-export-新目录
```

目标必须是新目录。脚本先取得远端验证 SHA-256，传输后比对 SHA-256 并本地检查 SQLite。`remote.json` 与文件是可核实记录；失败目录仅供排查，不视为有效备份。远端 Compose 命令设置 `/dev/null` 只为只读 `exec` 解析 token 配置，不创建容器或变更其现有 token。导出期间该快照被轮换时命令失败，可重新选择最新文件后重试。

## 隔离恢复演练／灾后步骤

1. 保留现有服务和卷；不要运行 `down -v`，不要用测试文件覆盖 `/data/poetry.sqlite`。验证导出记录 SHA-256。
2. 恢复工具要求新路径，经一致复制和完整性检查才发布。相同路径或已有文件会拒绝覆盖：

```sh
python3 service/snapshots.py restore /tmp/poetry-export-新目录/poetry-实际文件名.sqlite /tmp/poetry-recovery-新目录/poetry.sqlite --sha256 已核实SHA256
POETRY_TOKEN_FILE=/路径/私有测试令牌 python3 service/poetry_service.py --database /tmp/poetry-recovery-新目录/poetry.sqlite serve --host 127.0.0.1 --port 8788
```

3. 在隔离地址请求 `/v1/content`、`/v1/backup`，检查内容版本、收藏数量与作品。恢复是主动动作：新客户端先读取内容，再由用户明确执行「恢复收藏」。内容请求不会自动合并或覆盖收藏。
4. 真机演练需为隔离端口提供独立且受认证的可达地址，手机设置该地址和令牌后主动恢复。验收前不切换正式服务。
5. 灾后正式切换前停止旧 Poetry API 与快照侧车；把验证过的恢复文件导入一个**新建** Poetry 数据卷，配置独立 Compose 项目或 override 指向该卷；先启动和验证，再切换 Poetry 地址。保留旧卷以便回退。不更改 Immich 地址。

## 实际验证与限制

`python3 -m unittest discover -s service` 通过：在线 WAL 存在未提交写入时备份仍得到已提交内容与收藏；跨九日快照保留最近七日、同日重复手动快照保留前六日；写入失败／缺源保留此前全部 SHA-256；坏库与错误 SHA-256 拒绝；目标已存在拒绝覆盖；从导出恢复的新数据库启动真实 HTTP 服务并两次重启后内容和收藏一致；空测试客户端主动请求备份后才恢复收藏。所有测试使用临时目录。

这里的 HTTP 测试客户端不是 iPhone，亦不是 Docker 容器重启验收。真机主动恢复、Mac 实际定时运行及容器重启由主实施流程另行记录，不以测试替代。
