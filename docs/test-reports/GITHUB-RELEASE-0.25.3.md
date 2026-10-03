# v0.25.3 Windows 试玩包与发布核验

日期：2026-10-03。按用户请求从已合入 main 的开发提交 `a6e8656163bae6a7a1ec8dabce2c853cb09ccab6` 构建 Windows x64 试玩包。NPC 可真实误咬钩、自动挣扎、逃脱、断线或被拉起。钓错 NPC 不结束比赛，玩家可继续吃饵和回巢；捕获 NPC 暂离生态，8 秒后以新 ID 补充。玩家原流程与既有摄食、抢食、社会行为和补饵规则保持；NPC 本轮不作为抄网目标。P3.4 人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的最终结果覆盖 57 个当前套件及编辑器导入（58 条结果，244,509 项汇总检查/完成标记，含单项复查结果，不是一次全绿的完整批次），来自本次同步阶段验证；首次运行有一个联机结果同步断言失败，在运行源码不变的情况下，两次单独复查均 9/9 通过。原始失败记录保留，不能据此声称已修复或完全排除间歇性时序问题。
- 发行 PCK 的十个针对性套件全部通过，共 7,720 项检查：社会行为画面、自动咬食反馈、NPC 状态恢复、本机 ENet 联机、共享摄食归属、抢食决策、社会行为集成与决策、钩目标生命周期、NPC 中钩原生画面。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.3，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 54 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 64 个发行页正文及附件保持不变。

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

- ZIP：89,609,793 字节；SHA-256 `ce62ba2acf7015b83402e779c303927631648459d2d489784609ff556ffeaa00`。
- PCK：2,315,728 字节；SHA-256 `8268d057fc4ac371b6fee6e64deef96b401aa9bde65b41db1cc00fd7cf8b8ef3`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.3)。
- 原始本地日志：`artifacts/release-v0253-source`、`artifacts/release-v0253-pack`、`artifacts/release-publish-v0253`及两次 `artifacts/release-v0253-network-recheck*`（忽略产物）。
