# BaitbreakPixel Phase 1.5 人工试玩修正门禁 + Phase 2 启动规格

版本：Draft v0.2 + Round 1 实施记录（0.23.1）  
日期：2026-10-02  
面向对象：开发 Agent / Codex / 后续自动开发流程  
当前开发分支：`feature/dev`  
当前源码版本：`0.23.0`（未发行）  
当前阶段：Phase 1.5 人工试玩修正门禁  
Phase 2 状态：**冻结，禁止提前实施**

---

# 0. 文档用途

这份文档不是普通设计说明，而是给开发 Agent 使用的**当前阶段执行规格**。

从现在开始，Phase 1.5 采用如下工作模式：

```text
Agent 完成一轮修复
        ↓
自动测试 / 打包
        ↓
用户人工试玩
        ↓
用户反馈需要调整的问题
        ↓
把反馈写入下一版阶段文档
        ↓
Agent 继续修复
```

重要原则：

> **人工试玩结果由用户给出，Agent 不得自行宣布“手感通过”“玩法好玩”或关闭 Phase 1.5。**

自动测试只能证明：

- 逻辑没有明显回归；
- 网络和快照结构仍然有效；
- 隐藏信息边界没有破坏；
- 某些数值指标满足预期。

自动测试不能代替：

- 操作手感；
- HUD 可读性；
- 动画反馈；
- 双方对抗体验；
- 是否真正有趣。

只有用户明确确认：

> Phase 1.5 可以结束 / 可以进入 Phase 2

之后，Agent 才能开始 Phase 2。

---

# 1. 当前仓库上下文

当前开发工作应继续基于：

```text
branch: feature/dev
source version: 0.23.0
```

不要从旧 `main` 重新开始。

当前已经存在并应保留的 Phase 0–1 基础包括：

```text
FishObservation
fish_network_observation
fish_id / rod_id / bait_id / hook_id
satiety
instinct_drive
suspicion_by_bait
risk_tolerance
CALM / UNEASY / ALARMED
event-random hook assignment
role-filtered network projection
RoundStats
batch simulation
policy comparison
snapshot schema 13
```

除非人工试玩反馈直接证明这些结构存在问题，否则本阶段不要重构它们。

---

# 2. 当前阶段的唯一目标

Phase 1.5 的目标不是增加新玩法。

当前目标是：

> **把现有 0.23.0 做到“可以正常、清楚、顺畅地人工试玩”。**

因此本阶段优先修复：

1. 操作阻断；
2. 角色初始状态错误；
3. 缺失的核心反馈动画；
4. HUD 可读性；
5. 数值手感。

暂时不要开发：

- 多种新饵料；
- 咬食；
- AI 鱼；
- 多鱼竿；
- 记忆；
- 自动吸食；
- 新地图。

---

# 3. 人工试玩反馈记录机制

每一轮用户反馈都追加到本节。

Agent 每次开始工作前必须先阅读最新反馈。

反馈状态只允许：

```text
OPEN
IMPLEMENTED
WAITING_FOR_PLAYTEST
CONFIRMED
REJECTED
```

其中：

- `IMPLEMENTED`：代码已完成，但用户尚未试玩；
- `WAITING_FOR_PLAYTEST`：已打包并等待用户确认；
- `CONFIRMED`：用户明确认为该问题已解决；
- `REJECTED`：实现方向不符合用户预期，需要重新设计。

Agent 不得自行把：

```text
WAITING_FOR_PLAYTEST
```

改成：

```text
CONFIRMED
```

---

# 4. 当前人工试玩反馈：Round 1

反馈来源：用户对 0.23.0 当前开发版本的人工试玩。

当前反馈如下。

---

## PF-001：警惕度字符位置过挤

状态：

```text
IMPLEMENTED
```

现象：

当前鱼侧 HUD 中：

```text
体力
警惕
饱食
```

区域的文字布局较拥挤。

“警惕”字符与附近 UI 元素之间的间距不足，视觉上显得挤压。

用户提供的当前 HUD 画面表现为：

```text
体力                    饥饿/警惕相关文本
[体力条]

警惕
```

