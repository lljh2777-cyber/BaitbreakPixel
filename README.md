# 吃饵，不上钩 · BaitbreakPixel

一个 2D 像素风格的人鱼对抗游戏：小鱼在水下觅食、缠线和逃脱，钓鱼人在岸边控竿、收放线与抄网。支持单机挑战、自由练习和一人对一鱼的局域网联机。

**当前开发源码版本：0.23.1（本地试玩修正版，非公开发行）** · Windows x64 · Godot 4.7.2

## 下载试玩

### 公开发行包：0.20.1

从 [v0.20.1 发行页](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.20.1)下载 [BaitbreakPixel-0.20.1.zip](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/download/v0.20.1/BaitbreakPixel-0.20.1.zip)，解压后运行 `BaitbreakPixel.exe`。EXE 与同目录 PCK 需要放在一起，玩家无需安装 Godot；发行页的 `Source code` 是源码，不能直接作为游戏运行。

截至 2026-10-02 核验，GitHub 最新公开发行仍为 0.20.1。该包不包含下面的 0.21 / 0.22 开发改动；包内“开始试玩.txt”对应其自身版本。

### Phase 1.5：0.23.1 人工试玩修正

本分支源码为 0.23.1，可按下方“开发运行”直接运行或自行构建；包的实际验证状态见 [Phase 1.5 检查记录](docs/test-reports/PHASE15-VALIDATION.md)。既有 Windows 本地试玩包的记录见 [0.22.5 测试与打包报告](docs/test-reports/TEST-REPORT-0.22.5.md)；该包没有发布到 GitHub Releases，也不随源码仓库下载。当前脚本的默认构建输出为仓库相邻的 `Releases/BaitbreakPixel-0.23.1` 目录及 `BaitbreakPixel-0.23.1.zip`；这是输出约定，不表示这些包已存在。

本轮修复开局部署显示、收放线可见反馈、A/D 默认速度（+25%）和鱼侧 HUD。必须等待用户人工确认，Phase 2 冻结；反馈记录见 [阶段文档](docs/architecture/PHASE-1.5-PLAYTEST-GATE.md)。

0.23.0 新增饱食度、可抵抗的本能偏移、基于可见线索的三档警惕，以及按饵生命周期随机决定的隐藏鱼钩。保持一条玩家鱼和现有主鱼竿，没有加入自动吸食、多鱼或长期记忆。实施与验收范围见 [Phase 0–1 检查记录](docs/architecture/PHASE-0-1.md)。当前版本尚需人工试玩确认控制手感与核心博弈，不能将自动统计当作“已经好玩”的证明。

0.22.6 基于 `96faf4d`，修复首次打开玩法方案页时因方案目录尚不存在而产生的引擎错误；同时维护测试入口、截图产物路径和文档，并排除未引用的调色着色器。检查环境与范围见 [2026-10-02 维护报告](docs/test-reports/TEST-INFRASTRUCTURE-MAINTENANCE-2026-10-02.md)，不能将原始 0.22.5 的 Windows 检查结果当成本次改动的验证。

- 0.21：扩大水域、跟随镜头、完善草木石环境；鱼视角隐藏钩体、吊线及饵料身份，钩饵与散饵整团共用吸动响应
- 0.22.0–0.22.1：轻吸剥外层、猛吸快速拉近，增加拉伸、流线与入口反馈；吸食时默认以当前游动模式的 68% 游速移动
- 0.22.2–0.22.4：水体层次、自然树根巢穴、远中近景视差及木石体积明暗；相连主干、枝干和根系统一透明，连接处不重复混合
- 0.22.5：精简发行包并整理测试与打包工具，玩法、规则及画面与 0.22.4 相同

逐版记录见 [开发历史](docs/history/CHANGELOG.md)，包体校验来源和后续维护约定见 [版本与包索引说明](docs/history/RELEASES.md)。当前源码的完整操作见 [试玩说明](docs/gameplay/PLAY.txt)，双人连接方法见 [联机指南](docs/gameplay/NETWORK.md)。

## 游戏画面

| 钓鱼人：岸边第一人称 | 小鱼：水下侧视 |
| --- | --- |
| ![钓鱼人持竿与抄网](docs/images/angler-view.png) | ![小鱼躲避抄网](docs/images/fish-view.png) |

## 基本操作

| 角色 | 操作 |
| --- | --- |
| 小鱼 | WASD 游动，鼠标朝向；左键吸食，滚轮调吸力，右键持续冲刺；空格进行 QTE 和主动缠线；满足目标后按 E 回巢 |
| 钓鱼人 | A/D 左右移竿，W/S 收放线，Q 下钩或补饵；F 尝试解缠，空格进行 QTE；E 进入水下观察，左键依次选择抄网起点 A、终点 B |
| 通用 | H 查看帮助，Esc 打开菜单，F2 / F3 调整玩法规则，F11 全屏 |

鱼需要权衡食物、体力、张力与逃脱时机；钓鱼人可以拉鱼出水，也能主动抄网。体力、断线时间、QTE 时长等玩法数值可在设置中调整、保存和分享方案。联机由房主提供本局规则。

目前为单池塘 MVP，联机支持一人对一鱼；尚无互联网大厅、多鱼多人或更多地图。

## 开发运行

1. 克隆仓库，用 **Godot 4.7.2** 导入根目录的 `project.godot`。
2. 按 **F5** 运行项目。
3. Windows 打包使用根目录的脚本，指定已安装的 Godot 目录：

```powershell
.\Build-Pixel.ps1 -GodotDirectory 'D:\Tools\Godot_v4.7.2-stable_win64.exe'
```

该目录需要同时包含 `Godot_v4.7.2-stable_win64.exe` 和 `Godot_v4.7.2-stable_win64_console.exe`。默认输出到相邻 `Releases/BaitbreakPixel-0.23.1` 目录及 ZIP；也可用 `-OutputDirectory` 指定位置。

当前测试入口、套件状态和产物目录配置见 [测试运行指南](tests/README.md)。核心抄网逻辑检查示例（替换为本机引擎路径）：

```powershell
& 'D:\Tools\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/net_v021.gd -- --test-profile
```

测试使用独立配置；带原生画面截图的脚本需要图形窗口，不使用 `--headless`。本次检查见 [2026-10-02 维护报告](docs/test-reports/TEST-INFRASTRUCTURE-MAINTENANCE-2026-10-02.md)；此前 Windows 试玩包的验证保留在 [0.22.5 原始报告](docs/test-reports/TEST-REPORT-0.22.5.md)。

## 项目结构与文档

- `scripts/`：游戏模拟、输入、AI、显示与联机。
- `scenes/`、`assets/`：场景和素材；素材制作记录与素材放在一起。
- `tests/`、`tools/`：回归检查与开发工具。
- [`docs/`](docs/README.md)：[架构](docs/architecture/)、[玩法](docs/gameplay/)、[测试报告](docs/test-reports/README.md)、[开发历史](docs/history/CHANGELOG.md)。
- [`history/releases.json`](history/releases.json)：42 个历史恢复包及 0.21 起本地试玩包的分区索引；字段与来源见 [索引说明](docs/history/RELEASES.md)，历史标签的恢复范围见 [历史恢复说明](docs/history/HISTORY-RECOVERY.md)。

`.godot/` 缓存、`artifacts/` 测试产物和游戏发行包不纳入源码仓库。旧版可运行包保存在 [Releases](https://github.com/lljh2777-cyber/BaitbreakPixel/releases)。
