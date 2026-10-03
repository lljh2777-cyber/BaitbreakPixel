# 0.25.1 · P3.2 抢食竞争验证

2026-10-03，`feature/dev`，基线 `c1e3946f0b8cf1afa7becf2b238c8297efda5dc8`。用户已确认 0.25.0 环境鱼试玩通过。本轮只交付 P3.2，完成后 STOP 等待新的人工门。

仅提交推送源码，没有生成 ZIP、PCK 或 GitHub Release。最近公开 Windows 包仍为 0.25.0，历史发布资料保持原样。

## 结论与需人工判断的问题

NPC 已能真实抢食，食物生命周期没有出现永久资源耗尽。玩家与 NPC 共用嘴部和摄食物理，所有权、存档、隐私、真实 ENet 和原生画面门通过。

**竞争压力明显，尚未认定平衡合适。** 100 个同种子策略对照中，原样 P2 Mixed bot 的回巢胜局从 39/100 降到 13/100，平均玩家食物从 54.63 降到 41.46；Hook 事件局从 21% 升到 38%。不为追求某个胜率调整种子或事后调参。机器人没有熟练玩家的 QTE/逃脱技巧，这不是玩家胜率估计，但需要优先判断是否抢得太凶。

## 本轮交付

- 合法 `FishObservation → FishSuspicion → NPC Brain → Intent → Authority`；仅 WANDER/APPROACH_FOOD/FEED，饱食影响找食距离、风险接受和进食频率
- 真实 edible grain 消失、NPC 饱食增加，玩家 score/stamina/食物统计不受冒领；颗粒团/散粒偏吸食，细条/块状偏近嘴 Bite
- 共用 `fish_feeding.gd` 与同一个 `_attempt_bite`：默认 10 px、0.80 s、4/6/8 容量不变，没有独立 AI 咬食物理
- 饵的年龄、水流、移动和真实玩家钩接触只积分一次；多鱼按稳定 ID 摄食，玩家既有接触/摄食先处理
- 用原补饵循环解决抢食练习的有限食物问题；挑战、练习的目标分不降低，移动主钓具仍通过既有 Q 重挂饵
- schema15 / FoodProfile guard3 保持；新增私有字段严格校验，旧 0.25.0 不完整快照拒绝，联机 exact-build=0.25.1，angler NPC 公共投影 guard2
- 五个 NPC 开发统计、内部目标/饱食/警惕/RNG/计时不传任一客户端；继续六字段公共鱼表现，玩家无 NPC 数值 HUD

不实现 HESITATE/FLEE/COMPETE、NPC Hook/错误目标/重生、NPC 抄网结算、第二根鱼竿、新地图或 Watergen 改动。[架构和统计定义](../architecture/PHASE03-FORAGING.md)。

## 最终正式门禁

Godot 4.7.2 official `ed1daf0bf`，Linux，隔离 XDG 配置、Dummy 音频，正式入口 `tools/run_tests.py`。

- 当前无窗口：**54/54 套件，240,658 项汇总断言，0 失败**，另有成功编辑器导入，合计 573.471 秒。[完整汇总](data/phase03-foraging-0251/headless-summary.json)
- 当前原生：**20/20 套件，528 项汇总断言 + 2 个 visual 日志标记，0 失败**，另有成功编辑器导入，合计 111.392 秒。[完整汇总](data/phase03-foraging-0251/native-summary.json)
- Python：运行器与新比较/合并保护 **48/48**，既有摄食分析 **11/11**。[运行器](data/phase03-foraging-0251/python-runner.txt) · [新分析保护20项](data/phase03-foraging-0251/python-competition.txt) · [既有分析](data/phase03-foraging-0251/python-analysis.txt)
- Phase 1/1.5/2 当前门继续通过，包括 Hook/QTE、抄网、缠线、规则迁移、感知、类型物理、摄食和真实网络。历史诊断套件不冒称通过

本阶段相关结果：

