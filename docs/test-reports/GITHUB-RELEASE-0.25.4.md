# v0.25.4 Windows 试玩包与发布核验

日期：2026-10-03。按用户请求从已合入 main 的开发提交 `ae23fea4a2d53ff4bd3cdb21099fa538c6331e0b` 构建 Windows x64 试玩包。修正 QTE 准备阶段误判、缠线开局顺序和暂停/失焦后的重复输入；联机同批按键正确归属。NPC 向内收线与拉力采用 1.8 倍系数，玩家原控线及既有摄食、抢食、社会行为和补饵参数保留。P3.4 人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的 60 个当前套件及编辑器导入全部通过（61 条结果，244,875 项汇总检查/完成标记），来自本次同步阶段验证。
- 发行 PCK 的十四个针对性套件全部通过，共 8,201 项检查：NPC/社会行为画面、自动咬食反馈、状态恢复、ENet 联机、摄食归属与决策、钩目标生命周期、玩家开局输入及其联机批次、NPC 实际收近和暂停/失焦原生输入。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.4，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 54 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 65 个发行页正文及附件保持不变。

本次没有运行完整发行包原生门禁，没有重跑完整策略诊断或整体平衡实验，没有验证真实声卡、两台物理电脑或公网联机。生命感、遮挡与性能体验仍需人工试玩。原始 Linux 开发验证与源码阶段报告保持原样；本报告补充 Windows 发布证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase03_npc_native` | 117 | 0 |
| `phase02_bite_native` | 23 | 0 |
| `phase03_npc_snapshot` | 5,463 | 0 |
| `phase03_npc_network` | 497 | 0 |
| `phase03_npc_foraging` | 80 | 0 |
| `phase03_npc_foraging_brain` | 397 | 0 |
| `phase03_npc_social` | 25 | 0 |
| `phase03_npc_social_brain` | 963 | 0 |
| `phase03_npc_hook_target` | 69 | 0 |
| `phase03_npc_hook_native` | 86 | 0 |
| `player_hook_entry` | 46 | 0 |
| `player_hook_network` | 76 | 0 |
| `phase03_npc_hook_pacing` | 243 | 0 |
| `player_hook_entry_native` | 116 | 0 |

- ZIP：89,610,942 字节；SHA-256 `5d62fa9a6177391eeb34e129509aab104774c93412eaed5f396fd8ea6423c0a0`。
- PCK：2,317,776 字节；SHA-256 `bb421112d8bca9dd8d4051ffc2f9304d28da886402c68cdc553998d30797044b`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.4)。
- 原始本地日志：`artifacts/release-v0254-source`、`artifacts/release-v0254-pack`、`artifacts/release-publish-v0254`（忽略产物）。
