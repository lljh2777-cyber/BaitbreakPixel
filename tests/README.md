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

[`suite_registry.json`](suite_registry.json) 显式登记全部 142 个顶层 GDScript 入口。新增/改名后必须同步注册表，否则运行器拒绝运行。

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

所有 38 个使用原生画面、且会写 PNG 的脚本都接受：

```sh
godot --path . --script res://tests/wood_fade_native.gd -- --test-profile --capture-output-directory=/absolute/writable/captures
```

默认路径不变。目录会创建，空值、建目录失败、PNG 写入失败都返回非零。5 个旧脚本继续支持 `--visual-output=`，同时提供时以 `--capture-output-directory=` 为准。

计数说明：39 个脚本使用原生渲染/画面回读，其中 `reel_hand_native_v016` 只验证像素连通性，不写图片。另一个会写图的 `plant_art` 是无窗口图像测试：默认不写图，保留 `--preview=文件名`，也支持公共目录参数生成 `plant-art-preview.png`；显式 `--preview` 优先。因此所有 39 个会写图片的入口均有可写路径选择，不需要给不写文件的测试增加空参数。

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


## 0.25.4 · P3.4 上钩开局与 NPC 收近修正

- `player_hook_entry`：准备阶段按键与最后一帧边界、没有输入缓存、原绿区/超时、移动后缠线准入、接触/张力中断、原回合终局原因、snapshot 重放
- `player_hook_network`：远端鱼与钓鱼人真实 ENet 准备/成功流程、同批警告与可见按键归属、历史年龄/编号/重放守卫
- `player_hook_entry_native`：重复入口/缠线、真实键盘长按/重复、暂停和失焦恢复、重开、原生画面与接触中断提示
- `phase03_npc_hook_pacing`：浅/中/深与横向偏移的真实接触后连续收近、正常 W/S、完整提鱼动画、松线与持续高张力断线，不将 NPC 捕获算玩家终局

网络 exact-build0.25.4；authority schema15、鱼端 NPC guard2、钓鱼人 guard4 不改。本轮只提交源码，不新建 Windows 包；[验证与人工复测](../docs/test-reports/PHASE03-HOOK-FIX-0.25.4.md)。


## 0.25.5 · P3.5 整体生态平衡

`phase03_ecology_balance` 覆盖正常 2/3/4 条密度下的集成生态、暂停/回放/隐私和连续捕获补鱼。默认仍为 3；不新增 NPC 抄网或多人胜利阵营。

`tools/phase03_run_ecology.py` 运行四种生态状态 × 两种规则 × 挑战/练习 × 三种既有摄食策略的真实 60 Hz 配对矩阵，显式保留策略适配、未终局、补给准入、NPC 占线期间玩家摄食和成功补鱼。`phase03_ecology_analysis.py` 按种子整簇重采样，不把同种子多行当独立样本；完整范围见 [预声明协议](../tools/phase03_ecology_protocol.md)。通过不等于真人体验验收。


## 0.26.0 · P4.0 + P4.1 地图数据基础

- `phase04_map_definition`：独立 pond_v2 值 / 40 targets / fade groups / coils / GRASS 等价；固定 canonical hash、重排稳定、Authority / Presentation hash 边界、深层返回值隔离和零 RNG 消耗
- `phase04_map_validator`：精确 schema、有限几何、四个最少生命周期饵位、非法 polygon / ID / 引用 / hash、循环 / Object / Callable / script-typed containers、输入不可变和 RNG 纯度
- `phase04_map_baseline`：八个确定性场景的现行模拟 / snapshot / FishObservation / wire 守卫；这是 standalone 自检，不等于跨版本比较
- `python3 tools/phase04_compare_baseline.py --godot <Godot4.7.2路径>`：从锁定的 0.25.5 Git tree 冻结基线，双端运行同一外部 harness，对照每 tick Authority 字节哈希、RNG 和详细 checkpoint；只允许精确声明的版本文字改动
- `python3 -m unittest discover -s tests/runner -v`：包含不可变基线、源码 allowlist、harness 来源与失败拒绝检查

