# v0.26.4 Windows 试玩包与发布核验

日期：2026-10-04。按用户要求发布最新开发版本，从已合入 main 的提交 `f049df519f3cd4505f086272d436d232d08e2179` 构建 Windows x64 试玩包。包含 P4.3 存档/联机 MapRef 及 P4.4–P4.6 画面迁移、依赖清理和最终等价门；当前仍为原 pond_v2，没有新地图菜单、随机地图、Phase 5 或 Watergen 合并。只发布最新 0.26.4，中间源码阶段报告保留。

Windows / Python 3.11.2 / Godot 4.7.2.stable.official.ed1daf0bf / OpenGL Compatibility / AMD Radeon Graphics；Dummy 音频及隔离测试档案。

- 22 个定向源码套件加编辑器导入全部通过：23 条结果，46,861 项汇总检查。包含地图快照/真实 ENet MapRef/状态回放、地图表现和岸边投影、不同地图 fixture、架构及摄食/草/线/网/NPC 快照/Hook/生态回归。清单和命令保留在源码 summary.json。
- 源码新地图原生套件 44/44 通过，验证 fixture 切换、逻辑视口与地图范围区分，以及回到原池塘后的完整像素恢复。
- 固定旧版 7efe59b 的 Git 原源码与当前源码直接状态字节对照通过：8 场景、每侧 2,100 tick、86 个检查点、零差异，源码稳定。未掩码、裁剪或用 payload 哈希代替原始字节。最初启动未准备冻结目录、随后相对基线路径不适用于引擎工作目录，两次均在模拟执行前退出；保留初次目录/日志。使用固定 Git 对象冻结数据和绝对路径后正式运行通过，没有修改运行代码。
- 发行 PCK 的 12 个定向套件通过，共 3,988 项检查，覆盖 MapContext/架构/生态、NPC 和玩家 ENet、原生 Hook/玩家输入、木头淡出、抄网和现行岸上控制。旧 `shore_native_v015` 被注册为 historical，本轮原样得到 14 通过/4 失败，屏内复跑相同；保留初次 summary 与复跑日志，不计入现行套件通过数。另一次冻结基线原生启动因未导入纹理而受阻，在断言前终止，未计作有效对照。依赖发行包排除的 authored fixtures/equivalence 只在源码执行；包运行器首次遇到 source-only 注册项时中止，未执行该项也未算作通过，后续仅续跑未完成的可打包套件，保留此前已通过结果。
- 新 Python snapshot 与 presentation 工具共 39 项运行：38 通过；`test_missing_symlink_and_unexpected_frozen_runtime_fail` 创建符号链接因 Windows WinError 1314 产生 1 个权限错误，日志保留。未放宽或伪装为通过。
- 独立 EXE 启动退出 0，菜单就绪标记 v0.26.4，无引擎/脚本错误。
- ZIP CRC 与四个文件内容匹配本地，包版本和主场景加载通过。本轮 30 个改动运行脚本与标签源码直接比较字节，不做逐脚本 SHA256 扫描；仅对 ZIP/PCK 及公开附件计算必要的包校验值。
- GitHub ZIP 和 SHA256SUMS 大小、校验值与本地一致，正式发布且为最新；此前 69 个 Release 的正文与附件保留。

本次没有重复全部 Windows current/native、完整旧新 RGBA 帧对照或 4,000 场景供给实验，也未重跑 P3.5 策略留出矩阵；原 Linux 证据按原报告保留。未验证真实声卡、第二台物理电脑、公网链路或人工手感。新增同 tick 抄网 float0.0 修复在当前 snapshot/network 门中检验，严格非法 int0 拒绝仍保留；旧报告中的当时缺陷不回写为已修复。

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
| `phase15_controls` | 131 | 0 |

- ZIP：89,629,545 字节；SHA256 `0b91efd09ca16bfdc32661a5d87b1928113da1bb20e6fbf8360384b5c49dfa76`。
- PCK：2,387,560 字节；SHA256 `ae491e319f4a1f8e60689f81d0e58549e8178cfc83cf94e0d25a8e82621f2810`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.26.4)。
- 本地证据：`artifacts/release-v0264-source`、`artifacts/release-v0264-pack`、`artifacts/release-v0264-map-native`、`artifacts/map-native-v0264.log`、`artifacts/release-v0264-old-new-absolute`（正式对照），`artifacts/release-v0264-old-new` / `old-new-frozen`（启动前受阻），`artifacts/python-map-snapshot-v0264.log`、`artifacts/python-map-presentation-v0264.log`、`artifacts/release-publish-v0264`（忽略产物）。
- 本地最新三版应保留 0.26.0、0.26.1、0.26.4；0.25.3、0.25.4、0.25.5 目录与 ZIP 需按 AGENTS.md 由用户手动清理，GitHub 历史发行页与报告保留。
