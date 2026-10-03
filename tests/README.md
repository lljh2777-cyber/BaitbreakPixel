# 回归测试入口

推荐使用有超时保护的 Python 3 入口，不要把 `tests/*.gd` 全部直接逐个启动：部分历史套件依赖已经移除的玩法或方法，Godot 的运行时错误会中止测试函数，却不一定退出进程。

```sh
python3 tools/run_tests.py --import
python3 tools/run_tests.py --profile native
python3 tools/run_tests.py --suite rules_v020
python3 -m unittest discover -s tests/runner -v
```

Windows 可使用 `D:\python\python.exe`；用 `--godot "引擎可执行文件路径"` 或环境变量 `GODOT` 指定 Godot。Linux/WSL 使用 `python3`。原生测试需要可用的图形显示，例如桌面终端或已安装的 Xvfb；运行器不会把无窗口执行误报成原生验证。测试显式使用 Dummy 音频驱动，只验证逻辑/画面，不验证真实声卡输出。

## 注册表与状态

[`suite_registry.json`](suite_registry.json) 显式登记全部 118 个顶层 GDScript 入口。新增/改名后必须同步注册表，否则运行器拒绝运行。

- `current`：当前有效的回归门禁；不按文件名版本新旧决定。`--profile current` 运行无窗口套件，`--profile native` 运行图形套件。已重新验证的 effort、net_animation、rules_network 等较早版本仍在当前门禁中
- `historical`：当前检出复现了失败的诊断套件。保留原断言，失败仍返回非零；这不是“已证明所有断言过时”，更不是通过。具体原因和结果见[维护报告](../docs/test-reports/TEST-INFRASTRUCTURE-MAINTENANCE-2026-10-02.md)
- `retired`：只有证据充分、依赖已删除 API/已移除玩法的 `rules_v019` 和 `net_route_v0102`。保留完整历史测试体，直接执行入口打印替代套件并退出 2；注册表选择也明确报告 RETIRED 并返回非零
- `manual`：AI 探针、双进程 peer 配对脚本和纯截图序列。单独启动不能代表完整回归；保留显式原因，不算通过

```sh
python3 tools/run_tests.py --list
python3 tools/run_tests.py --profile historical
python3 tools/run_tests.py --profile all-headless
python3 tools/run_tests.py --suite shore_native_v015
```

历史诊断预期会有红项；不要把 `--profile current` 的通过写成“全仓库所有历史测试通过”。报告中逐项保留具体失败和未覆盖范围。

## 超时、退出与日志

每个进程使用注册表的有限超时（通常 90 秒，联网/大型图像测试 120 秒），可以通过 `--timeout 30` 覆盖。超时后终止进程组；Ctrl+C 也清理当前测试。Unix 进程组清理已验证；Windows 使用 `taskkill /T /F` 尽力清理进程树，本次未验证 Windows 原生执行。

标准输出写入临时文件，避免残留子进程持有管道而卡住回收。非零退出、`SCRIPT ERROR`、`ERROR:`、失败标记或失败计数均不会显示为绿项。没有测试完成证据也算失败。无汇总计数的老套件只能统计日志标记，`summary.json` 的 `count_basis` 会注明 `log_markers`，不要把它与断言数混为一谈。

日志默认在 `artifacts/test-runs/`，包括每个套件的 `.log`、命令、耗时和 `summary.json`。使用 `--output-directory` 为不同运行保留独立记录。运行器总是添加 `--test-profile`；Linux 还将 XDG 数据、配置、缓存目录隔离到输出目录，避免读写正常游戏档案。

## 原生与打包截图

所有 36 个使用原生画面、且会写 PNG 的脚本都接受：

```sh
godot --path . --script res://tests/wood_fade_native.gd -- --test-profile --capture-output-directory=/absolute/writable/captures
```

默认路径不变。目录会创建，空值、建目录失败、PNG 写入失败都返回非零。5 个旧脚本继续支持 `--visual-output=`，同时提供时以 `--capture-output-directory=` 为准。

计数说明：37 个脚本使用原生渲染/画面回读，其中 `reel_hand_native_v016` 只验证像素连通性，不写图片。另一个会写图的 `plant_art` 是无窗口图像测试：默认不写图，保留 `--preview=文件名`，也支持公共目录参数生成 `plant-art-preview.png`；显式 `--preview` 优先。因此所有 37 个会写图片的入口均有可写路径选择，不需要给不写文件的测试增加空参数。

发行 PCK 故意不包含 `tests/` 和 `tools/`。运行器用外部绝对 `--script` 加载测试，让 `res://scripts/` 和素材来自包内：

```sh
python3 tools/run_tests.py --profile native --pack /path/to/BaitbreakPixel.pck --output-directory artifacts/packed-native
```

每个脚本的路径配置在自身内部，不依赖包内不存在的测试 helper。`net_v021`、`untangle_v021`、旧 hand_rig 等继承 `res://tests/...` 的包装脚本不能这样外部加载；注册表把它们明确标为包模式 BLOCKED，需在源码模式执行。这个限制不会被当作通过，也不会把测试源码偷偷加入发行包。

