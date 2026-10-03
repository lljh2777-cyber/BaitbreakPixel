# WG-3：0.25.1 可选水域试玩

2026-10-03 用户明确回复「可接入试玩」。本轮将 WG-2.1 的蕨叶庭（713284）接入主游戏本地小鱼视角，等待实际试玩反馈；没有自动批准环境鱼 P3.2 或后续玩法。

## 使用

运行 0.25.1 的 `BaitbreakPixel.exe`，在标题或暂停菜单进入「设置」，打开「蕨叶水域 · 本地小鱼视角」，再进入小鱼挑战或自由练习。第一次准备约需一秒，发生在设置页。开关只在本次启动有效，不写入玩家档案或玩法规则。

默认仍使用原水域。关闭开关立即返回原水域；准备失败也完整回退，并在设置页和日志说明。联机时禁用设置项；岸上、抄网观察和联网绘制始终沿用原环境，返回本地小鱼时可以继续使用已准备的图层。

命令行也可显式选择：`BaitbreakPixel.exe -- --water-appearance=fern`。这是应用本地的表现选项，不是预览参数、规则或网络协议字段；仍受同样的角色/联机限制。不要把不同版本的客户端混连，0.25.1 需双方同版。

## 适配边界

集成基线是 `origin/feature/dev @ c1e3946f0b8cf1afa7becf2b238c8297efda5dc8`（0.25.0），已在独立提交 `415dc5050d10829d860cb98e2dd617cd230badc7` 同步到水域分支。只读地图摘要与 WG-2 相同；保留 0.25.0 的三条环境鱼及其现有信息权限。原主游戏检出不被覆盖。

共享适配点：`PondView._draw()` 判定是否允许显示；`Scenery.environment_layer()` 与床面裁剪槽选择供应器；菜单设置/应用启动负责显式准备。`pond_water_appearance.gd` 只接收固定公开 Layout、白名单 profile、常量视觉 seed，以及绘制时的相机和 elapsed 数值。它不接收 world 或网络副本。

原岸缘、实际水流粒子、巢穴提示、交互木石/草、前后鱼线、鱼/饵/网/HUD 调用顺序保留。使用主游戏 elapsed，单机暂停时不动、重开回到初始相位；相机或时间变化不触发生成。全部六层就绪才启用，GPU 图集复用 WG-2.1；新开关关闭时使用原画家及原绘制路径。

YELLOW 接口变更依据为用户本轮明确允许接入；本 Agent 在此工作树承担集成修改，没有要求另一条主线停工。没有修改地图、模拟、摄食、信息白名单或快照 schema；网络文件仅同步游戏 build 为 0.25.1，不增加水域字段。

`export_presets.cfg` 显式包含生成所需的单个 JSON profile；tests/tools 仍排除在发行 PCK 外。游戏版本、菜单、启动日志、网络 build、构建目录和当前玩法说明使用 0.25.1。公开下载链接继续指向既有 0.25.0，不能把本地包误写成已发布 GitHub Release。

## 验证入口

新套件 `watergen_integration` / `watergen_native` 注册到现行 runner。私有 wrapper 复用其注册、超时与失败判定，额外隔离 Windows/Linux 用户目录，记录基线/源码/diff 摘要和命令：

```powershell
& D:\python\python.exe tools/watergen/run_wg3.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode current --import --run-id wg3-current-final
& D:\python\python.exe tools/watergen/run_wg3.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode native --run-id wg3-native-final
& D:\python\python.exe tools/watergen/run_wg3.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode generated --run-id wg3-generated-final
```

`generated` 运行原有 20 个现行原生套件，唯一额外参数是 `--water-appearance=fern`；不替换旧断言或黄金图。`focused` 仅运行两个新套件。`--pack` 让资源来自实际 PCK，测试脚本由外部加载；不兼容包模式的历史包装脚本仍标 BLOCKED。

本轮最终结果和实际包位置见 [WG3_REPORT.md](WG3_REPORT.md)。完成后停在 `WAITING_FOR_PLAYTEST`；请反馈新环境是否影响三类食物、细线、绕行/QTE 和抄网的辨识，以及具体位置/角色/是否仅新版环境出现。
