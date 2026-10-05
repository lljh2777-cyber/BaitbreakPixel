# 0.26.5 钓鱼人右键加速移竿

日期：2026-10-05。基于已发布 0.26.4，在 feature/dev 增加按住鼠标右键以 2 倍速度左右移竿。默认 A/D 为 90 px/s，加速为 180 px/s；松开立即恢复，仅按右键不产生移动。自定义 angler_speed 同样按 2 倍计算。

LocalInput 复用现有右键 dash 映射，Commands 严格接收布尔值，权威 AnglerRig 计算移速，鱼线与浮漂仍通过原惯性更新。联机两种角色分配均验证加速和释放，移动限制及边界继续生效。菜单、HUD、说明和版本标识同步至 0.26.5；当前公开 Release 仍为 0.26.4，本轮未构建或发布新包。

Windows / Godot 4.7.2 / Python 3.11.2；真实 OpenGL Compatibility 与 Dummy 音频。测试入口为 tools/run_tests.py；证据保留在下列忽略产物目录。

| 检查 | 通过 | 失败 |
| --- | ---: | ---: |
| `editor-import` | 0 | 0 |
| `architecture_v020` | 60 | 0 |
| `phase04_map_network` | 282 | 0 |
| `phase04_map_snapshot` | 295 | 0 |
| `line_motion_v021` | 29 | 0 |
| `phase15_controls` | 199 | 0 |
| `phase15_native` | 25 | 0 |

- 控制回归包括实际右键事件经 InputMap/LocalInput、A/D 冲突、按下/松开、双向 2 倍速度、空输入、非法数值/字符串加速、边界、提鱼/捕获限制和自定义基础速度；本地及编码解码链路均覆盖。
- ENet 使用本机真实 UDP，分别验证钓鱼人为房主和客户端时的加速、释放和同步位置。没有验证跨电脑或公网延迟。
- 原生画面 25 项通过，人工查看生成的岸边 HUD 截图，右键加速提示正常显示；未代替人工手感试玩。
- 首次把新移动用例串入旧已部署钩饵 fixture，延长模拟后 4 个旧“仍持有部署饵”断言失败（183 通过、4 失败）。改为独立重置场景测试新加速，原部署流程与断言保留；控制最终 199/199。没有修改运行逻辑来规避失败，首次日志保留。
- 源码/地图/线惯性：`artifacts/angler-boost-0265`；最终控制：`artifacts/angler-boost-0265-controls-final`；画面：`artifacts/angler-boost-0265-native`。本轮共 890 项计数检查通过，另编辑器导入通过；不是全仓库历史套件全绿。
