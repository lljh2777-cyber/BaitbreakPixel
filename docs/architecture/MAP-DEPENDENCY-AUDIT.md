> 0.26.4 更新：本文保留原阶段的历史状态；P4.4–P4.6 的最终实现与已清理依赖见 [地图抽象最终架构](MAP-PRESENTATION-FINAL.md)。

# Phase 4.0 地图依赖审计

## 1. 范围、基线与结论

- 审计日期：2026-10-04
- 唯一源码基线：`9d11fe8ae4bb7a49abe5fcd0e6f518ed0ebd3a92`，版本 / network build `0.25.5`，Authority Snapshot schema `15`
- 冻结目录：`artifacts/p40-frozen-baseline-9d11fe8`；下文行号全部指向上述 Git 基线，不随后续文档或版本修改漂移
- 搜索范围：基线的全部 977 个 tracked 文件；文本搜索使用 `git grep -I`，不把 PNG 二进制字节中的偶然数字当作源码依赖。包括归档测试、工具和历史报告；不搜索 `.godot`、未跟踪临时文件或其他分支
- 实施范围以开发说明 §79、§88 的第一轮任务为准：**P4.0 + P4.1 数据基础**，包含 definition、canonical hash、validator、registry 和等价测试；旧游戏仍由 `PondLayout` 驱动
- 本审计不迁移 World、Snapshot、Network、Presentation，不合并 Watergen，不生成地图，不修正既有玩法。下述后续迁移建议不表示本轮已执行

关键结论：

1. 基线有 **18 个 SOLIDS + 22 个 PLANTS 派生交互目标 = 40 个目标**。所有目标都允许鱼穿过、接触淡出和成功 QTE 后缠线；只有 18 个木石目标阻挡抄网
2. `GRASS` 是另一个不可遗漏的权威数据集：**3 个移动减速区域**，并影响抄网观察可见度。它不是 22 个 plant target，也不能由这些矩形合并或重算
3. `grass_binding.gd` 的草茎绑定 / 变形是显示逻辑。真正的 grass rope anchor 是 `interaction_targets()` 产生的固定矩形及 `coil_at()` 的权威线圈
4. 当前目标索引参与 contact / wraps / opacity、Snapshot 和网络验证；不能按新 feature ID 重排运行时目标。木头分组使用的是旧 `seed`，不是数组索引
5. 640×360 是逻辑 viewport；1280×720 是窗口。它们与 1280×480 世界尺寸必须分开。另一方面，`rope.gd:50` 的 `9/631/309` 确实用于世界坐标寻路，不能因近似旧 viewport 就忽略

## 2. 可复现搜索与分类

```sh
git grep -I -n -E 'PondLayout|\bLayout\b|MAP_ID|pond_v2' 9d11fe8 --
git grep -I -n -E '\b(1280|480|433|1272)\b|60[[:space:]]*,[[:space:]]*401|66[[:space:]]*,[[:space:]]*385' 9d11fe8 --
git grep -I -n -E 'map_id|\.HOME|\.SOLIDS|SPAWN_REGIONS|vegetation_drag|Grass\.(profile|deform)|Rope\.solve' 9d11fe8 -- scripts tests tools
```

第一条找到 **58 文件 / 211 匹配行**；第二条找到 **67 文件 / 266 匹配行**。匹配行数不是依赖数量：一行可能有多个引用，数字查询也有指标、时间、音高、测试坐标等误报。附录 A/B 列出每个命中文件及全部行号，不跳过归档材料。第三条是补充语义检查；数据定义本身和经 `world/g/game` 转发的依赖亦在正文列出。

分类含义：

| 类别 | 内容 |
| --- | --- |
| Authority | 世界状态、规则执行、感知 / AI、移动、net、spawn 等 |
| Network | 输入边界、wire projection、公开 NPC 状态验证 |
| Snapshot | Authority capture / restore 及索引和地图身份验证 |
| Presentation | 镜头、投影、纹理、显示用线圈 / 水草变形 |
| Tests | tracked 测试和地图特定 fixture，包括历史套件 |
| Tools | 诊断策略、截图工具和归档诊断脚本 |
| Docs | 说明、历史报告、数据输出和 provenance |

多重用途的文件注明多个类别；不能仅按文件名判断权威边界。例如 `net_simulation.visibility()` 被显示调用，但其几何规则必须保持；`npc_fish_public_state` 同时影响网络接收和显示。

## 3. 权威数据源清单

`scripts/pond_layout.gd` 是当前唯一固定地图数据源：