| 套件 | 通过 | 覆盖 |
|---|---:|---|
| foraging_brain | 397 | 独立旧游动/RNG 对照、输入不变、公开线索、饱食/风险/频率、平滑接近、严格状态 |
| foraging | 80 | 4/6/8、10 px、47/48 tick 冷却边界、去重/归属、共享吸食、远处消费者隔离、隐藏真值实际进食轨迹 |
| food_reachability | 25 | 24 聚合不变量 + 文件写入，覆盖完整4,000场景；不把每 tick 循环膨胀成断言数 |
| snapshot | 2,911 | 活跃摄食/RNG/计时重放、非法字段原子拒绝、旧缺字段快照拒绝 |
| network | 257 | 两角色真实 ENet、食物消失同步、私有字段/统计拒绝、ID 插值/重连 |
| rng | 7,043 | Passive 0/3/6 对照、Hook/QTE/refill 主随机源隔离、真实抢食隐藏真值等价 |
| statistics | 2,141 | 私有统计、类型归属、Passive 与活跃0/3/6性能/包体 |
| ambient / entities / observation | 194,441 / 7,274 / 209 | 原游动、合法水域、身份/数组顺序、玩家感知等价 |
| native | 48 | 三图案、遮挡顺序、视角可见性、真实消耗像素、私有状态/Hook 像素等价 |

逐套日志与数据保存在 [证据目录](data/phase03-foraging-0251/evidence-README.md)。

## 1,000 种子食物结构可达性

[定义与汇总](data/phase03-foraging-0251/food-reachability-summary.json) · [4,000 原始场景](data/phase03-foraging-0251/food-reachability.csv) · [正式门日志](data/phase03-foraging-0251/phase03_food_reachability.txt)

种子 51001–52000，每个种子都跑 survival/duel × challenge/practice，6 NPC 压力场景。经共用摄食路径清空初始和随后三轮可见食物，再运行原 warning/refill/redeploy 生命周期，最后用真实共享 Bite 给出玩家摄入原目标的见证：

- 4,000 场景、0 失败种子；每次符合补给条件的耗尽后，最多 423 tick（7.05 s）重新有食物
- 生存 NPC 至少消费180点，对战至少150点；后续玩家仍可获得原挑战60点/练习30点
- 至少生成5/4个新饵身份，目标不变，无强制胜负、没有另造食物或加速补给时钟
- 最终正式 gate 222.145 秒；所有场景保留，不挑选成功样本

此项是**资源生命周期见证**：测试控制嘴部位置、清零取食冷却，且不模拟行程、真实抢位、饥饿、钩接触/逃脱。它不保证玩家在任意策略/持续上钩状态下都能赢。运动、冷却、危险和真人体验分别由真实对照、回归与人工门承担。

## 真实60 Hz自动策略比较

[冻结协议](../../tools/phase03_competition_protocol.md) · [汇总与配对区间](data/phase03-foraging-0251/competition-heldout-summary.json) · [来源指纹](data/phase03-foraging-0251/competition-heldout-provenance.json)

先跑独立4种子 pilot，再固定源码和控制器跑44001–44100共100个留出种子，每个种子三种模式，原默认生存挑战、370秒上限、原 P2 Mixed 公开感知控制器与既有 AnglerBrain。300/300均终局，无超时删样、输局筛选或50%目标调整。NPC Hook/错误捕获尚未实现，记录为 null，不能当作测得零。

| 指标 | NoNPC | PassiveNPC | ForagingNPC |
|---|---:|---:|---:|
| 玩家食物均值 | 54.6255 | 54.6255 | 41.4600 |
| 获得60点目标的局数 | 50 | 50 | 19 |
| 回巢获胜 /100 | 39 | 39 | 13 |
| 被拉起 / 被抄网 | 12 /49 | 12 /49 | 32 /55 |
| Hook事件局比例 | 21% | 21% | 38% |
| 对局秒数均值 | 76.5155 | 76.5155 | 64.5900 |
| NPC食物均值 | 0 | 0 | 91.6155 |
| 补饵生命周期/模拟分钟均值 | 2.8021 | 2.8021 | 2.9936 |

NoNPC 与 PassiveNPC 100种子全部非NPC结果逐值一致。Foraging−NoNPC 的配对 bootstrap 95%描述区间：食物 −13.1655 [−17.2035, −9.228]；胜率 −26个百分点 [−38, −15]；Hook事件局 +17个百分点 [+5, +29]。这些是种子抽样不确定性，不是人工平衡认证。原始结果分模式无损保留：[NoNPC](data/phase03-foraging-0251/competition-NoNPC.json)、[PassiveNPC](data/phase03-foraging-0251/competition-PassiveNPC.json)、[ForagingNPC](data/phase03-foraging-0251/competition-ForagingNPC.json)。

