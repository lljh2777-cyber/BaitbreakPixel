# Watergen WG-0：旧环境独立预览

本文保留 WG-0 旧环境入口和原始 0.24.5 基线说明。当前水域工作树同步至 0.24.6；最新动态预览见 [WG2_README.md](WG2_README.md)，静态生成入口见 [WG1_README.md](WG1_README.md)。WG-0 入口自身仍只显示旧环境，不启动对局。

## 工作区与入口

开发工作树：`E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen`。
基线：`origin/feature/dev @ 9c447e7210987472d108ce284b9df5cd057f2dc7`。
分支：`feature/watergen`。原主游戏目录保持 `main`。

Windows PowerShell 启动可交互预览：

```powershell
& 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen\tools\watergen\Open-Preview.ps1'
```

默认使用现有 Godot 4.7.2 和 `D:\python\python.exe`；引擎可通过 `-Godot` 指定。
原生视口 640×360，窗口按项目原设置整数放大。方向键平移；1–5 切换左上、中心、右下、左下、右上；G 显示公开几何/构图保留区；H 切换木石和植物参考；Esc 退出。

请通过启动器运行，以将引擎日志、用户目录和缓存隔离到本次 `artifacts/watergen/<run_id>/`。预览本身无玩家档案读写、网络、authority、世界 RNG 依赖。自动化命令的原生截图不能改用 `--headless`。

自动验证并捕获：

```powershell
& 'D:\python\python.exe' 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen\tools\watergen\run_wg0.py' --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

默认生成唯一运行目录，已有目录拒绝覆盖。`--mode headless` 仅运行地图契约；`--mode native` 仅运行原生捕获；`--run-id` 可指定唯一目录名。脚本有进程超时、引擎错误扫描、完成标记检查、源码前后摘要与原生产文件不变检查。Windows 子进程的 APPDATA/LOCALAPPDATA 指向运行目录；截图任务还断言引擎实际 user data 路径已隔离。

## 画面基线的含义

六层来自未经修改的 `Water.layers()`。木石来自原 `Art.scene_props()`，植物采用原画家及原裁剪公式，固定时间为 0。环境层视差系数和背景/床面/木石/植物/近景次序沿用原代码。

`legacy_preview_canvas.gd` 复制了 `pond_scenery.background()` 的无状态岸缘/图层调用片段，以及 `pond_view._make_plant_layer()` 的裁剪公式，来源提交见 `data/watergen/source_baseline.json`。没有加载 `pond_view`、主场景或伪造 world 对象。

明确省略：动态水流粒子、活动钓组的水面铺板、巢穴外观与进度提示、鱼/食物/线/网/HUD。这些依赖对局状态。截图是**旧画家的静态环境预览基线**，不是完整游戏画面或主游戏兼容报告。G 显示的候选饵位保留框只用于预览诊断。

`data/watergen/legacy_baseline.json` 冻结同引擎六层原始 RGBA SHA-256 与公开地图摘要；不使用 PNG 压缩文件摘要替代像素摘要。首次采集原始证据留在 `wg0-dev-02`；不得自动重写 golden 以消除失败。

## PublicMapContext v1 的具体化

适配器仅显式读取 Layout 的公开固定字段。核心契约模块不依赖 Layout；只使用纯字典、数组、字符串、布尔和有限数值。

在总规格列出的字段之外，本实现明确携带：

- `net_area_px`、`bait_sites_px`、`legacy_grass_rects_px`、`wood_groups`：规格要求纳入摘要的公开固定数据。
- `static_cover_records`：保持原索引，每项包含 kind、polygon_px、bounds_px、fade_group 和 source。木石 source 仅 seed/name；植物 source 仅 x/y/height/width/kind/stems/back。这里的 seed 是公开固定材质编号，不是玩法 seed。
- `protected_regions`：巢穴 64×64、出生点 48×48、公开候选饵位各 48×48 的构图参考矩形。它们不是碰撞体，也不提示本局分配；尺寸是 WG-0 预览初始值。

摘要包括上述全部静态字段及契约版本；排除 `source_commit` 和摘要自身。字典键排序、数组顺序保留、整数值规范化为整数、UTF-8 SHA-256。结构校验先于摘要验证，拒绝未知/私有字段、错误版本、类型错误、非有限坐标、无效尺寸、空地图、超限对象、错序索引与非法分组，不修改输入。

WG-0 尚无 VisualProfile、ScenePlan 或生成器；报告的 profile/seed 均为 null。VisualProfile 校验及视觉随机子流将在 WG-1 实施。

## 测试接入方案

共享 `tools/run_tests.py` 用 `tests/*.gd` 的顶层 glob 与 registry 比较，**不会递归发现 `tests/watergen/`**。本阶段保持 registry/runner 原样，用私有 `run_wg0.py` 显式启动两个入口：

1. `tests/watergen/context_contract.gd`：公开契约、拒绝非法输入、复制隔离、40 个运行时 target 的几何/索引/分组。
2. `scenes/watergen/preview.tscn --wg-capture`：真渲染器、五镜头重复像素、旧六层摘要、绘制前后数据不变、用户目录隔离、产物写入。

未来集成负责人可新增两个顶层包装入口，并分别登记 headless/renderer、120 秒超时；不得为了发现子目录大改共享 runner，也不得把测试打入生产 PCK。WG-3 再运行 current/native、固定指令 authority/RNG 重放和真实角色场景。

## 当前任务单

任务 ID：WG-0；目标：基线、只读适配器、旧场景独立预览。
授权：用户 2026-10-03 要求依文档在 aquatic_system 开发。
允许变化：本次新增 watergen 私有目录、文档、产物。
禁止变化：原生产文件、主入口、地图、玩法、网络、用户档案、版本号。
人工确认项：预览隔离、旧画面基线、WG-1 是否可开始。
输出：`artifacts/watergen/<run_id>/`；停止点：`WAITING_FOR_REVIEW`。

关闭预览即可回到原游戏工作流程；生产入口没有更改。无需重置主线、删除工作树或清理存档。
