# v0.26.0 Windows 试玩包与发布核验

日期：2026-10-04。按用户请求从已合入 main 的开发提交 `906fe1c5309bf36a705df681199e50082a448ab7` 构建 Windows x64 试玩包。新增 MapDefinition、canonical hash、Validator 和 Registry；地图 API 尚未接入游戏，池塘和玩法保持。P4.2 尚未开始，Watergen 分支没有合并。

Windows / Python 3.11.2 / Godot 4.7.2.stable.official.ed1daf0bf / OpenGL Compatibility / AMD Radeon Graphics。使用 Dummy 音频和隔离测试档案。

- 七个定向源码套件加编辑器导入全部通过：8 条结果、6,885 项汇总检查。覆盖新 map definition/validator/baseline、生态集成、NPC/玩家 ENet 联机和旧规则联机。
- 发行 PCK 十个定向套件通过，共 7,204 项检查；除上述七个套件外，包含 NPC 表现、玩家原生暂停/失焦输入和 NPC Hook 表现。原生窗口使用 `--position -2000,-2000`，隔离桌面鼠标移动对观察光标的影响；完整像素断言保持不变。没有将 headless 当成原生图形验证。
- 官方同版引擎执行冻结 0.25.5 基线与当前源码：8 个模拟场景、每侧 2,100 个 input ticks、86 个检查点完全一致，差异 0；runtime contract、归档和源码稳定性通过。130 个旧运行时文件保持逐字节一致或精确允许的版本标记替换；新增 API 限于 scripts/maps。
- 初次基线驱动在本机 Python 3.11.2 遇到不支持 tar.extractall(filter=...) 的 TypeError，尚未运行比较。改为只提取目标目录内的普通文件/目录，拒绝路径越界、Windows 特殊路径、符号链接和硬链接；修复后 Python 定向回归 9/9 通过，完整等价驱动重跑通过。修复只涉及离线工具及测试，没有改变游戏或原始 Linux 统计。首次产物目录保留，没有覆盖。
- 独立 EXE 从试玩目录启动并退出 0；PIXEL_READY 显示 v0.26.0，无引擎/脚本错误。
- ZIP CRC 及四个文件与本地一致；全部 58 个包内游戏脚本逐字节匹配标签源码；版本一致，主场景加载通过。
- GitHub ZIP 与 SHA256SUMS 两个附件大小、SHA-256 与本地一致，正式发布且为最新；此前 67 个 Release 正文和附件保留。

本次没有重跑全部 Windows current/native 套件、106 帧旧/新像素对照或完整 P3.5 留出平衡矩阵，也没有验证真实声卡、两台物理设备或公网联机。本报告仅补充 Windows 发布证据，原始 Linux 开发报告保留原文。继承的同 tick 打开观察加网起终点异常投影问题仍在原开发报告中记录，未修复；本轮普通逐步输入联机回归通过不能作为该异常的修复证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase04_map_definition` | 808 | 0 |
| `phase04_map_validator` | 1,863 | 0 |
| `phase04_map_baseline` | 3,388 | 0 |
| `phase03_ecology_balance` | 244 | 0 |
| `phase03_npc_native` | 117 | 0 |
| `player_hook_entry_native` | 116 | 0 |
| `phase03_npc_hook_native` | 86 | 0 |
| `phase03_npc_network` | 497 | 0 |
| `player_hook_network` | 76 | 0 |
| `rules_network_v019` | 9 | 0 |

- ZIP：89,618,094 字节；SHA-256 `794302f88c00f16a65aa1cf397b1b9f9d981d3eed3a67b9a1425627c47f15c05`。
- PCK：2,347,432 字节；SHA-256 `59a57acb2eec41c5dbf0bfb4aefbf9c6afcd02f01b3c88929d275411d9ba8f21`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.26.0)。
- 本地证据：`artifacts/release-v0260-source`、`artifacts/release-v0260-pack`、`artifacts/release-v0260-equivalence`（首次受阻）、`artifacts/release-v0260-equivalence-python311`（修复后）、`artifacts/release-publish-v0260`（均为忽略产物）。
- 本地版本保留策略：最新三个版本为 0.25.4、0.25.5、0.26.0；0.25.3 目录及 ZIP 待用户按 AGENTS.md 手动清理。GitHub 历史 Releases、源码标签和报告保留。
