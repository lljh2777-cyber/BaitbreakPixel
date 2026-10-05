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

P5.6/P5.7 正在继续，尚未声明完成。
