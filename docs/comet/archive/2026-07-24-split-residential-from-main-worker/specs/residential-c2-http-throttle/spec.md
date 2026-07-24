# residential-c2-http-throttle

## Purpose

定义住宅 proxy-lite 进程（`lite_manager`）在 **Realtime WebSocket 可用与否** 时，对住宅控制面 C2（主 Worker 内置 `/api/proxy/*` 或外部控制器同源 API）的 HTTP 上报与配置拉取节奏。目标是在不外置控制面的前提下降低主 Worker 请求数。

## Definitions

| 术语 | 含义 |
| --- | --- |
| WS 健康 | proxy 角色 Realtime 通道已连接，status 可经 WS 发送 |
| C2 | 住宅控制器 HTTP API 前缀（内置为 `/api/proxy`，外置控制器为 `/api`） |
| Config 事件 | `config.refresh` 或 transport 连接状态变化等既有唤醒 |

## Report

1. WS 健康且 status 已成功经 WS 发送时，HTTP `…/report` 两次提交的最小间隔为 **约 180 秒**。
2. WS 不健康且超过既有 grace 后，HTTP report 为权威落库路径，按既有 fallback 节奏（约 90 秒心跳档）发送，不强制套用 180 秒作为断线唯一策略。

## Config

3. Config 事件必须尽快触发 `…/config` 拉取。
4. WS 健康且无 Config 事件时，周期 HTTP config 最小间隔为 **约 600 秒**。
5. WS 不健康时，周期 config 回退既有约 **300 秒**（或空配置重试路径），保证无推送时仍能收敛地区/端口策略。

## Control-plane topology

6. 本 capability **不要求**配置外部控制器；内置 D1 控制器与可选 `PROXY_CTRL_URL` 桥接语义保持可用。
7. 本 capability **不**删除同域 C2；降频对内置与外置 C2 主机均适用（只要 lite 连该 C2）。

## Non-requirements

- 不规定强制拆出主 Worker 或取消 `proxyLocal`。
- 不规定 Dashboard 全舰队 interval。
- 不规定核心 KUI Agent 的 `/api/report` 节奏（另见 `agent-http-ws-fallback`）。

## Acceptance criteria

1. WS 健康时 HTTP report 不以约 60 秒为默认周期，而以约 180 秒为最小周期。
2. WS 健康时无事件 config 不以约 60 秒为默认周期，而以约 600 秒为最小周期。
3. `config.refresh` 仍立即触发 config 拉取。
4. 未配置外部控制器时，内置住宅控制面仍可工作。
