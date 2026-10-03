# Phase 3.2 · 抢食竞争

版本：0.25.1；基线：`c1e3946f0b8cf1afa7becf2b238c8297efda5dc8`；2026-10-03。

用户已确认 0.25.0 环境鱼试玩通过，进入 P3.2。只做寻找食物、摄食和资源竞争，完成后 STOP。P3.3 社会动作、P3.4 NPC Hook/错误目标、P3.5 全生态平衡及 Phase 4 多竿仍未开放。后续发布的 0.25.0 Windows 包与历史记录保持原样，本轮只提交源码。

## Observation → Brain → Authority

- `npc_fish_brain.gd` 只接收 detached `FishObservation`、自身记忆、公共邻鱼位置/水域边界、规则、delta 和独立随机源；没有 World、钩真值或玩家私有警惕入口
- 使用 `FishSuspicion.update/tolerance` 解释可见运动与扰动；FoodProfile 只通过公开 shape/smell 线索影响选择。未知远处食物不被直接归类为安全/危险
- 仅启用 `WANDER / APPROACH_FOOD / FEED`。原游动保持自己的随机序列；即使进入觅食，也不消费 `world.rng`。真正改变食物/补给后，世界结果自然分叉是允许的
- 初始 NPC satiety=70，范围 0–100；82 以下开始寻找，持续觅食达到 94 后休息。自身饱食影响搜索距离、风险容忍和 1.6 秒周期内进食占比。仍受同一个成功咬食冷却约束
- NPC 饱食变化是生态状态，不显示数值 HUD；使用既有 satiety_decay 和食物恢复倍率。玩家 hunger_enabled 只控制原玩家生理辅助，NPC 食欲仍使用自己的饱食数值
- 颗粒团/散粒优先吸食，细条/块状优先贴近咬食；接近位置使用减速和侧向软避让，嘴朝向可以独立于微调移动。不实现犹豫、逃离、社会竞争状态或其他鱼情绪读取

Authority 每 tick 连续积分位置和饱食，约每 0.12 秒接受一次新意图。NPC 自己只能提出移动、朝向、吸食和目标；世界负责颗粒、饱食、统计。不同 NPC 的邻鱼几何取自同一 tick 起点，摄食顺序按稳定 ID 排序。玩家先处理真实钩接触与摄食，再处理 NPC 摄食，避免数组重排改变所有权。

## 共用真实摄食物理

`fish_feeding.gd` 是有限的共享纯逻辑：

- mouth = position + aim × 10
- 原渐变距离场和吸食锥
- 可食颗粒按距离、bait_id、颗粒顺序稳定排序
- 按 FoodProfile 效率消耗 Bite 容量，保留“不会跳过更贵的近处颗粒”

世界中 `_attempt_bite(npc={})` 是同一个近嘴自动摄食路径。玩家维持原状态门；NPC 必须 active、处于 FEED、未暂停/终局且冷却结束。默认范围 10 px、成功间隔 0.80 秒、容量 4/6/8 没有改动，NPC 也没有独立 `ai_bite` 公式。

`_pull_food` 共用颗粒剥离、FoodProfile 效率和散粒传输。每个饵的水流/被动运动/钩接触只积分一次；整饵位移由当前实际最强吸力者控制，多鱼不会重复积分饵的年龄或水流。各鱼随后依稳定顺序争取真实颗粒。

审查发现并修正：远处吸食者不能给另一个位置的剥离预算充能。共享预算现在仅在当前外层附着颗粒真的落入该鱼吸食场时累积；旧 loose survivor 也不能给远处重新挂上的饵充能。力场、剥离倍率、颗粒速度和预算公式/上限保持，只有“接触前无效预算预充”被去掉；玩家与 NPC 使用同一修正。

`_consume_grain` 统一去重。成功摄食让真实 grain.eaten=true 并登记 counted，NPC 获得自身饱食和 NPC 开发统计；不增加玩家 score、stamina、玩家 food_by_type 或摄食反馈时间。NPC 不能 Hook、改变 hook_target_fish_id、结算比赛或作为抄网目标。

## 补给与结构可达性

NPC 消耗后不降低 `food_goal`。继续使用 warning → refill → redeploy_bait 和既有移动钓具 Q 重挂饵。

过去练习模式不运行 `_step_supply`，在 NPC 抢食后会有永久耗尽风险。现在当 `npc_foraging_enabled=true` 且有 NPC 时，练习也运行同一个补饵生命周期；NoNPC/PassiveNPC 练习保持旧行为。此项只复用现有补给，不增加独立 AI 食物池。

`phase03_food_reachability` 检查 1,000 种子 × 四种模式，反复通过共用口部路径耗尽食物后，既有生命周期能继续产生足够食物，实际玩家摄入到原目标。该见证有受控嘴部位置和冷却清零，只证明资源生命周期不会永久锁死；不证明任何操作策略必胜，也不覆盖玩家一直处于钩住/抄网状态的无限停滞。真实移动、实际冷却、危险与对手另由完整策略比较和其他回归覆盖。

## 私有统计与同步

Authority 的五个新增统计：

- `npc_food_consumed`：实际 NPC 摄入的 points 总和
- `npc_food_by_type`：cluster/worm/chunk points，与总量校验一致
- `npc_feeding_events`：成功 Bite 或成功吸食 batch，每鱼每 tick 至多一次
- `player_npc_food_contests`：NPC 成功咬食所得颗粒同时落在玩家 Bite 半径内的事件数；这是窄口部争食指标，不等于所有附近竞争
- `npc_target_switches`：选入新的有效目标，包括从无目标首次取得目标

这些是开发统计，均不传给任一角色客户端。NPC 内部目标、饱食、警惕、风险、RNG、摄食计时和开发开关也不发送。两角色仍只接收六个 NPC 公共表现字段；没有新名字、状态条或精确头顶图标，岸边/观察可见性不变。钓鱼人其他历史 Authority 字段不在本阶段重设计。

保持 snapshot schema15 和 FoodProfile guard3；新配置和 NPC 字段采用精确形状/类型/范围校验，0.25.0 不完整快照拒绝，不默默补造决策/RNG 状态。钓鱼人公共投影 guard 升为2，网络 exact-build 为0.25.1。公共副本只负责显示，不能继续运行 NPC Authority。存储与恢复均保持 detached、原子拒绝和确定性重放。

开发对照开关 `npc_foraging_enabled` 默认 true，不加入普通玩法设置。false 为 PassiveNPC，继续验证 P3.1 游动与主 RNG 隔离；npc_count=0 为 NoNPC。比较协议见 [实验协议](../../tools/phase03_competition_protocol.md)，最终结果与人工门见 [验证报告](../test-reports/PHASE03-FORAGING-VALIDATION-0.25.1.md)。
