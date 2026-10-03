# WG-2 交付报告

状态：**IMPLEMENTED / WAITING_FOR_PLAYTEST**。动态预览及自动验证已完成；人工可读性尚未确认，未进入 WG-3。

## 本轮范围

- 任务/获准阶段：WG-2 动态预览与可读性完善。
- 用户指令：继续在 `E:\Fish_catches_people\aquatic_system` 开发；2026-10-03 明确答复「沿用 713284」。该答复确认 WG-1 构图选择，不代表 WG-2 人工验收或生产接入批准。
- 目标：固定构图下的视差留边、显式可暂停时间、有限资源缓存、公开可读性样本及可复现实测。
- 冻结上游基线：`4e8a7b9011b65e53e1971cf3ddcba38880fbd6c8`，主游戏 0.24.6。与上一轮只差发布文档，详见 [WG2_BASELINE.md](WG2_BASELINE.md)。
- 实现提交：`7aa9ed39346153ff4e4bae3936d4050291d689be`；最终测试提交：`a82a1c1cc796f3385b634d92309ed81727d4594b`。后者仅将 profile 的 CRLF 改为 LF，执行代码及规范化 profile 完全相同。
- 两次正式测试开始时均 `dirty=false`，测试期间 source manifest 未变化。旧版回归在提交前执行，`dirty=true`，具体源码文件 SHA-256、diff 摘要与命令保存在对应 manifest；不可将其描述为干净提交测试。
- Godot `4.7.2.stable.official.ed1daf0bf`（完整 hash 见 manifest），Windows，原生 GL Compatibility/OpenGL 3.3，AMD Radeon(TM) Graphics / Ryzen 7 7735H。Dummy 音频，无声音验收。

## 变更与边界

均为 GREEN 私有水域改动；没有申请或实施 YELLOW/RED 生产接口修改。新增动态 profile、生成/烘焙/缓存子类、纯 FrameContext 数学、独立预览场景、夹具、私有测试、wrapper 和说明。旧水域缓存增加可覆写生成/烘焙方法与动画小纹理上传；WG-1 原算法/profile/seed 流保留。

生成器版本 `wg-2.0`，profile `forest_pond_v1`，选定 seed `713284`，测试 seeds `42/731/2649/713284`。

- 规范化 profile SHA-256：`51416a25253a1aeaef4157873cd9bf783338a3abf7e8bc32d7af476110c2c591`。
- 公开地图前/后 SHA-256：`ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d`，保持一致。
- 固定几何、目标顺序与分组不变。相机补偿只在环境绘制中应用一次；原木石和交互草仍按世界坐标绘制。
- 仅两株非交互中景草使用已烘焙小纹理横条摆动，根部固定、幅度 ≤2 px。装饰颗粒静止，没有新增流向或食物闪光信号。
- 最多两个缓存 bundle；六张带原点的静态纹理与最多两张小草纹理。每帧不创建 Image/Texture，不执行全图栅格循环。
- 夹具复用公开鱼/表盘/浮漂素材，并按现有食物形状与颜色规则绘制合成样本；夹具在 ScenePlan 外，固定屏幕位置。它们不是生产对局或 authority 状态。
- 不改 `project.godot`、生产 Layout/View、世界/RNG、食物视觉源码、信息协议、网络、游戏版本、测试注册表及存档。相对冻结上游的原有生产文件修改清单为空；原主游戏检出最终仍干净。

## 自动验证

主要证据：[`wg2-final-02`](../../artifacts/watergen/wg2-final-02/)；复测证据：[`wg2-final-01`](../../artifacts/watergen/wg2-final-01/)。完整命令、引擎、时间、源文件摘要在各自 `run-manifest.json`。按配套模板填写的独立文件为 [delivery-run-manifest.json](../../artifacts/watergen/wg2-final-02/delivery-run-manifest.json)，交叉审计及可重跑审计脚本同目录保存。

实际执行入口（均显式指定本机 Godot console exe）：

```powershell
& D:\python\python.exe tools/watergen/run_wg2.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg2-final-02 --timeout 180
& D:\python\python.exe tools/watergen/run_wg1.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg2-wg1-regression --timeout 60
& D:\python\python.exe tools/watergen/run_wg0.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg2-wg0-regression --timeout 60
```

以上 run-id 已存在，复跑应使用新名字。

| 检查 | 状态 | 实际结果与限制 |
|---|---|---|
| WG-T01/02 输入与不可变 | PASS | WG-2 headless 78 个断言；版本/字段/有限时间/补偿范围/分配上限/纯值/输入不变；原生进一步核对地图及 profile |
| WG-T03 可重现 | PASS | 新计划和层像素复现；两次独立进程的四种子计划、24 张层图、20 个视口摘要一致，全部 74 张 PNG 字节一致 |
| WG-T04 随机隔离 | PASS（预览） | 原 WG-1 隔离测试保留；WG-2 延用同一对象流，非动画对象坐标与选定布局相同 |
| WG-T05 几何 | PASS（静态） | 公开地图/原 Layout 数据字节和目标顺序不变；对局运行态仍留 WG-3 |
| WG-T08 视差/边缘 | PASS | 四种子 × 五镜头；层覆盖边界；全部视口边沿不透明且非黑；原生正负补偿探针位置正确、只出现一次 |
| WG-T10 可读性 | NOT_RUN（人工） | 20 张原生视口夹具及选定样片已导出，不能由自动截图代替玩家辨识判断 |
| WG-T11 生命周期 | PASS（预览） | 两次各 20 次 seed 切换、真实被淘汰纹理 WeakRef 释放、资源数稳定、暂停/恢复/seek；两次各 60 秒实测无重建 |
| 旧版本回归 | PASS | WG-1：58 headless + 140 native；WG-0：81 headless + 44 native；旧计划/六层/固定视口仍与原样片相同 |
| 辅助静态审计 | PASS | JSON Schema、Python 语法、11 个核心模块依赖边界扫描；不冒充隐藏真值等价证明 |
| WG-T06/07/09/12/13/14/15 | NOT_RUN | 权威逐 tick、隐藏真值、生产遮挡、生产回退、完整游戏回归、网络和包体属于 WG-3 |
| WG-T16 | NOT_RUN（WG-2） | 仅有 WG-1 选种子确认；本轮动态/可读性尚未人工确认 |

