# v0.25.0 Windows 试玩包与发布核验

日期：2026-10-03。按用户请求从 main 提交 `741927505931d1dd21bb99626fc5b1ee8115c882` 构建 Windows x64 试玩包。默认三条环境鱼只游动、转向与软避让，不抢食、不上钩、不影响胜负。既有摄食规则保留。P3.1 人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的 51 个当前套件及编辑器导入全部通过（52 条结果，237,341 项汇总检查/完成标记），来自本次同步阶段验证。
- 发行 PCK 的四个针对性套件全部通过，共 2,720 项检查：环境鱼画面、自动咬食反馈、NPC 状态恢复、NPC 本机 ENet 联机。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.0，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 52 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 61 个发行页正文及附件保持不变。

本次没有运行完整发行包原生门禁，没有验证真实声卡、两台物理电脑或公网联机。生命感、遮挡与性能体验仍需人工试玩。原始 Linux 开发验证与源码阶段报告保持原样；本报告补充 Windows 发布证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase03_npc_native` | 41 | 0 |
| `phase02_bite_native` | 23 | 0 |
| `phase03_npc_snapshot` | 2,451 | 0 |
| `phase03_npc_network` | 205 | 0 |

- ZIP：89,595,725 字节；SHA-256 `ba7b905b96bebff305efbac4f23fadd75b55c0f1482c3c540cb4b30d02ac5974`。
- PCK：2,265,812 字节；SHA-256 `e097b5a71755a35886ba6e33d418be463ae863ab8639e908336556caecec8bd9`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.0)。
- 原始本地日志：`artifacts/sync-v0250-source`、`artifacts/release-v0250-pack`、`artifacts/release-publish-v0250`（忽略产物）。
