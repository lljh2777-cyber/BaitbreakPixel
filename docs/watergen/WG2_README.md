# WG-2 动态水域预览

当前默认入口已升级为 [WG-2.1 视觉氛围版](WG21_README.md)，V 可冻结当前时间切换原版。下文保留 WG-2.0 的设计与验证说明；加 `--baseline` 可运行该版本。用户暂不接入主游戏，当前只做视觉迭代。

用户已选定 WG-1 的青绿色调与种子 **713284**。本阶段仍是独立工具；游戏生产入口、碰撞、交互草、食物、协议和存档不变。

Windows 启动：

```powershell
powershell -ExecutionPolicy Bypass -File E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen\tools\watergen\Open-Dynamic-Preview.ps1
```

| 操作 | 功能 |
|---|---|
| 空格 | 暂停/恢复装饰动画 |
| 逗号 / 句号 | 暂停并向前/后采样 0.25 秒 |
| R | 时间归零，保留当前暂停状态 |
| F | 切换公开可读性夹具 |
| [ / ] | 四个固定种子间切换 |
| 1–5 | 左上、中心、右下、左下、右上 |
| 方向键 | 平移镜头 |
| G / H | 保护区 / 原交互几何参考 |
| Esc | 退出 |

夹具使用原鱼、钩形表盘、浮漂贴图及公开食物绘制规则；食物位置是固定合成样本，入口闪光、锥体、细线和 QTE 是静态示例，不模拟对局，不载入 authority。夹具固定在屏幕位置，使不同背景可直接比较。表盘保留原生尺寸，省略真实状态文字和时序。与生产真实动作、遮挡顺序的兼容验证留至 WG-3。

## 实现与边界

- `forest_pond_dynamic.json` 使用 `wg-2.0`；WG-1 的 profile、生成器及子随机流保持可调用。WG-2 明确复用 WG-1 对象布局流，升级留边/动画语义与缓存键。
- 层补偿为 `-camera + round(k*camera)`，原点仅在纹理绘制时加一次。每轴留边为 `ceil(abs(k)*最大镜头偏移)+4`，系数为零则不留边。water/floor 固定系数 0。
- 默认 distance：1570×508、原点 (-145,-14)；surface：1456×496、原点 (-88,-8)；terrain：1366×494、原点 (-43,-7)；foreground：1346×480、原点 (-33,0)；water/floor：1280×480。全部 RGBA8，透明层沿世界坐标继续栅格化，无平铺。
- 两个中景草簇各拆出一株非交互草。单独小纹理在加载时生成，按一像素横条重绘；根部权重为零，摆幅 ≤2 像素。不移动交互几何，不动画化颗粒，不增加流向信号。
- 显式 `visual_time` 来自预览的 delta 累加或 seek，暂停时冻结；24 小时循环。墙钟仅用于性能测量和定时测试，不决定植物姿态。FrameContext 只接受预览角色、合法镜头、640×360 或零镜头的1280×480截图尺寸、有限时间。
- 缓存最多两个 bundle；每 bundle 六张静态纹理和至多两张草叶小纹理。CPU Images 在导出后释放；相机、时间、夹具开关不重新生成计划、烘焙或上传。
- WG-2 的远景顶点移动至留边坐标系后，浮点像素取整可有少量变化（713284 相比 WG-1 中央远景图有 6 个像素变化）；对象坐标保持相同。新版本内要求计划与图像可复现，旧 WG-1 继续使用原像素基线。

## 验证入口

```powershell
& D:\python\python.exe tools/watergen/run_wg2.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg2-final-01
```

默认包含 headless 契约检查、四种子五镜头、原生定位探针、固定时间复采、20 次切种子、120 帧预热和 60 秒定时原生绘制。`--test-seconds 1` 仅用于开发 smoke，manifest 会明确 `acceptance_60_seconds=false`；不能作为 WG-2 完整验收。使用唯一 run-id，不覆盖历史产物。

每次输出独立 `run-manifest.json`、原生证据、ScenePlan、六层/视口 PNG、画廊和隔离用户目录。缓存计数依次为计划调用、CPU 烘焙、bundle 上传、纹理创建；draw_cpu_us 是 CPU 提交绘制命令耗时，不是 GPU 时间或整场游戏帧耗时。frame_interval_us 包含显示同步等待。内存读数是引擎静态堆，不是显存。

性能记录有意保留原始数组：切换记录与时间序列自身会占用少量内存；同时检查实际被淘汰纹理的 WeakRef 已释放和资源计数稳定，避免将记录开销误称纹理泄漏。测试注册仍使用私有 wrapper，不改共享 suite registry。

本阶段结束于 `WAITING_FOR_PLAYTEST`。用户确认“可接入试玩”并明确集成基线后才能进入 WG-3。回退：关闭预览；WG-0/WG-1 入口继续可用。
