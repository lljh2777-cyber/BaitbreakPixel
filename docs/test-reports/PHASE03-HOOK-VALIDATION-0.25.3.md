# P3.4 · NPC 钓错目标验证 0.25.3

2026-10-03；`feature/dev`；基线 `6a2f1244fd3ba1db81fc507a26e3830d13f1cc62`，保留其中用户发布的 0.25.2 Windows 文档。用户确认 P3.3 人工通过后，仅实施 P3.4。当前源码 0.25.3，本轮按要求只提交推送源码，不生成 ZIP/PCK/EXE/Release；公开包仍为 0.25.2。

## 结果与边界

一根原有鱼线现可被真实接触钩尖的 NPC 占用。目标 ID 区分无目标、玩家与 NPC；NPC 自动挣扎，可通过钓鱼人正常 W/S 操作逃脱、断线或被拉起。钓错 NPC 不触发比赛结算，玩家继续吃饵/回巢；捕获 NPC 移出活动生态，8 s 后以新 ID 补充，钓组需重新部署。

玩家原入口/松线 QTE、wrap、张力、断线、回巢限制和提鱼保持；10 px / 0.80 s / 4/6/8 自动摄食与既有抢食、社会行为和补饵数值不重调。没有 NPC 抄网捕获、第二根竿、新阵营、P3.5 平衡扩展、Watergen 或地图 ABI 变化。[实现边界](../architecture/PHASE03-WRONG-HOOK-TARGET.md)。

## 正式门禁

环境为 Linux 云端，Godot 4.7.2 official `ed1daf0bf`，原生画面使用实际 X11 桌面、Compatibility/Mesa llvmpipe；音频 Dummy。

| 检查 | 最终结果 |
|---|---|
| 注册 current headless + editor import | 57 套无窗口、244,509 个断言，0 失败；另有 import 通过 |
| 注册 native + editor import | 21 套原生、683 个断言 + 2 个完成标记，0 失败；另有 import 通过 |
| Python runner / 分析完整性 | 101 项通过，其中 41 项为新四模式诊断约束 |
| 新 `phase03_npc_hook_target` | 69/69 |
| Snapshot 全量/Hook 重放与非法状态 | 5,463/5,463 |
| NPC 网络/双角色真实 ENet | 497/497 |
| 新原生 NPC Hook | 86/86 |
| 独立状态机补充探针 | 258/258 |
| Food reachability | 1,000 seeds × survival/duel × challenge/practice，4,000 场景通过 |

这里“通过”只指注册的当前门禁，未重跑或声称所有 historical/retired 旧测试通过。两个完成标记不混记为断言。没有超时、blocked 或跳过的当前门禁。

可复现入口：

```sh
python3 tools/run_tests.py --godot "$GODOT" --import --profile current
python3 tools/run_tests.py --godot "$GODOT" --import --profile native
python3 -m unittest discover -s tests/runner -v
```

逐套计数和命令见[headless summary](data/phase03-hook-0253/headless-summary.json)、[native summary](data/phase03-hook-0253/native-summary.json)、[Python 输出](data/phase03-hook-0253/python-runner.txt)。原生消费的 174 个运行时/资源/原生测试/runner 文件在前后保持一致，见[native provenance](data/phase03-hook-0253/native-provenance.json)；最终运行时代码指纹见[source manifest](data/phase03-hook-0253/runtime-source-manifest.json)，headless 测试指纹见[headless provenance](data/phase03-hook-0253/headless-provenance.json)。不提交不透明压缩 runner 总日志，保留逐套摘要和少量完整可读定向证据。

## 核心覆盖

