# Outcome

当 Agent 的 Realtime WebSocket 连接健康时，大幅降低对 Worker 的周期性 HTTP：`POST /api/report` 仅作慢速落库/兜底，`GET /api/config` 以 `config.refresh` 事件为主、HTTP 为长周期兜底。断线、流量批次与强制上报仍保持及时 HTTP，不牺牲计费增量与配置下发可靠性。

# Scope

- 修改核心 Agent：`vps/agent.py` 中 report HTTP 节流与主循环 config 拉取间隔。
- 保持：有 `pending_report_batches` 时尽快 HTTP 泄洪；`force_http`、断线 grace、无 WS 路径的既有语义。
- 保持：收到 `config.refresh` / transport 事件时立即唤醒 config 拉取。
- 用现有 `vps/test_agent_report_batches.py` 回归流量批次行为；必要时补充间隔相关单测。

# Non-goals

- 不改住宅 `lite_manager.py` 的 C2 节奏（可另开 change）。
- 不改 Dashboard 全舰队 `status.interval` 策略、frequency policy 默认值。
- 不改 `ensureDbSchema` 热路径、report 请求体结构、Realtime DO 协议。
- 不拆 `/api/proxy` 出 Worker、不改 cron。
- 不改变无 Realtime URL / WS 不可用时的 HTTP 主路径节奏（仍约 90s–300s 档，受 `global_interval` / `fast_mode` 约束）。

# Acceptance examples

1. **WS 在线、无流量批次、status-only**  
   - 输入：`realtime_channel.connected`，WS `send(status)` 成功，无 `pending_report_batches`，无 `pending_http_started`。  
   - 输出：两次成功的 HTTP `POST report` 之间间隔 **≥ 约 180s**（实现常量 `REALTIME_HTTP_INTERVAL`）；其间心跳仍可按 `realtime_status_interval` 走 WS。

2. **WS 在线、有流量批次**  
   - 输入：存在未确认 `pending_report_batches`。  
   - 输出：不因慢速 status 间隔阻塞；继续按活跃泄洪节奏 HTTP 提交批次（与现有 batch 语义一致，`test_agent_report_batches` 通过）。

3. **WS 在线、config 无事件**  
   - 输入：connected，期间无 `config.refresh` / 相关 wakeup。  
   - 输出：`fetch_and_apply_configs` 的周期性 HTTP 间隔 **≥ 约 600s**（`REALTIME_CONFIG_HTTP_INTERVAL`），而非旧的 30s。

4. **WS 在线、收到 config.refresh**  
   - 输入：connected 且收到 `config.refresh`（或 `transport.connected` 等既有 wakeup）。  
   - 输出：主循环被唤醒并执行 config 拉取，不等待长周期兜底到期。

5. **WS 断开且超过 grace**  
   - 输入：enabled 但未 connected，grace（约 30s）已过。  
   - 输出：report 以 HTTP 为主（force/allow 语义不变）；config 间隔回到无 WS 时的 `fast_mode ? 30 : 300` 行为，不被 600s 兜底卡住。

# Constraints and invariants

- 流量增量批次仅在 API 确认后推进本地基线；不得因拉长 status 间隔丢弃未确认批次。
- 慢速 HTTP 不得用于「假装已提交」流量；status-only 可慢，批次不可慢到违背活跃泄洪。
- 离线判定仍依赖 D1 `last_report`：WS 健康时 180s 落库仍远小于 6/20 分钟舰队阈值。
- 不在产物中写入真实 token/URL 密钥。

# Decisions

- 采用用户选定的 **P0**：WS 健康时拉长 HTTP report/config 兜底，config 事件驱动。
- WS 健康 status-only HTTP 间隔默认 **180 秒**；config HTTP 兜底默认 **600 秒**。
- 流量批次与 `pending_http_started` 路径不受 180s 限制（保持尽快 HTTP）。
- 本 change 仅核心 `agent.py`，不含 lite_manager。

# Open questions

（无）

# Verification expectations

- `python3 -m unittest vps/test_agent_report_batches.py` 通过。
- 静态/小测：WS 在线 status-only 使用新 `REALTIME_HTTP_INTERVAL`；config 使用 `REALTIME_CONFIG_HTTP_INTERVAL`。
- 代码审查：`config.refresh` 仍 `config_wakeup.set()`；断线路径不误用长 config 间隔。