| 行 | 旧数据 | 必须逐项保留的内容 |
| --- | --- | --- |
| 4 | `SIZE` | `Vector2(1280,480)` |
| 5 | `FLOOR` | `433.0` |
| 6 | `HOME` | `Vector2(60,401)` |
| 7 | `SPAWN` | `Vector2(66,385)` |
| 8 | `WATER` | `Rect2(8,68,1264,363)`，end 为 `(1272,431)` |
| 9 | `NET_AREA` | `Rect2(30,85,1220,315)`，end 为 `(1250,400)` |
| 10 | `BAIT_SITES` | 六个位置的原始顺序：`(220,170),(450,230),(680,175),(880,255),(1070,190),(1160,315)` |
| 13 | `WOOD_GROUPS` | seed 分组 `[[1,4,5,6,11,12],[7,15],[17,18]]` |
| 17–36 | `SOLIDS` | 18 项的原始顺序、kind、points、seed、可选 name；polygon 顶点顺序亦不可改 |
| 38 | `GRASS` | `Rect2(135,363,30,70), Rect2(951,346,34,87), Rect2(1118,337,42,96)`，保留顺序 |
| 39–62 | `PLANTS` | 22 项的原始顺序与 `x,y,height,width,kind,stems,back`；交互和显示分开保存仍须能精确复原 |

函数不是新的地图数据：`fish_bounds` 64–65、`nearest_boundary` 67–76、`touches` 78–79、`solid_fade_group` 81–88、`interaction_targets` 90–102、`coil_at` 104–121。未来可迁至通用 MapGeometry，本轮不得因此改写算法或旧调用路径。

边界不是同义词：水域底边 431、地板 433、地图底边 480；部分木石点 x=6，水域左边是 8。草区和交互轮廓可以延伸到地板。Validator 应验证 feature 在地图允许范围内，**不能要求所有 feature/drag zone 完全位于 WATER 内**，否则会拒绝原始 pond_v2。

## 4. 消费者清单及后续风险

### Authority

| 文件 | 已核实用途 / 风险 |
| --- | --- |
| `scripts/world_simulation.gd` | 22/25/27 转发 `Layout/HOME/SOLIDS`；54/486 玩家出生；219 构造目标；582 保序复制饵位再用 world RNG 洗牌；614–619 固定 NPC spawn regions、HOME 距离和 SOLIDS 排除；661/702 NPC bounds；855–858 木石碰撞查询；860–864 GRASS；867/877 鱼 bounds；880–911 接触 / 淡出 / 目标选择；977 权威线圈；1086 玩家草区减速；1277 loose-food 水域；1311 脱钩 clamp；1049/1430/1593 巢穴判定 / 返回 |
| `scripts/angler_brain.gd` | 6：巡逻宽度来自 `world.Layout.SIZE.x` |
| `scripts/angler_rig.gd` | 121–122 水面 x clamp；168 投掷目标；188 光标；190 步行；246 tackle bounds。左 / 上边的 20、38、79、80、100 等仍是独立旧假设，后续不应只迁移右 / 下边 |
| `scripts/fish_brain.gd` | 87 逃离方向边界；123–133 逐目标查找和目标中心 clamp；138 `game.HOME`；46/172 经 `vegetation_drag` 估算速度。顺序改变可能改变同距离目标选择 |
| `scripts/fish_observation.gd` | 133：脱落颗粒必须在 `Layout.WATER` 内才进入食物感知；保持隐藏真值边界 |
| `scripts/net_simulation.gd` | 20–32/153/287 经 `g.SOLIDS` 使用木石轮廓；21 经 `g.Layout.touches`；282 `NET_AREA` 和钓鱼人 reach 同时约束 A/B；222 经 `g.HOME` 返回；289 经 GRASS 影响观察。不能用所有 interaction targets 代替 SOLIDS |
| `scripts/rope.gd` | 不直接 import Layout，读取调用方传入的 `obstacle.points`；50 的旧固定 node 边界及 `_prepare()` 缓存属于后续 map-aware 审计重点。当前唯一生产 `Rope.solve` 调用为 net 提网出口路径（`net_simulation.gd:32`）；玩家缠线在 World 中按已确认 wraps 构造，不是自动绕所有 solid |
| `scripts/npc_fish_state.gd` | 56 地图鱼 bounds；57 landing/captured 上界扩展到 y=39；19 三个 `SPAWN_REGIONS` 是独立固定 pond 假设，虽非 Layout 字段也不能漏掉后续 NPC spawn 迁移 |
| `scripts/npc_hook.gd` | 113–120 中钩 NPC 的 water bounds / 弹性长度 clamp；迁移不改 hook 生命周期或 RNG |
| `scripts/npc_fish_brain.gd` | 通过传入 `environment.bounds` 消费地图；没有直接 Layout 常量，不需要新增静态依赖 |

### Snapshot / Network

