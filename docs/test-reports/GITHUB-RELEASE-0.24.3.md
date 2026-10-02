# v0.24.3 Windows 试玩包与发布核验

日期：2026-10-02。从开发分支提交 `2564d97e93d12860912ef418963460e214202017` 构建 **BaitbreakPixel-0.24.3.zip**。三种饵型现在影响吸动/剥离、碎散、自动咬食容量和饱食恢复；每粒计分不变，咬食距离与冷却仍为 18 px / 0.40 秒。

本次按用户请求发布 Windows 试玩包。既有策略比较仍发现远处吸食占优，平衡目标尚未通过；原始 300 局留出实验、负面结果和局限均保留。本次没有重跑该实验或调参，没有关闭 Phase 2 最终人工门，也未推进 Phase 3。此前[Linux 源码验证](PHASE02-FEEDING-VALIDATION.md)保留其原交付阶段“未打包”的结论，本报告单独补充 Windows 发布证据。

## Windows 验证

环境：Windows、Godot 4.7.2 stable (`ed1daf0bf`)、OpenGL Compatibility / AMD Radeon Graphics；测试使用 Dummy 音频与 `--test-profile`。

- **44 个当前源码套件及编辑器导入通过**，共 25,651 项汇总检查/完成标记，0 失败、超时或阻塞。
- 新增摄食差异、私有统计和观测驱动策略回归通过；类型/钩独立、回放和真实本机 ENet 检查通过。
- 外部测试脚本实际加载发行 PCK，**6 个针对性原生套件全部通过**，共 153 项检查；包括三类型 4/6/8 粒摄入、饱食/HUD、隐藏钩像素等价、自动咬食及饵团吸动。
- 发行 EXE 从独立目录启动，菜单就绪日志显示 `v0.24.3`，无引擎/脚本错误。
- 新增基准分析 Python 测试 **11/11 通过**，包含负面结果保留、配对完整性和弱均值支配识别。

| 源码 Phase 2 套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase02_bite` | 57 | 0 |
| `phase02_bite_network` | 132 | 0 |
| `phase02_bait_types` | 6,564 | 0 |
| `phase02_food_profiles` | 158 | 0 |
| `phase02_observation` | 59 | 0 |
| `phase02_bait_network` | 93 | 0 |
| `phase02_feeding_balance` | 44 | 0 |
| `phase02_feeding_policies` | 29 | 0 |

| 独立包原生套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase02_bait_native` | 78 | 0 |
| `phase02_bite_native` | 18 | 0 |
| `phase15_native` | 25 | 0 |
| `phase01_native` | 16 | 0 |
| `bait_suction_native_v0211` | 7 | 0 |
| `bait_suction_native_v0212` | 9 | 0 |

本次仅运行上述 6 个原生套件，未声称完整 Windows 原生门禁通过；没有验证真实声卡、两台物理电脑或公网联机。趣味性、手感、策略取舍及最终平衡仍需人工试玩。

## 包与公开附件

- 标签 `v0.24.3` 精确对应 `2564d97e93d12860912ef418963460e214202017`，48 个包内游戏脚本 SHA-256 与标签源码逐字节一致，项目版本一致，包内主场景实际加载成功。
- ZIP：89,588,435 字节，SHA-256 `d1b502836346f01ea75734fb0f1a18df3363f4ede733a6263b5db566cbf00bf2`。
- PCK：2,241,524 字节，SHA-256 `dd076ea695b50b29f43890bd6763efda471fb74c2849ad0864be40d385d35a97`。
- ZIP 全部成员 CRC 正常，与本地 EXE、PCK、引擎许可及试玩说明完全一致。
- [v0.24.3 发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.24.3)与[直接下载 ZIP](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/download/v0.24.3/BaitbreakPixel-0.24.3.zip)已存在，另附 `SHA256SUMS.txt`。GitHub 附件状态、大小和 SHA-256 与本地文件一致，最新公开版本明确设为 v0.24.3。
- 此前 15 个公开试玩版本和 42 个历史 Release 保留；完整元数据见[JSON 索引](../../history/releases.json)，前一版见[0.24.2 发布记录](GITHUB-RELEASE-0.24.2.md)。

本地证据保存在 `artifacts/release-v0243-source/summary.json`、`artifacts/release-v0243-pack-native/summary.json`、`artifacts/release-publish-20261002/0.24.3/pack-verification.log`、`artifacts/release-publish-20261002/exe-v0243.log` 与 `artifacts/release-publish-20261002/0.24.3/published.json`，二进制和运行产物不提交到源码仓库。
