# Phase 5 实施与验证记录

基线：feature/dev 002cbaa；用户于 2026-10-05 授权完成剩余 P5，覆盖原规范第一轮 STOP。

## P5.2 / P5.3：实际比赛

- 新增 MapResolver：严格验证内置来源或生成 recipe，双验证后建立普通 MapContext。最多缓存 16 个已验证生成上下文；不接受远程几何。
- WorldSimulation.reset_world 接受 map_source；失败发生在状态/RNG 安装前。
- 路由由已验证来源选择：经典 pond_v2 保持 (9,631,309)，generated_pond_v1 使用 (9,1271,430)。Map contract 仍为 1，几何 hash 未改变。
- 结构 Gate 增加六条分散的保守净空提网通道；真实 Net 的碰撞/出水、Bite、三类食物、NPC 误钩、玩家 QTE、缠线/解缠、回巢通过实际 World 测试。
- 开发入口：运行主游戏并加 `-- --map-seed=42`；菜单接入将在后续 P5.6 完成。

验证：phase05_runtime 832 项、phase05_playability 17 项、phase05_generator_determinism 506 项、phase04_map_fixture 122 项通过。更新后 10,000 seeds / 20,000 检查通过，结果见 data/phase05/seed-sweep-runtime.json。主场景 Seed 42 启动通过。首次测试暴露测试数据复用 grain ID 和 recipe 插入 StringName 键，已修正并重跑；没有放宽契约检查。

所有几何身份使用必要的 content_hash；状态重复性直接比较值/序列化字节，无逐文件或逐帧 SHA256 扫描。

## P5.4：存档与联机（源码 0.27.3）

- Snapshot schema 17 / fish public schema 3：map_source + map_ref 必填。恢复先本地重建、双验证和内容标识核对，再验证/写入状态。旧 schema 明确拒绝。
- ENet hello 验证客户端已知地图能力；welcome 由房主选择 recipe，客户端本地重建后才可 Ready。Ready / start / ack / state 均严格匹配已选 recipe 与 MapRef；不传几何。
- tick 路径只核对标量身份；生成上下文缓存有界，不逐帧重新生成或计算 hash。
- 新测试：phase05_snapshot 126 项，phase05_network 72 项（两种角色、三张地图真实 ENet，另测六类拒绝）。既有 phase04_map_network 282 项、phase04_map_snapshot 298 项和 architecture_v020 60 项通过。
- 回归：phase02_bait_network 94、phase02_bite_network 136、phase03_npc_snapshot 5463、phase03_npc_network 497、phase04_snapshot_equivalence 8449、phase04_map_equivalence 7589 项通过。既有语义/隐私断言保留，仅更新新 schema / recipe 元数据契约。

## P5.5：Watergen 视觉适配

从 feature/watergen 的 63112b1a161975e466639525dff5deb1fd252b80 按模块移植公共契约、分层生成、像素烘焙、气氛/动态枝叶和视觉底床；没有合并该分支历史或替换玩法。

WatergenPublicAdapter 仅接受普通 MapContext，按公共交互目标导出轮廓与材质元数据。公共契约升级为 2，支持 generated map ID。真实木石、草、联合木组透明度继续由 MapPresentation 绘制；背景底床以低对比度叠加，不改变可移动范围或碰撞。

视图使用独立 visual_seed 与最多两个 GPU bundle；同图同视觉种子复用纹理。移植时删除逐装饰物 SHA seed derivation、逐图像 RGBA SHA 和 cache key 再哈希，改为显式整数视觉派生、直接像素/状态比较。只保留用于数据身份与缓存隔离的公共地图/视觉配置摘要。

验证：phase05_watergen_boundary 298 项（包括三张地图完整局、两组视觉种子下的全 Authority 与 RNG 演化一致）；phase05_gameplay_native 61 项（普通/开阔/密集/极端/手动 Seed 五地图及岸边视角，实际 GL 截图，视觉 Seed 改变像素而不改变状态）。截图已人工查看；这是 agent 的图像审查，不代替用户最终体验确认。

经典回归也通过：phase04_map_native 44、phase04_map_presentation 442、phase04_shore_projection 3036 项。

## P5.6：玩家入口（0.27.5）

标题提供经典/生成池塘选择、随机/手动/复制 Seed；本地设置保存选择。R 和普通重开保留地图，暂停/结算中的“新地图”显式换 Seed。房主将所选 recipe 带入房间，客户端显示相同 Seed / generator version；连接期间不能本地换图。

