# v0.25.5 Windows 试玩包与发布核验

日期：2026-10-04。按用户请求从已合入 main 的开发提交 `f2a6216acd67a7d7334af0f8eeca254ab5f21e44` 构建 Windows x64 试玩包。新增整体生态集成验证、统计完整性保护和最终试玩清单；玩法参数保留 0.25.4，未重调生态。54 个运行脚本经审计：51 个逐字节不变，另外三个仅版本/菜单/日志标记变化。Phase 3 最终人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的 4 个定向源码套件及编辑器导入全部通过（5 条结果，826 项汇总检查/完成标记），来自本次同步阶段验证。新增生态 Python 测试 101/101 通过；初次发现 Windows 指纹路径使用反斜杠，已改为 as_posix()，保持 Linux 清单格式一致并复跑通过。此修复仅影响离线证据工具，原始 Linux 统计及验证记录未改写。此前 0.25.4 完整 Windows 回归仅作为历史基线，不计入本版检查数。
- 发行 PCK 的七个针对性套件全部通过，共 1,145 项检查：新增生态集成、NPC/玩家 ENet 联机、旧联机规则、NPC 表现、NPC Hook 与玩家暂停/失焦原生输入。
- 首次发行包检查中，两个原生画面套件因观察视角的实时鼠标光标移动出现 5 个像素一致性断言失败（NPC 表现 2 个、NPC Hook 3 个）。保持测试和完整像素断言不变，通过 Godot `--position -2000,-2000` 将原生窗口移出桌面鼠标交互区域复查，两套件分别 117/117、86/86 通过。初次日志、截图和汇总保留在 `artifacts/release-v0255-pack`；复查命令、日志、截图在 `artifacts/release-publish-v0255/native-recheck`，合并结果在 `pack-final.json`。下表统计最终结果，未覆盖初次失败记录。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.5，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 54 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 66 个发行页正文及附件保持不变。

本次没有重复运行完整 Windows 源码或完整发行包原生门禁，没有重跑完整策略诊断或整体平衡实验，没有验证真实声卡、两台物理电脑或公网联机。生命感、遮挡与性能体验仍需人工试玩。原始 Linux 开发验证与源码阶段报告保持原样；本报告补充 Windows 发布证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase03_ecology_balance` | 244 | 0 |
| `phase03_npc_native` | 117 | 0 |
| `player_hook_entry_native` | 116 | 0 |
| `phase03_npc_hook_native` | 86 | 0 |
| `phase03_npc_network` | 497 | 0 |
| `player_hook_network` | 76 | 0 |
| `rules_network_v019` | 9 | 0 |

- ZIP：89,610,467 字节；SHA-256 `436791403f21ee19270b99f624b3325c2df78152b9524c8170085795a8a0eb31`。
- PCK：2,317,776 字节；SHA-256 `0a8d5b497642b3019f810f2fdde81bff1bbfd41c9b22cd81c21fdb33fdf9ce29`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.5)。
- 原始本地日志：`artifacts/release-v0255-source`、`artifacts/release-v0255-pack`、`artifacts/release-publish-v0255`（忽略产物）。