游戏仍使用旧 PondLayout；schema15 / 网络格式 / 渲染不迁移。测试 fixture 只在 tests 中构造，Registry 不注册。历史全仓 globs 不计入当前通过；P4.2 与后续整体迁移未开始。范围、已知继承问题与人工抽查见 [0.26.0 报告](../docs/test-reports/PHASE04-MAP-FOUNDATION-0.26.0.md)。


## 0.26.1 · P4.2 Authority MapContext

- `phase04_map_context`：旧 pond 全字段/目标顺序/coil 等价、只读 context、深层与 PackedArray 导出隔离、按能力缓存、非法输入和零 RNG
- `phase04_map_authority`：仅 tests 内的 800×380 / shifted-water fixture；证明 World 初始化、原子拒绝、出生/回巢/饵位/NPC/观察/AI/抄网/接触等实际权威路径读取地图。包模式明确 blocked，不将测试地图加入 Registry/菜单/Release
- `python3 tools/phase04_compare_authority.py --godot <4.7.2> --require-engine 4.7.2 --output <new-directory>`：冻结 0.26.0 实际最新提交，使用未改的旧外部 harness 对照每 tick 全状态/输入/RNG/观察/回放；源码许可清单和审查哈希必须一致
- 旧 `phase04_compare_baseline.py` 保留为 P4.1 历史门，其“所有 consumer 不可改”规则有意不适用于 P4.2；不得放宽它或把当前运行失败伪报为通过。当前 standalone `phase04_map_baseline` 仍是注册回归之一

仅声明当前 profile，通过不包括 historical/retired/manual。schema15 和公开网络仅支持原 pond；不同地图持久化/握手属于 P4.3，Presentation 属于 P4.4，剩余 Rope 固定路由节点边界属于后续硬编码清理。详见[本轮验证](../docs/test-reports/PHASE04-MAP-AUTHORITY-0.26.1.md)。


## 0.26.2 · P4.3 Snapshot / Network MapRef

- `phase04_map_snapshot`：严格四字段 MapRef、本机 Registry 解析、schema16 精确 roundtrip/replay、schema15 明确拒绝、恶意/嵌套/循环/typed-container 拒绝，以及 fixture→pond 的原子地图/状态恢复
- `phase04_map_network`：鱼端 schema2 / 钓鱼人 schema16 的本机公开地图、两种角色真实 ENet、hello/welcome/start/ack 的 exact-build+MapRef、未知/缺失/错误 revision/contract/hash 和握手前伪造对局数据拒绝；测试 peer helper 不进入发行包
- `phase04_snapshot_equivalence`：当前 standalone 自检；外部 `tools/phase04_compare_snapshot.py` 才负责 0.26.1 冻结源码与 0.26.2 的真实跨版本对照。验证原八场景/相同输入、每 tick 状态/rig/RNG、观察、Hook/QTE/wrap/NPC/net/stats、公开投影与完整回放；仅排除事先严格核验的两个顶层 schema/map 身份字段，不归一化玩法字段
- `python3 -m unittest discover -s tests/runner -v` 包含新比较器的缺字段、错误元数据、输入/检查点/随机状态变化和非法源码范围拒绝

原 `phase04_map_baseline` 与 P4.1/P4.2 外部工具保留历史 schema15 字节契约，该入口标记为 historical，须在锁定历史 Git 基线运行；当前替代门具有原样的场景/setup/commands/intervention 输入带。旧 timing/queue 单元 fixture 显式从已验证地图后的 host/playing 状态开始；原有断言全部保留，真正 ENet 测试仍执行完整握手，不把单元前置状态当成传输验证。

复现跨版本门（绝对引擎路径推荐）：

```sh
python3 tools/phase04_compare_snapshot.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --baseline artifacts/p43-frozen-baseline-8831f52 --output artifacts/p43-equivalence-recheck
```