- phase05_ui 19 项通过：真实菜单信号、非法/手动 Seed、物理 R 路由、重开、新地图、保存/加载、host 配方和客户端锁定。
- 原生图像审查发现生成木枝的旧固定 6 px 材质轴会压成深色，现按真实多边形提取材质中心线和宽度。联合组 alpha / 交互轮廓不变。更新后 native 61、presentation 442、wood_fade 57 项通过。
- 发行 PCK 显式包含 data/watergen/*.json，防止导出丢失视觉配置。试玩说明和源版本同步为 0.27.5。

## P5.7：统计门与极端样本

`tools/phase05_run_gameplay.py` 执行 25 map seeds × 20 simulation seeds × 2 controllers，共 1,000 完整局；两种规则各 500 局，默认规则、3 NPC、60 Hz、370 秒有限保护。所有 1,000 局合法结束且最终 Snapshot 可恢复，最长 138.07 秒；没有命中“补饵条件允许时持续 20 秒无饵且无新供应”的死锁门。测试没有注入食物或降低胜利条件。

| 控制策略 / 规则 | 局数 | 鱼胜率 / 回巢率 | 平均时长 | 抄网捕获率 |
| --- | ---: | ---: | ---: | ---: |
| Native AI / 生存 | 250 | 95.6% | 47.56 s | 0% |
| Native AI / 对抗 | 250 | 88.0% | 52.92 s | 1.6% |
| Mixed 观察策略 / 生存 | 250 | 32.4% | 68.12 s | 51.2% |
| Mixed 观察策略 / 对抗 | 250 | 5.6% | 53.19 s | 92.0% |

整体均值：玩家食物 51.96、NPC 食物 45.98、玩家中钩 0.229 次、NPC 误钩 1.136 次、成功缠线 0.065 次。发生玩家中钩的局占 21.4%，发生 NPC 误钩占 74.9%。这两种现有控制器能力不同，Mixed 不主动缠线，不能以合并 55.4% 胜率宣称人类玩法公平；报告保留策略分层以及每张地图全部指标。

- 每图 40 局的合并鱼胜率为 47.5%–67.5%；最低 Seed 8 / 2147483647，最高 Seed 9；抄网率最高 Seed 8（47.5%）、最低 Seed 9 / 64（27.5%）。样本小、策略混合，仅作回归候选。
- 最长补饵可用条件下无供给为 7 秒，Seed 73501 / simulation 73513，之后正常回巢。
- 最长局 Seed 6 / simulation 73512 / Mixed 对抗：138.07 秒、最长全场无饵 58 秒、达标未回巢 61 秒，最终被钓起。该不利样本保留；对应两策略从头复跑均通过，未因结果不好删样本。
- 八类结构极端 corpus 保持：open=2166、dense=1346、bait-spread=937、bait-clustered=1141、net-friendly=144、net-hostile=296、rope-rich=64、rope-poor=22。六条提网通道加入后 10,000 seeds 仍全过、10,000 个不同 MapRef、零非法接受、零不确定输出、最多第 6 次 retry。

首次矩阵的测试器错误地要求已抄中、合法上提中的鱼仍在水内，导致 19 局提前终止。v2 检查允许 caught/landing 位置，但仍要求有限坐标与最终完整 Snapshot 验证。19 局全部从 tick 0 重跑通过；`gameplay-initial-report.json` / `gameplay-initial-rounds.jsonl` 保留失败原始证据，`gameplay-validated-rounds.jsonl` 保留最终 1,000 局，`gameplay-summary.json` 逐一列出替换 run ID。无玩法代码或统计规则为改善胜率而修改。

## 性能与收尾检查

Windows / Godot 4.7.2 / OpenGL Compatibility / AMD Radeon Graphics。10,000 Seed 中生成含双验证平均 4.30 ms，独立再验证平均 3.07 ms。五张代表地图的 MapContext 建立含结构验证为 1.73–3.30 ms，Watergen 首次 plan / CPU bake / terrain / texture upload API 合计 1.58–3.21 s；后续同图视图 prepare 为 0.43–1.07 μs，Resolver 命中为 6.47–16.39 μs。部分测量与回归进程并行，属于本机观测，不是跨硬件保证；首次换图仍可能有短暂停顿。视图两份 bundle 上限、重复 prepare 不再烘焙均通过。原始数据见 `data/phase05/performance.json`，可用 `tools/phase05_benchmark.gd` 复现。

完整回归发现旧 `network_rules_v012` 手造 state 包缺少新 map_source；补齐 fixture 后 26 项通过。首次新房间检查发现端口与 Seed 标签区域重叠，第一次间距调整仍不足，最终重排后真实房主菜单 22 项通过并保存截图；三次结果均保留，未放松布局断言。

完整 current 回归和最终打包汇总待本轮剩余检查结束写入。
