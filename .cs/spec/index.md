# Project Spec：KUI x Server Monitor Pro

## 这个项目是什么

KUI 是一套**自托管**的代理节点管理与服务器探针面板。当前实现部署在**单一 Cloudflare Worker** 上：静态前端与 VPS 安装组件由 Worker Assets 提供，业务 API 走 `/api/*`，实时 WebSocket 与在线状态由同 Worker 内的 Durable Objects 提供，持久化用 D1（binding 名固定为 `DB`）。

服务三类使用者：

| 角色 | 当前能做什么 |
|---|---|
| **运维者（管理员）** | 登录管理端，接入 VPS、下发节点、管用户与配额、配出口/中转/扩展、看探针大盘与系统设置 |
| **终端用户** | 用自己账号登录「我的主页」，拿普通/Clash 订阅与二维码 |
| **观众** | 打开公开探针页看机器与展示信息（是否开放由策略控制） |

目标产品全景见 [../vision/index.md](../vision/index.md)。本文件只写**当前仍成立**的现实。

## 当前状态与重点

- **形态**：单 Worker 聚合（API + 实时 + Assets）；不再要求单独 Realtime Worker 才能用实时能力。仓库里仍保留 `realtime/` 源码与其独立 `wrangler.jsonc`，但主路径是被 `src/worker.js` **import 进同一 Worker** 并 export DO 类。
- **数据**：首次访问会 `ensureDbSchema` 自动建表/升级；业务状态主要在 D1。
- **实时**：每台 VPS 对应 `VpsPresence` DO（按 IP 命名）；管理端/公开页经 `DashboardHub`（固定名 `main`）聚合快照与订阅。
- **定时**：Worker Cron `*/5 * * * *` 调离线检查（`checkOfflineServers`）；亦可走带 `CRON_SECRET` 的 `/api/cron_check`。
- **维护者此刻注意**：
  - binding 名 `DB`、`ASSETS`、`VPS_PRESENCE`、`DASHBOARD_HUB` 被代码硬依赖，改名会断。
  - 管理员口令、住宅代理凭据当前可从 Worker vars/secrets 注入；**公开实例必须用 Secret 覆盖默认弱凭据**，且勿把真实密钥提交进仓库。
  - 运行时会把 `PAGES_ORIGIN` 与 `REALTIME_URL` 设为**当前 Worker origin**，使实时与面板同域，免再配独立 Realtime URL。

## 能力地图

| 能力区 | 读者用它完成什么 | 深入 |
|---|---|---|
| **部署与运行面** | 装依赖、登录 Cloudflare、`wrangler deploy` / 一键部署、绑域名 | 下文「使用路径 · 部署」；架构落点「入口 Worker」 |
| **管理端 UI** | 在浏览器里完成运维全流程 | 界面与交互；证据 `index.html` |
| **准入与会话** | 管理员/用户登录、会话、登录节流、Agent 鉴权 | 架构落点「API 网关」 |
| **服务器与节点** | 登记 VPS、装 Agent、协议节点 CRUD、批量 8 合 1 下发 | 使用路径「接入 VPS」；VPS 侧落点 |
| **多用户与订阅** | 开通用户、配额/到期/启停、订阅令牌重置 | API `users` / `user` / `sub` |
| **订阅导出** | 普通订阅、Clash/Mihomo（含 AnyTLS）；全局可配置 Clash `rules` 与可选 `rule-providers` | API `sub`、`settings`/`data` 中的 clash 字段；系统设置 UI |
| **探针与展示** | 管理端探针大盘、公开探针主题、展示信息 | API `probe`；实时 `/public/ws` |
| **实时在线** | Agent 上报状态、面板即时刷新、频率策略 | 架构落点「实时」 |
| **节点出口** | 原生 / WARP / 住宅 / 手动 SOCKS5 等出网路径 | VPS Agent + API `proxy` / egress |
| **中转与扩展** | Realm、第三方订阅/服务、住宅控制器、相关系统参数 | 管理端对应菜单；`thirdparty`、proxy 相关表 |
| **通知** | Telegram 告警、Cron 发现离线节点 | `checkOfflineServers` + `sys_config` 中 TG 配置 |

