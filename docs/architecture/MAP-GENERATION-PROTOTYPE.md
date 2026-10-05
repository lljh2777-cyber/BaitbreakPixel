# Phase 5 第一轮：地图生成原型

依据用户 2026-10-05 提供的 BaitbreakPixel_Phase_5_Interactive_Map_Generation_Development_Spec.md 第 49 节，仅实现 P5.0 + P5.1 Prototype；第一轮完成自动验证与开发预览后停止。基线为 0.26.4 后的 a110f52，保留用户刚加入的右键移竿加速。

## 生成契约

`MapGenerationRequest.create(seed)` 接收 0..2147483647 的整数，固定 generated_pond / version 1 / balanced_pond_v1 / contract 1。严格拒绝未知字段、浮点种子、对象及视觉配置。`source()` 单独记录来源；生成器仍只产生既有 MapDefinition，不把来源塞进 contract-v1，也不建立第二套地图模型。

Map RNG 使用明确的 31 位整数派生及 Park–Miller 48271 序列，仅依赖请求和 attempt。命名空间为 generated_pond:1:attempt:N；visual 命名空间可另行派生，但不进入地图请求。没有 world、scene、network、Simulation RNG 或 Visual RNG 依赖。

固定 1280×480、WATER(8,68,1264,363)、floor_y=433、原 HOME/SPAWN。首先保护 HOME、SPAWN、核心开放水道、抄网安全区和六个食物候选点，再在分区生成木石草。所有坐标来自整数模板/整数变换；ID 由确定性类型槽分配，连接木组共同淡出。

本轮不改变 Snapshot 或 Network 协议/解析路径，仅同步 exact-build 版本号 0.27.0。MapRegistry 仍只接受 pond_v2；不移植 Watergen，不开放游戏地图选择。生成地图的全域 routing profile、实际比赛、存档与联网是后续阶段；原型的路线指标不宣称已验证完整绳路求解或比赛平衡。

## 分步记录

P5.0：请求/整数随机源测试 603 项通过，既有右键移竿控制 199 项通过，编辑器导入通过。首次 seed_derivation 使用了引擎保留参数名 namespace，解析失败后改名 domain；原日志保留在 artifacts/phase05-step0，复测为 artifacts/phase05-step0-fixed。

P5.1 布局：GeneratedPondV1 输出 contract-v1 的六个食物候选点、2–3 个连接木组、3–5 个石块、5–8 片交互水草。固定次数分区尝试后失败返回空候选；MapGenerator 最多重试 32 次，明确失败不回退。100 个种子逐一重复生成，403 项确定性检查、775 项几何/能力/MapContext 检查与编辑器导入通过（artifacts/phase05-step1）。本步仅结构校验，下一步增加可玩性门与大样本检查。

P5.1 初版可玩性门：先完整结构校验，再检查固定框架、饵点间距/边缘/巢穴距离、保护区、类型预算、覆盖密度、NPC 空间采样、锚点数量/跨度/饵点距离及 24 条默认网口膨胀 AABB 路线。路由指标采用保守矩形近似；不等同于游戏的完整多边形绳路与不同规则参数验证。正常比赛仍不使用生成地图。

10,000 种子（0..9999）每个重复生成两次并独立复验：20,000 项通过，0 接受非法地图、0 非确定性、0 最终失败、10,000 个不同 Authority content hash；总耗时 125.17 秒，生成含双门平均 4.14 ms。初版非法地图/重试测试 17 项通过。统计保存在 docs/test-reports/data/generation-0270/seed-sweep.json，极端布局语料为 corpus.json。跨平台确定性目前仅以整数实现和 Windows 重复生成验证，不宣称已跑另一操作系统。

## 独立开发预览

在仓库目录运行 PowerShell：

```powershell
.\Preview-Generated-Pond.ps1 -MapSeed 42
```

或者使用 Godot console：

```powershell
& 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/preview_generated_pond.gd -- --map-seed=42
```

预览支持手动 Seed、重新生成同 Seed、随机 Seed、复制 Seed、显示/隐藏检查层。它直接读取 MapContext 和已有像素木石草绘制模块，不创建 WorldSimulation，不启动比赛、不登记地图。检查层显示保护区与能力轮廓；六个标记是候选食物位置，不包含未来食物/Hook 真值。可加 `--preview-output=E:/Fish_catches_people/BaitbreakPixel/artifacts/preview-42.png` 保存图并退出。

生成地图使用独立的 generated_pond_prototype 视觉 profile，避免把经典池塘的固定木纹路径套到新木组。未接入 Watergen；地图轮廓均由 Authority 多边形提供。覆盖率是多边形面积之和除以水域面积（重叠部分重复计入），用于原型预算比较，不是精确并集覆盖率。

代表 Seed：普通 42、开阔 2166、密集 1346、抄网受限 296、饵点分散 937、较聚集 1141、锚点多 64、较少 22。先审查形态与布局，下一轮再进行 P5.2/P5.3 的完整可玩性、全域 routing 和实际比赛。
