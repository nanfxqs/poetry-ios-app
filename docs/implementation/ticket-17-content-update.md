# 私网内容更新

原生设置页 `ServiceSettingsView(application:)` 使用 Keychain 保存完整连接资料（HTTPS URL 与 bearer token），手动检查更新并显示行内失败重试。由集成分支把该页接到诗集。下载或校验失败不进入事务；写入失败整笔回滚。更新不写收藏表或 `daily_selection`，已选作品的快照和被移除作品的收藏继续可读。

## 协议与扩展入口

`GET /v1/content` 必须带 `Authorization: Bearer <private token>`。返回 envelope：`schemaVersion: 1, version: positive Int, sha256: lowercase hex, payload: String`。校验覆盖 payload 原始 UTF-8 字节，不重新序列化。最大 envelope 8 MB，版本严格递增，当前版本返回正常包并由客户端报告已是最新。服务无数据库文件下载或远程发布接口。

payload 为完整 JSON：`poems: [Poem]`, `catalogs: {poets: [Poet], places: [PoetryPlace], placeAssociations: [PlaceAssociation], lifeEvents: [LifeEvent], relationships: [Relationship], tags: {poemID: PoetryTags}}`。所有键必需，未知目录拒绝。诗人、作品、地点与事件 ID 唯一且符合小写稳定标识；作品作者、地点关联、标签、事件作者和事件关联作品均须存在；人物关系两端须为不同的已收录诗人，每首证据作品须存在且作者为关系的发出方。作品数组顺序即人工推荐顺序。来源保留标题、URL、许可与说明；自动校验不证明史实正确。

目录整体替换：`poets`, `places`, `place_associations`, `life_events` 与 `poems` 在同一事务内；相关种子安装标记同步写入，避免重启恢复旧种子。标签持久化于 `content_tags`，阅读及探索默认使用当前标签；显式测试标签仍可传入。新增目录必须同时扩展服务与客户端验证、事务安装和测试，不能默默忽略。

备份集成使用 `ServiceCredentials(baseURL:token:)`、`PoetryServiceSettings.load()/save()`；共享私密配置，不引入第二个地址或凭据表单。网络客户端 `PoetryServiceClient` 使用 ephemeral URLSession，默认拒绝重定向，30 秒超时。更新入口 `application.installContentPackage(data:)` 和 `contentVersion()`。

## 独立服务与维护者流程

`service/compose.yaml` 项目 `poetry-private`，独立 `poetry_data` 卷，仅绑定 Mac localhost:8787。不触及 Immich 容器、卷或 Tailscale 既有映射。根代理负责实际部署与私网 HTTPS 验收；建议单独 Serve 8443 端口，执行前核对现有 Serve 配置，禁止 reset。

维护者在私有路径生成至少 32 个非空白随机字符的 token 文件，权限 0600；环境变量 `POETRY_TOKEN_FILE` 指向绝对路径，Compose 作为只读 secret 装载。禁止提交文件、打印 token 或将 token 放命令参数。客户端在设置页输入。

```sh
python3 service/poetry_service.py pack /private/content.json /private/content-package.json --version 1
python3 service/poetry_service.py validate /private/content-package.json
# 本地维护；服务容器中 /data 指向持久卷，包通过临时复制/挂载传入。
python3 service/poetry_service.py --database /private/poetry.sqlite publish /private/content-package.json
# 服务 Compose（需先在私有环境设置 POETRY_TOKEN_FILE）
docker compose -f service/compose.yaml up -d --build
```

`service/poetry_service.py` 的 `database(path)` 是后续收藏备份、SQLite snapshot CLI 的共用服务库入口。HTTP handler 在 `create_server` 内，新增备份端点须沿用恒定时间 bearer 校验，不开放发布接口。数据库路径默认 `/data/poetry.sqlite`。

## 验证与限制

Python `python3 -m unittest discover -s service -p test_service.py`：真实 HTTP 授权、内容返回、禁止数据库路径、服务重建后发布持久、损坏包、引用缺失、未知目录和旧版本拒绝。需要本地 socket 权限。

Swift `ContentUpdateTests`：真实 SQLite 的成功替换、重启、收藏保留、当日推荐保持、缺失引用、截断、校验损坏、事务写入失败回滚。Linux 无 Swift；由集成分支在 Mac 执行。实际 iPhone 蜂窝 HTTPS、Mac 重启、安装启动和 UI 操作须由集成分支完成，测试或 Compose 文件不等于已验收。
