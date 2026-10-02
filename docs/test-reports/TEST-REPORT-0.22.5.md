# 0.22.5 测试与打包整理验证

日期：2026-10-02（Asia/Shanghai）。分支 `feature/dev`，基于 `b6705d6`。Windows、Godot 4.7.2 / GL Compatibility；运行检查使用隔离的 `--test-profile`，带原生画面的检查不使用 `--headless`。

## 本版内容

本版没有玩家可见的玩法或画面改动，只整理打包体积与测试、打包工具。

| 提交 | 内容 |
| --- | --- |
| `0670da2` | 测试与截图工具的产物路径由固定的 `E:/Fish_catches_people/...` 改为 `res://artifacts`，并在入口创建目录（`save_png` 不会自动建目录）。此前在 `-ds` 工作副本里跑原生测试会把截图写进另一份检出。 |
| `16e33ed` | 导出排除三张不再被任何脚本或场景引用的手部素材（`angler_hand*.png`），素材本身仍保留在仓库中作为制作记录。 |
| `24680b2` | 删除 14 个全仓库零引用的模拟常量，其中 `MANUAL_NET_WARNING` 还与生效值矛盾（0.55 对 `net_manual_warning` 0.5）。玩家可见数值一律经 `rule(id)` 取自规则目录。 |
| `6fa9e4c` | 29 个原生测试与 10 个截图工具在 `DisplayServer` 报 headless 时以退出码 2 快速失败并给出提示，不再无限等待永远不来的帧。 |
| `a687a79` | `grass_binding_v021.gd` 的输出标签由 `GRASS_BINDING_V0183` 改正为自己的名字。 |
| `6d92ea0` | 修正 v0.18 缠草套件的两处过期目标索引；该套件此前因 `Grass.profile()` 返回空字典而抛错、`run()` 提前中止、`quit()` 不再执行，进程会一直挂着。 |
| `26ea589` | 删除已被 0.21 套件取代的 `tests/grass_binding_v0183.gd`，原因记入 [测试报告索引](README.md)。 |
| 本版 | 导出排除 `history/*`（历代校验记录，运行时不读取）；项目版本、菜单、日志、联机 build、默认打包目录与当前试玩文档同步为 **0.22.5**。 |

## 验证

源码检查（Windows、Godot 4.7.2，`--headless`）共 **17,438 项通过，0 失败**：`wood_fade` 57、`wood_junctions` 20、`pond_v021` 31、`architecture_v020` 44、`rules_v020` 177、实际双端 ENet `net_network_v021` 13、`grass_binding_v021` 70、`bait_suction_v0212` 41、`feeding_feel_v022` 27、`feeding_movement_v0221` 28、`fish_orbit_v021` 160、`line_motion_v021` 29、`tackle_dynamics_v021` 26、`plant_art` 16,578、`water_art` 14、`obstacle_art` 92、`network_rules_v012` 25、`untangle_network_v018` 6。

原生画面检查（不使用 `--headless`）：`wood_fade_native` 17、`obstacle_visuals_native` 16、`pond_native_v021` 9、`water_scenery_native` 19，共 **61 项通过，0 失败**。

发行目录加载包内源码和素材、测试脚本从外部载入：同一组四项原生检查仍为 **61 项通过，0 失败**（`wood_fade_native` 17、`obstacle_visuals_native` 16、`pond_native_v021` 9、`water_scenery_native` 19），并写出 48 张截图；直接启动 EXE 自动加载主场景与菜单，输出 `PIXEL_READY | asymmetric-2d | 640x360 | v0.22.5 | expanded-pond-unified-suction`，退出码 0。包内 `project.binary` 的版本串为 0.22.5。

打包检查必须带 `--test-profile`：`obstacle_visuals_native` 会在缺失时直接拒跑，`pond_native_v021` 的远岸抄网画面检查在不隔离时会读到玩家 `user://pixel.cfg` 中的非默认设置而失败。两者都不是本版引入的问题。

PCK 索引共 55 项，其中 3 张贴图、43 个 `.gd` 与包内 `history/` 均与源码一致；`history/releases.json` 与三张未引用素材不再入包。

## 已知的旧版套件

以下失败在改动前的 `b6705d6` 检出上逐字相同，属旧版断言，不影响本版：`untangle_v020` 42/1、`shore_v015` 16/1、`angler_v010` 31/20、`architecture_v011` 42/2、`arm_motion_v0159` 9/1、`bait_suction_v0211` 20/10、`balance_v014` 26/3、`dual_role_v09` 20/9、`fish_orbit_v0182` 66/9。另有 `rules_v019` 调用 0.20 已退役的 `net_capture_seconds()`，报错后进程不再退出（与已删除的 v0183 同一机制），尚未处理。

联机补饵红闪会暴露无钩饵的记录见 [水域与镜头架构](../architecture/POND-ARCHITECTURE.md)。

## 本地试玩包

- EXE：`E:/Fish_catches_people-ds/Releases/BaitbreakPixel-0.22.5/BaitbreakPixel.exe`，与 PCK 保持同目录。
- PCK：2,181,080 字节；SHA-256 `65C98D1367E90C0AF4C211661621A0B4D98B6EA97D645BC64EE1683886F94730`。对照 0.22.4 的 4,039,884 字节减少 46.0%，条目由 62 减至 55。
- ZIP：`E:/Fish_catches_people-ds/Releases/BaitbreakPixel-0.22.5.zip`，88,098,452 字节。
- 随包 `GODOT-NOTICES.txt` 111,024 字节、`开始试玩.txt` 6,717 字节（由本版 `PLAY.txt` 生成）。

未发布 GitHub Releases，公开发行页仍为 0.20.1。

## 环境备注（与项目无关）

从 `E:/Fish_catches_people-ds/...` 目录启动本包时，引擎写 `user://logs` 的日志轮转与原生截图的 `save_png` 都会失败（`Can't save PNG`），且 CPU 占用低；把**同一份包**放到该目录之外运行则写出 7 张截图、无任何错误。把 0.22.4 的既有包放进该目录也会复现同样的日志错误，故这是工作区目录的环境特性，不影响包内源码与素材的验证结论。此外，测试脚本中的运行时错误会中止当前函数，使 `quit()` 不再执行，进程由此常驻；排查时不要把它当作死循环。
