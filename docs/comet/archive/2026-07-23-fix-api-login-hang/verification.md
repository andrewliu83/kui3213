# Acceptance evidence

<!-- comet-native:acceptance-evidence:start -->
[
  {
    "acceptance_id": "acceptance-0e880ce08785d6004bf2d007b327dbdcde7129b45640e3c26bbe1e6c4dbfacb5",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-5b5edbd6b25643dcc72e0c5628ae52322be1634e942feae503d8f498213ddcf5",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-5b83cd12f66aa492099d2aba9417f723bfdee53a6f8899d9edbb50e98b6d1552",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-86158c8b4b6f3305dda7e47d15df68b2203f1a81de5dde92546f32895d6fb44b",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-8622bc55780aa7ad96a78140ee259f25cefde475ccc7ae550e6466559291b581",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-b75f6e6a67f5789b9756e629aa607e0d5d24adeac8eab46d71dc8dc8f1e9aae7",
    "evidence_refs": [
      "functions/api/[[path]].js"
    ]
  },
  {
    "acceptance_id": "acceptance-ccb0d1e0b8b4afab5b576497e5a7fedf30ca88a141f0969ce4004f2bbcb466bf",
    "evidence_refs": [
      "index.html"
    ]
  },
  {
    "acceptance_id": "acceptance-dc8c93704a37edfa4646bbb10a143201a436a378149e11b9071f59de1f923931",
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
| 静态：`DB_SCHEMA_VERSION`、`schema_version` 短路、`nodes.json seed timeout`、login `fetchWithTimeout` | **PASS** |
| 线上观测（修复前）：`POST /api/login` 约 1/5 次 12s 无字节超时；成功路径 ~1.05s；`/api/probe/public` 同类抖动；非密码/throttle（`login_throttles` 空） | **记录** |

# Skipped checks

- 未在本机模拟 GitHub 全断网 E2E；seed 超时路径以代码 `Promise.race` 1.5s 为准。
- 生产部署后需再测登录成功率。

# Spec consistency

- `ensureDbSchema` 版本短路与 seed 超时满足规格 1–3。
- 登录 UI 15s 超时与 429 提示满足规格 4。

# Known limitations and risks

- 首次部署后第一次请求仍会跑完整迁移一次；之后短路。
- Worker 其他路径（Agent report 等）仍可能造成 isolate 压力，需持续观察。

# Conclusion

pass
