# 当前架构：0.19

世界模拟、输入、AI、显示、联机分层继续保留。0.19 增加独立规则模块；完整职责与修改约束见 [RULES-ARCHITECTURE.md](RULES-ARCHITECTURE.md)。当前协议 0.22.4、快照 schema 12；水域与镜头见 [POND-ARCHITECTURE.md](POND-ARCHITECTURE.md)。以下为早期重构记录。

# 0.11：联机前的最小必要重构

> 本文记录 0.11 的重构边界。0.12 已接入双人联机，当前会话与延迟处理见 [联机指南](../gameplay/NETWORK.md)；快照 schema 随联机 QTE 等待参数升级为 2。

本轮保持现有单池塘、一条鱼、一个钓鱼人及原有操作。重点是使双方操作能送入同一个世界，且世界规则不再由“本机选择哪一方”决定。尚未连接网络、创建房间或增加多人实体。

## 分层

```text
local_input / fish_brain / angler_brain / 外部指令
                        ↓
                 game_commands
                        ↓
       world_simulation.advance_tick(鱼指令, 人指令)
               ↙                     ↘
    状态、快照、绝对胜者          feedback / match_ended
               ↓                     ↓
          pond_view          pond：音效、菜单、本机记录
```

`world_simulation.gd` 不读取 Input、不打开菜单、不访问存档；可不加入场景树直接运行。它保留 Node2D 基类，让原有绘制和回归测试继续使用现有字段，不引入大量转发属性。`pond.gd` 继承这个模拟，只承担本机应用层职责。`angler_rig.gd` 是世界内部钓组执行器，不是输入来源；自动调节的原公式留在这里以保留手感。

本轮不拆分全部鱼线和抄网子系统，不引入 ECS、通用实体框架或新的网络库。旧 `angler_controller.gd` 作为兼容入口保留。

## 世界启动及规则

```gdscript
var world = preload("res://scripts/world_simulation.gd").new()
world.reset_world({
    "ruleset": "duel",
    "challenge": true,
    "seed": 2649,
    "slack_hold": 0.5,
    "mouth_window": 0.4,
    "break_hold": 3.0,
    "line_sensitivity": 1.0,
    "line_force": 1.0,
    "water_strength": 1.0
})
world.advance_tick(fish_command, angler_command)
world.free()
```

`reset_world` 使用固定默认值，不继承上一局的调节值。单机应用层显式传入玩家保存的配置；以后对战则由房主提供同一份配置。时间与练习力度范围沿用既有设置。

| ruleset | 保留的规则 |
| --- | --- |
| `survival` | 原小鱼挑战／练习：固定钓位与补饵轮换；挑战超时由人类获胜。 |
| `duel` | 原钓鱼人挑战：可移动钓位、Q 下钩／补饵、手动抄网；挑战超时由鱼获胜。 |

两种规则与本机观看角色分开。后续真人鱼对真人钓鱼人应由双方共同使用 `duel`，不能让鱼客户端使用 `survival`。

`player_role` 仅在 `pond.gd` 决定本机视角、提示、输入映射和相对输赢。世界保存 `match_over`、`winner_role`（fish / angler）、`reason`；同一个结算在双方显示相反但一致的胜负。

## 双方指令

`game_commands.gd` 对本地、AI、外部指令统一做有限数值检查和范围限制。指令为纯值 Dictionary，不带节点或回调。

| 鱼指令 | 含义 |
| --- | --- |
| move / aim | 游动向量、朝向；世界负责速度、体力、拉力及锁定。 |
| power / suck | 吸力与持续吸食。 |
| dash / slow | 持续冲刺／慢游。 |
| qte / home | 当前 tick 按下空格／E 的一次性意图。 |

| 人类指令 | 含义 |
| --- | --- |
| walk / target | 沿岸方向与逻辑视口鼠标坐标。 |
| deploy | 当前 tick 按 Q 下钩／补饵。 |
| reel / release | 持续收／放线。 |
| net_hold / drag | E 与左键的当前按住状态。 |
| net_events | 当前 tick 内按原顺序排列的 point、cancel、suspend 事件。 |
| auto_reel / auto_net | 由现有钓鱼人 AI 启用的自动策略。 |

当前运行入口 `advance_tick` 固定推进 1/60 秒，先执行人类钓组指令，再执行鱼和世界规则。`simulate(delta, ...)` 用于已有不同步长回归检查。旧 `step` / `controlled_step` 为兼容测试保留；新接入应只调用双指令入口。

本机鼠标事件只写入输入缓存，不再直接移动网口或开始捕捉。下一次世界更新按序处理所有拐点；松键取消在本次扫网和捕获计算前执行。取消延迟最多一个正常模拟 tick，约 16.7 毫秒。同帧点击、拐弯、松键不会被压缩成单一终点。

`fish_brain` 输出与玩家同类的鱼指令；`angler_brain` 输出自动收线与自动抄网意图。指令提供器的内部决策记忆属于输入来源，世界只处理其输出。

## 快照

`capture_snapshot()` 返回与世界脱离引用的 Dictionary；`restore_snapshot(snapshot)` 校验后恢复，失败返回 false，校验失败时不部分写入。

- schema = 1，map_id = pond_v1。
- 显式列出全部可变世界及钓组字段，包括鱼、体力、颗粒及去重 ID、鱼钩、张力、线圈、QTE 序号、抄网路线／执行游标、计时、绝对胜负。
- 保存世界随机源 seed / state，恢复后的 QTE 随机区间可继续一致。
- 数组、Dictionary、PackedVector2Array 均复制，不共享活引用。
- 不含视角、键鼠、菜单、音量、本机胜场／存档路径、AI 决策记忆。固定地形由 map_id 对应的 Layout 提供。
- 恢复本身不播放音效、不重新弹结算、不重复写入胜场。

该接口用于本地快照及后续主机状态同步。验证覆盖格式版本、必要字段、字段类型、有限数值和部分范围；不是完整的陌生网络数据接收器。联网时仍需限制包长和集合长度、鉴权、角色权限及合法状态转换，不能直接接受客户端任意世界快照。AI 若要完整续档，应额外保存其决策状态；本轮恢复后重放使用相同的双方指令。

目前只验证相同引擎／运行环境、相同配置与指令的重放一致性，不承诺跨平台浮点逐位一致。后续仍以房主计算结果为准。

## 本机菜单与后续接入

现有单机菜单继续暂停本局，设置及记录保存行为保留。`start_shared_session(local_role, config)` 是内部接入测试入口，不在标题提供联机选项；该模式不自动推进，需要外部会话按 tick 提交双方指令。

内部共享模式中，本机菜单不暂停世界、不重开共同对局，也不能调节双方规则；`match_paused` 是明确的全局暂停状态。角色视角不会改变世界结果。结果与音效通过信号通知本机应用层。

下一阶段可在这个入口增加本机双进程 1v1：房主推进世界，客户端上传指令，房主回传快照。届时还需会话／实体归属、输入序号及去重、抄网手势序号、QTE 时间与延迟策略、插值和断线处理。本轮未实现这些网络行为。
