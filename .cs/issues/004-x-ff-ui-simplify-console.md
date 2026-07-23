---
kind: issue
title: "ff: 管理端 UI 简洁化（静默仪表）"
type: ff
status: closed
created: 2026-07-23
---

# ff: 管理端 UI 简洁化（静默仪表）

## 做了什么

把管理端从「玻璃拟态 + 多渐变 + 超大圆角 + 重字重」收到扁平运维台：统一 surface、sticky bar、按钮 token；去掉 backdrop-blur/自定义超大圆角/彩色渐变按钮；字重 black→semibold；顶栏文案去 emoji。

## 改了哪些

- `index.html`：设计 token（`--kui-*`）、`.kui-surface` / `.kui-sticky-bar` / `.kui-btn*`；批量替换 noisy utility

## 怎么验证

- 登录后顶栏、Tab、VPS 卡片、系统设置卡片为白底细边框，无毛玻璃/彩虹按钮
- 探针主题页仍走原 probe 主题样式（未拆主题引擎）
- 小屏 Tab 横向滚动仍可用

## 对 `.cs/` 的影响

- 无 Project Spec 行为变更；仅视觉。
