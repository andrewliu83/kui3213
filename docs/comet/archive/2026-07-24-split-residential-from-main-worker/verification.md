# Acceptance evidence

<!-- comet-native:acceptance-evidence:start -->
[
  {
    "acceptance_id": "acceptance-04c848a7e5981832eb81a74322a53960b41cc6fd72016c991df74e03b74f56bb",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-096c0621d6df8e0206eb715b39349f91b50a2b894ba6ea467530181a7a4a2e36",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-142fe4f53a5e6d218a219be058e5c11d678e4aab26e00102c972d2f1a5530aba",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-1509cdcf40cea79b0c85a42fe52b96de3d5ea628dcdd60b805dca3972c06eb00",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-6148042f80ddc02beafd420f3d15e525ed94caebb5c054064d3d7d91f0b0e827",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-73d792567981d8263da0d6f0cb1d0e5abd10d8b73f5f8efc1596ae1853305f6a",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-846ee34befad26ea0d58714e447c063b61c3a9aac10e148de7b5b3251b628561",
    "evidence_refs": [
      "functions/api/[[path]].js",
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-a044e61fc16461a7948696db6fd2126057829e381caac99c4519be1feca96151",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-c1ddcf082288ed968c13814bc28b06ead6e3d1b1ffbedc618e76a793d1bb4e81",
    "evidence_refs": [
      "vps/lite_manager.py"
    ]
  },
  {
    "acceptance_id": "acceptance-fc8fb5823aab840f7add6aebd714a293d81adb34397c59b7410983183ec67fd7",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  }
]
<!-- comet-native:acceptance-evidence:end -->

# Commands and results

1. **静态断言（Python）**  
   - `REALTIME_HTTP_INTERVAL = 180`  
   - `REALTIME_CONFIG_HTTP_INTERVAL = 600`  
   - WS connected 时 `config_interval = REALTIME_CONFIG_HTTP_INTERVAL`  
   - report 仍用 `last_http_report >= REALTIME_HTTP_INTERVAL`  
   - `config.refresh` 仍存在  
   - 无旧常量 `= 60`  
   - `proxyLocal` 与 `PROXY_CTRL_URL` 仍在 `functions/api/[[path]].js`  
   - 结果：PASS  

2. **单元测试**  
   - 仓库无 `lite_manager` 专用测试；未伪造 E2E。  

# Skipped checks

- 未在生产多 VPS 上统计 `/api/proxy/report` 与 `/api/proxy/config` 下降幅度（需部署并更新 proxy-lite 后观察）。  
- 未跑真机 Realtime + C2 联调。

# Spec consistency

与 `residential-c2-http-throttle` 一致：WS 健康 180/600、事件立即 config、断线回退、不强制外置。

# Known limitations and risks

- 生效需部署新 `lite_manager.py` 并由 proxy-lite 自更新（约每小时）或重启。  
- 地区切换若仅改 DB 而未推 `config.refresh`，最坏约 600s 才收敛（WS 健康时）。  
- 名称 change 为 split，实际交付为降频；外置控制器仍为可选运维路径，本 change 未强制。

# Conclusion

实现满足 C 形态 brief/spec。结论：**pass**。