- 真嘴部接触、移动钩与移动 NPC 的连续相对扫掠、旋转嘴部、仅身体接触不算、隐藏钩接触前等价
- 单目标互斥、玩家/NPC 分流、同 tick 稳定 ID 次序、数组重排后正确线端、占线期间不能 cast/deploy 或让补给替换该饵
- NPC 中钩期间玩家自由移动、真实摄食和回巢；NPC 不消费主 Hook/QTE RNG，玩家统计不串入 NPC 结果
- 正常 W/S 收放线、松线自动逃脱、持续高张力断线、真实 lift/capture、不结束比赛、延迟新 ID 重生、再接触保护
- 暂停/终局冻结；练习抄网抓到玩家后回巢不误清 NPC 的线；抄网检测仍只针对玩家
- schema15 exact shape/type/finite-value 与目标/阶段关系，非法恢复原子拒绝；中钩、提鱼、捕获、重生连续重放
- 鱼端/钓鱼人端均通过真实 ENet UDP peers 同步接触、线端、逃脱、断线、捕获、移除和重生；每个角色包括错误状态和私有字段拒绝

当前 P3.4 ENet 用同一进程内两个独立 peer 节点，不能描述为本轮跨设备或双独立进程验证。之前独立进程的历史结果保留自身范围。

## 隐私与原生画面

NPC Brain 继续只看合法 Observation。私有 Hook record 的挣扎相位、RNG、饱食、警惕、食物目标、决策/恢复计时不进入公共 NPC 数据；已实现的目标 ID、phase、嘴部位置与 Hook/escape/break/capture 结果可见。原全局张力历史计时仍用于既有风险 HUD，属于已发生的线状态。未接触的其他 bait Hook truth 不因 NPC 附钩而公开。

新原生测试检查 hooked/landing/escaped/broken 在鱼、岸边、观察三个视角的重复像素稳定、公开副本等价，以及未接触 Hook truth / 私有 NPC 状态污染的像素等价。玩家继续是金色主角，NPC 没有名字或数值状态条；鱼线随 NPC 嘴，抬起结束后去除鱼和鱼线。实际云端 Godot 窗口也查看了中钩、提鱼和钓错后重新部署画面。[原生评审与限制](data/phase03-hook-0253/native-review.md)。

旧 P3.3 社会层控制另重复 720 组配对，0 observation/authority mismatch；自然无目击预测分类器 balanced accuracy 51.36%，未越过 90–95% 审查线。该控制显式关闭 NPC Hook 以保留其原设计范围；不把它伪称为 720 次完整 P3.4 中钩对局。P3.4 的接触前开启 Hook 等价及实际结果后的角色裁剪由新 authority/network/native 测试覆盖。[社会回归摘要](data/phase03-hook-0253/social-regression-summary.txt)与[分析](data/phase03-hook-0253/social-regression-analysis.json)。

## 四组自然策略比较（不据此调平衡）

相同旧 P2 Mixed 玩家与 AnglerBrain、默认规则、真实 60 Hz。Pilot 为 4×4=16 场，heldout 为互不重叠的 seeds 64401–64425，25×4=100 场。370 s 观察上限，所有 100 场均自然终局，无删去输局或未终局冒充胜利。正式 source fingerprints 一致；此前因阶段标签修正而中止的运行仅保留在本地 artifacts，未纳入下列结果。

| Heldout 模式 | 鱼获胜 | 玩家平均食物 | 平均局时 | NPC Hook / 错捕总数 |
|---|---:|---:|---:|---:|
| NoNPC | 10/25 = 40% | 51.20 | 71.54 s | 0 / 0 |
| PassiveNPC | 10/25 = 40% | 51.20 | 71.54 s | 0 / 0 |
| ForagingNPC | 7/25 = 28% | 46.34 | 64.00 s | 0 / 0 |
| HookableNPC | 12/25 = 48% | 48.31 | 64.94 s | 32 / 25 |

NoNPC/Passive 每个种子的既有结果完全一致。Hookable 的 32 次 Hook 来自自然嘴部接触，分布在 19/25 场；25 次错捕分布在 14/25 场。另有 1 次自然逃脱、0 次自然断线、6 次在线上时主比赛先结束，计数闭合。自然断线缺少样本，不拿 0 当作路径覆盖；受控 W/S/张力用例独立验证该路径。NPC 平均占线 9.47 s/场，最多 31.93 s（64404），该种子自然错捕四次。