## 使用路径

### 部署面板

1. `npm install` → `npx wrangler login` → `npx wrangler deploy`（或 Cloudflare 一键 Deploy 按钮）。
2. 确保 D1 binding 名为 `DB`，DO 类 `VpsPresence` / `DashboardHub` 已迁移。
3. 打开 Worker URL；首次 API 访问触发 schema 初始化。
4. 用 `ADMIN_USERNAME` / `ADMIN_PASSWORD`（vars 或 secrets）登录管理端。
5. 生产环境用 `wrangler secret put` 覆盖管理员与代理相关凭据后重新部署。

限制：未绑 `DB` 时 `/api/*` 直接 500 并提示绑定错误。改 Variables/Bindings 后需重新部署才生效。

### 接入一台 VPS 并形成节点

1. 管理端 → **服务器与节点** → 添加名称与公网 IP。
2. 复制页面生成的 Full Deploy 命令，在 VPS 上以 root 执行（安装脚本与组件由 Assets 下的 `/vps/*` 提供）。
3. Agent 用机器 IP + 鉴权回连；可拉配置、上报状态/流量，并经实时通道推状态。
4. 在面板创建协议节点（或 8 合 1 批量），节点绑定 `vps_ip`。

支持的协议类型在后端路由/生成逻辑中覆盖常见 Reality / Hysteria2 / TUIC / Trojan / AnyTLS / Naive / Argo / Socks5 等（以当前 API 与 UI 为准）。

### 给人开订阅

1. **多用户管理**开通用户，设流量上限、到期、启用状态。
2. 终端用户登录后在「我的主页」复制普通/Clash 订阅或二维码。
3. 订阅令牌可重置；保护逻辑会限制可疑/私有订阅主机等场景（见 `protectedSubscriptionResponse` 一类实现）。
4. （运维，可选）在 **系统设置 → Clash 分流规则** 选择模板或编辑 `rules` / `rule-providers` 并保存；之后所有 `format=clash` 订阅共用这份全局壳。空配置时规则回退为全量 `MATCH,PROXY`，且不输出 `rule-providers`。

### 盯机器是否活着

1. 管理端 **探针全景大盘** 看实时指标；公开页给观众。
2. Agent 周期性 HTTP 上报 + WebSocket 实时；Cron 每 5 分钟扫离线并可 Telegram 通知。
3. 面板 UI 会 `ui_ping` 标记活跃，配合实时频率策略降低空闲推送成本。

### 本地开发

- 根目录：`npm run dev` → `wrangler dev`。
- 实时子系统历史上可单独部署，**当前产品路径不要求**；改实时逻辑时改 `realtime/src/index.js`，随主 Worker 一起发。

## 界面与交互

### 管理端壳层

- 角色与入口：运维者登录后进入「KUI 管理面板」；终端用户偏「我的主页」。
- 图示状态：当前

```text
+------------------+----------------------------------------+
| 侧栏导航         | 主内容区                               |
| 服务器与节点     |  列表 / 表单 / 命令复制 / 批量下发      |
| 多用户管理       |                                        |
| 住宅IP代理       |                                        |
| Realm中转        |                                        |
| 第三方服务/订阅  |                                        |
| 系统设置         |                                        |
| 探针全景大盘     |  卡片/表格/地图 + 图表                  |
| 我的主页         |  订阅复制 / 已开通节点（用户视角）      |
+------------------+----------------------------------------+
```

- 交互与状态：侧栏切换页面（前端路由式 `page` 提示：`nodes` `users` `proxy` `realm` `services` `thirdparty` `settings` `dashboard` 等）；登录前有准入/登录页。
- 稳定约束：单页 `index.html` 承载管理端与探针相关 UI；后端契约是 `/api/{action}/...`。
- 仅作示意：具体控件文案与图表库细节以线上 UI 为准。

## 架构落点