真实对局的最长可见食物为空区间是22.15秒，不能套用结构门的7.05秒。[44072精确复现](data/phase03-foraging-0251/supply-eligibility-44072.json)证实全部1,329 tick玩家已上钩、cycle_phase=refill、符合补给条件的tick=0；此前已获得67.95点，随后被拉起。另一个22秒样本[44009](data/phase03-foraging-0251/supply-eligibility-44009.json)也属原有上钩暂停补给。没有把这些不利区间排除出统计。

## 原生画面、性能和来源

在实际云端 X11 桌面运行原生图形套件，GL Compatibility / Mesa llvmpipe，640×360回读。亲自检查[真实食物消耗前](data/phase03-foraging-0251/fish-npc-food-before.png)与[消耗后](data/phase03-foraging-0251/fish-npc-food-consumed.png)：NPC嘴边食物消失，玩家HUD不加分，仍没有NPC数值标签；完整套件覆盖两角色公共副本和私有真值像素等价。

[原生414文件manifest](data/phase03-foraging-0251/native-source-manifest.json)及[来源核对](data/phase03-foraging-0251/native-provenance-verification.json)：最终运行时代码、素材、场景、原生测试和运行器完全匹配。仅后续实验说明文字及未被原生profile消费的分析/诊断工具有差异；[最终源码manifest](data/phase03-foraging-0251/final-source-manifest.json)独立保存。

[无窗口0/3/6原始性能](data/phase03-foraging-0251/headless-performance.json)，每组240tick预热、1,200tick计时。活跃鱼端0/3/6平均tick约705/728/715 μs，P95约1070/1176/1448 μs；钓鱼人端约683/816/810 μs，P95约1026/1333/1649 μs。所有实际生产角色包仍在协议限制内。更多鱼有时因吃掉可见颗粒而让鱼端包更小，因此单调大小断言保留在Passive控制，而活跃测试记录真实颗粒数。

[原生帧成本](data/phase03-foraging-0251/native-frame-costs.json)：0/3/6分别20.91/18.01/19.97ms均值，P95 34.19/25.98/33.57ms；每组45个冻结画面样本。均包含显示节奏、软件渲染与共享主机调度，不是隔离GPU成本，不能声称3鱼更快或保证实际设备帧率。

未验证 Windows 本机、新发行包、真实声卡、两台物理设备或公网网络。软件驱动保留 V-Sync 能力警告，部分旧原生套件有退出对象清理警告；正式门没有脚本/引擎ERROR、失败或超时。

## 保留的初次问题与修正

[首次完整无窗口](data/phase03-foraging-0251/initial-headless-summary.json)有3项失败：两个旧吸食套件暴露新通用函数在非defer入口的TypedArray赋值错误；修复显式类型构造后重跑通过。旧Phase1网络夹具要求所有preexisting字段相等，但未排除新增私有NPC配置和统计，修正只排除新增NPC字段，保留所有旧Authority、rig和RNG逐值断言。

独立审查另发现远处消费者可给别的鱼增加剥离预算。现在只在该鱼真正接触当前附着外层时累计预算，旧散粒不能为远处新饵充能。新增近NPC/远NPC、近玩家/远NPC、近NPC/远玩家、refill旧散粒隔离回归；独立重现从“12 vs23粒脱落”修正为“12 vs12”。该修正同时用于玩家和NPC，没有改力场/速度/容量。最终完整门全部重跑，早期结果不当作最终通过。

## 人工试玩门：OPEN，完成后 STOP

1. 同步 `feature/dev`，Godot4.7.2打开`project.godot`，F5，核对菜单0.25.1
2. 先自由练习：等NPC靠近并吃食物，检查是真实减少，玩家分数没有被加上；离远观察、再靠近争同一团
3. 分别试颗粒团、细条、块状：NPC是否会合理靠近/吸食/咬食，有没有停在饵旁抖动、不吃、突然跳点或抢走所有食物
4. 玩几轮挑战：抢食是否促使更快选择；现在压力是否过大；能否稳定达到目标。自动策略压力明显增加，请优先反馈这一项
5. 让NPC吃空再等补饵，检查练习也会继续有食物；对战钓具沿用Q重挂饵，不要把上钩中暂缓补给误判为永久锁死
6. 检查岸边/观察视角有没有信息过量；如方便，同版本两份源码联机，交换角色，核对食物消失、NPC移动、暂停/重开与性能
7. 反馈“更有趣还是烦人”，以及过强/过弱、饵型、模式和可复现位置

用户确认之前不进入P3.3，不把自动通过当作整个Phase3完成。
