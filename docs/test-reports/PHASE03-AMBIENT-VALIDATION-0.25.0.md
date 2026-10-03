# 0.25.0 · P3.0 + P3.1 环境鱼验证

2026-10-03，`feature/dev`，基线 `4e8a7b9011b65e53e1971cf3ddcba38880fbd6c8`。用户已确认 0.24.6 手感合适并允许进入 Phase 3。本轮依据新规格 §52/55，只交付多鱼基础与三条环境鱼，完成后停止等待人工试玩。

本次仅提交推送源码；不生成 ZIP、PCK 或 GitHub Release，不提供新下载包。最近公开 Windows 包仍为 0.24.6，发布文档与历史记录保持原样。

## 交付范围

- 玩家 scalar authority、主鱼竿、自动咬食 10 px / 0.80 s、4/6/8 容量与渐变吸力保持。`game_rules.gd`、`food_profile.gd`、地图和规则档案迁移没有修改
- 新增独立 NPC 状态、稳定 ID/递增分配器、每鱼确定性独立 RNG、合法生成区域、持续游动、平滑转向、预测边界回避和单向软避让。默认 3 条，开发参数 0–6，不向普通设置暴露
- `FishObservation.build_for()` 泛化，玩家兼容入口保持原字段、数值、顺序和隐藏信息边界。NPC Brain 只能读感知与公开环境，输出 Intent，由主模拟积分；没有 world/Hook 真值入口
- schema15 完整保存 NPC Authority/RNG/计时，保留 FoodProfile guard3，明确拒绝旧 schema14。`hook_target_fish_id=-1` 只预留，玩家既有 HookState 不变
- 鱼/钓鱼人客户端均只收到 6 个 NPC 公开字段，按稳定 ID 插值，不发 NPC 内部目标、随机状态、警惕或风险权重。钓鱼人原有非 NPC Authority/RNG 数据边界不在本轮重新设计
- 三种较小低饱和度外观，只改变轮廓/图案。先于玩家绘制；岸边与观察继续使用既有模糊鱼影、深度/可见性和 3 px 观察位置网格，没有 NPC 名称或状态条

没有实现 NPC 抢食、危险警惕、社会线索、NPC Hook/抄网、自动重生或多竿。NPC 不吃食物、不增加玩家分数、不影响比赛结果。架构细节见 [PHASE03-AMBIENT-FISH](../architecture/PHASE03-AMBIENT-FISH.md)。

## 最终自动门禁

使用 Godot 4.7.2 official `ed1daf0bf`，Linux，独立 XDG 测试档案、Dummy 音频。正式入口 `tools/run_tests.py`，没有直接遍历所有历史测试来宣称全仓通过。

- 当前无窗口门禁：**51/51 套件，237,341 项汇总断言，0 失败**，另有成功的编辑器导入；用时 316.759 s。[完整汇总](data/phase03-ambient-0250/headless-summary.json)
- 当前原生门禁：**20/20 套件，521 项汇总断言 + 2 个 visual 日志标记，0 失败**，另有成功的编辑器导入。[原生汇总](data/phase03-ambient-0250/native-summary.json)
- Python 测试运行器 **28/28**、摄食分析工具 **11/11**。[运行器](data/phase03-ambient-0250/python-runner.txt) · [分析工具](data/phase03-ambient-0250/python-analysis.txt)
- 全部原 Phase 1、Phase 1.5、Phase 2 当前套件继续通过，包括真实 ENet、咬食/吸食、类型物理、饱食/警惕、Hook/QTE、缠线、抄网与规则迁移。历史诊断套件保持原状态，不纳入“通过”计数

新增套件结果：

| 套件 | 通过 | 重点 |
|---|---:|---|
| [entities](data/phase03-ambient-0250/phase03_npc_entities.txt) | 7,274 | 128 seeds×两模式×6 鱼，合法生成、唯一 ID、移除后新 ID、重排一致 |
| [rng](data/phase03-ambient-0250/phase03_npc_rng.txt) | 6,501 | 0/3/6 下全部非 NPC 权威值一致，真实 Hook/QTE/refill/双角色指令轨迹，隐藏真值等价 |
| [observation](data/phase03-ambient-0250/phase03_npc_observation.txt) | 209 | 冻结旧玩家构造器的字段/值/顺序/字节等价，多观察者距离与隐私 |
| [snapshot](data/phase03-ambient-0250/phase03_npc_snapshot.txt) | 2,451 | ID/RNG/计时重放、所有嵌套字段非法值原子拒绝、schema14 拒绝 |
| [ambient](data/phase03-ambient-0250/phase03_npc_ambient.txt) | 194,441 | 3×180 模拟秒、合法水域、逐 tick 积分/约7.5Hz决策、暂停终局、无摄食或胜负影响 |
| [network](data/phase03-ambient-0250/phase03_npc_network.txt) | 205 | 两角色真实 ENet、公开投影、稳定 ID 插值、重排/移除/替换/重连、严格字段校验 |
| [statistics](data/phase03-ambient-0250/phase03_npc_statistics.txt) | 380 | 真实 0/3/6 模拟、双角色生产包、统计无 NPC 污染 |
| [native](data/phase03-ambient-0250/native-npc.txt) | 41 | 原生像素、玩家最上层、视觉身份、公开副本与私有真值等价、岸边与观察 |

## 原生画面与来源一致性

原生测试在实际 X11 桌面运行，GL Compatibility / Mesa llvmpipe，640×360 回读；不是 headless 截图替代。检查了较小的蓝绿色 NPC、金色主角、重叠顺序、岸边淡影与观察轮廓；17 张最终 NPC PNG 与已检查图像逐字节一致。补充 28 秒实际权威游动预览确认位置持续变化与转向，无脚本错误；这仍不代替用户对自然度、抖动、拥挤或趣味性的判断。

