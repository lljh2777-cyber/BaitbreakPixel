# Phase 3.0 + 3.1 · 多鱼基础与环境鱼

版本：0.25.0；基线：`4e8a7b9`；日期：2026-10-03。

用户已人工确认 0.24.6 摄食手感合适，Phase 2 关闭。依据本轮 Phase 3 规格 §52/55，只实现 P3.0+P3.1，完成后停在人工试玩门。P3.2 抢食、P3.3 社会警惕、P3.4 NPC Hook/错误目标、P3.5 平衡和 Phase 4 多竿未开放。

## Authority 保持小步扩展

- 原玩家 `fish/velocity/aim/stamina/satiety/hooked/score` 等 scalar 字段仍是唯一玩家权威。既有 QTE、wrap、rope、抄网和胜负路径不重构
- `npc_fishes` 是独立值记录；玩家 ID 固定 1，NPC ID 从 2 起，`next_fish_id` 单局内只增不复用，不等于数组索引
- 开发配置 `npc_count` 默认 3，范围 0–6，不暴露到普通玩法设置。NPC 与地图生成分离，不修改 `pond_v2`、1280×480、水体、巢穴、障碍或饵位 ABI
- `hook_target_fish_id=-1` 仅作后续保留，连玩家已上钩时也继续为 -1。本轮既有 `hooked/bound_bait` 管理玩家钩状态，没有提前启用目标鱼逻辑
- `npc_fish_state.gd` 定义可序列化内部状态、独立 seed 与校验。新鱼由 round seed + fish ID + 固定命名空间派生 seed，不消费主 `world.rng`

## Observation → Intent → Authority

`FishObservation.build(world)` 保持原玩家兼容入口，通过显式 `player_self()` 包装 `build_for(world, observer_state, include_visuals)`；字段、排序与可见信息不变。每条 NPC 只把自己的公开状态送入合法感知入口。

`npc_fish_brain.gd` 接收感知、自己的游动记忆、公开边界/邻鱼位置、规则、delta 与 NPC-local RNG；输出移动意图。它没有 World 引用，不能看 hook/truth/player suspicion，也不能修改位置、食物、饱食、Hook 或分数。

本轮仅 WANDER：主模拟 60 Hz，决策间隔 0.12 秒（固定 tick 实际约 7.5 Hz），保留 1.6–3.8 决策秒的游动朝向，平滑转向、预判边界和软避让。NPC 只避开玩家，绝不推动玩家或形成碰撞墙；与玩家相同，覆盖物允许鱼穿行。生成避开巢穴、可见饵和实心轮廓，移动始终限制在现有合法水体内。

## Schema、网络与显示

权威 snapshot schema 14 → 15，保留 FoodProfile authority guard 3。快照完整保存 ID、NPC 状态、决策计时和各自 RNG，校验通过后原子恢复；旧 schema14 明确拒绝。普通玩法方案格式与个人数值迁移不变。

`NPCFishPublicState` 仅投影 fish_id、position、velocity、aim、visual_variant 和固定 swim 动画状态，过滤 inactive。两种客户端都不接收 NPC RNG、目标、警惕、风险数值或内部决策权重。鱼端继续严格裁剪隐藏饵/Hook 信息。钓鱼人原有角色数据不在此轮重新设计，只新增独立 NPC 公共投影；显示历史按稳定 ID 插值，新增/移除/重排不会将不同鱼互相插值。

三种图案仅影响较小、较暗的轮廓与花纹，不改变速度/饥饿/风险。鱼视角 NPC 先于玩家绘制，玩家仍突出；岸边只有既有深度淡化的鱼影，观察视角沿用可见性规则。没有 NPC 名字、血条、警惕条或精确头顶图标。

## 验证与停止条件

新增套件登记到 `tests/suite_registry.json`，正式入口仍为 `tools/run_tests.py`。覆盖确定性/唯一 ID、主 RNG 隔离、玩家感知等价、隐私、重放、真实 ENet、合法水域、0/3/6 性能及原生像素检查；原 Phase 1/2 和当前回归门继续执行。

本轮 NPC 不进食、不抢食、不反应危险、不触发 Hook、不被抄网结算，不改变玩家分数或比赛结果。未来行为的统计实验（例如 P3.2 的 1000-seed food reachability）不提前实现，也不虚称已验证。

结果与人工清单见 [验证报告](../test-reports/PHASE03-AMBIENT-VALIDATION-0.25.0.md)。按用户要求仅提交推送源码，不生成新 ZIP 或公开 Release。