| 文件 | 已核实用途 / 风险 |
| --- | --- |
| `scripts/world_snapshot.gd` | 9 schema 15；13 `MAP_ID="pond_v2"`；179 capture；220 restore；247 surface_x 上限；279 public hook cue 在 WATER 内。255/263–269/310–313 使用目标数量、contact/wrap/untangle 索引和 loops 验证，稳定目标顺序是 ABI |
| `scripts/fish_network_observation.gd` | 14 是独立 public format schema 1，不能误当 Authority schema；18 地图 ID；107 capture；128/132 固定顶层键 / map_id 校验；198 surface_x 边界；156–180 opacity/target/wrap 的索引一致性 |
| `scripts/angler_network_observation.gd` | 12 固定 wire 字段含小写 `map_id`，故不在最初大写搜索中；15 继承 Authority capture；26–57 构造并验证 snapshot。后续 MapRef 改造必须一并考虑，第一轮不动 |
| `scripts/network_protocol.gd` | 6 exact build 0.25.5；65 将 angler target clamp 到 Layout.SIZE，和普通 viewport 无关 |
| `scripts/network_session.gd` | 383 远端 net point clamp 到 `game.Layout.SIZE` |
| `scripts/npc_fish_public_state.gd` | 44/80 使用鱼 bounds 验证公开坐标；43–45 landing bounds 上沿 y=39。供网络与显示共用，不能只改 World 后留下接收端仍按旧地图校验 |

本轮保留 schema 15、现有 map_id wire 形状和 exact-build 机制；新 MapDefinition hash 尚未加入 live handshake / Snapshot。§44–49、§68–69 的 MapRef / schema 16 门属于后续轮次。

### Presentation

| 文件 | 已核实用途 / 风险 |
| --- | --- |
| `scripts/pond_camera.gd` | 12 `Layout.SIZE - VIEW_SIZE`；5 的 640×360 是 viewport；11 的 `0..120` 是当前 480−360 的 angler camera 行程假设，后续需要 fixture 识别 |
| `scripts/shore_view.gd` | 27/32/35/37 由地图宽度 / 地板做可逆投影；58 angler hand 行程；134–145 显示所有 solids/plants。640、257、WATER_LEVEL=55 是当前 pond-style 投影参数，不等同 WATER 顶边 68 |
| `scripts/pond_view.gd` | 56 plant 缓存；143 巢穴指向；153–179 plant 前后层、target−solid 偏移、132 高 strip；512–513 巢穴进度；110 solid assembly 的最小 target opacity；167–168 grass strip deform |
| `scripts/pond_scenery.gd` | SIZE/FLOOR 画面覆盖、solid 接地阴影、HOME 巢穴；55/53/56 等为美术岸线位置，不应强行等于 water.top |
| `scripts/pixel_art.gd` | 124–143 按 solid fade_group 构造 11 个 render assemblies；纹理严格使用旧轮廓，不能把绘制集合当成 11 个物理目标 |
| `scripts/pond_wood_art.gd` | WOOD_GROUPS 和全部 SOLIDS 建立共享木纹；SHAPES 是 seed-keyed 的视觉主轴。seed 同时用作旧分组键，提取时应显式保存分组关系再把纯材质 seed 放到显示 metadata |
| `scripts/pond_water_art.gd` | 24 全地图图像；55/378 深度梯度、1260/333 mote 范围、BEAMS 为旧视觉配置，不是 Authority geometry |
| `scripts/pond_depth_art.gd` | 8 全地图 canvas；73 FLOOR 深度；18/29 固定装饰石位置；85 以1280取模散布碎石。其余岩坡、草、荷叶、前景位置也为 fixed visual profile |
| `scripts/net_observation.gd` | SIZE/FLOOR/PLANTS 绘制观察层，读取 net reach/visibility；0..640 screen interaction hitbox 是 viewport，不是世界 clamp |
| `scripts/line_motion.gd` | 74 线段 sag 不能超过地板；158 读取 Grass.profile；仅产生显示几何，不写权威 rope |
| `scripts/fish_winding.gd` | 25/27 限制显示用绕圈姿态；16 读取 Grass.profile；鱼模拟坐标、contact、捕捉仍使用 authority fish |
| `scripts/grass_binding.gd` | 10–12 `wrap.target-SOLIDS.size()` 找 PLANTS；草茎细节、弯曲、pitch/entry、radii 是显示派生值；见 §5 |
| `scripts/pond_plant_art.gd` | 不直接读 Layout，但接收 plant Dictionary 并使用其 kind/stems/back 等；与 grass_binding 的茎公式必须一致 |
| `scripts/pond.gd` | 249 通过继承 World 的 `vegetation_drag` 显示草区提示；间接消费者 |

### Tests / Tools / Docs

