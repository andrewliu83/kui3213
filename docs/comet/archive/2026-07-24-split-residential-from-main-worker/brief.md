# Outcome

在**不外置、不取消内置**住宅控制面的前提下，降低住宅 proxy-lite（`lite_manager`）在 WebSocket 健康时对主 Worker（或当前 C2 同源）的周期性 HTTP：`…/report` 慢速落库，`…/config` 以 `config.refresh` 事件为主、长周期 HTTP 兜底。多机住宅场景下主 Worker 的 `/api/proxy/*` 请求密度明显下降。

# Scope

- 修改 `vps/lite_manager.py`：report HTTP 节流与 config 拉取间隔（对齐核心 Agent 的 WS 健康策略）。
- 保持：内置 `proxyLocal`、未配置 `PROXY_CTRL_URL` 时的同域 C2、面板 `/api/proxy/*` 与桥接逻辑不变。
- 保持：`config.refresh` / transport 事件立即唤醒 config；WS 断线后回退较快 HTTP。
- 验收以代码审查 + 常量/路径静态断言为主（无独立 lite 单测文件时诚实记录）。

# Non-goals

- 不强制配置外部 `PROXY_CTRL_URL`，不删除 `proxyLocal` / 内置 D1 住宅控制面。
- 不改部署命令强制 `--proxy-api`、不改 `kui.sh` / `residential-proxy.sh` 默认同域行为。
- 不改核心 `agent.py` 的 report/config（已由 `agent-http-ws-fallback` 处理）。
- 不改 Dashboard 全舰队 `status.interval`、不改 `ensureDbSchema`。
- 不改住宅数据面（本机 SOCKS、隧道切换逻辑本身）。

# Acceptance examples

1. **WS 在线、status 已发 WS**  
   - 输入：`realtime_channel.connected` 且 `send(status)` 成功。  
   - 输出：两次 HTTP `…/report` 间隔 **≥ 约 180s**（`REALTIME_HTTP_INTERVAL`），而非旧的 60s。

2. **WS 在线、config 无事件**  
   - 输入：connected，期间无 `config.refresh` 等 wakeup。  
   - 输出：周期 `fetch_controller_config` 间隔 **≥ 约 600s**（`REALTIME_CONFIG_HTTP_INTERVAL`），而非旧的 60s。

3. **收到 config.refresh**  
   - 输入：connected 且收到 `config.refresh`。  
   - 输出：`config_wakeup` 触发，立即拉 config，不等待 600s。

4. **WS 断开超过 grace**  
   - 输入：enabled 但未 connected，grace 已过。  
   - 输出：report 按 fallback 走 HTTP；config 间隔回到约 **300s** 常态，不被 600s 唯一路径卡住。

5. **内置控制面仍可用**  
   - 输入：未配置 `PROXY_CTRL_URL`，C2 仍指向主站 `/api/proxy/*`。  
   - 输出：路径与鉴权语义不变；仅节奏变慢。

# Constraints and invariants

- 不在产物中写入真实凭据。
- 国家切换、`switch_trigger` 仍依赖 config 拉取；事件路径必须保留。
- 离线 grace（约 30s）与既有 fallback 语义保留。

# Decisions

- 用户确认目标形态 **C：不外置，仅降频**。
- WS 健康 status HTTP 默认 **180s**；config HTTP 兜底默认 **600s**（与核心 Agent P0 同量级）。
- 不引入强制外部控制器。

# Open questions

（无）

# Verification expectations

- 静态确认 `lite_manager.py` 中 `REALTIME_HTTP_INTERVAL=180`、`REALTIME_CONFIG_HTTP_INTERVAL=600`，且 WS 连接时 config 使用后者。
- 确认 `config.refresh` 仍 `config_wakeup.set()`。
- 确认 `proxyBridge`/`proxyLocal` 与 `PROXY_CTRL_URL` 行为未因本 change 被删除或强制。
