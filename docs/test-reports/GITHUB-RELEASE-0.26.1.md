# v0.26.1 Windows 试玩包与发布核验

日期：2026-10-04。按用户请求从已合入 main 的开发提交 `92b90107fbe3d920b2f971d06c55775f2d98d431` 构建 Windows x64 试玩包。Authority 迁移到每局固定的 MapContext，池塘和玩法保持；schema15、网络结构和画面尚未迁移，P4.3 未开始。Watergen 分支没有合并。

Windows / Python 3.11.2 / Godot 4.7.2.stable.official.ed1daf0bf / OpenGL Compatibility / AMD Radeon Graphics；Dummy 音频和隔离测试档案。

- 完整 current headless 源码回归 66 套件及编辑器导入全部通过：67 条结果、254,835 项汇总检查。包括 MapContext 2,626 项、不同尺寸 Authority fixture 1,017 项和架构 60 项；不混入 historical/manual/retired 套件。
- 发行 PCK 的 11 个定向套件通过，共 3,857 项检查：MapContext、架构、生态集成、NPC/玩家/旧规则 ENet 联机、NPC 与玩家原生表现、木头淡出及抄网。phase04_map_authority 使用发行包刻意排除的测试 fixture，只在源码执行；不作为包内已通过项。
- 首次完整源码批次的 phase03_food_reachability 在本机达到默认 360 秒上限，状态为 timeout；其余套件结果及初次日志保留。以 900 秒时限独立重跑原套件，保留 1,000 种子 × 四配置共 4,000 场景、原断言与输出范围；最终通过。汇总统计取独立复查结果，未覆盖首次超时记录。复查证据在 `artifacts/release-v0261-food-recheck`，最终合并在 `artifacts/release-publish-v0261/source-final.json`。
- 原生窗口使用 `--position -2000,-2000` 隔离桌面鼠标移动；完整像素断言不变。没有将 headless 当成图形验证。
- Python 对照工具测试运行 20 项：19 项通过，`test_frozen_source_edit_extra_and_symlink_rejected` 因 Windows 创建符号链接权限不足（WinError 1314）产生 1 个错误；初次日志保留在 `artifacts/python-authority-v0261.log`。未将此项改写为通过，也未放宽测试。该项属于离线归档保护，不是游戏测试失败，Linux 原开发报告仍保留其独立结果。
- 独立 EXE 从试玩目录启动、退出 0，PIXEL_READY 显示 v0.26.1，无引擎/脚本错误。
- ZIP CRC、四个文件与本地内容一致，项目版本和包内主场景加载通过。只对本轮改动的 13 个关键运行脚本进行直接字节比较，匹配标签源码；没有重复全仓库/逐脚本 SHA256 扫描。SHA256 仅用于发行 ZIP、PCK 及 GitHub 附件的必要完整性校验。
- GitHub ZIP 与 SHA256SUMS 两个附件大小和校验值与本地一致，正式发布且为最新；此前 68 个 Release 正文和附件保持不变。

本次没有重跑独立旧新完整模拟驱动、106 对帧 RGBA 对照、全部 native 套件或完整 P3.5 平衡矩阵；原 Linux 证据保留原文。本轮没有验证真实声卡、两台物理设备、公网联机或人工手感。继承的同 tick 打开观察加网起终点异常投影仍未修复；普通分步联机测试通过不能作为该边界问题的修复证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase04_map_context` | 2,626 | 0 |
| `architecture_v020` | 60 | 0 |
| `phase03_ecology_balance` | 244 | 0 |
| `phase03_npc_native` | 117 | 0 |
| `player_hook_entry_native` | 116 | 0 |
| `phase03_npc_hook_native` | 86 | 0 |
| `wood_fade_native` | 17 | 0 |
| `net_native_v020` | 9 | 0 |
| `phase03_npc_network` | 497 | 0 |
| `player_hook_network` | 76 | 0 |
| `rules_network_v019` | 9 | 0 |

- ZIP：89,624,523 字节；SHA256 `3138bd78065d3aa6b8727d4c025192c5b060f3849d3d2653819ec8a9a9217734`。
- PCK：2,364,480 字节；SHA256 `82c62b0ebd6efccd12038a36cc585d762d4b37c385c5bf3ec43e731b00280c31`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.26.1)。
- 本地日志与截图：`artifacts/release-v0261-source`、`artifacts/release-v0261-pack`、`artifacts/release-publish-v0261`（忽略产物）。
- 本地最新三个版本：0.25.5、0.26.0、0.26.1；0.25.3 与 0.25.4 的目录/ZIP 待用户按 AGENTS.md 手动清理，GitHub 历史 Releases 和报告保留。