- 附录 A 列出的每个测试都保留为地图特定的 golden / regression 证据；`phase03_npc_ambient.gd:5` 是未使用的 Layout preload，也记录而不遗漏
- 核心已有等价证据入口：`pond_v021`（bounds/camera/projection/network/plant）、`wood_fade`（分组但不合并物理目标）、`wood_junctions` / `obstacle_art`（显示不改几何）、`grass_binding_v021` / `fish_orbit_v021` / `line_motion_v021`（显示不写 authority）、`water_art`（地图 canvas）、NPC entities / foraging / social / hook 套件
- `tools/phase02_feeding_policy.gd:63` 的回巢策略硬依赖 Layout.HOME；归档 `docs/test-reports/data/phase02-distance/tuning-100/phase02_feeding_policy.gd` 保留相同旧依赖；`p32-brain-compare.gd.txt` 保存 Layout fish bounds 诊断
- 间接旧工具：`tools/capture_fish_orbit_v0182.gd:14`、`capture_line_motion_v0181.gd:14` 仍有 `(600,285)` clamp；`capture_grass_motion_v0183.gd:14` 和 `capture_grass_v0183.gd:13` 使用数值 target index。这些不在当前第一轮迁移范围，后续不要当通用新地图验证工具
- 历史文档的版本不能当作当前事实：`ARCHITECTURE.md:89` 的 schema 1 / pond_v1、`POND-ARCHITECTURE.md:66` 的 schema 12 / build 0.22.6 是历史叙述；本轮基线事实以实际代码为准
- 源码 manifest 中的 `scripts/pond_layout.gd` 文件名 / hash 是 provenance，不是代码读取地图常量；不通过改历史 hash 来“清除依赖”

## 5. capabilities 逐项判定

| 对象集合 | fish_passable | net_blocking | rope_anchor | contact_fade | grass_binding | shore_visible |
| --- | --- | --- | --- | --- | --- | --- |
| 18 个 SOLIDS（10 wood / 8 stone） | true | true | true | true | false | true |
| 22 个 PLANTS 派生的 grass targets | true | false | true | true | true（显示能力） | true |
| 3 个 GRASS drag zones | 可穿过，玩家主动游速可变 | false | 不另建目标 | 不另建目标 | 不等同茎绑定 | 无独立绘制对象 |
| 纯装饰 depth/water 植物与岩石 | 不参与碰撞 | false | false | false | false | 取决于既有显示层，非交互 feature |

### fish_passable 不能与 NPC spawn exclusion 混淆

`move_fish()` 只 clamp WATER 并应用鱼线约束，不调用 `_collision`；`_tick_npc_fishes()` 同样只 clamp water bounds。木石“solid”不代表鱼移动撞墙。但 `spawn_npc()` 使用 `_collision(candidate,RADIUS)` 排除木石区域，并排除 HOME 附近、饵附近、其他 NPC 附近。未来 capability/查询若用于 spawn，需要保留 **solid spawn exclusion**，不能因为 fish_passable=true 就允许 NPC 初始生成在木石内。当前 grass 既不阻鱼也不参与 spawn solid exclusion。

### net_blocking 与观察遮挡

`manual_net_blocked`、提网路径膨胀、多段 lane、`_net_reaches_fish` 都只用 SOLIDS。22 plant target 不能误加入 net obstacle 列表。`Net.visibility` 是另一层语义：超 net_sight 返回0，SOLIDS polygon 内返回0；若 `vegetation_drag(point)<1` 再乘0.42。它不是对所有 plant interaction rectangles 都乘0.42；且当 vegetation_speed 不小于1时，GRASS 也不会触发该折减。

### contact_fade 与顺序

`_update_contacts` 每次检查全部40目标，接触半径12；淡出到 `cover_opacity`，恢复到1，速率 `delta*4`。已经 wrapped 的目标仍可参与淡出，但不会被再次选为新的 contact target。QTE wrap 时 contact_target 保持 wrap_target；否则保留尚接触且未 wrapped 的旧目标，再按 bounds center 距离选最近者。严格 `<` 的比较使相同距离时原数组顺序有意义。

WOOD_GROUPS 的元素为1-based旧seed；实际 fade group 是 group首seed对应的0-based solid索引：

- group0：targets `[0,3,4,5,10,11]`
- group6：targets `[6,14]`
- group16：targets `[16,17]`
- stone targets `[1,2,7,8,9,12,13,15]` 各自独立
- grass targets `18..39` 各自独立（旧字典未显式给 fade_group，consumer fallback 到 index）

18 solids 被显示为11个 assemblies，但 authority仍是18个独立polygon。Snapshot 与 fish network带 target_opacity；保守地把稳定 fade_group_id 纳入本轮 canonical authority 数据，可确保这个已序列化状态的分组语义不会静默改变。不要仅因“透明是视觉”就丢掉这层等价约束。

### rope_anchor 与 grass_binding

所有40目标都可在 hooked、接触、未已缠、QTE成功等既有门满足后建立 wrap。PLANTS矩形严格为：

```text
Rect2(x - width*0.5 - 3, y - height, width + 6, height)
polygon = [top-left, top-right, bottom-right, bottom-left]
```

`coil_at` 保留 y夹取、交点排序、左右最外交点、最小横半径7、wood纵半径6 / 其他7，以及65个采样点和原始entry。不能因画面实际草茎较窄而缩小权威矩形或权威线圈。

