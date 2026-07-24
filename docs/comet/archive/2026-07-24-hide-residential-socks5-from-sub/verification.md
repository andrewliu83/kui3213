# Acceptance evidence

<!-- comet-native:acceptance-evidence:start -->
[
  {
    "acceptance_id": "acceptance-0c627407c0f0e908506ca3d1f5b478342a525010b864f40507213ddc0bca1513",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-1f56317a41ae2b3371da875b413558abb73c1c68c869dd600fe5dc17ac6799ee",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-2279abbd5d261d93a077a99b3151e4741b068aba0dca984d862aad19a51bcb8d",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-2e665a06c2a7407c6dd2cfd6792dd00b3a7be4f1255ebfd551e0f00f397f23d9",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-328a08ab91335b75aee8b899ea43d8b09c72cfe4f7deb086fe1d606301b5b9cb",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-5deb34b647ed02b4a0f2bb6fc0ebbab35e8fb10fba661dbc2da39dbdc63588f5",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-5efe3d9b3b212ac810c27b6d938c881ee6cbdb709fbc6cb81a02f820d4235c59",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-630bb8a8d154b5e33645242380f2164cec07cb21296cb22f14e2fbaf900618eb",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-68f537321ce3c8a6bbfc0faa40a4b5f349977a4609d55613719707596cc8226f",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-bfb3ab8ab7a7f8ea713d24ccabb56bd77df3a641fb5a1dea253b9f8c650261f5",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-f939ee03eb239dd78667ec66053f412cb0dc02b8a5a8646b8552021913c806f6",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  }
]
<!-- comet-native:acceptance-evidence:end -->

# Commands and results

1. **静态切片检查（Python 脚本，工作区本地）**  
   - 定位 `if (action === "sub" && method === "GET")` 代码块。  
   - 结果：
     - `proxy_ctrl_servers` 不在 sub 块内 → PASS  
     - `住宅 SOCKS5` 不在 sub 块内 → PASS  
     - `PROXY_USER` / `PROXY_PASS` 不在 sub 块内 → PASS  
     - `case "Socks5"` 仍在 sub 块内（协议节点）→ PASS  
     - 控制面 `subPath === 'proxies'` 仍在全文件中 → PASS  
   - sub 块内仅剩协议节点 `Socks5` 链接生成，无住宅追加。

2. **`comet native check hide-residential-socks5-from-sub`**  
   - 退出码 1。  
   - 原因：scope 内 `functions/api/[[path]].js` 既有 trailing-whitespace 共 72 处（多在未改动的行，如 schema/API 段）。  
   - 与「订阅是否导出住宅 SOCKS5」无关；未作为 pass 证据引用 receipt。

3. **代码 diff 审查**  
   - 删除原管理员分支：在 `reqUser === adminUser && env.PROXY_USER && env.PROXY_PASS` 时从 `proxy_ctrl_servers` 向 `subLinks`/`clashProxies` 追加住宅条目。  
   - 保留简短注释说明住宅运行时记录不得进入任一订阅格式。

# Skipped checks

- 未对真实 Cloudflare Worker + D1 发起端到端 `GET /api/sub` 请求（本环境无已部署实例与有效订阅 token）。  
  用源码路径完备性断言替代：住宅追加逻辑已从 sub 路径移除，管理员与普通用户共用同一组装路径，故两种用户 × 两种格式均不再注入住宅条目。

# Spec consistency

- 与 `specs/subscription-export/spec.md` 一致：可导出集合 = 协议节点 + 第三方节点；排除住宅运行时登记与共享凭据。  
- 控制面 `/proxy/proxies` 仍读取 `proxy_ctrl_servers` 并可用共享凭据拼装列表，符合 Non-goals / Out of scope。  
- 协议型 `Socks5` 的 `case` 分支未删。

# Known limitations and risks

- 运行时 E2E 未跑；若其他入口另有订阅导出副本，需另查（当前仓库仅 `functions/api/[[path]].js` 的 `action === "sub"`）。  
- 内置 text-safety check 仍会因历史 trailing whitespace 失败；未在本 change 做全文件空白格式化，避免无关 diff。  
- 客户端若已缓存旧订阅，需重新拉取订阅 URL 后才会看不到住宅节点。

# Conclusion

实现满足 brief 与完整目标规格：普通 Base64 与 Clash 订阅均不再暴露住宅 SOCKS5 及 `PROXY_USER`/`PROXY_PASS`。结论：**pass**。
