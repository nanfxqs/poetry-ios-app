# Stitch 中断排查 · 2026-09-05

本记录根据迁移前已核实的排查结果恢复。

## 已知结果

1. 上一轮实际走的是 `/tmp/stitch-call.py` 的 Python urllib 备用连接，不是原生 Stitch MCP。此前工具目录未暴露 Stitch；桌面日志记录启用配置，但不能据此认定当前任务已加载工具。
2. 连接中断不能直接视为生成失败；后台可能继续处理。不得自动重复提交生成或修改请求。
3. Clash 日志证实请求经过 TUN 和谷歌服务代理。同一时段有 ICMP 超时，但没有能将某条 Stitch TCP 断线归因于代理的证据。不据此更换节点或修改全局网络配置。
4. Stitch 的 `generate_screen_from_text` 工具描述明确说明：请求可能需要几分钟；连接中断后后台仍可能成功；不要重试，应查询结果。

## 连接客户端

- `scripts/stitch-client.py` 使用 HTTP/2、TCP keepalive、匹配 ID 的 JSON/SSE 完整响应检测，不自动重发。
- 同项目修改互斥；提交前持久化状态。结果不明时阻止后续修改，允许查询核对。
- 记录 receipt 中的阶段、耗时和 HTTP 状态，不记录密钥。
- 本次排查未调用生成、修改、变体或上传接口，未改变 Stitch 页面。

## 限制

最终连接由 Stitch 服务端还是中间链路关闭，现有日志仍不能唯一定位。没有为复现而再次运行耗时生成任务。后续正常授权调用如再次断开，receipt 将保留请求阶段、耗时和 HTTP 状态以辅助排查；不得反复提交同一工作。

参考：[Codex MCP 配置](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)、[MCP Streamable HTTP 传输](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports)。Stitch 行为以当次工具描述为依据。