## Phase 0–1 统计与隐私检查

- `phase01_*` 覆盖实体、感知、饱食、本能、警惕、随机生命周期、网络裁剪、策略与原生视觉
- `python3 tools/run_rounds.py --strategy distance --rounds 1000 --seed 3001` 导出真实60 Hz对局；`cautious` 使用相同种子作对照
- `--project` 选择不可变归档，默认从该归档冻结一份 harness；provenance.json 记录实际脚本哈希
- `tools/summarize_rounds.py` 合并不重叠种子，`tools/compare_policies.py` 提供配对差值与重采样区间
- 详细验收范围与未关闭的人工试玩项见 `docs/test-reports/PHASE01-VALIDATION.md`

## Phase 1.5 试玩修正

`phase15_controls` 验证未部署开局、首次 Q、W/S 正反向真实长度、空闲/冲突键、A/D 对称边界、实际状态动画与重开。`phase15_native` 捕获鱼 HUD 饱食/警惕与岸上未部署/收线/放线关键帧。自动通过本身不解锁 Phase 2；用户现已试玩并允许暂通过推进，既有问题仍可重开。

## Phase 2.1 Bite 垂直切片

`phase02_bite` 验证无按键自动咬食、冷却后持续近距再咬、空处无反馈、摄入上限、范围边界、稳定排序、Bite 对 Suck 的优先级、恢复与真实钩尖接触；`phase02_bite_network` 验证移除命令位、schema15 回放、倒计时验证与鱼端裁剪，并通过真实 ENet 鱼客户端验证自动咬食、近距重复与钩尖接触结果。`phase02_bite_native` 验证就绪/空处/远距/摄入/冷却画面及隐藏钩像素等价。自动通过不替代用户的手感与双端人工试玩。

## Phase 2.2 饵型基础

`phase02_bait_types` 覆盖三类型分配、原食物预算、生命周期、混合旧散粒、schema15 重放，以及固定种子范围的初始/重挂钩型独立性诊断；`phase02_food_profiles` 验证集中定义、不可变配置和分数/饱食分离。`phase02_observation` 与 `phase02_bait_network` 验证合法线索、严格裁剪、版本门和回放；`phase02_bait_native` 捕获三类型、部分吃掉/散落/吸动和 safe/hooked 像素等价。P2.3 已加入类型效率差异；测试通过不能替代人工辨识度与最终平衡确认。

## Phase 2.3 摄食选择

`phase02_feeding_balance` 覆盖整粒 4/6/8 摄入、混合旧散粒预算、重复计分保护、饱食倍率、真实吸动/剥离/碎散物理、schema15 回放、新统计保密与嵌套校验。`phase02_feeding_policies` 验证纯观察策略、自动咬食语义、隐藏真值等价命令和真实 60 Hz 重放。后者引用不打包的 tools，PCK 模式明确 BLOCKED。

现有 `bait_suction_v0212`、`feeding_feel_v022` 与 Bite 基准 fixture 显式固定 Cluster，以继续验证原始曲线和基础容量，断言不放宽；各类型差异另有独立用例。

配对实验入口：

```sh
python3 tools/phase02_run_feeding.py --phase pilot --seed 21001 --rounds 4 --output artifacts/p23-pilot
python3 tools/phase02_run_feeding.py --phase heldout --seed 31001 --rounds 100 --pilot artifacts/p23-pilot --output artifacts/p23-heldout
```

默认真实 60 Hz、370 秒上限，运行前后验证源码哈希；留出种子不得与 pilot 重叠，源码/控制器及时间上限须保持一致。`SuckOnly` 只是远处吸食偏好，不会禁用嘴边自动咬食。比较保留所有输局、未终局与不利结果；无 QTE/解钩技巧，因此不能当成熟练玩家胜率。结果和最终人工门见 [P2.3 验证报告](../docs/test-reports/PHASE02-FEEDING-VALIDATION.md)。

## Phase 3.0 + 3.1 环境鱼

0.25.0 将权威 schema14 明确升级到 schema15；旧版拒绝恢复，FoodProfile guard3 保持。当前 Phase 1/2 套件继续验证已有摄食、QTE、Hook、隐私与玩家体感基础；仅把有意升级的 schema 断言更新为15，不放宽玩法断言。

新增 8 个 current 套件：

