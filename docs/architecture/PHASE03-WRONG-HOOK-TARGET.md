# Phase 3.4 · 钓错目标

版本 0.25.3；基线 `6a2f124`（含用户的 0.25.2 Windows 发布文档）；2026-10-03。用户确认 0.25.2 社会线索试玩通过后，仅推进 P3.4，结束 STOP 等待本轮人工门。

## 单根线与玩家兼容

`hook_target_fish_id` 为 -1（无目标）、1（玩家）、大于1（稳定 NPC ID），不是数组下标。仍只有一组 `bound_bait / rope_path / rope_length / tension / reel_speed`。原 `world.hooked`、`landing`、QTE、wrap、体力、计分与回巢均保持玩家专用；NPC 中钩时玩家仍是 FREE，可以正常游动、摄食和回巢。玩家自己的上钩、入口/松线 QTE、缠线、张力、断线、提鱼与胜负逻辑不降级。

`line_hooked()` / `line_landing()` / `hook_target_mouth()` 为钓组、公开表现和线端提供目标无关查询。已占线时不能 Q 重新部署或替换目标；同一 tick 同一钩的重合候选按玩家兼容优先、NPC 稳定 ID 顺序处理。抄网仍只检测玩家；NPC 不作为抄网捕获或胜负目标。玩家练习模式的抄网回巢不清除另一个 NPC 的线状态。

## 真实接触

所有鱼使用唯一 `FishFeeding.mouth()` 和同一连续相对钩尖扫掠判定，保留原玩家嘴前 3 px 的接触几何与原半径。食物 10 px 自动 Bite、0.80 s 成功冷却、4/6/8 容量、吸食距离场和 FoodProfile 不变。先处理真实钩接触，再授予摄食；没有按 NPC 食欲概率掷一次“中钩”。未接触之前，Brain 仍仅接收 detached Observation、自身状态与 NPC-local RNG。

每 tick 先保存 NPC 嘴部位置，独立更新生态运动；钩尖与鱼嘴的相对扫掠同时涵盖移动钩和游过钩尖的鱼。已有目标时其他鱼不能抢占这根线。NPC 的 Hook 是 authority 接触结果，不是 Brain 指令。

## 简化挣扎与结果

`npc_hook.gd` 单独维护 NPC 线阶段、时间和抬起起点，阶段只有空、hooked、landing。挣扎方向/强度来自稳定 ID 派生相位与经过时间，不消费主 Hook/QTE RNG，也不额外消费 NPC 决策 RNG。NPC 中钩期间不运行 forage/social Brain、吸食或 Bite。

钓鱼人 W/S 和自动对手继续使用原 `AnglerRig.spool_target / manual_spool_speed`，相同线长上限、弹性、拉力和断线阈值。NPC 用简化摆动抵抗，随时间疲劳；连续松线达到原 slack_hold 加 0.65 s 后自动脱钩，无玩家 QTE。持续高张力达到原 break_hold 会断线；靠近岸边且有张力，按原 landing_hold / landing_lift 提鱼。NPC 没有 wraps、独立得分或 home 目标。

脱钩/断线仅清理 NPC 线，NPC 恢复活动并有 2 s 自身再接触保护。捕获时移出 active ecology，钓组失效、附着食物随捕获离开且不计任何玩家/NPC摄入，钓鱼人需重新挂饵部署；现有非手控钓组补给恢复该饵槽。捕获 NPC 永不调用 finish，也不修改 match_over、winner_role、玩家 Hook/逃脱计数或得分。8 s 模拟时间后移除旧记录，调用原确定性合法 spawn，分配全新 fish_id；暂停和终局冻结所有计时。合法出生失败会延迟重试，不回收旧 ID。

其他非占线饵仍走原补给循环；正在处理的钩饵不会被补给警告、替换或吸动打断。开启 NPC 抢食的练习模式继续补给，不降低玩家目标。本轮不重新调整已人工接受的 P3.2/P3.3 食欲、竞争或社会行为参数。

