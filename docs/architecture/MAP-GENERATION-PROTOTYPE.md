# Phase 5 第一轮：地图生成原型

依据用户 2026-10-05 提供的 BaitbreakPixel_Phase_5_Interactive_Map_Generation_Development_Spec.md 第 49 节，仅实现 P5.0 + P5.1 Prototype；第一轮完成自动验证与开发预览后停止。基线为 0.26.4 后的 a110f52，保留用户刚加入的右键移竿加速。

## 生成契约

`MapGenerationRequest.create(seed)` 接收 0..2147483647 的整数，固定 generated_pond / version 1 / balanced_pond_v1 / contract 1。严格拒绝未知字段、浮点种子、对象及视觉配置。`source()` 单独记录来源；生成器仍只产生既有 MapDefinition，不把来源塞进 contract-v1，也不建立第二套地图模型。

Map RNG 使用明确的 31 位整数派生及 Park–Miller 48271 序列，仅依赖请求和 attempt。命名空间为 generated_pond:1:attempt:N；visual 命名空间可另行派生，但不进入地图请求。没有 world、scene、network、Simulation RNG 或 Visual RNG 依赖。

固定 1280×480、WATER(8,68,1264,363)、floor_y=433、原 HOME/SPAWN。首先保护 HOME、SPAWN、核心开放水道、抄网安全区和六个食物候选点，再在分区生成木石草。所有坐标来自整数模板/整数变换；ID 由确定性类型槽分配，连接木组共同淡出。

本轮不改变 Snapshot 或 Network 协议/解析路径，仅同步 exact-build 版本号 0.27.0。MapRegistry 仍只接受 pond_v2；不移植 Watergen，不开放游戏地图选择。生成地图的全域 routing profile、实际比赛、存档与联网是后续阶段；原型的路线指标不宣称已验证完整绳路求解或比赛平衡。

## 分步记录

P5.0：请求/整数随机源测试 603 项通过，既有右键移竿控制 199 项通过，编辑器导入通过。首次 seed_derivation 使用了引擎保留参数名 namespace，解析失败后改名 domain；原日志保留在 artifacts/phase05-step0，复测为 artifacts/phase05-step0-fixed。
