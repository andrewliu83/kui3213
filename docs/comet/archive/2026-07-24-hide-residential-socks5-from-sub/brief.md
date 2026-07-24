# Outcome

普通 Base64 订阅与 Clash 订阅（两种 `GET .../sub` 格式）均不再附带住宅 SOCKS5 代理条目，也不再在订阅载荷中输出住宅代理共享凭据（`PROXY_USER` / `PROXY_PASS`）。订阅只导出协议节点与已启用的第三方节点。

# Scope

- 修改订阅生成路径：`functions/api/[[path]].js` 中 `action === "sub"` 的响应组装。
- 覆盖两种输出：默认 Base64 节点链接列表，以及 `format=clash` 的 YAML。
- 覆盖管理员订阅与普通用户订阅（二者均不得暴露住宅 SOCKS5）。
- 验收时以代码审查与静态断言确认住宅追加逻辑已移除，且订阅组装路径不再引用住宅凭据字段。

# Non-goals

- 不改变住宅代理控制面接口（如 `/proxy/proxies`、`/proxy/nodes`）及其对 Agent / 外部控制器的用途。
- 不改变 VPS 本机住宅出口（egress `residential`）、`proxy_server.py`、Agent 出口注入。
- 不删除或禁用用户/管理员自建的协议型 `Socks5` 节点（`nodes` / `third_party_nodes` 中的 Socks5 协议条目仍按原规则导出）。
- 不改动订阅鉴权、subscription protection、Clash rules / rule-providers。
- 不改动管理端 UI 文案（除非实现时发现直接引用了“订阅内含住宅 SOCKS5”的说明）。

# Acceptance examples

1. **管理员 Base64 订阅**  
   - 输入：有效管理员 `user` + `token` 的 `GET .../sub`（无 `format` 或非 clash）。  
   - 输出：响应体为 Base64 解码后的节点链接列表；**不包含**名称或内容可识别为「住宅 SOCKS5」的条目；**不包含** `socks5://...@<proxy_ctrl 服务器>:<住宅端口>` 这类由 `proxy_ctrl_servers` 拼出的链接；**不包含**明文或 Base64 形式的 `PROXY_USER`/`PROXY_PASS` 作为住宅凭据。  
   - 仍可包含该管理员可见的协议节点与已启用第三方节点链接。

2. **管理员 Clash 订阅**  
   - 输入：同上 URL 且 `format=clash`。  
   - 输出：YAML `proxies:` 下**没有** `type: socks5` 且名称含「住宅 SOCKS5」或等价住宅追加条目；proxy-groups 不引用此类名称；YAML 中**没有**住宅共享 `username`/`password` 字段值来自 `PROXY_USER`/`PROXY_PASS` 的住宅段。

3. **普通用户两种订阅**  
   - 输入：有效普通用户 token 的 Base64 / Clash 订阅。  
   - 输出：与现状一致地不含住宅 SOCKS5；改动后仍不含，且行为与管理员侧「不暴露住宅」对齐。

4. **仅存在住宅代理、无协议节点时**  
   - 输入：管理员订阅有效，但无可导出协议/第三方节点，仅 `proxy_ctrl_servers` 有活跃住宅记录。  
   - 输出：Base64 可为合法空/近空 profile（无住宅链接）；Clash 仍为合法 YAML，proxies 不因住宅而新增条目（可为仅 DIRECT 的 group，与现有空节点行为一致）。

5. **协议型 Socks5 节点仍导出**  
   - 输入：存在 `protocol = Socks5` 的启用协议节点（非 `proxy_ctrl_servers` 住宅追加）。  
   - 输出：该节点仍按既有规则出现在 Base64 /（若 Clash 支持该协议则）相应格式中；不被本次改动误删。

# Constraints and invariants

- 订阅响应不得携带住宅代理共享凭据。
- 住宅控制面与订阅导出职责分离：订阅是用户客户端配置；住宅列表接口是运维/Agent 通道。
- 不在 brief、规格、验证报告中写入真实 `PROXY_USER`/`PROXY_PASS` 或 token 值。
- 最小改动：优先删除或短路订阅路径中的住宅追加块，避免无关重构。

# Decisions

- 管理员与普通用户的两种订阅格式一律不导出住宅 SOCKS5（不是“仅对普通用户隐藏”）。
- 协议节点表中的 Socks5 与住宅 `proxy_ctrl_servers` 追加条目区分对待：只去掉后者。
- `/proxy/proxies` 等控制面接口保持可用（本 change 非目标）。

# Open questions

（无）

# Verification expectations

- 静态检查：订阅组装路径不再从 `proxy_ctrl_servers` 向 `subLinks` / `clashProxies` 追加住宅条目。
- 静态检查：`action === "sub"` 分支中不再使用 `env.PROXY_USER` / `env.PROXY_PASS` 生成订阅节点。
- 回归：协议节点与第三方节点导出逻辑保持；住宅控制面路径字符串仍存在且未被误删（若仍被 Agent 使用）。
- 若环境具备可运行的单测或可本地模拟的 handler 测试则运行；否则以有界代码审查 + 字符串/结构断言作为证据，并在 verification 中诚实记录限制。