主要验证共 6 次套件执行、**571 个通过断言**（WG-2 248，旧版 323），0 失败。另一轮正式 WG-2 重复执行 248 个断言，单独记录，不计为新增覆盖。日志中的写文件成功也属于断言计数；这不是 571 个独立玩法测试。开发 smoke 不计入交付验收。

## 画面与性能

[样片画廊](../../artifacts/watergen/wg2-final-02/gallery.html)包含四种子六层静态烘焙图、5 个原生环境视口、相同视口的公开夹具、0/3 秒整世界图，共 74 张 PNG。静态 terrain 图不含单独动态草叶小纹理；整世界和视口图包含最终合成。ScenePlan 和 RGBA 摘要见种子目录及 `wg2-native-evidence.json`。

默认留边尺寸和原点见 [使用说明](WG2_README.md)。对象坐标沿用 WG-1；留边坐标重定位会产生少量浮点取整差异（713284 远景中央区域 6 像素），因此升级为新栅格版本。WG-1 旧黄金图没有更新或放宽。

| 实测项 | final-01 | final-02 |
|---|---:|---:|
| 定时运行 | 60.007803 s | 60.007736 s |
| 预热 | 120 帧 | 120 帧 |
| 采样绘制次数 | 7271 | 7189 |
| CPU 绘制提交中位数 / p95 | 0.801 / 1.005 ms | 0.813 / 0.929 ms |
| 帧间隔中位数 / p95 | 8.341 / 9.065 ms | 8.342 / 8.681 ms |
| 24 次冷烘焙范围 | 630.167–1112.174 ms | 624.643–1139.181 ms |
| 切 seed 后资源计数 | 始终 26 | 始终 26 |
| 定时前/后缓存计数 | `[26,24,24,192]`，不变 | `[26,24,24,192]`，不变 |

缓存计数顺序：计划调用、CPU 烘焙、bundle 上传、纹理创建。四个首次种子的计划耗时为 4.355–10.564 ms，上传 API 为 1.595–4.279 ms；所有原始生成/烘焙/上传记录均保留。冷生成在预览准备/切换阶段，不能直接搬到实时对局每帧运行。

两轮切换期引擎静态堆范围均为 38,527,828–39,155,168 bytes；定时期为 38,576,324–39,043,824 bytes。记录数组及时间序列自身会分配内存，因此不要求字节读数绝对不动。缓存至多两项，资源计数保持稳定，淘汰纹理实际已释放。本次未发现纹理累积；不能据此宣称任意时长或生产角色切换完全无泄漏。

上述 CPU 绘制耗时只包括提交命令，帧间隔包含显示同步，上传 API 不代表 GPU fence 时间；静态堆不是显存。整场游戏/相对 legacy 稳态 p95 增量、GPU 时间、真实操作手感均 **NOT_RUN**。没有把该数据宣称为生产 60 Hz 性能验收。

## 开发记录与已知限制

开发日志保留：`wg2-dev-contract-01` 发现 JSON 浮点零数组比较被误拒绝，已改为逐分量数值判断；`wg2-dev-contract-02` 发现新旧栅格跨版本像素取整差异，现分开验证对象布局、WG-2 精确复现和保留的 WG-1 像素基线；`wg2-dev-smoke-01` 发现夹具变量的 GDScript 类型推断错误，已补明确类型。后续 smoke、原生探针和正式运行全部通过。未覆盖或隐藏这些失败记录。

首轮提交时 profile 带 CRLF，后续独立格式提交已修正；最终 `git diff --check` 通过。两次正式运行唯一的源文件字节差异就是该换行修正，规范化 profile 完全一致，审计保留这一事实。

## 人工验收、回退与停止点

WG-PF-001：2026-10-03 用户确认「沿用 713284」，WG-1 构图方向 CONFIRMED。WG-PF-002：WG-2 动态幅度、远近层边缘、三类食物/旧散粒、细线、入口闪光、QTE 辨识，等待用户反馈，**尚未 CONFIRMED**。

入口：[Open-Dynamic-Preview.ps1](../../tools/watergen/Open-Dynamic-Preview.ps1)。空格暂停，逗号/句号逐步采样，F 显示样本，R 归零，Esc 退出。关闭预览即可回退；WG-0/WG-1 原入口保留，没有生产补丁需要撤销。

源码提交并推送至 `feature/watergen`；本机 PNG、日志、审计和模板 manifest 位于忽略的 artifacts 目录，未冒用游戏发布包或版本。完成后停在 **WAITING_FOR_PLAYTEST**。根据用户提供里程碑的 WG-2 停止点，用户确认「可接入试玩」并给定/同意生产集成基线后，才允许 WG-3 小范围接入；默认 legacy、联网/岸上/抄网观察保持原实现的要求仍适用。
