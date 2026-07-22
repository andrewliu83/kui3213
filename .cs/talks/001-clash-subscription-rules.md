# Clash 订阅分流规则 talk

## 原始想法

用户要给 KUI **增加 Clash 的分流规则功能**。

## 真问题

运维者能在面板配置 Clash/Mihomo 订阅里的 `rules`，用户拉 `format=clash` 后客户端即带分流；当前写死 `MATCH,PROXY`，无配置入口。

## 术语

- **Clash 订阅**：`/api/sub?...&format=clash` 返回的 YAML 配置
- **分流规则 / rules**：YAML 中 `rules:` 列表，决定域名/IP 走 PROXY、DIRECT、REJECT 等
- **模板**：内置可一键填入编辑器的规则草稿，可再改后保存

## 已确认决策

- **v1 形态**：全局 **rules 文本** + **内置 2～3 套模板**（用户选此项）
- **不做（v1）**：可视化规则编辑器、per-user 规则、完整 rule-providers 市场、改普通 base64 订阅

## 约束

- 只影响 `format=clash`；普通订阅不变
- 固定保留生成侧 `PROXY` / `AUTO` 策略组；规则可引用 `DIRECT` / `REJECT` / `PROXY` / `AUTO`
- 空配置回退「全量代理」默认
- 全局一份规则（所有用户同一 Clash 壳）
- 不完整校验 Clash schema；长度上限防滥用

## 影响面、风险与取舍

- 订阅导出主路径、系统设置 UI、`sys_config`
- 坏规则导致客户端导入/运行失败 → 提供恢复默认与模板重填
- GEOIP 模板依赖客户端自带 GeoIP 数据（Mihomo/Clash Meta 通常具备）

## 候选质量目标

- **兼容性**：生成 YAML 仍可被 Mihomo/Clash Meta 导入
- **可维护性**：规则拼装集中在 sub 生成路径；模板有名可辨
- **信息安全性**：仅管理员读写；规则文本不当代码执行；限制体积

## 初步出口草案

- **建议出口**：独立 feature issue（受管理）
- **判断理由**：跨 API + UI + 配置持久化，需验证清单与关闭回写 Project Spec
- **候选事项**：`001-o-clash-subscription-rules` — rules 文本 + 三模板 + 设置读写 + clash 生成注入
- **暂不纳入**：rule-providers 双文本、策略组可视化、每用户规则
