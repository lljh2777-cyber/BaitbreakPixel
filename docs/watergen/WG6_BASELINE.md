# WG-6.0 开发基线

2026-10-04，在 Windows / PowerShell、`feature/watergen` 工作区执行 `git fetch origin`，成功完成。

| 项目 | 实际观测 |
|---|---|
| watergen HEAD | `e333c90c46d03e6a9bf4080d758bb8e264548d8e` |
| origin/feature/dev | `dfdd9af72e3700c4b82fcf32419ff998231d7ef9` |
| merge-base | `dfdd9af72e3700c4b82fcf32419ff998231d7ef9` |
| ahead / behind | 30 / 0 |
| 初始工作区 | clean |
| 正式游戏版本 | 0.25.6 |
| 公共地图 digest | `ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d` |

`git log HEAD..origin/feature/dev` 为空；上次整合已包含最新可见 dev，无需再次合并。先前同步详情见 [0.25.6 整合报告](DEV_SYNC_0.25.6.md)。这里记录的是 fetch 时观测，不保证未来上游不再变化。

WG-5 人工项 [WG-PF-501 / 502](WG5_PLAYTEST_FEEDBACK.md) 均为 `WAITING_FOR_PLAYTEST`。同步主线与本次“继续开发 WG-6”不代替木石、草叶材质的最终视觉确认。

依据用户提供、保存在工作树上一层的 `WG6_UNDERWATER_TERRAIN_ECOLOGY_DEV_SPEC.md` 第 21 节，首轮实施 WG-6.0 + WG-6.1：纯值视觉地势、四构图独立预览、原生样片、契约验证、报告。交付后阶段状态为 `WAITING_FOR_REVIEW`；WG-6.2 需要地势方向确认。

输入规格 SHA-256：`95c4c9a95b2410115798889d8ed3549b5e7f3710742eafbbbec440e800375069`。原文保持不变。

## 隔离边界

新增地势生成和 CPU 烘焙模块置于 `scripts/watergen/`，仅由 `tools/watergen/terrain_preview_cache.gd` 引用。独立场景为 `scenes/watergen/terrain_preview.tscn`。生产 View、Scenery、Layout、World、RNG、NPC、网络、规则、鱼线、抄网、交互目标和游戏入口均保持此基线的文件内容。

预览复用已有六层纹理、动态植被图集、两套 LRU 缓存和 WG-5 RGB 材质函数。它不实例化主游戏或读取玩家存档；每次运行隔离 Godot 用户目录。正式 0.25.6 试玩包及版本不变。

`terrain_profiles.json` 是独立预览的视觉配置，不能作为权威地图。地势描述仅接受白名单数值字段，读取已经验证的公开地图摘要，不向 `interaction_targets()` 写入任何内容。
