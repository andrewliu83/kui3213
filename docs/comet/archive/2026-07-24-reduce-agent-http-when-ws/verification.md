# Acceptance evidence

<!-- comet-native:acceptance-evidence:start -->
[
  {
    "acceptance_id": "acceptance-35738c6f63aa80a7d7dd0cb15c56de53067b8d8fbd5436b5294cfe25d99fb976",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-4fe46d928fd431289b9d9b57a8bc6288d1c70d579f0da4f8365721928896cad0",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-7246d5da80ad04010d95f86da2032c607b63e319f78080d3e8d504bc86ef59b8",
    "evidence_refs": [
      "vps/agent.py",
      "vps/test_agent_report_batches.py"
    ]
  },
  {
    "acceptance_id": "acceptance-740e191d1fa816e00e1c395bd32b7b9e00ab315a9fe1dc4950599df03b544c1a",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-76a67b72eaf91defd288b39323e05c95e5be0633afa3337ba019ab2faf6f9cf5",
    "evidence_refs": [
      "vps/agent.py",
      "vps/test_agent_report_batches.py"
    ]
  },
  {
    "acceptance_id": "acceptance-77ba495f835e8811fb05f459e282a9bde3d42b94239fdc949f9d8eaa27758dfb",
    "evidence_refs": [
      "vps/agent.py",
      "vps/test_agent_report_batches.py"
    ]
  },
  {
    "acceptance_id": "acceptance-a3eb2efd8edc7a7bf04a07be3ec688a780e9b4ae73e3b73d181f6039332c99ab",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-a78d9273a5b41053906c11c99f3f6ece85b2366c64653053dc3fc627934116f0",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-b5e842259cc8988e109808ae14308c76afa3e3d8582d989bac40feea828b6dd2",
    "evidence_refs": [
      "vps/agent.py"
    ]
  },
  {
    "acceptance_id": "acceptance-c9c7bd4924f52ee8b99a7a604622030db7b496a68d1250ccb8f3fa7e323f6c80",
    "evidence_refs": [
      "vps/agent.py",
      "vps/test_agent_report_batches.py"
    ]
  }
]
<!-- comet-native:acceptance-evidence:end -->

# Commands and results

1. **`python3 -m unittest vps.test_agent_report_batches -v`**  
   - 结果：7 tests OK。  
   - 覆盖：>200 拆批、WS 下批次立即 HTTP、status-only 不误触发 5s 泄洪、失败/重启恢复、legacy pending 迁移。

2. **静态断言**  
   - `REALTIME_HTTP_INTERVAL = 180`  
   - `REALTIME_CONFIG_HTTP_INTERVAL = 600`  
   - status skip 条件含 `not pending_report_batches`  
   - WS connected 时 `config_interval = REALTIME_CONFIG_HTTP_INTERVAL`  
   - `config.refresh` 仍调用 `config_wakeup.set()`（未改 on_realtime_message 逻辑）

3. **代码审查**  
   - 断线 config：`connected` 为假时仍为 `30 if fast_mode else 300`。  
   - 流量批次绕过 180s status 节流。

# Skipped checks

- 未在生产多 VPS 上采样 Cloudflare 请求计数下降（需部署后观察）。  
- 未跑端到端 Realtime DO + 真机 Agent（本地无完整 Worker/Realtime 环境）。

# Spec consistency

与 `agent-http-ws-fallback` 一致：WS 健康 status-only HTTP ≥180s、config 兜底 ≥600s、事件立即 config、批次及时 HTTP、断线回退旧间隔。

# Known limitations and risks

- 部署后 Agent 需更新到新 `agent.py` 才生效。  
- D1 `last_report` 在纯 status-only 时最多约 180s 滞后；仍低于 6/20 分钟舰队阈值。  
- 面板改节点仍依赖 `notifyRealtimeVps` → `config.refresh`；若 Realtime 故障，靠 600s 兜底收敛（断线后走 30/300s）。  
- `lite_manager` 未改，同域住宅仍有独立 HTTP。

# Conclusion

实现与验收项满足 brief/spec；单元测试通过。结论：**pass**。
