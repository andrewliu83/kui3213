# agent-http-ws-fallback

## Purpose

定义核心 VPS Agent 在 **Realtime WebSocket 可用与否** 时，对 Pages Worker 的 HTTP 上报与配置拉取节奏的完整目标行为。目标是在不损害流量计费可靠性与配置下发可达性的前提下，降低多机规模下的 Worker 请求数。

## Definitions

| 术语 | 含义 |
| --- | --- |
| WS 健康 | Realtime 通道已启用且当前 `connected`，status 可通过 WS 发送成功 |
| Status-only 报告 | 无待发送节点流量增量批次时的遥测/在线报告 |
| 流量批次 | 带独立幂等 `report_id` 的节点流量增量 HTTP 提交单元 |
| Config 事件 | 面板经 Realtime 下发的 `config.refresh`，或 transport 连接状态变化等既有唤醒源 |

## Report transport

1. **展示用遥测**：WS 健康时，常规 status 优先经 WebSocket 发送；不要求每次心跳都 HTTP。
2. **HTTP status-only 落库**：WS 健康且仅 status-only、且当前没有已开始的 pending HTTP 提交时，两次 HTTP report 的最小间隔为 **180 秒** 量级（实现常量可命名为 `REALTIME_HTTP_INTERVAL`）。
3. **流量批次**：存在未确认流量批次时，必须继续通过 HTTP 尽快提交；不得套用上述 180 秒 status-only 节流来推迟批次泄洪。活跃泄洪心跳可保持较短间隔（与既有 5 秒活跃档兼容）。
4. **断线与禁用 Realtime**：WS 未连接且超过既有 grace（约 30 秒）后，HTTP 为权威落库路径；间隔遵循服务端回包 `interval` / `fast_mode` 与既有 90–300 秒约束，不强制 180 秒下限替代断线语义。
5. **幂等与基线**：批次仅在 Worker 成功确认后推进本地流量基线；进程重启可恢复未确认批次（既有 batch 能力保留）。

## Config fetch

6. **事件优先**：收到 Config 事件时，Agent 必须尽快执行 `GET /api/config`（或等价配置拉取），不得等待长周期兜底定时器。
7. **WS 健康时的周期兜底**：在无 Config 事件时，周期 HTTP 配置拉取最小间隔为 **600 秒** 量级（实现常量可命名为 `REALTIME_CONFIG_HTTP_INTERVAL`），替代「WS 在线反而 30 秒一轮」的旧行为。
8. **WS 不健康时**：配置拉取间隔回到既有无 WS / fast_mode 语义（例如约 30 秒 fast 或约 300 秒常态），保证无推送时仍能收敛配置。

## Non-requirements

- 不规定住宅 proxy-lite 进程的 C2 间隔。
- 不规定 Dashboard 是否把全舰队 `status.interval` 设为 5 秒。
- 不规定 Worker 侧 schema 探测优化。
- 不要求秒级 D1 `last_report` 与 WS 展示完全一致；允许 status-only HTTP 滞后约数分钟。

## Acceptance criteria

1. WS 健康 status-only 下，HTTP report 不以约 30 秒为默认周期，而以约 180 秒为最小周期。
2. 流量批次 HTTP 泄洪与批次测试套件行为保持正确。
3. WS 健康时无事件的 config HTTP 默认约 600 秒一轮，且 `config.refresh` 仍立即触发拉取。
4. WS 断开超过 grace 后，不以 600 秒 config 兜底阻塞恢复。