当前问题重点不是修改警惕系统逻辑，而是：

> **调整 HUD 排版。**

### 要求

优先检查：

- 警惕文字的 x/y 坐标；
- 与体力 HUD 的垂直间距；
- 与屏幕右侧信息的水平间距；
- 低分辨率 640×360 viewport 下的实际像素布局；
- 中文像素字体宽度。

### 实现原则

不得通过：

```text
缩小到难以辨认的字体
```

简单掩盖问题。

优先考虑：

- 调整元素位置；
- 增加行距；
- 将状态信息统一成左侧纵向 HUD；
- 或明确分成左右两个信息区。

### 验收

Agent 自动验收：

- 不越界；
- 不重叠；
- native screenshot 正常生成。

最终验收：

> 用户人工确认视觉不再拥挤。

---

## PF-002：饱食度只有文字，缺少可视化条

状态：

```text
IMPLEMENTED
```

现象：

当前体力有：

```text
体力
████████████
```

但饱食度只有文字状态。

用户要求：

> **饱食度改成和体力类似的条形 HUD。**

### 目标

饱食 HUD 至少应该包含：

```text
饱食
[████████------]
```

条的长度、像素风格、边框和体力 HUD 保持统一语言。

### 推荐表现

不要求复制体力逻辑，只要求视觉体系一致。

例如：

```text
体力
[██████████████]

饱食
[████████------]

警惕
不安
```

或者：

```text
体力 [██████████]
饱食 [██████----]
警惕 不安
```

具体布局可以根据现有 HUD 尺寸决定。

### 数据来源

饱食条直接读取当前权威/鱼侧允许显示的：

```text
satiety
```

或经过合法投影后的自身饱食数据。

饱食条：

```text
0% → 空
100% → 满
```

### 不要做

不要新增：

- 数字百分比；
- 小数；
- 复杂食物图标；
- 动态渐变；
- 新动画系统。

本轮先保证：

> 简单、清楚、和体力条一致。

### 自动测试

增加或调整 native screenshot 检查：

- 满饱食；
- 中等饱食；
- 临界饱食；
- 极低饱食。

至少验证：

```text
bar width 随 satiety 单调变化
0 ≤ width ≤ max_width
```

最终视觉由用户人工确认。

---

# 5. 钓鱼人侧当前阻断问题

以下问题优先级高于 HUD 美化。

因为它们直接阻断钓鱼人角色正常试玩。

---

## PF-003：钓鱼人开局已经处于“下钩”状态

状态：

```text
IMPLEMENTED
```

现象：

选择钓鱼人角色进入一局后：

> 游戏刚开始就已经显示鱼钩/饵处于水中或已部署状态。

这与预期流程不符。

### 正确流程

钓鱼人开局应处于：

```text
READY / UNDEPLOYED
```

即：

- 鱼竿已持有；
- 玩家可以左右移动；
- 鱼线/钩尚未正式投入目标区域；
- 玩家主动执行下钩/抛投后才进入部署状态。

如果当前游戏设计仍使用：

```text
Q = 下钩 / 补饵
```

则初始状态必须允许玩家主动按 Q 完成第一次下钩。

### 检查范围

Agent 应重点排查：

```text
angler_rig.gd
world_simulation.gd
round initialization
bait initialization
cast state
deploy state
active bait state
```

重点确认是否存在：

- 初始 bait.active 默认 true；
- rig casting 状态恢复错误；
- round reset 沿用旧状态；
- 0.23.0 hook random 生命周期修改导致默认部署；
- view 层单独把未部署钩画出来。

### 原则

不要通过：

> “开局把钩藏起来，但逻辑仍然已经部署”

来修。

要求逻辑状态和表现状态一致。

---

## PF-004：钓鱼人左右移动速度过慢

状态：

```text
IMPLEMENTED
```

现象：

钓鱼人使用：

```text
A / D
```

左右移动鱼竿时速度明显过慢。

当前手感不能满足正常观察、调整落点和应对鱼移动的需要。

### 处理顺序

先确认：

