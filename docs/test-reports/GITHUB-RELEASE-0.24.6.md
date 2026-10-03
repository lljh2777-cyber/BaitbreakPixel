# v0.24.6 Windows 试玩包与发布核验

日期：2026-10-03。从开发分支提交 `282595e98a4184895db217c298d1e2cbf4ecd140` 构建 **BaitbreakPixel-0.24.6.zip**。默认自动咬食距离 10 px，成功摄入冷却 0.80 秒；基础/类型容量 4/6/8 粒及渐变吸力不变，个人设置修订 3 逐项迁移旧默认，保留其他自定义值及之后明确保存的旧值。

本次按用户请求发布 Windows 试玩包。此前[Linux 源码验证](PHASE02-BITE-TUNING-0.24.6.md)及原始日志/源码清单保留原记录，本报告单独补充 Windows 发布证据。本次没有重跑完整策略平衡实验或调参，此前 0.24.4 的比较属于历史证据；Phase 2 最终人工门保持开放，没有推进 Phase 3。

## Windows 验证

环境：Windows、Godot 4.7.2 stable (`ed1daf0bf`)、OpenGL Compatibility / AMD Radeon Graphics；测试使用 Dummy 音频与 `--test-profile`。

- **44 个当前源码套件及编辑器导入通过**，共 25,873 项汇总检查/完成标记，0 失败、超时或阻塞。
- 10 px 边界、0.80 秒重复摄入、冷却期间吸食衔接、个人设置逐项迁移与显式旧值保留通过；旧 guard3 快照按显式规则恢复和确定性回放、隐私及真实本机 ENet 检查通过。
- 外部测试脚本实际加载发行 PCK，**7 个针对性原生套件全部通过**，共 182 项检查；包括 11 px 外不误咬、0.60 秒仍冷却、0.80 秒再次摄入和嘴部动画、三类型/HUD及隐藏钩像素等价。
- 发行 EXE 从独立目录启动，菜单就绪日志显示 `v0.24.6`，无引擎/脚本错误。

| 源码重点套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `bait_suction_v0212` | 41 | 0 |
| `feeding_feel_v022` | 28 | 0 |
| `rules_v020` | 256 | 0 |
| `phase02_bite` | 57 | 0 |
| `phase02_bite_network` | 136 | 0 |
| `phase02_bait_types` | 6,564 | 0 |
| `phase02_food_profiles` | 158 | 0 |
| `phase02_observation` | 59 | 0 |
| `phase02_bait_network` | 94 | 0 |
| `phase02_feeding_balance` | 204 | 0 |
| `phase02_feeding_policies` | 29 | 0 |

| 独立包原生套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase02_bait_native` | 78 | 0 |
| `phase02_bite_native` | 23 | 0 |
| `feeding_feel_native_v022` | 24 | 0 |
| `phase15_native` | 25 | 0 |
| `phase01_native` | 16 | 0 |
| `bait_suction_native_v0211` | 7 | 0 |
| `bait_suction_native_v0212` | 9 | 0 |

本次仅运行上述 7 个原生套件，未声称完整 Windows 原生门禁通过；没有验证真实声卡、两台物理电脑或公网联机。趣味性、手感、策略取舍及最终平衡仍需人工试玩。

## 包与公开附件

- 标签 `v0.24.6` 精确对应 `282595e98a4184895db217c298d1e2cbf4ecd140`，48 个包内游戏脚本 SHA-256 与标签源码逐字节一致，项目版本一致，包内主场景实际加载成功。
- ZIP：89,589,365 字节，SHA-256 `7be3d0bf8576ed7c630bd3fee210e49343b273fa61fc13fda339c16ec71d4ce6`。
- PCK：2,242,628 字节，SHA-256 `47f5b76c706e8e8b2e85d0f4c6e4975ba082f9e8ddcf87c50177b4593da98731`。
- ZIP 全部成员 CRC 正常，与本地 EXE、PCK、引擎许可及当前 0.24.6 试玩说明完全一致。
- [v0.24.6 发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.24.6)与[直接下载 ZIP](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/download/v0.24.6/BaitbreakPixel-0.24.6.zip)已存在，另附 `SHA256SUMS.txt`。GitHub 附件状态、大小和 SHA-256 与本地文件一致，最新公开版本明确设为 v0.24.6。
- 此前 18 个公开试玩版本和 42 个历史 Release 保留；完整元数据见[JSON 索引](../../history/releases.json)，前一版见[0.24.5 发布记录](GITHUB-RELEASE-0.24.5.md)。

本地证据保存在 `artifacts/release-v0246-source/summary.json`、`artifacts/release-v0246-pack-native/summary.json`、`artifacts/release-publish-v0246/0.24.6/pack-verification.log`、`artifacts/release-publish-v0246/exe-v0246.log` 与 `artifacts/release-publish-v0246/0.24.6/published.json`，二进制和运行产物不提交到源码仓库。
