# 0.22.6 开发版：测试、截图与首次规则方案修复

日期：2026-10-02（UTC）。基于 `feature/dev` 的 `96faf4d`（0.22.5）开展维护；本次源码版本为 **0.22.6**。测试环境为 Linux、**Godot 4.6.3**、GL Compatibility / Mesa llvmpipe。原生画面在云桌面的真实 X11 显示中运行，不是 headless 截图。本报告不替代历史 [0.22.5 Windows / Godot 4.7.2 报告](TEST-REPORT-0.22.5.md)，也不代表已生成或发布新的 Windows ZIP / GitHub Release。

## 改动与边界

- 新增 `tools/run_tests.py`、完整 81 入口注册表和[运行说明](../../tests/README.md)，逐进程设定超时、隔离测试配置、保存日志/机器可读结果，严格检查引擎错误与退出状态
- `rules_v019` 保留历史代码，入口明确退出 2 并指向 `rules_v020`。两者原本基本重复；旧版使用已移除的 `net_capture_seconds()` 和旧抄网路线夹具，不能继续当作当前回归
- 扩大检查时还复现了第二个挂起：`net_route_v0102` 调用已移除的 `manual_net_pending_path()`。它验证的是已弃用的任意多拐点拖网；当前路线、捕获和返回动画由 `net_v021`、`net_animation_v0201` 覆盖。该入口同样保留历史体、打印替代测试并退出 2
- 30 个原生截图脚本统一接受 `--capture-output-directory=`，保留默认路径和 5 个旧 `--visual-output=` 别名。目录创建、PNG 写入、退出状态均检查；11 个 `require()` 风格脚本增加粘滞失败计数，避免末尾 `quit(0)` 覆盖截图失败
- `plant_art` 是额外的无窗口图片生成测试：保留默认不写图及 `--preview=`；公共目录参数可以写出预览。31 个渲染/画面回读脚本中，`reel_hand_native_v016` 不写文件，不需要输出目录。因此按图片能力统计的 32 个入口中，31 个写图入口全部具有路径选择，另 1 个仅做像素检查
- `architecture_v020` 增加 schema 12 / 非默认 `net_aim` 的兼容性往返检查；未改变 schema 或删字段
- 原生规则界面检查发现真实首用问题：没有保存过方案时，打开方案面板会对不存在的目录执行 `DirAccess.get_files_at` 并输出引擎错误。修复 `rules_store.preset_names()`，确认可打开的父目录下缺少目标叶目录时返回空列表，不创建目录；路径是文件或访问失败等情况仍暴露错误。加入无副作用的首次空目录回归及文件冲突负向检查
- 未引用的 `hand_palette.gdshader` 只排除导出，保留源文件；本次没有改动玩法参数、网络 schema 或美术表现

## 当前有效验证

无窗口当前门禁：**26 套件，17,653 项通过，0 失败**。其中 `plant_art` 的 16,579 包含运行器请求的额外预览保存检查；直接不请求预览仍是 16,578。

| 套件 | 通过 |
| --- | ---: |
| architecture_v020 | 46 |
| bait_suction_v0212 | 41 |
| effort_v013 | 31 |
| feeding_feel_v022 | 27 |
| feeding_movement_v0221 | 28 |
| fish_orbit_v021 | 160 |
| grass_binding_v021 | 70 |
| line_motion_v021 | 29 |
| net_animation_v0201 | 41 |
| net_network_v020 / net_network_v021 | 13 / 13 |
| net_v021 | 43 |
| network_rules_v012 | 25 |
| obstacle_art | 92 |
| plant_art | 16,579 |
| pond_v021 | 31 |
| reeling_v0122 / rod_load_v017 | 20 / 11 |
| rules_network_v019 / rules_v020 | 9 / 178 |
| tackle_dynamics_v021 | 26 |
| untangle_network_v018 / untangle_v021 | 6 / 43 |
| water_art / wood_fade / wood_junctions | 14 / 57 / 20 |

没有因文件名旧而关闭仍有价值的覆盖：重新运行后，把 effort、net_animation、rules_network、reeling、rod_load 和旧区域 net_network 的有效检查保留在当前门禁。

原生当前门禁：源码和导出 PCK **各 15 套件全部通过、无引擎错误**；各包含 **338 项汇总计数的检查**，加 `visuals` 的 **2 条完成标记**（不是额外 2 项断言），各写出 **134 张 PNG**。

| 原生套件 | 汇总计数 |
| --- | ---: |
| bait_suction_native_v0211 / v0212 | 7 / 9 |
| effort_native_v013 | 23 |
| feeding_feel_native_v022 | 24 |
| hand_joint_native_v0156 | 84 |
| net_native_v020 | 9 |
| obstacle_visuals_native | 16 |
| pond_native_v021 | 9 |
| reel_hand_native_v016 | 97 |
| reeling_native_v0122 | 10 |
| rules_native_v019 | 8 |
| untangle_native_v018 | 6 |
| water_scenery_native / wood_fade_native | 19 / 17 |
| visuals | 2 条完成标记，不与断言合计 |

打包后的外部规则/架构测试另行执行：`rules_v020` **178/0**，`architecture_v020` **46/0**。截图脚本没有增加 `res://tests/` helper 依赖，仍可以用外部绝对 `--script` 对包内源码运行。

