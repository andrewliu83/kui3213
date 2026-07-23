# Outcome

登录接口与未登录探针列表在 Worker 偶发压力下可在有限时间内成功或给出明确失败；不再因 schema 初始化卡住整站 `/api/*`，用户不会无限等待登录或空白探针列表。

# Scope

- `ensureDbSchema`：schema 版本短路，已迁移库跳过数十次 ALTER 探测。
- 初始化路径中对外部 GitHub `nodes.json` 的拉取增加超时，且失败不阻塞 schema promise。
- 前端登录使用有超时的 `fetchWithTimeout`，超时/429/网络错误给出可读提示。

# Non-goals

- 不改管理员密码与鉴权算法。
- 不保证消除全部 Cloudflare isolate 抖动；保证冷路径不再被外部 fetch 永久卡住。
- 不重做舰队 UI。

# Acceptance examples

1. **登录成功路径**  
   - 输入：正确管理员账号密码；`POST /api/login` 在 15s 内返回。  
   - 输出：获得 token 并进入管理端。

2. **登录超时**  
   - 输入：`POST /api/login` 超过客户端 15s 无完整响应。  
   - 输出：提示登录超时并可重试，不静默卡死。

3. **schema 已就绪的冷请求**  
   - 输入：`sys_config.schema_version` 等于当前 `DB_SCHEMA_VERSION`；任意需 `ensureDbSchema` 的请求。  
   - 输出：仅做版本读，不跑全量 CREATE/ALTER/外部 fetch。

4. **nodes 种子超时**  
   - 输入：首次 schema 初始化时 GitHub 不可达或超过 1.5s。  
   - 输出：schema 仍完成；`schemaReadyPromise` 不被外部 fetch 挂死；登录/探针可继续。

# Constraints and invariants

- 不写入明文密码到日志或 Native 报告。
- 外部网络不得成为 schema 完成的硬依赖。
- 版本号变更时必须重新跑完整 `initializeDbSchema`。

# Decisions

- 使用 `sys_config.schema_version` 与代码内 `DB_SCHEMA_VERSION` 对齐短路。
- GitHub seed 超时 1.5s；失败跳过。
- 登录前端 15s 超时。

# Open questions

（无阻塞项。）

# Verification expectations

- `node --check functions/api/[[path]].js`
- 静态检查含 `DB_SCHEMA_VERSION`、seed timeout、login `fetchWithTimeout`