- `phase03_npc_entities`：实体唯一性、稳定 ID、确定性合法生成、移除后新 ID、数组重排
- `phase03_npc_rng`：0/3/6 NPC 下所有非 NPC 权威值和主 RNG 一致，Hook/QTE/refill 轨迹，以及隐藏真值等价
- `phase03_npc_observation`：独立 legacy player fixture 的字段、值、顺序与字节等价；多观察者距离、公开 self 和隐藏线索
- `phase03_npc_snapshot`：schema15 全量恢复、RNG/计时/转向重放、嵌套字段与非法未来行为的原子拒绝
- `phase03_npc_ambient`：3×180 模拟秒的合法水域、慢频决策/连续积分、暂停与终局、软避让和无摄食/胜负影响
- `phase03_npc_network`：严格 NPC 公共字段、鱼/钓鱼人投影、稳定 ID 插值，以及两个角色真实 ENet、移除/替换和断开重连
- `phase03_npc_statistics`：0/3/6 的 simulation time、snapshot bytes、公开包压缩前/后字节；不把测量当作长期性能保证
- `phase03_npc_native`：原生三种外观、玩家最上层、公开副本/隐藏真值像素等价、岸边和观察视角，以及0/3/6冻结帧耗时

正式门禁：`python3 tools/run_tests.py --import --profile current` 与 `--profile native`；渲染脚本需真实图形环境。历史结果见[0.25.0 验证](../docs/test-reports/PHASE03-AMBIENT-VALIDATION-0.25.0.md)。本轮保留显式 PassiveNPC 控制，以继续验证环境游动和玩家主随机源隔离。

## Phase 3.2 抢食竞争

- `phase03_npc_foraging_brain`：独立旧游动对照、合法公共线索、饱食/风险/摄食频率、确定性和输入不可变
- `phase03_npc_foraging`：玩家/NPC 共用 mouth/Bite 容量与冷却、吸食物理、真实归属/去重、远处吸食者不补充其他鱼的剥离预算、隐藏真值等价
- `phase03_food_reachability`：1,000 distinct seeds × 生存/对战 × 挑战/练习 = 4,000 场景，反复 NPC 耗尽后通过既有补给给出不降低目标的玩家摄食见证；结构可达性，不是自动获胜或熟练玩家保证
- 既有 snapshot/network/statistics/native 套件增加实际抢食、私有字段/统计、真实 ENet 消耗同步和摄食画面
- 自动策略对照：`NoNPC` / `PassiveNPC` / `ForagingNPC`，使用原 P2 Mixed，仅用于发现极端失衡；完整复现与限制见 [实验协议](../tools/phase03_competition_protocol.md)

权威 schema15、FoodProfile guard3 保持；新增配置/内部字段严格检查，所以旧 0.25.0 快照明确拒绝，网络 exact-build=0.25.1，angler NPC 公共投影 guard2。该阶段当时未启用 P3.3/P3.4；用户随后确认 P3.2 试玩通过。历史[报告与人工门](../docs/test-reports/PHASE03-FORAGING-VALIDATION-0.25.1.md)。


## Phase 3.3 社会线索

- `phase03_npc_social_brain`：短暂 HESITATE/FLEE、饥饿 COMPETE、连续线索锁存与恢复、危险事件年龄/距离、边界逃离、输入/RNG隔离及严格私有状态
- `phase03_npc_social`：NPC专用观察边界、附近公开动作/实际危险结果、玩家警惕隔离、隐藏真值配对与真实60Hz食物摄入
- snapshot/network/native原套件扩展到三种社会行为：生产意图生成、严格字段/旧快照拒绝、回放、双角色真实ENet及像素等价
- `tools/phase03_social_diagnostics.gd` 与 `tools/phase03_analyze_social.py`：离线行为/真实钩关系诊断，显式区分自然模拟与配对干预，报告类别数量、简单分类器/基准和>90–95%审查标记

仍为schema15、FoodProfile guard3；新增私有字段与世界事件严格校验，旧0.25.1快照拒绝。网络exact-build0.25.2，angler投影guard3，NPC公共六字段不扩展。只有运动/摄食结果可见，没有数值警惕HUD。P3.4与多竿不在本轮。当前[验证与人工门](../docs/test-reports/PHASE03-SOCIAL-VALIDATION-0.25.2.md)。

## Phase 3.4 钓错目标

- `phase03_npc_hook_target`：真实嘴部/相对扫掠、稳定目标与线端、玩家继续摄食/回巢、正常 W/S、独立 RNG、逃脱/断线/捕获/延迟新 ID 重生、暂停/终局与接触前隐私
- 原 snapshot/network 套件扩展到 Hook 全生命周期、严格非法状态原子拒绝、两个角色真实 ENet 与目标切换表现
- `phase03_npc_hook_native`：原生鱼/岸边/观察镜头的 NPC 中钩/提鱼/捕获/逃脱/断线、正确线端、公共副本和未接触隐藏真值像素等价
- `tools/phase03_run_hook_diagnostics.py`：NoNPC / PassiveNPC / ForagingNPC / HookableNPC 四组同种子实际 60 Hz 对照，含 Hook/钓错鱼及有限观察窗，不代替人工平衡

Authority schema15；旧 0.25.2 缺少 Hook 生命周期字段的快照明确拒绝。网络 exact-build0.25.3，鱼端 NPC guard2、钓鱼人 guard4。当前[验证与人工门](../docs/test-reports/PHASE03-HOOK-VALIDATION-0.25.3.md)。