```text
浏览器 / VPS Agent
        |
Cloudflare Worker (src/worker.js)
  |- /api/*     → functions/api/[[path]].js  (onRequest + Cron onRequestScheduled)
  |- 实时路由   → realtime/src/index.js
  |                 |- VpsPresence  DO  (每 VPS)
  |                 `- DashboardHub DO  (main)
  |- 其它路径   → ASSETS (目录为仓库根；run_worker_first: /api)
  |- D1 DB
  `- Cron */5
```

| 子系统 | 支撑路径 | 交互 | 落手位置 |
|---|---|---|---|
| **入口 Worker** | 全部 HTTP | 分发 API / 实时 / 静态；注入 origin | `src/worker.js`，`wrangler.jsonc` |
| **API 网关** | 登录、CRUD、订阅、Agent 上报、探针 API、设置 | 读 D1；鉴权；可通知实时 Hub | `functions/api/[[path]].js` |
| **实时服务** | Agent WS、面板 WS、公开 WS、策略与 notify | DO 存短时状态；可查 D1 验 Agent/Admin | `realtime/src/index.js` |
| **前端 Assets** | 管理端与探针 UI、安装脚本下载 | 调 `/api` 与实时路径 | `index.html`，`vps/*`，`.assetsignore` |
| **VPS Agent** | 安装、拉配置、跑 sing-box/出口、上报 | HTTPS 回面板；WS 实时 | `vps/agent.py`，`vps/kui.sh`，`vps/realtime_client.py` |
| **住宅代理组件** | 住宅出口控制面/本地代理 | 与控制器 API、面板 proxy 配置 | `vps/lite_manager.py`，`proxy_server.py`，`residential-proxy.sh` |

### 请求如何进系统（现状机制）

1. 请求打到 Worker。
2. 路径以 `/api` 开头 → 解析 `params.path[0]` 为 **action**（如 `login` `vps` `nodes` `sub` `report` `probe` `settings`…），缺 `DB` 则失败。
3. 实时路径集合（`/agent/ws`、`/dashboard/*`、`/public/ws`、`/notify`、`/health` 等）→ realtime 模块；Agent 进 `VpsPresence`，面板/公开进 `DashboardHub`。
4. 其余 → `ASSETS.fetch`（前端、脚本、静态文件）。
5. Cron → `onRequestScheduled` → 离线检查。

### D1 中的主要实体（概念）

| 概念 | 表（名） | 作用 |
|---|---|---|
| 机器 | `servers` | VPS 身份与最近探针字段 |
| 用户 | `users` | 终端用户、配额、到期、订阅令牌 |
| 节点 | `nodes` | 协议节点，挂在 `vps_ip` |
| 流量 | `traffic_stats` 等 | 增量流量记录 |
| 系统键值 | `sys_config` | 站点标题、realtime_url、ui_active、admin_sub_token 等 |
| 探针配置/展示 | `probe_settings` `probe_servers` | 公开探针与展示 |
| 代理/住宅 | `proxy_servers` `proxy_slot_map` `proxy_ctrl_servers` | 出口与控制器侧状态 |
| 第三方订阅 | `third_party_subscriptions` `third_party_nodes` | 外站订阅导入 |
| 鉴权辅助 | `auth_sessions` `auth_replays` `login_throttles` `report_receipts` | 会话、防重放、登录节流、上报回执 |

### Agent 组件更新

`/api/agent_update`（Agent 鉴权）可从 Assets 拉取组件：`agent`、`realtime-client`、`proxy-manager`、`proxy-server`、`proxy-installer`、`full-installer`，对应 `vps/` 下脚本。

## 统一语言

