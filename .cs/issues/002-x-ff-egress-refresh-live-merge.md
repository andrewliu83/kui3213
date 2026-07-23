---
kind: issue
title: "fix: refresh 不再用实时 live 覆盖出口期望"
type: ff
status: closed
created: 2026-07-23
---

# fix: refresh 不再用实时 live 覆盖出口期望

## 做了什么

刷新 `/api/data` 后合并内存实时 live 时，改为只合并指标字段；`egress_mode` 等出口配置以 API/D1 为准。同 revision 下仍可合并实时 applied 状态与 egress_ip。

## 改了哪些

- `index.html`：新增 `mergeServerLiveMetrics`；`refreshData`、公开探针列表、探针详情 merge 使用之

## 怎么验证

- 本地模拟：API `egress_mode=native` + live 旧 `residential` 且更新的 `_realtime_ts` → 合并结果仍为 `native`，cpu 仍取 live
- 同 revision 时 live 的 `egress_ip` 可保留
- 页面：切原生看到已应用后点刷新，下拉应保持原生（需部署/本地打开新 `index.html`）

## 对 `.cs/` 的影响

- 无 Project Spec 真相变更（属 UI 刷新合并实现细节）；本 ff 留痕
