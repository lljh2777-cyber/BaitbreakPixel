# v0.24.2 Windows 试玩包与 GitHub 发布核验

日期：2026-10-02。从开发分支精确提交 `196c067fef604b97a9ba8292455c6bc390788732` 构建 **BaitbreakPixel-0.24.2.zip**，提供颗粒团、弯曲细条和块状三种饵料。各类型倍率与食物预算保持原值，自动近距咬食沿用 0.24.1；本次发布不关闭饵型辨识与手感人工试玩门，不推进 P2.3。

## Windows 检查

环境：Windows、Godot 4.7.2 stable (`ed1daf0bf`)、OpenGL Compatibility / AMD Radeon Graphics。测试使用 `--test-profile` 与 Dummy 音频。

- 当前源码 **42 套件及编辑器导入全部通过**，25,577 项汇总检查/完成标记，0 失败、超时或阻塞。
- 新饵型回归覆盖形态/颗粒位置、类型与隐藏钩独立、重新挂饵和旧散饵生命周期、严格快照、鱼端信息裁剪及真实本机 ENet。详细计数见下表。
- 独立 PCK 运行 **6 个针对性原生画面套件**，共 135 项检查通过：新饵型、自动咬食、钓组/状态栏、隐藏钩等价及两类饵团吸动。包内游戏脚本与当前版本一致；没有把源码检查冒充包内检查。
- 发行 EXE 从独立目录启动，菜单就绪日志显示 `v0.24.2`，无引擎/脚本错误。
- Python 测试运行器：首次运行 23 通过、5 跳过；显式配置 Godot 后 4 个引擎集成检查全部复测通过。Windows 不执行的 1 个 POSIX 进程组检查保持跳过。

| 源码针对性套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase02_bite` | 57 | 0 |
| `phase02_bite_network` | 132 | 0 |
| `phase02_bait_types` | 6,564 | 0 |
| `phase02_food_profiles` | 158 | 0 |
| `phase02_observation` | 59 | 0 |
| `phase02_bait_network` | 92 | 0 |

| 独立包内原生套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase02_bait_native` | 60 | 0 |
| `phase02_bite_native` | 18 | 0 |
| `phase15_native` | 25 | 0 |
| `phase01_native` | 16 | 0 |
| `bait_suction_native_v0211` | 7 | 0 |
| `bait_suction_native_v0212` | 9 | 0 |

本次未运行完整 Windows 原生门禁，也未验证真实声卡、两台物理电脑、公网或长时间压力测试；主观外观、入口位置与趣味性仍需要人工试玩。此前 [Linux 源码验证](PHASE02-BAIT-VALIDATION.md)保留原开发阶段“没有打包”的历史结论；本报告单独记录 Windows 构建和公开发布。

## 包与源码

- 源码标签：`v0.24.2`，精确对应 `196c067fef604b97a9ba8292455c6bc390788732`；48 个包内游戏脚本 SHA-256 与标签源码逐字节一致，项目版本一致。
- ZIP：**89,587,715 字节**，SHA-256 `139aaff5bdd00f1ea464884a0852fcc56a849b29067f26dbb867df7359fe8140`。
- PCK：**2,238,836 字节**，SHA-256 `31db2bd0f4c2ba299a9e58f8a6541a370919a57a4c07364d6084c3803797188f`。
- 全部 ZIP 成员 CRC 正常，并与本地 EXE、PCK、引擎许可和试玩说明完全一致；说明含三种饵型人工试玩步骤。
- [v0.24.2 发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.24.2)与[直接下载 ZIP](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/download/v0.24.2/BaitbreakPixel-0.24.2.zip)已存在；附件大小、上传状态与 GitHub SHA-256 均核对一致，另附 `SHA256SUMS.txt`。
- 最新公开版本明确设为 v0.24.2；此前 14 个新版本附件及 42 个历史 Release 均保留。完整记录见 [JSON 索引](../../history/releases.json)；此前批量补发见[原发布记录](GITHUB-RELEASES-2026-10-02.md)。

本地证据：`artifacts/release-v0242-source/summary.json`、`artifacts/release-v0242-pack-native/summary.json`、`artifacts/release-publish-20261002/0.24.2/pack-verification.log`、`artifacts/release-publish-20261002/exe-v0242.log` 和 `artifacts/release-publish-20261002/0.24.2/published.json`。这些产物及发行二进制不提交到源码仓库。
