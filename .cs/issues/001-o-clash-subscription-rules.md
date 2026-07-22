---
kind: issue
title: "Clash 订阅分流规则（文本 + 模板）"
type: feature
status: open
created: 2026-07-22
epic: ""
---

# Clash 订阅分流规则（文本 + 模板）

## 目标

运维者在系统设置中配置全局 Clash `rules`（可套用内置模板并编辑保存）。终端用户或运维者拉取 `format=clash` 订阅时，YAML 中的 `rules` 使用所保存内容；未配置时与今日行为一致（全量 `MATCH,PROXY`）。

## 范围

- 包含：
  - `sys_config` 键 `clash_rules` 持久化规则正文
  - 三套内置模板：全量代理、绕过大陆、仅局域网直连
  - 管理端系统设置：模板按钮 + 多行编辑 + 保存 + 恢复默认
  - `/api/data` 返回当前规则与模板；`/api/settings` POST 保存 `clash_rules`
  - `/api/sub?format=clash` 注入已保存规则
- 不包含：
  - per-user 规则、可视化规则表、rule-providers 托管 UI
  - 修改普通 base64 订阅
  - 服务端完整 YAML/schema 校验

## 归属

- 独立 issue
- 来源 Vision：订阅导出 / 终端用户拿 Clash 订阅 — [../vision/index.md](../vision/index.md)
- 相关 spec：[../spec/index.md](../spec/index.md) 订阅导出
- 来源 talk：[../talks/001-clash-subscription-rules.md](../talks/001-clash-subscription-rules.md)

## 背景与证据

- 当前 clash YAML 硬编码 `rules: - MATCH,PROXY`（`functions/api/[[path]].js` sub 分支）
- 系统设置已有 `site_title` 经 `/api/settings` + `/api/data` 读写模式可扩展

## 现状如何工作

客户端请求 `/api/sub` 且 `format=clash` → 鉴权 token → 汇总节点/第三方/（管理员）住宅 SOCKS → 拼 proxies 与 PROXY/AUTO 组 → **写死 rules** → 返回 YAML。无规则配置存储。

## 影响范围

- 必须修改：`functions/api/[[path]].js`、`index.html`（系统设置区）
- 需要验证：保存规则后 clash 订阅含新 rules；空/恢复默认；模板填入；非 clash 订阅不变；非管理员不可写
- 仍待调查：无

## UI 变化

- 角色与入口：运维者 → 系统设置 → 「Clash 分流规则」卡片
- 图示状态：目标

```text
+------------------------------------------+
| Clash 分流规则                            |
| [全量代理] [绕过大陆] [仅局域网直连]        |
| +--------------------------------------+ |
| | textarea: rules 列表正文             | |
| +--------------------------------------+ |
| [保存规则]  [恢复默认]                    |
| 提示：可引用 PROXY / AUTO / DIRECT / REJECT |
+------------------------------------------+
```

## 质量目标

- **兼容性 · 客户端导入**
  - 目标：默认与三模板在常见 Mihomo/Clash Meta 下可导入；自定义文本运维自测
  - 来源：本次风险扫描 + talk
  - 预期证据：拉订阅检查 YAML 结构；默认与改前一致
- **信息安全性 · 管理面**
  - 目标：仅管理员读写 `clash_rules`；限制正文最大长度（如 32KiB）
  - 来源：project spec 信息安全性
  - 预期证据：非管理员 POST 被拒；超长拒绝
- **可维护性**
  - 目标：模板与默认规则单一常量来源，生成路径只读配置
  - 来源：economy / 结构

## 方案判断

采用「全局可编辑 rules 文本 + 模板填入」：改动面小、灵活，避免可视化编辑器与 Meta 能力不同步。已知上限：运维需懂规则语法；无 per-user。升级触发：多租户规则或远程 rule-providers 需求 → 另开 epic/issue。

## 实现设计

### 这次要怎么做

后端定义默认 rules 与三模板；存 `sys_config.clash_rules`；clash 生成时 normalize 后写入 `rules:`；设置 API 读写；前端设置页编辑。

### 功能怎么分工

- 规则常量与 normalize / 长度校验：API 辅助函数
- 持久化：`sys_config`
- 导出：sub clash 分支
- UI：系统设置卡片

### 请求 / 数据怎么走

管理员保存 → POST `/api/settings` `{ clash_rules }` → D1  
拉数据 → GET `/api/data` 含 `clashRules` + `clashRuleTemplates`  
拉订阅 → GET `/api/sub?...&format=clash` 读 `clash_rules` 拼 YAML

### 哪些边界不碰

- 不改 proxy-groups 结构（仍 PROXY + AUTO）
- 不服务端下载 GeoIP
- 第三方节点/住宅逻辑不变

### 一步步怎么改

1. API：模板常量、`normalizeClashRules`、`MAX_CLASH_RULES_CHARS`
2. sub 分支注入
3. settings POST / data GET
4. 前端设置 UI + 保存/模板/默认

### 怎么确认做对

- 未配置时 clash 仍含 `MATCH,PROXY`
- 保存自定义后订阅 body 含对应行
- 恢复默认清空存储表现
- 普通 sub 仍 base64

## 验证

- [x] 默认 / 恢复默认 — `normalizeClashRules('')` → `MATCH,PROXY`；恢复默认清库语义（与默认相同则 DELETE）
- [x] 三模板存在 — `full-proxy` / `bypass-cn` / `lan-direct`；前端按钮 + API `clashRuleTemplates`
- [x] 自定义规则注入路径 — sub 使用 `clashRulesYamlBlock(await loadClashRules(db))`
- [x] 超长拒绝 — `> 32768` → `normalizeClashRules` 返回 null / settings 400
- [x] 辅助函数单测 — node 本地 PASS（empty、prefix、bare、too long、indent）
- [ ] 浏览器端到端：登录设置页保存 → 拉 `/api/sub?format=clash` 肉眼确认（待部署环境）
- [ ] 非 clash 格式回归（手动）

## 执行记录

- 2026-07-22：实现后端模板/归一化/settings·data·sub 注入；系统设置 UI 卡片与 setup 导出。
- 2026-07-22：检索主流方案后扩展模板为 6 套；支持 `clash_rule_providers` 持久化与 YAML 注入；远程规则集采用 [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)（jsDelivr）。
- 改动文件：`functions/api/[[path]].js`、`index.html`。
- 制度记忆：`.cs/talks/001-clash-subscription-rules.md`、本 issue。
- 未部署、未 commit；E2E 待有 Worker/本地 `wrangler dev` 时补。
- 已知：完整 ACL4SSR/多策略组（AI/流媒体分组）未做——当前仍只有 PROXY/AUTO，模板 rules 均指向这两组 + DIRECT/REJECT。

## 关闭回写

- project spec：订阅导出能力补充可配置 clash rules
- notes：无则跳过