`Grass.profile()` 仅读世界 elapsed/tension/line anchors，复制 wrap 再生成显示 profile；生产调用者仅 `fish_winding.gd:16`、`line_motion.gd:158`，以及 `pond_view.gd:167–168` 的 deform。它没有 authority写入。`stems/kind/back` 等显示数据不应凭此升级为移动阻挡规则；但必须原样保留以保持显示用线圈、茎形、前后层和根部位置。

### shore_visible 不等于 fish visibility

`shore_view._underwater` 134–145 无条件遍历所有 SOLIDS 和 PLANTS，分别画ghost和三条简化茎，故这些 features 的 shore_visible=true 是“feature会在岸边显示”。其画面不使用contact_fade来改变整个岸边几何。鱼 / NPC 在普通岸边画面按深度显示近似轮廓；net observation才通过 `Net.visibility` 遮挡/衰减。不能用一个 shore_visible 布尔值替换这两种不同的信息边界。

### GRASS 必须保留为单独 authority 区域

三个区域在 `world_simulation.vegetation_drag` 中按序判断，命中返回规则 `vegetation_speed`，否则1。当前真正乘该系数的是玩家主动游速；水流、线拉力和net impulse另加，不一同乘。NPC常规移动不读取vegetation_drag，但net观察NPC也使用同一可见度规则。迁移时不能顺手给NPC添加草区减速。

建议字段为 `bounds.vegetation_drag_zones: Array[Rect2]`（保序、authority-hashed、finite/map-bounded validation），明确与40个interaction_features分开；不能追加3个目标导致目标数量变43。

## 6. 数字硬编码逐项处理原则

真正地图参数 / 地图特定几何：

- `pond_layout.gd` 的1280/480、433、HOME/SPAWN是authority数据；solid points里的433、plant根部433是具体几何，不能批量替换为无区别的floor引用；solid7的`Vector2(480,430)`中480是一个顶点x而不是地图高度
- `pond_depth_art.gd:85` 的1280是装饰散布横向周期，18/29的1280/1272是旧地图固定装饰锚点，均属Presentation；`pond_wood_art.gd:16` 的433是木纹主轴视觉控制点
- `fish_orbit_v021.gd:30` 的1272是WATER右边界golden；`pond_v021.gd:38,99` 的1280是世界右边界golden
- `phase02_feeding_policies.gd:44` 的 `(60,401)` 是回巢fixture；`water_scenery_native.gd:37,60` 的SPAWN/HOME是视觉 / 巢穴等价fixture
- `water_art.gd:15,24,25` 与 `wood_junctions.gd:17,18,46` 的1280×480和433是地图尺寸 / floor画像golden，保持其“验证旧pond”的目的，不机械换成自引用导致测试失去独立性

明确不是地图尺寸：

- `project.godot:14` 的1280是native窗口宽度；逻辑viewport仍为640×360
- `sound.gd:15` 的480是音高Hz；多个NPC/tackle测试的`for tick/frame in 480`是时长；native鼠标 / net测试中的`Vector2(480,...)`是选定样例点，不代表map.width或map.height
- 历史报告中的480断言、91,252,433字节、1280×720窗口；JSON/JSONL/CSV里的tick、样本index、行为计数、duration小数尾部433、积分1272.*等均不是地图参数。附录B保留其命中和排除理由

指定数字之外已发现的地图假设（只登记）：`rope.gd:50` 的旧world节点过滤；`pond_camera.gd:11` 的120高行程；`npc_fish_state.gd:19` 的三个生成区；`angler_rig` / `fish_brain` 固定上左边距；NPC landing y=39；net出口y=5；water / scenery / shore 中的surface55。后续应区分模式规则、投影profile和地图范围，不能以“搜索不到1280”宣称无硬编码。

## 7. P4.1 数据契约建议与本轮验收