| 术语 | 本 spec 含义 | 勿混 |
|---|---|---|
| **运维者 / 管理员** | 持 `ADMIN_*` 管理端权限的人 | ≠ 终端用户 |
| **终端用户** | `users` 表中的订阅消费者 | ≠ 观众 |
| **VPS / 机器 / servers 行** | 已登记且可跑 Agent 的主机 | ≠ 协议节点 |
| **节点 / nodes 行** | 可导出到订阅的协议入口 | ≠ 机器 |
| **Agent** | VPS 上 `agent.py` 为主的接入进程 | ≠ Worker 后端 |
| **实时** | 同 Worker 内 DO+WS 通路 | ≠ 必须单独部署的旧 Realtime Worker |
| **订阅** | 带 token 的节点清单导出 | ≠ 登录 session |
| **Clash 规则 / rules** | `format=clash` YAML 中的分流列表；全局一份，存在 `sys_config.clash_rules` | ≠ 代理节点列表本身 |
| **rule-providers** | Clash 远程/本地规则集声明；可选，存在 `sys_config.clash_rule_providers` | ≠ `rules` 正文 |
| **action** | `/api/{action}/...` 的第一路径段 | ≠ 前端 page 名（常相关但不必相等） |
| **DB** | D1 binding 名，不可随意改 | ≠ 数据库显示名 |
| **信息安全性** | 凭据、会话、Agent 鉴权、订阅保护 | 见质量约束 |

与 Vision 术语对齐；若冲突，**描述当前行为时以本 spec + 代码为准**，描述目标时以 Vision 为准。

## 阅读路径

- 想理解产品目标世界：读 [../vision/index.md](../vision/index.md)
- 想部署或改绑定：读「使用路径 · 部署」+ `wrangler.jsonc` + `src/worker.js`
- 想改业务 API / 表结构 / 订阅 / 用户：读「架构落点 · API」+ `functions/api/[[path]].js`
- 想改实时推送 / 在线状态：读「架构落点 · 实时」+ `realtime/src/index.js`
- 想改面板交互：读「界面与交互」+ `index.html`
- 想改 VPS 安装或 Agent 行为：读 `vps/kui.sh`、`vps/agent.py`、相关组件
- 想查历史取舍与坑：扫 [../notes/](../notes/)、[../issues/](../issues/)（当前可能仍空）

## 当前边界

**做（已具备主路径）**

- 单 Worker 上的管理端 + API + 内置实时 + Assets
- VPS Agent 接入、多协议节点、用户配额与订阅导出
- 全局可配置的 Clash 分流：`rules` 文本 + 可选 `rule-providers` + 内置模板（本地绕过与 Loyalsoldier 远程规则集）
- 探针大盘与公开探针、Cron 离线检查、可选 Telegram
- 住宅/WARP/SOCKS 等出口相关能力与第三方订阅扩展（以实现与 UI 为准）

**不做 / 非当前主路径**

- 不把独立 `realtime/` Worker 当作新部署必选项（代码可被单独部署，但产品文档与主入口已内置）
- 不提供非 Cloudflare Workers 的一等运行说明
- 不做完整多租户 SaaS 控制面（当前是自托管单实例面板模型）
- 不做 per-user Clash 规则、可视化规则表，或完整 ACL4SSR 多策略组（AI/流媒体等）；当前 Clash 壳仍只有 `PROXY` / `AUTO` 两组供规则引用
- Project Spec **不**承载「将来想做成什么样」——那是 Vision

## 关键考量

- **单 Worker 聚合**：减少 `REALTIME_URL` / 双 D1 / 双部署心智；用 `withWorkerOrigin` 把 origin 注入 env，使实时与 API 同域。代价是 Worker 包体与职责更重，实时与 API 同发布节奏。
- **D1 + 自动 schema**：降低运维建表成本；复杂迁移依赖 `ensureDbSchema` 增量逻辑，改表需谨慎兼容旧库。
- **DO 分 VPS 在线状态**：按 IP 的 presence 隔离并发与连接；Hub 做面板侧聚合与 ticket，避免浏览器直连每个 presence 的鉴权复杂度。
- **Assets 根目录发布**：前端与 `/vps` 脚本同 origin 下载简单；需用 `.assetsignore` 排除不该进 CDN 的路径。
- **保留 realtime 子包**：便于理解历史拆分与 DO 实现边界；新功能默认改被 import 的源，而不是假设两套生产 Worker。
- **Clash 规则文本 + 模板，而非可视化编辑器**：与 Meta/Mihomo 语法同步成本低；运维可直接贴社区 rules。默认/空配置不写库，订阅回退全量代理。远程模板依赖客户端拉取 jsDelivr 上的 Loyalsoldier 规则集。有界简化上限：全局一份壳、不校验完整 YAML schema、策略组不扩展为机场级多组。

