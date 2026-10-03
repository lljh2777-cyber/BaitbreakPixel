# WG-1：静态水域生成与预览

当前范围：一个 `forest_pond_v1` profile、四个公开视觉种子、固定 pond_v2 几何。生成器版本 `wg-1.0`。仅独立预览；不接入生产主场景，不增加动态效果。

## 打开预览

```powershell
& 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen\tools\watergen\Open-Generated-Preview.ps1'
```

`[` / `]` 切换 42、731、2649、713284；方向键平移；1–5 切换左上、中心、右下、左下、右上；G 显示构图保留区；H 显示/隐藏原木石和植物；Esc 退出。所有动画固定在时间 0。第一次切换种子在预览加载阶段生成，返回最近两个种子之一复用纹理。

完整自动验证与导出：

```powershell
& 'D:\python\python.exe' 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen\tools\watergen\run_wg1.py' --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

运行目录为本工作树的 `artifacts/watergen/<唯一 run_id>/`；已有目录拒绝覆盖。`--mode headless/native/preview` 分别选择契约测试、原生捕获或交互预览。运行器记录源码摘要、SHA/dirty、命令、日志、实际引擎、硬件、渲染器、参数和图像摘要；子进程用户目录隔离。原生产物附 `gallery.html`，可本地浏览四个种子的五镜头、整世界和分层图片。

## 配置与参数

配置：`data/watergen/forest_pond.json`。唯一 profile 来自用户配套 `forest_pond.example.json`；原资料保持原样。复制的 `visual_profile.schema.json` 给出草案结构，GDScript 校验器再施加范围顺序、有限数、精确算法版本和阶段约束。原 schema、原 example 和本配置均已用 JSON Schema Draft 2020-12 校验。

**阶段约束：WG-1 的六个 parallax_compensation 必须全为 `[0,0]`。** 原示例的非零值属于 WG-2 的视差/留边工作，本阶段明确拒绝为 `PARALLAX_REQUIRES_WG2`，不会默默忽略。当前 profile 按此约束设为零；预览无无效调节控件。全世界 1280×480 静态图按实际 640×360 镜头裁剪。

其余字段全部进入计划或像素生成：色板影响相应材料；光束数量/宽度/深度/倾斜/强度决定水体光域；中央保留带决定两侧群落位置；草簇/浮叶/碎石/颗粒预算决定对应对象数量。profile_id 是方案名称，缓存同时使用完整规范化内容摘要。以后改变随机流或栅格化语义需升级 generator_version。

## 数据与渲染职责

`PublicMapContext + VisualProfile + visual_seed → generate() → 纯值 ScenePlan → bake() → 六层 Image → cache.prepare() → RenderBundle`。

- `water_visual_profile.gd`：字段白名单和语义校验。输入错误不产生部分计划。
- `water_visual_seed.gd`：UTF-8 SHA-256 标签的前 31 位派生局部 RNG；标签包含算法版本、整数种子、图层、对象种类和索引。
- `water_visual_generator.gd`：构图、逐对象参数、固定几何接地阴影；ScenePlan 只含纯值，无 Node/Object/Callable/RNG。
- `water_raster.gd`、`water_visual_baker.gd`：只操作本地 Image，不上传纹理。局部像素线内核注明旧 pixel_art 来源，不引入其 Layout 依赖。
- `water_visual_cache.gd`：完整成功后一次创建 bundle，最多保存两个；键包含算法版本、profile/map 摘要、visual_seed、raster 约定及完整引擎提交。缓存命中仍校验并重建低成本计划，但不烘焙/上传。
- 预览层复用 WG-0 的固定木石/植物准备函数。旧 WG-0 环境绘制保持同像素；新核心不直接或间接依赖 Layout、authority、玩法 RNG、网络或档案。

六层含义不变。水体不透明；远景草与静态颗粒低对比；浮叶与长茎同层，左上垂根；底床为弱变化的沙泥斑块与簇状碎石；中景为装饰植物；近景为两侧/底缘暗草。没有背景鱼影、可食装饰、碰撞/缠线对象或真实水流。

根系三簇、草簇内茎/叶的细分、床面频率和材料语法是本算法版本的固定参数，并非未实现的 profile 控件。新的大型岩石/倒木不进入环境；原游戏交互形状与原画家保留。

## 验证与限制

WG-1 私有入口不更改主测试注册表。契约测试覆盖非法输入、最大预算、相同 seed 同计划/像素、不同 seed、增粒不影响光束/草簇及既有对象、缓存内容键、数据不变和不透明底色。原生捕获覆盖五个固定视口、重复静态帧、四组分层样片、缓存命中/容量和源地图不变。原 WG-0 检查继续运行，验证抽取几何辅助函数没有改变旧样片。

性能记录分为 plan、CPU bake、texture upload API 调用耗时；API 时间不是 GPU 完成时间。记录引擎静态内存计数和资源数，不把它当作实测显存或泄漏结论。稳态游戏帧 p95、20 次 seed 切换、动态草/粒子、视差留边、真实鱼饵/线网可读性与主游戏回放/网络兼容留待 WG-2/3。

本阶段完成后停止于 `WAITING_FOR_PLAYTEST`，等待用户选定构图/色彩方向；截图成功不代表人工美术通过。