1. definition为value-only；meta保存id/revision/contract_version/content_hash；几何保持Vector2/Rect2/PackedVector2Array，不存Node、Texture、Callable或RNG实例
2. 每个feature有稳定id、原kind、shape、显式capabilities、`compatibility_index`、稳定`fade_group_id`和`presentation_ref`。40项按旧target次序生成；ID不是index，但本阶段index仍是兼容ABI
3. visual_features保存能复原旧SOLIDS/PLANTS的metadata与关联ID。seed/name/stems/back等不因抽象丢失；wood grouping先转换成显式关系，避免把未来视觉seed改动变成分组改动
4. hash必须使用显式字段次序、数值编码和数组顺序，不能靠Dictionary迭代或`hash(var_to_bytes(dictionary))`。包含size/water/floor/net_area/spawn/home/保序bait_sites/GRASS zones/feature geometry/capabilities/兼容次序/fade grouping；纯纹理、visual seed、颜色等排除。hash不包含其自身
5. 读取返回detached data，修改一次返回值不能污染registry模板、后续读取或旧Layout；load/validate/canonical/hash均不消耗world或NPC RNG
6. Validator拒绝未知contract、非法meta/hash、非finite或越界bounds/anchors、重复或不足饵位、重复feature ID、坏polygon、无效capabilities/ID关系。至少需4个bait sites以支持现有四slot初始化，built-in保留全部6个；本轮不做生成图可达性证明
7. Golden逐项比较旧常量、18 solids / 22 plants / 3 GRASS、40 targets原顺序与kind/polygon/bounds、fade组、所有必要显示metadata、代表性contact下的完整coil结果。检查视觉metadata变更不改变authority hash，authority几何/flag/顺序/GRASS变更能改变hash或被validator拒绝
8. 第一轮应验证新文件可加载、合法图通过、非法图拒绝、canonical/hash稳定、detachment、旧数据未变。不得把这些结果写成World已迁移、Snapshot16已接通或多地图运行已通过
9. 后续P4.2必须带着本审计处理NPC spawn regions、间接SOLIDS/HOME、感知WATER和net-only rope调用；后续再做Snapshot/Network与Presentation迁移、不同尺寸fixture及完整simulation/RNG/native gates

本文件提供静态审计结论与验收要求；自动测试的实际命令、通过数、产物hash和失败项由本轮验证报告记录，不以本审计代替运行证据。审计自身已校验：附录A/B的文件与全部行号逐项等于基线git grep结果，所有完整源码路径存在于基线，文档通过diff whitespace检查。

## 附录 A：全部直接符号命中

以下由基线第一条搜索生成，包含preload、调用、注释、文档；同文件全部匹配行聚合为一行。数据源 `pond_layout.gd` 自身不写 `Layout.`，已在§3单独完整登记。

| 类别 | 基线文件 | 全部匹配行 |
| --- | --- | --- |
| Docs | `docs/architecture/ARCHITECTURE.md` | 93 |
| Docs | `docs/architecture/PHASE03-AMBIENT-FISH.md` | 11 |
| Docs | `docs/architecture/PHASE03-SOCIAL-CUES.md` | 7 |
| Docs | `docs/architecture/PHASE03-WRONG-HOOK-TARGET.md` | 43 |
| Docs | `docs/architecture/POND-ARCHITECTURE.md` | 9, 28, 36, 66 |
| Docs | `docs/history/CHANGELOG.md` | 48, 224 |
| Docs | `docs/test-reports/README.md` | 87 |
| Docs | `docs/test-reports/TEST-REPORT-0.21.0.md` | 12 |
| Docs | `docs/test-reports/TEST-REPORT-0.21.1.md` | 11 |
| Docs | `docs/test-reports/TEST-REPORT-0.22.4.md` | 7 |
| Tools（归档于 Docs） | `docs/test-reports/data/phase02-distance/tuning-100/phase02_feeding_policy.gd` | 5, 63 |
| Tools（归档于 Docs） | `docs/test-reports/data/phase03-social-0252/p32-brain-compare.gd.txt` | 4, 27 |
| Authority | `scripts/angler_brain.gd` | 6 |
| Authority | `scripts/angler_rig.gd` | 35, 121–122, 168, 188, 190, 246 |
| Authority | `scripts/fish_brain.gd` | 11, 87, 125, 133 |
| Network | `scripts/fish_network_observation.gd` | 18, 107, 132, 198 |
| Authority | `scripts/fish_observation.gd` | 6, 133 |
| Presentation | `scripts/fish_winding.gd` | 2, 25, 27 |
| Presentation | `scripts/grass_binding.gd` | 3, 10–12 |
| Presentation | `scripts/line_motion.gd` | 2, 74 |
| Presentation | `scripts/net_observation.gd` | 6, 24–25, 27–28, 32, 36, 44, 64 |
| Authority | `scripts/net_simulation.gd` | 21, 282 |
| Network | `scripts/network_protocol.gd` | 4, 65 |
| Network | `scripts/network_session.gd` | 383 |
| Network / Presentation | `scripts/npc_fish_public_state.gd` | 5, 44, 80 |
| Authority / Snapshot | `scripts/npc_fish_state.gd` | 4, 56 |
| Authority | `scripts/npc_hook.gd` | 7, 113 |
| Presentation | `scripts/pixel_art.gd` | 114, 124, 126, 130–131, 133 |
| Presentation | `scripts/pond_camera.gd` | 4, 12 |
| Presentation | `scripts/pond_depth_art.gd` | 4, 8, 73 |
| Presentation | `scripts/pond_scenery.gd` | 3–4, 10, 12, 15, 17, 19–20, 41–43, 45, 60 |
| Presentation | `scripts/pond_view.gd` | 9, 56, 143, 153–154, 156, 174, 176, 179, 512–513 |
| Presentation | `scripts/pond_water_art.gd` | 4, 24 |
| Presentation | `scripts/pond_wood_art.gd` | 4–5, 28 |
| Presentation | `scripts/shore_view.gd` | 6, 27, 32, 35, 37, 58, 134, 136–137 |
| Authority | `scripts/world_simulation.gd` | 22, 25, 27, 54, 219, 486, 582, 661, 857, 861, 867, 877, 880, 977, 1277, 1311 |
| Snapshot | `scripts/world_snapshot.gd` | 13, 179, 220, 247, 279 |
| Tests | `tests/fish_orbit_v0182.gd` | 15 |
| Tests | `tests/fish_orbit_v021.gd` | 15 |
| Tests | `tests/grass_binding_v021.gd` | 14, 18–19, 40 |
| Tests | `tests/line_motion_v0181.gd` | 15, 84 |
| Tests | `tests/line_motion_v021.gd` | 15, 84 |
| Tests | `tests/obstacle_art.gd` | 4, 15, 18, 42 |
| Tests | `tests/obstacle_visuals_native.gd` | 6, 50–51, 55 |
| Tests | `tests/phase03_npc_ambient.gd` | 5 |
| Tests | `tests/phase03_npc_entities.gd` | 5, 20–22 |
| Tests | `tests/phase03_npc_foraging_brain.gd` | 6, 38 |
| Tests | `tests/phase03_npc_social_brain.gd` | 6, 41, 94 |
| Tests | `tests/phase15_controls.gd` | 74–75 |
| Tests | `tests/plant_art.gd` | 4, 41–42, 44, 59, 81 |
| Tests | `tests/pond_v021.gd` | 3, 24, 27, 87–89, 92–93, 98–99 |
| Tests | `tests/untangle_v018.gd` | 97, 102, 107 |
| Tests | `tests/untangle_v020.gd` | 100, 105, 110 |
| Tests | `tests/water_art.gd` | 56 |
| Tests | `tests/wood_fade.gd` | 3, 14–15, 24, 27–28, 54 |
| Tests | `tests/wood_fade_native.gd` | 3, 27–28, 59–60, 68–69 |
| Tests | `tests/wood_junctions.gd` | 5, 13, 21, 45, 53, 58 |
| Tools | `tools/phase02_feeding_policy.gd` | 5, 63 |

