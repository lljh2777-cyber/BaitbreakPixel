# WG-0 基线差异（2026-10-03）

文档基线：`a4a1f538860cb37741a49ccd9fdb078d7b39b8b0`，feature/dev，0.24.4。
本次 fetch 后远端开发头：`9c447e7210987472d108ce284b9df5cd057f2dc7`，0.24.5。
原主游戏检出：main，`c9f3c4c7ebb238fac78912fd1cd172bef16c8663`，初始工作区干净。
水域工作树从明确的开发分支 SHA 创建；没有移动原检出或覆盖未提交工作。

| 核对项 | 事实 | WG-0 处理 |
|---|---|---|
| 游戏版本 | 0.24.4 → 0.24.5 | 保留 0.24.5，无新增游戏版本 |
| 摄食默认值 | 自动咬食半径/冷却与档案迁移变化；有对应测试与文档更新 | 不使用旧参数构造 gameplay fixture，不修改摄食 |
| 地图/相机 | pond_layout.gd、pond_camera.gd 与文档提交无差异 | 固定 1280×480、640×360、18 木石、22 植物 |
| 环境/显示 | pond_view、pond_scenery、pond_water_art、pond_depth_art、pond_plant_art 无差异 | 直接复用旧画家；无生产绘制调用变更 |
| authority | world_snapshot.gd 无差异：schema14、bait guard3、pond_v2 | 不加载 authority |
| 鱼表现 | fish_network_observation.gd 无差异：schema1、public bait guard1 | 不更改白名单 |
| 网络 build | network_protocol.gd 版本字符串更新 | 无水域网络字段 |
| 测试注册 | suite_registry.json、run_tests.py 无差异；103 个顶层入口 | 私有子目录显式运行，提出后续注册方案 |
| 阶段 | README 仍标 Phase 2.3 最终人工门 | 水域工作不解锁主游戏 Phase 3 |

证据命令：`git fetch origin`、`git log -1 origin/feature/dev`、`git diff --stat a4a1f538... 9c447e72...`，以及逐项文件 diff / 常量静态核对。完整主线差异为 32 个文件，主要是摄食调参、版本记录与验证记录；以上不是全仓库审计结论。

事实：Godot 实际版本为 `4.7.2.stable.official.ed1daf0bf`，完整引擎提交 `ed1daf0bf001b61586d9930840f2f1394092c079`；Windows 原生 OpenGL Compatibility 可用。

推断：水域依赖接口未变，因此无需为 0.24.5 改动旧画家或地图适配来源。该推断不替代 WG-3 的实际主游戏重放/网络回归。

待验证：真实对局可读性、食物/网线遮挡、authority/RNG 重放、包体一致性、性能完整矩阵以及用户人工确认，均留在相应后续阶段。