## 可观察结果与保密

真实 NPC 附钩发布原社会危险事件，附近 NPC 可据此受惊；这是已经发生的结果。另有明确的公开结果记录（tick、稳定鱼 ID、hooked/escaped/broken/captured、发生位置），没有未接触食物的 hook 标签。原六字段 NPC public state 增加允许的 hooked/landing 动画值，不新增目标饵、饱食、警惕、风险、挣扎相位、计时或 RNG。

两个角色同步真实线目标 ID、只含 phase 的 NPC 线表现、正确嘴部线端、位置和结果。原全局张力历史计时继续服务既有断线风险 HUD；它是已发生的公开线状态，不是 NPC 私有挣扎/决策计时。岸边仍为模糊鱼影，鱼视角仍以金色玩家为主，不添加 NPC 名称、血条、警惕条或精确 debug 图标。已发生的 NPC Hook 可见，其他钩仍遵守原角色裁剪。Angler 既有自身钓组 authority 字段保持原协议边界，本轮不把其旧权限伪称为新增保密。

## Snapshot、网络与统计

Authority schema15、FoodProfile guard3 保持。NPC Hook 私有字段与 hook_immunity、捕获/重生状态使用 exact shape/type/finite-value 与目标/阶段关联校验；旧 0.25.2 不完整记录明确拒绝。玩家 HookState 与 target=1 必须一致；NPC target 必须对应唯一 active hooked/landing NPC，不能同时有玩家 QTE、landing 或 wraps。恢复失败不写入世界。

网络 exact-build=0.25.3；鱼端 NPC guard2，钓鱼人 guard4。钓鱼人表现通过专用 public 验证入口恢复，不伪造 NPC brains 来通过权威校验。渲染历史仅保存 public record，同 ID 连续运动插值，目标阶段变化/移除/新 ID 不跨鱼插值，线端每帧重建。

新增私有统计 `npc_hook_count / npc_escapes / npc_breaks / wrong_catches / npc_hooked_seconds`，不混入玩家胜负和原玩家 Hook 指标，不外发开发统计。四组自动策略 NoNPC、PassiveNPC、ForagingNPC、HookableNPC 使用同一旧 P2 Mixed 与 AnglerBrain，只用于发现不可玩状态；不以 50% 胜率为目标，不用机器人差异擅自重平衡。

## 范围和停止条件

本轮不改 `pond_v2`、1280×480、HOME/SPAWN/SOLIDS/PLANTS/BAIT_SITES，不改 Watergen，不加第二根鱼竿、NPC 抄网、长期记忆、新阵营或复杂生态。正式验证与人工试玩项见[0.25.3 报告](../test-reports/PHASE03-HOOK-VALIDATION-0.25.3.md)。只提交推送源码，不生成新下载包。P3.5 和 Phase4 均等待用户后续授权。


## 0.25.4 试玩修正补充

上文保留 0.25.3 实施时的数值与验证范围。0.25.4 根据人工反馈仅给 NPC 的向内 spool 目标和物理 line pull 增加 1.8 倍系数，继续通过原执行器积分，放线速度、逃脱/断线条件、岸边确认和提鱼动画不变；玩家规则和生态游动/摄食完全不调整。NPC 的钓错处理仍有可见占线成本。

玩家 QTE 准备期目标尚未显示时只消费空格；绿区、扫动总时长、失败与终局条件保持。缠线在真实移动/抄网后检查准入，失去接触会解释中断而不隐式锁住玩家移动；准备期接触/张力中断不记技能已判失败。暂停、失焦和重开后的界面空格要先释放，才能形成新的游戏判定。

网络同批指令允许后续可见判定替换此前被忽略的准备期按键，但第一次可见判定仍有唯一所有权，不挑选后来的绿区作弊。所有年龄仍来自 authority history；exact-build 改为 0.25.4，schema15 与角色 guard 不变。详见[修正验证](../test-reports/PHASE03-HOOK-FIX-0.25.4.md)。