合计：58个文件，211个匹配行。额外的裸常量数据源、`map_id`、间接`HOME/SOLIDS`、GRASS调用链及无Layout字面的消费者已在§3–5列明。

## 附录 B：全部指定数字命中及判定

此表保留第二条搜索的全部67个文件、266个匹配行，包括误报；长JSON/JSONL行中的数字按其实际字段含义判定，不将输出数据改造成参数。连续行号以区间表示。

| 类别 | 基线文件 | 全部匹配行 | 判定 |
| --- | --- | --- | --- |
| Docs | `docs/architecture/PHASE03-AMBIENT-FISH.md` | 11 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/architecture/PHASE03-SOCIAL-CUES.md` | 7 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/architecture/PHASE03-WRONG-HOOK-TARGET.md` | 43 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/architecture/POND-ARCHITECTURE.md` | 3, 18, 24 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/gameplay/PLAY.txt` | 31 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/history/CHANGELOG.md` | 222 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/test-reports/PHASE01-PILOT-50.json` | 39 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/PHASE02-BITE-TUNING-0.24.6.md` | 17 | 480个断言；排除 |
| Docs | `docs/test-reports/TEST-REPORT-0.12.1.md` | 24 | 480项历史检查；排除 |
| Docs | `docs/test-reports/TEST-REPORT-0.12.md` | 32 | 480项历史检查；排除 |
| Docs | `docs/test-reports/TEST-REPORT-0.15.md` | 29 | 1280×720窗口；非地图尺寸 |
| Docs | `docs/test-reports/TEST-REPORT-0.18.1.md` | 38 | ZIP字节数91,252,433；排除 |
| Docs | `docs/test-reports/TEST-REPORT-0.20.0.md` | 3 | 1280×720窗口；非地图尺寸 |
| Docs | `docs/test-reports/TEST-REPORT-0.21.0.md` | 3, 7 | 3：窗口1280×720；7：地图1280×480 |
| Docs | `docs/test-reports/TEST-REPORT-0.22.3.md` | 11 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/test-reports/TEST-REPORT-WATER-DEPTH.md` | 9, 11 | 历史地图尺寸、地板或HOME说明；保留历史记录 |
| Docs | `docs/test-reports/data/ecology-0255/baseline-rows/duel-challenge-Mixed.jsonl` | 1–4 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/baseline-rows/duel-challenge-SuckOnly.jsonl` | 1–4 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/baseline-run.txt` | 19–22 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/headless-ecology-balance.log` | 219, 245 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/headless-ecology-cases.json` | 375, 417 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/headless-npc-statistics.json` | 51, 466, 1503, 2955, 3683, 4407, 5859, 7311, 8768, 10220, 11672, 13124, 14576, 15912, 16028, 17345 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-2-run.txt` | 125–126, 133–134 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-3-run.txt` | 15–18, 23–26 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-4-run.txt` | 91–94 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-comparison.json` | 15122, 26760 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/duel-challenge-BiteOnly.jsonl` | 28 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/duel-challenge-Mixed.jsonl` | 1–3, 5–8, 21–22, 25–27, 57–60, 69–76, 96 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/duel-challenge-SuckOnly.jsonl` | 1–3, 5–8, 21–22, 25–27, 57–60, 69–76, 96 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/duel-practice-Mixed.jsonl` | 37–40, 96 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/duel-practice-SuckOnly.jsonl` | 37–40, 96 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/survival-challenge-SuckOnly.jsonl` | 38, 41 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/heldout-rows/survival-practice-BiteOnly.jsonl` | 77–80 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/native-review.md` | 18 | 1280×720窗口；非地图尺寸 |
| Docs | `docs/test-reports/data/ecology-0255/pilot-rows/duel-challenge-Mixed.jsonl` | 1–4 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/ecology-0255/pilot-rows/duel-challenge-SuckOnly.jsonl` | 1–4 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/hook-feel-0254/natural-diagnostic-run.txt` | 66 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/hook-feel-0254/npc-pacing.md` | 18, 25 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase02-feeding/heldout-100/comparison.json` | 789 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase02-feeding/heldout-100/rounds.csv` | 233 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase02-feeding/heldout-100/rounds.json` | 6189, 8219, 8368, 14403, 35919, 45308 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase02-feeding/heldout-extension-88/rounds.json` | 790, 2506, 2812, 8541, 30512, 39901 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase03-ambient-0250/headless-performance.json` | 51, 1500, 2949, 4053, 4333, 4398, 5847, 6111, 7296 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase03-foraging-0251/headless-performance.json` | 51, 478, 1024, 1213, 1267, 1503, 1921, 2801, 2955, 4407, 5859, 7311, 8768, 9023, 9076, 10007, 10220, 10600, 10607, 11060, 11369, 11672, 12790, 12793, 13016, 13124, 14576, 15096, 15816, 16028 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase03-social-0252/preview-competition.txt` | 12 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase03-social-0252/preview-social.txt` | 20 | 历史tick/计数/索引/时长/积分/性能或采样输出；非地图参数 |
| Docs | `docs/test-reports/data/phase03-social-0252/preview_compete.gd.txt` | 18 | 归档工具480 ticks；排除 |
| Presentation | `project.godot` | 14 | 窗口宽度1280；非地图尺寸 |
| Presentation | `scripts/pond_depth_art.gd` | 18, 29, 85 | 18/29：装饰锚点；85：全图横向散布周期 |
| Authority | `scripts/pond_layout.gd` | 4–7, 18–20, 23–27, 31, 33–34, 40–45, 48, 50, 52–61 | 地图常量、地板相关几何、一个x=480的solid顶点；见§3/6 |
| Presentation | `scripts/pond_wood_art.gd` | 16 | 木纹主轴控制点y=433；非新authority polygon |
| Presentation | `scripts/sound.gd` | 15 | 480Hz音高；排除 |
| Tests | `tests/angler_native_v010.gd` | 135 | x=480的鼠标fixture；非地图尺寸 |
| Tests | `tests/fish_orbit_v021.gd` | 30 | WATER右界1272的golden |
| Tests | `tests/net_animation_capture_v0201.gd` | 39 | 鱼x=480样例点；非地图尺寸 |
| Tests | `tests/net_animation_v0201.gd` | 18 | 鱼x=480样例点；非地图尺寸 |
| Tests | `tests/net_v020.gd` | 18, 128 | 鱼x=480样例点；非地图尺寸 |
| Tests | `tests/phase02_feeding_policies.gd` | 44 | HOME=(60,401)回巢fixture |
| Tests | `tests/phase03_npc_foraging.gd` | 190 | 480 ticks；排除 |
| Tests | `tests/phase03_npc_rng.gd` | 37 | 480 ticks；排除 |
| Tests | `tests/pond_v021.gd` | 38, 99 | 世界右界1280的golden |
| Tests | `tests/rules_v019.gd` | 107 | net x=480样例点；非地图尺寸 |
| Tests | `tests/tackle_dynamics_v016.gd` | 26 | 480 frames；排除 |
| Tests | `tests/tackle_dynamics_v021.gd` | 27 | 480 frames；排除 |
| Tests | `tests/water_art.gd` | 15, 24–25 | 1280×480图像及floor433的golden |
| Tests | `tests/water_scenery_native.gd` | 37, 60 | SPAWN=(66,385)、HOME=(60,401) fixture |
| Tests | `tests/wood_junctions.gd` | 17–18, 46 | 1280×480图像canvas golden |

合计：67个文件，266个匹配行。附录A/B有重叠文件；不得把两表相加当作独立依赖总数。