1. 输入是否正常达到 authority；
2. 是否存在 0.23.0 新状态导致移动倍率被错误降低；
3. 本地与联机是否一致；
4. 当前移动速度规则值是多少；
5. 是否只是动画慢，还是实际 rig.x 移动慢。

如果逻辑正常而只是默认值偏低，再调整参数。

### 调参原则

不要直接大幅翻倍。

建议分阶段：

```text
current
→ +25%
→ +50%
```

通过 native / 实际移动距离验证后，提供给用户试玩。

### 验收

自动：

- 按住 A / D 固定时间；
- 验证实际位移；
- 左右对称；
- 不越出允许范围。

最终速度是否合适：

> 用户人工确认。

---

## PF-005：钓鱼人无法正常收线 / 放线

状态：

```text
IMPLEMENTED
```

现象：

当前钓鱼人角色下：

```text
W / S
```

不能正常执行收线 / 放线。

这是当前最高优先级阻断问题之一。

### 预期

按当前操作设计：

```text
W = 收线
S = 放线
```

必须对真实游戏状态产生可观察结果。

至少包括：

```text
spool / line length 变化
hook / bait 垂直或张力状态变化
对应钓竿/鱼线表现变化
```

### 排查路径

按顺序检查：

```text
Input
↓
angler command
↓
game_commands.gd
↓
network/local command adapter
↓
world_simulation
↓
angler_rig
↓
spool / free_line_length / reel_speed
↓
presentation
```

尤其检查：

```text
game_commands.gd
network_protocol.gd
angler_rig.gd
world_simulation.gd
network_presentation.gd
shore view / rod rendering
```

### 必须区分两类问题

A：

```text
逻辑完全没变化
```

B：

```text
逻辑有变化，但画面没有反馈
```

不要在没有确认 A/B 前直接修改动画。

### 自动验收

至少增加：

```text
hold W 1 second
→ line/spool state changes in reel direction

hold S 1 second
→ line/spool state changes in release direction
```

同时确认：

```text
W 和 S 不能得到同方向结果
```

以及：

```text
无输入时不会持续变化
```

---

## PF-006：收放线没有动画反馈

状态：

```text
IMPLEMENTED
```

现象：

即使玩家执行收放线操作，当前也缺少足够明确的视觉动画。

用户要求：

> 收线 / 放线需要动画反馈。

### 第一版目标

不需要制作复杂骨骼动画。

优先复用已有：

```text
reel_phase
release_phase
reel_hand_mode
reel_hand_amount
rod_load
rod_lift
```

以及已有手部 / 卷线器动画基础。

目标：

### 收线时

至少看到：

- 卷线器旋转；
- 手部有周期动作；
- 鱼线长度变化；
- 必要时竿尖响应。

### 放线时

至少看到：

- 线从卷线器放出；
- reel 动画方向/状态与收线有区别；
- 手部表现与收线不同或弱化；
- 鱼线实际伸长。

### 关键原则

动画必须由真实状态驱动：

```text
reeling state
release state
spool delta
```

不要只根据：

```text
按键是否按下
```

播放假动画。

否则网络 / QTE / 状态禁止收线时可能出现：

> 画面在收线，逻辑没有收线。

### 自动验收

native test 至少覆盖：

```text
idle
reeling
releasing
```

并验证关键帧不同。

最终动画是否清楚：

> 用户人工确认。

---

# 6. 当前任务优先级

必须按以下顺序处理。

## P0 — 操作阻断

```text
PF-003 开局错误下钩
PF-005 无法收放线
```

这两个问题不解决：

> 不继续做手感评估。

---

## P1 — 钓鱼人基础手感

```text
PF-004 左右移动过慢
PF-006 收放线动画缺失
```

---

## P2 — HUD 可读性

```text
PF-001 警惕位置拥挤
PF-002 饱食条
```

---

# 7. 本轮 Agent 实施顺序

建议严格按：

```text
Step 1
复现 PF-003 / PF-005

Step 2
修复钓鱼人初始部署状态

Step 3
修复收放线逻辑

Step 4
确认左右移动逻辑后调整速度

Step 5
补收放线动画反馈

Step 6
调整鱼 HUD 布局

Step 7
增加饱食度条

Step 8
运行 targeted regression

Step 9
运行 current regression

Step 10
native screenshots

Step 11
构建 0.23.x 本地试玩包

Step 12
等待用户人工试玩
```