[原生执行时 402 文件 manifest](data/phase03-ambient-0250/native-source-manifest.json)保持不可变；[校验记录](data/phase03-ambient-0250/native-provenance-verification.json)说明与最终源码的 5 个差异都仅为未由原生 profile 消费的 headless 测试，最终无窗口门禁已重跑这些文件。运行时代码、素材、场景、原生测试、运行器、项目配置和注册表逐字节匹配；[最终源码 manifest](data/phase03-ambient-0250/final-source-manifest.json)在最终门禁后再次比对，402 项无变化。

软件渲染驱动仍警告不支持改变 V-Sync；若干旧原生套件保留退出时 ObjectDB 警告。最终测试无 engine/script ERROR、断言失败或超时。未验证实际声卡、Windows 原生执行、跨物理设备/公网网络，也未进行新包测试。

## 0 / 3 / 6 性能基线

[无窗口完整数据与原始样本](data/phase03-ambient-0250/headless-performance.json)。每组 240 tick 预热、1,200 tick 计时，每 60 tick 采样实际生产角色包；tick 时间排除序列化。角色表示包的接收方，angler 工作负载包含真正的 walk/reel/release/deploy。机器为共享 Linux AMD EPYC 9V74；顺序测量且没有隔离后台负载，不能作为普遍性能保证。

| 接收角色 | NPC | tick 平均 / P95 μs | 权威 snapshot 平均 B | 角色 snapshot 平均 B | Deflate 平均 B | 状态包平均 B |
|---|---:|---:|---:|---:|---:|---:|
| fish | 0 | 671.7 / 997 | 62,755.4 | 31,223.8 | 5,464.0 | 5,753.8 |
| fish | 3 | 696.7 / 1,020 | 64,806.8 | 31,763.8 | 5,626.5 | 5,916.2 |
| fish | 6 | 786.8 / 1,386 | 66,858.6 | 32,303.8 | 5,738.9 | 6,028.8 |
| angler | 0 | 734.1 / 1,026 | 63,051.6 | 63,095.6 | 7,990.5 | 8,280.0 |
| angler | 3 | 777.3 / 1,134 | 65,103.0 | 63,635.6 | 8,157.7 | 8,447.0 |
| angler | 6 | 833.8 / 1,483 | 67,154.8 | 64,175.6 | 8,270.7 | 8,560.4 |

数据另含 800-byte 分片后的实际应用包开销，但不含 ENet/IP/UDP 头。所有包均在现有协议限制内。

[原生帧基线](data/phase03-ambient-0250/native-frame-costs.json)：每组冻结场景 45 次 redraw→frame-post-draw 墙钟时间，含渲染、显示节奏和调度。

| NPC | 平均 ms | 中位 ms | P95 ms |
|---|---:|---:|---:|
| 0 | 18.862 | 16.872 | 35.578 |
| 3 | 19.368 | 16.088 | 24.356 |
| 6 | 16.260 | 16.594 | 18.987 |

结果并非随 NPC 数单调增加，反映共享机器/显示节奏噪声；不能据此声称 6 条鱼更快，也不能当作隔离 GPU 开销或稳定帧率保证。这里建立诊断基线，实际流畅度保留人工门。

## 测试夹具修正与保留的初次结果

[首次完整 headless](data/phase03-ambient-0250/initial-headless-summary.json)的 3 个旧套件未通过，原因是原夹具把完整 Authority 当作钓鱼人 wire，并断言显示历史等于原始私有状态。新的角色投影要求两者分开；仅把喂食插值、抄网插值和分片组装夹具改为生产 `AnglerPublic.capture()`，保留原物理/顺序/反重放断言，并增加原始输入与 Authority 字节不变检查。随后完整51套件重新通过。

[首次完整 native](data/phase03-ambient-0250/initial-native-summary.json)仅旧 Bite 全画面静止断言失败：一次真实 tick 中，30 个变化像素全部属于远处游动 NPC，嘴部/食物/HUD 检查均通过。该单独 Bite 夹具设置 `npc_count:0`，保留原全画面与 11 px 范围/0.80 秒重复断言，完整20原生套件重新通过；组合环境鱼画面由新 NPC 套件覆盖。[最终 Bite 23/23](data/phase03-ambient-0250/native-bite.txt)

早期新网络非法数据 fixture 曾被 GDScript TypedArray 在进入 validator 前拒绝，改为未类型化输入后覆盖原有非法值，没有放松验证器。代码审查还把新 headless 夹具的无效旧 angler 指令名改为真实命令名，最终门禁与上述性能数据均使用修正后的工作负载。初次红项不计作通过。

## 人工试玩门：OPEN，完成后 STOP

1. 同步 `feature/dev`，Godot 4.7.2 打开 `project.godot`，F5，核对菜单 **0.25.0**
2. 鱼练习模式游过整个池塘：三条 NPC 是否更有生命感，是否拥挤、遮挡玩家、卡边、抖动或突然跳点
3. 贴近 NPC、穿过它们，确认不会推走玩家或堵路；回归三类食物的远处吸食与贴近自动咬食，NPC 本轮不抢食
4. 切换钓鱼人，检查岸边与 E 观察视角的信息量，是否出现精确图标或过多注意力干扰
5. 如方便，两份同为 0.25.0 的源码运行，通过 127.0.0.1 联机，交换两角色；检查移动、朝向、菜单暂停、离房/重开和性能体验
6. 反馈自然度、拥挤/遮挡、边界异常、哪个视角/位置及能否稳定复现

用户确认后才进入 P3.2 抢食。P3.3/P3.4/P3.5 与 Phase 4 继续按后续人工门锁定。自动通过不代表整个 Phase 3 完成，也不证明已经好玩。