Hookable−Foraging 配对差：鱼胜率 +20 个百分点，固定种子 bootstrap 95% 区间 [0,+40]；玩家食物 +1.962，区间 [−5.754,+8.568]；玩家 Hook −0.16/场，区间 [−0.32,−0.04]；局时 +0.941 s，区间 [−6.623,+7.746]。Hookable−NoNPC 胜率 +8 点，区间 [−20,+36]。这些仅描述 25 个种子与不会玩家 QTE 技巧的控制器，不能外推为真人胜率、最终公平性或要求 50%。未重调此前用户接受的 P3.2/P3.3 参数。

不利结果完整保留：Hookable 13 场输局，最低食物为6（64413，抄网输）；最长不进食 31.2 s（64407）。全场无可食物的最长连续段：NoNPC/Passive 0 s、Foraging 19.667 s、Hookable 4.45 s（后两组均64423）。这不是永久 supply deadlock；Hook/net 期间原补给条件可暂时关闭。独立结构性 supply 见证仍在全部4,000场景中达到原食物目标，补给可运行时最长空窗423 tick=7.05 s，不等于机器人每场都能获胜。

完整[100 场原始记录](data/phase03-hook-0253/diagnostic-heldout-rounds.json)、[配对统计/区间](data/phase03-hook-0253/diagnostic-heldout-comparison.json)、[正式 provenance](data/phase03-hook-0253/diagnostic-heldout-provenance.json)、[源码及重新分析核验](data/phase03-hook-0253/diagnostic-source-verification.json)和[实验协议](../../tools/phase03_hook_protocol.md)均随源码保存，pilot 单独列档。

## 修正与验证限制

初次 headless 只有旧社会层负例“HOOKED 一律非法”失败；P3.4 已授权该状态，改为仍非法的 WRAPPED，另增加基本 Hook record 允许用例，完整世界关联仍由 snapshot 的孤儿目标负例拒绝。最终该套963/963，并完整重跑 current。新原生最初两处夹具问题和完整运行中止原因在原生评审公开记录，未放宽生产隐私/线端断言。菜单/启动日志已同时标记0.25.3与P3.4钓错目标。

原生软件渲染的 V-Sync 限制和四个既有 ObjectDB 退出警告见[warnings](data/phase03-hook-0253/native-warnings.json)；本轮没有新增 NPC ObjectDB 警告。0/3/6 NPC 下模拟、payload、snapshot 和冻结帧成本保留测量，共享云环境与并发测试会影响墙钟，不能当本机长期 FPS 承诺。

本轮未生成或验证 Windows 导出包，未测试实际声卡、公网 NAT 或跨物理设备。自动检查和少量实际窗口观察不替代用户对挣扎、机会窗口、错捕代价和辨识度的人工判断。远端提交/tree 与 exact-commit CI 状态将在发布完成消息中核对；没有配置 checks/runs 不能当作 CI 通过。

## 当前人工试玩门：P3.4，完成后 STOP

1. 看 NPC 接近钩饵：误咬是否自然、是否太频繁；真实中钩后线应始终跟着那条 NPC 的嘴
2. 钓鱼人用 W/S 尝试拉起、松线逃脱和高张力断线；钓错 NPC 后比赛继续，并需要重新部署
3. 鱼玩家趁 NPC 占线继续吃饵、回巢；机会是否明显、有趣，玩家是否仍是比赛核心
4. 钓走 NPC 后约8 s出现新鱼，无旧目标复活、悬空线或卡住；暂停/终局不会悄悄推进重生
5. 回归玩家自己的入口/松线 QTE、缠线、断线、回巢限制和提鱼结算，确认没有被 NPC 简化玩法影响
6. 两端同为0.25.3交换角色，观察目标、线端、捕获/逃脱一致；抄网不捕获 NPC，岸边不出现精确 NPC 数值标签
7. 判断“钓错鱼”的时间/注意力代价是否合适，能否从实际行为逐步判断目标，而不是得到未接触钩的固定答案

P3.5 与 Phase4 多竿继续锁定，等待用户反馈。
