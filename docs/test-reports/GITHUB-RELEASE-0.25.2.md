# v0.25.2 Windows 试玩包与发布核验

日期：2026-10-03。按用户请求从已合入 main 的开发提交 `cfbdd9ea37779791eca55e4318562d4031cb29f4` 构建 Windows x64 试玩包。NPC 新增减速和绕行观察、短暂逃离公开异常、饥饿时争食等可观察行为线索；也会误报与漏报，不显示警惕数值，不能作为验钩答案。原摄食与补饵规则保持，NPC 仍不上钩、不参与胜负。P3.3 人工试玩门仍开放。

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics，测试使用 Dummy 音频及隔离测试档案。

- 同一运行源码的 56 个当前套件及编辑器导入全部通过（57 条结果，242,804 项汇总检查/完成标记），来自本次同步阶段验证。
- 发行 PCK 的八个针对性套件全部通过，共 5,929 项检查：社会行为画面、自动咬食反馈、NPC 状态恢复、本机 ENet 联机、共享摄食归属、抢食决策、社会行为集成和社会行为决策。
- 独立 EXE 从试玩目录启动，退出码 0，菜单就绪日志显示 v0.25.2，无引擎/脚本错误。
- ZIP CRC 与四个本地附件内容核对通过；全部 53 个包内游戏脚本逐字节匹配标签源码；项目版本一致，包内主场景加载通过。
- GitHub 两个附件大小和 SHA-256 与本地一致，正式发行且为最新；此前 63 个发行页正文及附件保持不变。

本次没有运行完整发行包原生门禁，没有重跑完整社会行为诊断或策略比较实验，没有验证真实声卡、两台物理电脑或公网联机。生命感、遮挡与性能体验仍需人工试玩。原始 Linux 开发验证与源码阶段报告保持原样；本报告补充 Windows 发布证据。

| 发行包套件 | 通过 | 失败 |
| --- | ---: | ---: |
| `phase03_npc_native` | 117 | 0 |
| `phase02_bite_native` | 23 | 0 |
| `phase03_npc_snapshot` | 4,000 | 0 |
| `phase03_npc_network` | 325 | 0 |
| `phase03_npc_foraging` | 80 | 0 |
| `phase03_npc_foraging_brain` | 397 | 0 |
| `phase03_npc_social` | 25 | 0 |
| `phase03_npc_social_brain` | 962 | 0 |

- ZIP：89,603,828 字节；SHA-256 `9c36f22e6ba76979380b770fcc0f25e04f02e0ed7993653ddb3ea81cffefda5c`。
- PCK：2,293,652 字节；SHA-256 `adcceacaa05f061b32feffb959ca3e3685748173807d937d30fcd9c178b7ae88`。
- [公开发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.25.2)。
- 原始本地日志：`artifacts/release-v0252-source`、`artifacts/release-v0252-pack`、`artifacts/release-publish-v0252`（忽略产物）。