基础设施验证：**28 个 Python / Godot 集成测试通过**，包含真实 Godot 解析错误、运行时错误导致 `quit()` 未执行的超时、子进程持有 stdout、Ctrl+C 清理、退役入口退出 2、错误日志不能伪绿、文件冲突仍报错、注册表完整性、截图路径契约。另完成 30/30 截图脚本解析检查、10/10 路径/参数探针、11/11 失败 PNG 的退出码探针（成功控制退出 0）。

## 历史失败没有被抹掉

以下用户报告的旧套件在改动前的 0.22.5 源码复现，数字为通过/失败；断言原样保留，仍能通过运行器显式执行，失败仍使总结果非零。

| 套件 | 结果 | 主要证据 |
| --- | --- | --- |
| untangle_v020 | 42/1 | 旧固定障碍夹具的多圈逆序解绕；当前 expanded-pond 继承版 `untangle_v021` 43/0 |
| shore_v015 | 16/1 | 旧岸边右端点画面约束；不能据此宣称全部岸边断言无效 |
| angler_v010 | 31/20 | 多拐点拖网、取消旧语义及旧设置路径；其余有效断言保留 |
| architecture_v011 | 42/2 | 旧多拐点网络输入及捕网夹具；v020 使用当前两点提交及往返检查 |
| arm_motion_v0159 | 9/1 | 一秒位移阈值，不宣称已有完整替代 |
| bait_suction_v0211 | 20/10 | 旧“不吸动整团”语义与当前整团吸食矛盾；当前 v0212、feeding 套件覆盖新语义 |
| balance_v014 | 26/3 | 旧捕网时长/取消语义，并产生空路线索引错误 |
| dual_role_v09 | 20/9 | 旧投钩、抄网、限时与固定水域 AI 夹具 |
| fish_orbit_v0182 | 66/9 | 扩水域前的边界/目标帧基线；当前 v021 160/0 |

额外历史无窗口诊断：`hand_rig_v0153`～`v0157` 各 9/1，`reference_tackle_v0158` 9/1，`line_motion_v0181` 28/1，`net_v020` 42/1，`network_v012` 33/6，`smoke` 131/52，`tackle_dynamics_v016` 25/1，`untangle_v018` 41/2。它们保留为诊断，不据此更改当前玩法。`net_route_v0102` 首次探查触发 **90 秒超时**；定位删除 API 后才退役，未把超时写成普通失败或通过。

原生历史诊断也按真实非零结果保留：`nets_v06`、`nets_v08`、`balance_native_v014` 为旧暂停/练习菜单入口；`angler_native_v010` 为旧 F3 面板；`controls_v071`、`hauling_v07`、`visuals_v03/v04/v05` 为旧按键/缠绕/F2 夹具；`dual_role_native_v09` 为旧左键投钩；两个 `net_route_native` 为旧按住 E 的多拐点输入；`shore_native_v015` 为旧前景运动和路线约束。部分提前退出而没有完整计数，因此不伪造总断言数。

两个独立 peer 脚本需要双进程配对，本次未执行其完整原生流程；纯 `net_animation_capture_v0201` 截图序列只验证解析/输出配置，未完整渲染。有效的 ENet 双端测试已由当前无窗口网络套件执行。

## 打包与环境限制

Linux 使用 `Windows Pixel` 预设导出独立测试资源包 `BaitbreakPixel-0.22.6.pck`，**54 个条目，2,214,656 字节**；SHA-256：

`1458fc9b283076b6d78a4ef13aa72db0b446a25b9ccae4ecb8af9e295cbd1d7f`

索引确认不包含 `hand_palette.gdshader`、`tests/`、`tools/`、`history/` 和三张不再引用的旧手部贴图。Godot 头版本为 4.6.3，包内开发版为 0.22.6。本次开发导入产生的 UID cache 比早先验证包大，不能把不同引擎/导入缓存下的字节数当成 Windows 发行包体积对比。

- 源码继承 `res://tests/...` 的 `net_v021`、`untangle_v021` 等包装测试在 PCK 模式明确 BLOCKED；包故意不含其测试父类，源码模式有效。这不是完整无窗口门禁全部可打包执行的声明
- 初次原生尝试因云机没有 ALSA 设备报错，运行器正确判红；改为显式 Dummy 音频驱动后重新完整验证。没有过滤错误或把声卡问题算成玩法回归
- Linux `HOME` 不足以隔离 Godot `user://`，运行器使用独立 XDG 路径，避免宿主不可写目录及玩家配置干扰
- Windows Godot 4.7.2、Windows 进程树终止、EXE 和 ZIP 未在本次环境复验；也未发布公开发行版

## 可复现命令与本地证据

```sh
python3 -m unittest discover -s tests/runner -v
python3 tools/run_tests.py --profile current --output-directory artifacts/test-infrastructure-0226-current
python3 tools/run_tests.py --profile native --output-directory artifacts/test-infrastructure-final-native-source
python3 tools/run_tests.py --profile native --pack artifacts/test-infrastructure-package/BaitbreakPixel-0.22.6.pck --output-directory artifacts/test-infrastructure-final-native-pack
python3 tools/run_tests.py --suite rules_v020 --suite architecture_v020 --pack artifacts/test-infrastructure-package/BaitbreakPixel-0.22.6.pck --output-directory artifacts/test-infrastructure-final-pack-rules
```

每个结果目录包含逐项日志和 `summary.json`。开发产物在已忽略的 `artifacts/`，不提交截图、PCK 或机器目录。最终发布/提交记录由维护提交本身确定，不回填或改写历史 0.22.5 的 Windows 测试结论。