被排除/弱化的方案：

- **强制独立 Realtime Worker**：旧路径仍可见于 `realtime/wrangler.jsonc` 与部分 `REALTIME_URL` 读取逻辑，但主 Worker 已内置并默认同 origin。
- **传统常驻面板机**：与「Serverless 单 Worker」产品定位相反。
- **完整 ACL4SSR / 多策略组订阅壳**：与当前「只导出节点 + 简单 PROXY/AUTO」产品边界不符；升级触发是明确需要 AI/流媒体等分组时再开事项。

## 质量约束与取舍

- **信息安全性 · 身份鉴别**：管理端与敏感 API 依赖管理员凭据与会话/签名校验；Agent 接口用 Agent 鉴权。默认弱口令仅便装，公开环境必须覆盖 Secret。
- **信息安全性 · 防滥用**：登录节流（`login_throttles`）、鉴权 nonce 防重放（`auth_replays`）、订阅导出保护（私有主机等）存在于实现中，改鉴权时不得无替代拆除。
- **信息安全性 · Clash 配置面**：`clash_rules` / `clash_rule_providers` 仅管理员经 `/api/settings` 写入；正文有长度上限；不当代码执行。
- **可靠性 · 离线感知**：Cron 5 分钟粒度 + Agent 上报；不是秒级 SLA 保证，告警可能延迟一个周期。
- **性能效率 · 实时推送**：Dashboard 活跃与频率策略调节上报/广播间隔，空闲降频；改实时时需保持策略语义。
- **可维护性**：业务高度集中在单文件 API 与单页 HTML；改动面大，回归应覆盖登录、VPS 上报、订阅导出、实时连接四条主路径。Clash 模板与归一化集中在 API 辅助常量/函数，生成路径只读配置。
- **兼容性 · Clash 客户端**：默认与本地模板不依赖外网规则集；带 Loyalsoldier 的模板需 Mihomo/Clash Meta 且能访问 jsDelivr。服务端不完整校验 YAML。

指标阈值与合规声明：无单独对外 SLA 文档；不在此宣称标准符合性。

## 证据索引

| 理解 | 证据 |
|---|---|
| 路由三分（API / 实时 / Assets） | `src/worker.js` |
| Worker 名、D1、Cron、DO、vars | `wrangler.jsonc` |
| API action 与建表 | `functions/api/[[path]].js`（`onRequest`、`initializeDbSchema` / `ensureDbSchema`、`onRequestScheduled`） |
| DO 与实时路径 | `realtime/src/index.js`（`VpsPresence`、`DashboardHub`、default fetch） |
| 前端能力入口 | `index.html` 侧栏文案与 page 提示 |
| VPS 安装与 Agent | `vps/kui.sh`、`vps/agent.py`、`vps/realtime_client.py` |
| 住宅代理组件 | `vps/lite_manager.py`、`vps/proxy_server.py`、`vps/residential-proxy.sh` |
| 产品说明与协议列表 | `README.md` |
| Clash 规则模板与注入 | `functions/api/[[path]].js`（`CLASH_RULE_TEMPLATES`、`loadClashRules`、`loadClashRuleProviders`、sub `format=clash`）；设置 UI 在 `index.html` |
| 关闭沉淀来源 | [../issues/001-x-clash-subscription-rules.md](../issues/001-x-clash-subscription-rules.md) |
| 目标世界 | [../vision/index.md](../vision/index.md) |

说明：本 spec 从 README + 入口代码 + schema/路由抽样归纳，并在关闭 Clash 规则 feature 时补了订阅壳现状。细到每个 action 的请求体字段未逐条展开。改某一 action 前应再读对应代码分支，必要时补子层 spec 或 Explore issue。
