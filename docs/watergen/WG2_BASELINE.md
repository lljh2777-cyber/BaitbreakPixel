# WG-2 基线

用户于 2026-10-03 指示继续，并明确选择「沿用 713284」。WG-2 沿用 WG-1 青绿色调及该种子的对象布局；四种子验证仍保留。授权限于独立动态预览，完成后等待「可接入试玩」，不进入 WG-3。

WG-1 交付提交为 `4c1fb0fb949862eb519b51dd46cb12e4e632e2f8`。本轮先同步 `origin/feature/dev` 至 `4e8a7b9011b65e53e1971cf3ddcba38880fbd6c8`（0.24.6 发布文档）。相对上轮 `282595e98a4184895db217c298d1e2cbf4ecd140`，只有 9 份说明/发布索引变化；地图、绘制入口、authority、协议、食物、注册表没有源码差异。

环境：Windows，Python `D:\python\python.exe`，Godot 4.7.2 stable `ed1daf0bf001b61586d9930840f2f1394092c079`，GL Compatibility。开始时工作分支干净，无遗留 Godot 进程。测试期间冻结源码与 profile。主游戏原检出不参与修改。

可修改：`scripts/watergen/`、`data/watergen/`、`tools/watergen/`、`scenes/watergen/`、`tests/watergen/`、`docs/watergen/`。保留 WG-1 算法/profile 与旧样片；WG-2 使用单独 `wg-2.0` 版本。公开地图摘要仍需实测核对。测试计划：输入/留边/根部锚定/确定性、原生四种子五镜头、固定时间复采、至少 60 秒运行、20 次切种子及资源记录、WG-0/1 回归。人工可读性与主游戏兼容性不得用自动测试替代。
