# v0.25.1 Windows 试玩包与发布核验

日期：2026-10-03。按用户请求从已合入 main 的开发提交 `8b2cf81d4d1c4962ead35f406cf095442fd430aa` 构建 Windows x64 试玩包。默认三条 NPC 会寻找、靠近、吸食和自动咬食，真实消耗食物，只增加自身饱食；仍不上钩、不影响胜负。玩家与 NPC 共用摄食物理，既有规则保留。抢食压力明显增加，尚未认定平衡合适。P3.2 人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的 54 个当前套件及编辑器导入全部通过（55 条结果，240,658 项汇总检查/完成标记），来自本次同步阶段验证。
- 发行 PCK 的六个针对性套件全部通过，共 3,716 项检查：NPC 抢食画面、自动咬食反馈、NPC 状态恢复、本机 ENet 联机、共享摄食归属和独立抢食决策。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.1，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 53 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 62 个发行页正文及附件保持不变。

本次没有运行完整发行包原生门禁，没有重跑完整策略比较实验，没有验证真实声卡、两台物理电脑或公网联机。生命感、遮挡与性能体验仍需人工试玩。原始 Linux 开发验证与源码阶段报告保持原样；本报告补充 Windows 发布证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase03_npc_native` | 48 | 0 |
| `phase02_bite_native` | 23 | 0 |
| `phase03_npc_snapshot` | 2,911 | 0 |
| `phase03_npc_network` | 257 | 0 |
| `phase03_npc_foraging` | 80 | 0 |
| `phase03_npc_foraging_brain` | 397 | 0 |

- ZIP：89,599,722 字节；SHA-256 `68402a2e122254394fe2369de38abefee82bfbcd20e95e1bf3c0553182032cd9`。
- PCK：2,279,860 字节；SHA-256 `c77297e4bca742a397dee40ae98c0e797f6de62d23d094254d384a3ba456122d`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.1)。
- 原始本地日志：`artifacts/release-v0251-source`、`artifacts/release-v0251-pack`、`artifacts/release-publish-v0251`（忽略产物）。
