# 2026-10-02 GitHub 逐版补发记录

本次按用户请求，将 0.21.0–0.24.1 的 14 个 Windows x64 试玩包逐个公开发布，最新下载版本设为 **v0.24.1**。前 13 个保留原始本地 ZIP；收尾时发现远端新增 0.24.1，已同步其精确提交并新构建 Windows 包。运行程序为 Godot 4.7.2；包内 EXE、PCK、引擎许可和试玩说明均核对完整。旧报告中的“尚未公开发行”描述属于报告当时状态，不改写历史结论。

## 本次核验

- 前 13 个版本保留原始 ZIP 字节，0.24.1 使用新构建 ZIP；全部检查成员 CRC，并逐文件核对本地目录；0.22.2 额外保留原分支试玩说明。
- 0.21.0–0.22.5 的 PCK 大小与 SHA-256 与历史记录一致；0.22.5 原包来自另一份本地检出，复制时核对完整内容。
- 每版所有包内游戏脚本与其对应 Git 提交逐字节哈希一致，项目版本一致，实际加载包内主场景且没有引擎/脚本错误。此为无窗口主场景加载，不将它称作原生画面检查。
- 在精确源码提交上建立版本标签；上传 ZIP 和 SHA256SUMS.txt，在 GitHub 返回的附件大小、状态和 SHA-256 全部匹配后发布草稿。
- 旧版 0.20.1 及更早的 42 个 Release、附件和恢复清单保留；远端附件 ID、大小和 SHA-256 与原发布记录一致。本次没有重新验证所有历史玩法断言。

| 版本 | 标签对应提交 | 游戏脚本数 | ZIP 字节 | 公开发行页 |
| --- | --- | ---: | ---: | --- |
| 0.21.0 | `a65ad14` | 38 | 91,284,558 | [v0.21.0](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.21.0) |
| 0.21.1 | `1ab38d0` | 38 | 91,284,000 | [v0.21.1](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.21.1) |
| 0.21.2 | `662b631` | 38 | 91,284,684 | [v0.21.2](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.21.2) |
| 0.22.0 | `da33c39` | 39 | 91,285,512 | [v0.22.0](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.0) |
| 0.22.1 | `db215eb` | 39 | 91,285,587 | [v0.22.1](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.1) |
| 0.22.2 | `cb931f7` | 42 | 91,293,665 | [v0.22.2](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.2) |
| 0.22.3 | `5271433` | 43 | 91,295,570 | [v0.22.3](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.3) |
| 0.22.4 | `b6705d6` | 43 | 91,296,544 | [v0.22.4](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.4) |
| 0.22.5 | `96faf4d` | 43 | 88,098,452 | [v0.22.5](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.5) |
| 0.22.6 | `85299be` | 43 | 89,569,416 | [v0.22.6](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.22.6) |
| 0.23.0 | `ddf7909` | 47 | 89,581,632 | [v0.23.0](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.23.0) |
| 0.23.1 | `19178cc` | 47 | 89,583,029 | [v0.23.1](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.23.1) |
| 0.24.0 | `811a8b8` | 47 | 89,584,445 | [v0.24.0](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.24.0) |
| 0.24.1 | `baf909f` | 47 | 89,584,644 | [v0.24.1](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.24.1) |

完整 PCK/ZIP 哈希、发布时间及远端附件信息见 [JSON 索引](../../history/releases.json)的 `public_releases`；运行与下载入口见[项目首页](../../README.md)。核验日志与发布元数据保存在已忽略的 `artifacts/release-publish-20261002/`，不将游戏二进制提交到源码仓库。

## Windows 试玩与现有检查范围

此前在本地同步时完成的检查与本次归档核验分开记录：

- 0.22.6：26 组当前源码回归、5 组包内画面检查通过，EXE 菜单启动成功。
- 0.23.0：35 组当前源码回归通过；16 组包内画面套件中 15 组通过，旧标题自动点击检查失败，在 0.22.6 包也复现同一失败。未将该项计入通过。
- 0.23.1：8 组针对性源码回归通过；新状态栏、钓组反馈及鱼钩隐藏画面检查通过；收线自动输入检查首次 8/2、单独复测 10/0，两次结果保留。
- 0.24.0：9 组针对性源码回归与 3 组包内画面检查通过，包含真实本机 ENet 咬食输入、回放/边界验证、嘴部动作、冷却提示及隐藏钩真值像素等价。
- 0.24.1：Windows 当前源码 38 套件及编辑器导入全部通过，18,704 项检查/日志完成标记；自动咬食 57/57、真实 ENet 与回放/隐私 132/132。独立包内 `phase02_bite_native`、`phase15_native`、`phase01_native`、`bait_suction_native_v0211`、`bait_suction_native_v0212` 共 5 套件、75 项检查通过；检查咬食冷却截图，确认为自动咬食且没有 F 提示。发行 EXE 独立启动正常，日志版本 0.24.1，无引擎/脚本错误。本次只运行上述 5 套件，未宣称完整 Windows 原生套件通过。

上述原生检查使用 Windows、Godot 4.7.2 / OpenGL Compatibility、Dummy 音频和 --test-profile；未验证真实声卡输出、两台实体电脑或公网联机。0.23/0.24 的手感与玩法验收仍需人工试玩，公开发布本身不关闭这些门禁。

0.24.1 本地日志保存在 `artifacts/release-v0241-source/summary.json`、`artifacts/release-v0241-pack-native/summary.json` 和 `artifacts/release-publish-20261002/exe-v0241.log`。其源码测试报告保留此前 Linux 验证当时“未生成包”的结论；本报告单独补充 Windows 构建、独立包及公开发布证据。