基线来自 `8831f52ee7daae5d592282d5da432cbd67fccfb0` 的 immutable Git archive，包含用户已发布的 0.26.1 文档，runtime 与 `92b9010` 相同。首次在仓库根目录创建新的空目录，再解包这个已验证 Git 提交：

```sh
mkdir -p artifacts/p43-frozen-baseline-8831f52
git archive --format=tar 8831f52ee7daae5d592282d5da432cbd67fccfb0 | tar -x -C artifacts/p43-frozen-baseline-8831f52
```

已有冻结目录不要覆盖。工具读取 Git commit/tree、直接比较实际源字节并保存 scoped runtime diff；只有状态等价所需的数据 hash，无冗余全仓 SHA256 清单。最终独立内容审查仍不可用路径白名单替代。

仅本轮 current profile 通过算通过；historical/retired/manual 不算。本轮未构建新游戏包、P4.4 未开始。详见 [0.26.2 报告](../docs/test-reports/PHASE04-MAP-SNAPSHOT-NETWORK-0.26.2.md)。

## Phase 4 最终门

新增 source-only 的 map_presentation、shore_projection、map_fixture、map_equivalence 和 map_native 套件，均已注册。原生 map_native 使用未注册的测试地图，故明确标记 pack_compatible=false；它不绕过发行包排除 tests/ 的规则。

最终全状态对照使用 tools/phase04_compare_presentation.py，指定 --godot 和新的 --output-directory。基线固定7efe59b；需先以 git archive 将其解到 artifacts/p44-frozen-baseline-7efe59b，或通过 --baseline 指定同一提交的原样源码。驱动验证基线/输入脚本身份及运行期间源码稳定性，比较8场景2100tick与86检查点的完整Variant字节，不做字段排除或批量SHA256。原生完整RGBA对照和真实ENet门另列，自动结果不代替人工手感。

## Phase 5 第一轮生成原型

- `phase05_generation_request`：严格 recipe、整数种子与独立整数 RNG。
- `phase05_generator_determinism`：重复生成/完整输出与 canonical 对照、固定版本 hash、模拟 RNG 隔离、视觉元数据不改变 Authority hash。
- `phase05_generated_features`：整数几何、六个饵点、稳定 ID、连接木统一组、能力语义及普通 MapContext。
- `phase05_playability`：保护区、密度、NPC 采样、锚点/网路指标、主动非法输入和固定重试耗尽。
- `phase05_seed_sweep`：默认 10,000 seeds，每 seed 生成两次并重新经过双验证。报告写至 artifacts/phase05-seed-sweep.json；注册超时 1800 秒。
- `phase05_native`：独立开发预览和代表 Seed；全图截图、像素检查、手动 Seed/检查层、默认 pond_v2 不变。不启动比赛，不表示 P5.3 已完成。

独立运行大样本门：`D:\python\python.exe tools/run_tests.py --godot <Godot控制台路径> --suite phase05_seed_sweep --output-directory artifacts/phase05-sweep`。无需逐 Seed 截图或逐文件 SHA256 扫描。

### P5 完整生成地图

- phase05_runtime：真实比赛、完整路由范围、食物、NPC、钩、缠线与回巢。
- phase05_snapshot / phase05_network：schema17 recipe + hash；冷重建、原子拒绝、两种角色真实 ENet。
- phase05_watergen_boundary：严格公共几何出口，独立视觉种子与完整局的 Authority / RNG 一致性。
- phase05_gameplay_native / phase05_ui：五张代表地图的实际 GL 画面与岸边投影，菜单 Seed / R / 新地图 / 设置持久化。
- tools/phase05_run_gameplay.py：25 map seeds × 20 simulation seeds × 2 controllers，默认规则完整局统计。输出原始 JSONL 与按地图/策略汇总，不进行逐帧 SHA 扫描。

P4 的当前兼容套件已更新为 schema17 / fish schema3，并明确排除新增 recipe 元数据做跨版本玩法比较；原来的几何、状态、RNG、隐私断言保持。
