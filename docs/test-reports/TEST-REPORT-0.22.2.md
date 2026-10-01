# 0.22.2 版本与试玩包命名验证

日期：2026-10-01（Asia/Shanghai）。分支 `dot/improve-baitbreak-20261001`，基于 `9dbd39f11866505a877c452777fd999bb1f2f88c`。Windows、Godot 4.7.2 / GL Compatibility；运行检查使用隔离的 `--test-profile`。

当前场景改进版升为 **0.22.2**。项目版本、菜单、启动日志、联机 build、默认打包目录及当前试玩文档同步更新。菜单显示“0.22.2 · 水体层次 · 自然巢穴”。玩法与快照 schema 12 保持原状；联机双方使用 0.22.2。

试玩目录统一为 `Releases/BaitbreakPixel-<版本号>`，ZIP 为 `BaitbreakPixel-<版本号>.zip`，后续新版本递增版本号。约定已写入项目 `AGENTS.md`。

## 验证

- 默认运行 `Build-Pixel.ps1` 成功生成 0.22.2 目录与 ZIP。
- 直接启动发行 EXE，自动载入同目录 PCK 与主场景，原生菜单截图已目视确认版本号。启动日志为 `v0.22.2`，截图返回 `error=0`；退出码 0，标准错误输出为空。
- 实际双端 ENet 检查 `net_network_v021.gd`：**13 项通过，0 失败**，覆盖连接、规则同步、输入、抄网提交及结果同步。
- 发行 PCK 内 **42 个脚本**的 SHA-256 均与本次源码一致。ZIP 内五个文件均与发行目录逐字节一致，顶层目录为 `BaitbreakPixel-0.22.2`。

水体、远景、水底和巢穴沿用已验证的场景改进；此前源码 113 项、独立包 38 项验证及原生画面见 [水体层次测试报告](TEST-REPORT-WATER-DEPTH.md)。本次版本与命名修改没有重复运行全部场景检查。

## 本地试玩包

- EXE：`E:/Fish_catches_people/Releases/BaitbreakPixel-0.22.2/BaitbreakPixel.exe`，与 PCK 保持同目录。
- ZIP：`E:/Fish_catches_people/Releases/BaitbreakPixel-0.22.2.zip`，91,293,665 字节。
- PCK：4,030,312 字节；SHA-256 `8598CE2D4C6AF9712ECACB8C53D929F6139505B79E8CC7F7E6765DCF879987D4`。

原长名称目录已更名并重打包为 0.22.2，原长名称 ZIP 保留为历史包。此次更新本地试玩包，未发布 GitHub Releases。