不要把：

```text
Step 12
```

自动解释为：

> “阶段完成”。

---

# 8. 版本处理

当前源码：

```text
0.23.0
```

本轮属于 Phase 1.5 修复。

如果项目当前约定每个可试玩修正版递增 patch：

推荐：

```text
0.23.1
```

不要直接进入：

```text
0.24.0
```

因为：

> Phase 2 尚未开始。

后续 Phase 1.5 的继续修复可使用：

```text
0.23.2
0.23.3
...
```

Phase 1.5 最终通过后：

```text
0.24.0
```

才用于 Phase 2。

---

# 9. 本轮测试门禁

至少执行：

## 钓鱼人 targeted tests

覆盖：

```text
initial undeployed state
first deploy
angler horizontal movement
reel
release
reel/release exclusivity
line length/spool state
animation state
reset/restart
```

## Phase 0–1 regression

重点：

```text
phase01_observation
phase01_satiety
phase01_instinct
phase01_suspicion
phase01_random_hooks
phase01_network
```

确保修钓鱼人没有破坏：

> 鱼的信息边界。

## Native

至少截图：

```text
fish HUD normal
fish HUD low satiety
fish HUD uneasy/alarmed
angler idle
angler reel
angler release
```

---

# 10. 本轮不重新跑大规模统计的条件

如果此次只修改：

- 钓鱼人初始状态 bug；
- 输入链 bug；
- 钓鱼人动画；
- HUD 排版；
- 饱食条；
- 钓鱼人横移速度；

通常不需要立刻重跑：

```text
1000-pair cautious vs distance
```

但如果调整：

```text
hook logic
suspicion weights
satiety decay
instinct strength
```

则必须重新考虑对应统计门禁。

---

# 11. 本轮人工试玩入口

Agent 完成后，用户下一轮优先测试：

## Angler Quick Check

1. 选择钓鱼人；
2. 确认刚开局钩未自动部署；
3. A / D 左右移动；
4. Q 第一次下钩；
5. W 收线；
6. S 放线；
7. 观察手、卷线器、竿与线的动画；
8. 重开一局确认状态重置。

## Fish HUD Quick Check

1. 选择鱼；
2. 查看体力 / 饱食 / 警惕布局；
3. 等待饱食下降；
4. 确认饱食条同步缩短；
5. 触发不同警惕状态；
6. 检查文字是否仍拥挤。

---

# 12. 下一轮反馈写入规则

用户下一次试玩后，无论反馈多少，都继续追加：

```text
Round 2
PF-007 ...
PF-008 ...
```

不要删除已经解决的问题。

已解决的问题改为：

```text
CONFIRMED
```

保留历史。

这样这份文档同时承担：

> Phase 1.5 的人工验收日志。

---

# 13. Phase 1.5 总门禁

Phase 1.5 当前仍然：

```text
OPEN
```

至少在以下条件全部成立前不得进入 Phase 2：

### Fish

- 饱食 HUD 清楚；
- 警惕 HUD 清楚；
- 本能可理解、可抵抗；
- 警惕会影响玩家选择；
- 玩家不会把警惕当成确定钩检测器。

### Angler

- 正确未部署开局；
- 可以正常首次下钩；
- 左右移动速度可接受；
- 可以正常收线；
- 可以正常放线；
- 收放线有清晰动画；
- 重置后状态正确。

### Network / architecture

- FishObservation 边界不退化；
- hook truth 不泄露；
- snapshot / replay 保持有效；
- 双人联机核心流程正常。

### Human

最终由用户明确确认：

> “Phase 1.5 可以结束。”

---

# 14. Phase 2 状态

当前：

```text
LOCKED
```

Phase 2 仍定义为：

# Feeding Choice Expansion

包含：

```text
多种饵料
+
嘴部直接咬食
```

但本轮 Agent：

> **不得开始实现。**

只有收到用户明确指令：

