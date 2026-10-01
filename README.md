# 吃饵，不上钩 · BaitbreakPixel

一个 2D 像素风格的人鱼对抗游戏：小鱼在水下觅食、缠线和逃脱，钓鱼人在岸边控竿、收放线与抄网。支持单机挑战、自由练习和一人对一鱼的局域网联机。

**当前开发与本地试玩版本：0.22.1** · Windows x64 · Godot 4.7.2

## 下载试玩

从 [最新版 Releases](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/latest) 下载已发布的 `BaitbreakPixel-0.20.1.zip`，解压后运行 `BaitbreakPixel.exe`。EXE 和同目录的 PCK 需要放在一起，玩家无需安装 Godot。

本分支的 Windows 试玩包位于本地相邻 `Releases/BaitbreakPixel-0.22.1-water-depth-20261001`；公开发行页仍为 0.20.1。0.21 扩大水域并加入跟随镜头，完善草木石环境，鱼视角隐藏钩体、吊线及饵料身份，钩饵与散饵整团都随吸食向鱼嘴移动。0.22 加入轻吸剥外层、猛吸快速拉近的取舍，以及饵团拉伸、流线、拖尾和入口反馈。0.22.1 让鱼吸食时减速，默认游速为当前游动模式的 68%，松开后恢复。本分支继续完善水体渐变、柔和透光、远景草木与视差，并加入沙泥水底、接地阴影和树根巢穴。

本分支场景更新与 Windows 包验证见 [水体层次测试报告](docs/test-reports/TEST-REPORT-WATER-DEPTH.md)。

完整操作见 [试玩说明](docs/gameplay/PLAY.txt)，双人连接方法见 [联机指南](docs/gameplay/NETWORK.md)。

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

该目录需要同时包含 `Godot_v4.7.2-stable_win64.exe` 和 `Godot_v4.7.2-stable_win64_console.exe`。默认输出到相邻 `Releases/BaitbreakPixel-0.22.1` 目录及 ZIP；也可用 `-OutputDirectory` 指定位置。

核心抄网逻辑检查示例（替换为本机引擎路径）：

```powershell
& 'D:\Tools\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/net_v021.gd -- --test-profile
```

测试使用独立配置。其他检查与运行要求见 [0.22.1 测试报告](docs/test-reports/TEST-REPORT-0.22.1.md)；带原生画面截图的脚本需要图形窗口，不使用 `--headless`。

## 项目结构与文档

- `scripts/`：游戏模拟、输入、AI、显示与联机。
- `scenes/`、`assets/`：场景和素材；素材制作记录与素材放在一起。
- `tests/`、`tools/`：回归检查与开发工具。
- [`docs/`](docs/README.md)：[架构](docs/architecture/)、[玩法](docs/gameplay/)、[测试报告](docs/test-reports/README.md)、[开发历史](docs/history/CHANGELOG.md)。
- [`history/releases.json`](history/releases.json)：历代发行包校验记录；历史标签的恢复范围见 [历史恢复说明](docs/history/HISTORY-RECOVERY.md)。

`.godot/` 缓存、`artifacts/` 测试产物和游戏发行包不纳入源码仓库。旧版可运行包保存在 [Releases](https://github.com/lljh2777-cyber/BaitbreakPixel/releases)。
