# Acceptance evidence

<!-- comet-native:acceptance-evidence:start -->
[
  {
    "acceptance_id": "acceptance-170a3e97d6b7793e4ca0c9059e9897a9818e0bc8c61a29042b2716220a63b59b",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-20e2272b04b9627d458d3c71b977debf5cc13748127bb7d63c5531ddbb9c7c48",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-77f45c85fa7adcca8bd5d0b9abc55bfc72aa03df155e6fc976c315ed8a63688f",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-784115888c4f9d090a1b15c06cd94e6161a9c8ec720fe19fb33c317231fd16af",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-ac771cdb0738827002fc8730e99032f92fd5db11d8833b4fdf464dc7d98225ca",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-be7c2af1af326cb569563d16665b1a0ea3f035086a169a397c23b940b962db71",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-d3e7b6dc75b2eb6a50e836582de902da7c084bb090a725e42a93686246e15385",
    "evidence_refs": [
      "functions/api/[[path]].js",
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-ed7c1aa3dd8c34bc67c4848256a2f9412f28503928b7db763e5f2f4d815526ce",
    "evidence_refs": [
      "index.html"
    ]
  }
]
<!-- comet-native:acceptance-evidence:end -->

# Commands and results

| 命令 | 结果 |
| --- | --- |
| `node --check functions/api/[[path]].js` | **PASS** |
| `node --check src/worker.js` | **PASS** |
| 静态符号：`FLEET_READ_TIMEOUT_MS` / `fetchWithTimeout` / `scheduleProbePublicRetry` / `realtimeCoversInventory` / Cache API `Promise.race` | **PASS** |
| 线上复现（修复前）：`GET /api/probe/public` 与 `POST /api/login` 间歇性 8–45s 无字节超时；`GET /api/servers` 成功时约 1s 返回 2 台；D1 有 2 servers / 2 probe joined | **观测记录**（根因：API 偶发挂死 + 前端无超时导致永久 loading） |

# Skipped checks

- 未在本机启动完整浏览器 E2E；超时与重试逻辑以静态路径与线上失败形态对照验收。
- 未部署到生产 Worker；部署后需人工打开「服务器与节点」与探针地图确认。

# Spec consistency

- 舰队读：`fetchApi`/`fetchWithTimeout` 15s 上界；`loadFleetServers` 超时写入 `fleetServersError` 并关闭 loading。
- 探针读：公开/详情超时；失败保留缓存；空列表时 `scheduleProbePublicRetry` + `startProbePolling` 在 inventory 为空时继续回源。
- 后端：`/api/probe/public` 对 Cache API match/put 加短时 race，避免阻塞主路径。

# Known limitations and risks

- Worker/D1 偶发超时仍可能发生；前端现可结束 loading 并重试，不消除上游抖动。
- 探针重试为指数退避至 30s；极端长时间上游故障时地图仍可能短暂空白直至成功。
- 生产部署前用户仍看到旧 bundle。

# Conclusion

pass — 实现满足 brief/spec 关于读超时、加载态收口、探针失败保留与空列表回源的要求；静态检查通过。部署后观察一轮生产即可归档。
