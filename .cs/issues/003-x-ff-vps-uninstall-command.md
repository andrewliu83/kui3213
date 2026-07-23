---
kind: issue
title: "feat: VPS 卸载命令行与面板复制"
type: ff
status: closed
created: 2026-07-23
---

# feat: VPS 卸载命令行与面板复制

## 做了什么

为 Full Deploy 同脚本增加 `--uninstall`，并按 thermo-nuclear review 收敛：

- 安装备份 / 回滚 / 卸载 / **安装前清理** 共用 `KUI_SERVICES` + managed paths
- 面板单一 `installerShell` + `vpsCliCommands` 数据驱动
- 「彻底移除」静默复制卸载命令并展示于确认框

## 改了哪些

- `vps/kui.sh`：共享清单与 stop/disable/remove；`[1/7]` 复用；`--uninstall` / `--help`
- `index.html`：`installerShell` / `vpsCliCommands`；卸载命令行；`deleteVps` 静默复制

## 怎么验证

- `sh -n vps/kui.sh`；`--help`；dry `--uninstall`（none init 有降调提示）
- UI：`installerShell` 一处 `apk`/`apt`；token 空提示仅一处
- 真机：root 卸载后无托管路径；reinstall 前也会清 proxy-lite

## 对 `.cs/` 的影响

- 无强制 Project Spec 变更；需要时再补「接入 VPS」卸载一句。