```text
进入 Phase 2
```

之后才解锁。

---

# 15. Phase 2 解锁后的第一批任务

解锁后仍按之前规划：

```text
P2.1 bait_type / food_profile
P2.2 FishObservation shape/smell
P2.3 饵型视觉差异
P2.4 bite command
P2.5 mouth-contact bite resolution
P2.6 suck vs bite balance
P2.7 network projection
P2.8 regression
P2.9 human choice validation
```

并继续遵循：

> 每一小阶段完成 → 用户人工试玩 → 反馈进入下一版文档。

---

# 16. Agent 执行原则

本阶段 Agent 必须遵守：

1. **先修阻断，再美化。**
2. **先复现，再修改。**
3. **每个问题都要能对应到测试。**
4. **不因“自动测试通过”宣布人工问题解决。**
5. **不提前开发 Phase 2。**
6. **不要大规模重构已经通过 Phase 0–1 验证的信息边界。**
7. **不要顺手加入用户未要求的新玩法。**
8. **完成后生成本地试玩包，等待用户确认。**
9. **下一轮用户反馈继续写入本阶段文档，而不是开启新的无关设计文档。**

---

# 17. 当前 Agent 的直接任务

当前最新人工反馈已经明确。

下一轮开发只处理：

```text
PF-003 开局自动下钩
PF-005 无法收放线
PF-004 横向移动太慢
PF-006 收放线缺少动画
PF-001 警惕 HUD 拥挤
PF-002 饱食度改成条
```

优先级：

```text
PF-003
  ↓
PF-005
  ↓
PF-004
  ↓
PF-006
  ↓
PF-001 + PF-002
```

完成后：

```text
测试
→ 打包
→ 等待用户人工试玩
```

不要继续扩展其他玩法。


---

# 18. Round 1 实施记录：0.23.1

来源：2026-10-02 用户的 v0.2 文档。上文保留规格与历史基线；当前开发源码已递增为 0.23.1。

六项当前均为 IMPLEMENTED；待包验证完成后才改为 WAITING_FOR_PLAYTEST。Phase 1.5 仍 OPEN，Phase 2 仍 LOCKED。没有人工 CONFIRMED 项。

- PF-003：复现不是初始权威状态已部署，而是岸上表现按隐藏 hook 标记选择了环境饵。真实主鱼竿已正确未部署。现改为按 tackle + active + not removed 找自己的部署状态；开局提示“未下钩 · 按 Q”。不改随机钩生命周期，也不采用“仅藏画面”的补丁。
- PF-005：种子 42、731、2649 均复现 W/S 实际长度可改变（1 秒 W −32.55、紧接 S +62.625），但未下钩假象/错误跟踪对象让操作不可理解。种子 2649 首次下钩为无钩饵，原来仍画环境钩饵。修正为同一物理 tackle，验证键位→本地输入→命令→网络序列化/净化→权威→快照表现一致。
- PF-004：原始 authority 实测 1 秒移动 72 单位，无倍率错误；默认改为 90（+25%），左右对称并受边界约束。已有保存规则不强制覆盖，试玩旧档请仅将 F2 对应值设为 90。
- PF-006：复用真实 reel_phase / release_phase / reel_hand_mode；增加随真实收放线方向运动的线段高亮，空闲线的松弛按真实线长计算。状态文字也改用实际速度，未部署、极限、嘴部判定或提鱼时不产生虚假收放反馈。
- PF-001：鱼 HUD 顶栏增加到 49 像素高，警惕标签独立第二行并用 11 像素字体，和体力条/本能提示留出间隔。
- PF-002：自身许可感知增加 satiety 值；饱食显示为与体力相同 70×3 像素条，不显示数字百分比。网络鱼侧早已允许自身 satiety，未增加隐藏钩信息，snapshot schema 保持 13。

测试、打包信息与明确未覆盖范围见 ../test-reports/PHASE15-VALIDATION.md。人工步骤见 ../gameplay/PLAY.txt 的 0.23.1 节。后续反馈在本文追加 Round 2 / PF-007 等；只有用户明确确认才能标为 CONFIRMED。
