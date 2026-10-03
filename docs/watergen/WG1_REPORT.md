# WG-1 交付报告

状态：**WAITING_FOR_PLAYTEST**。静态生成已实现并完成本报告列出的自动检查；等待用户选定构图/色彩方向。WG-2/3 未开始。

## 本轮范围与基线

任务 ID / 授权阶段：WG-1。用户在 WG-0 交付后要求“继续”，按里程碑推进一个池塘的静态 Seed/Profile 视觉生成，不自动推进整条路线。

工作树：`E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen`，分支 `feature/watergen`。
上游基线：`282595e98a4184895db217c298d1e2cbf4ecd140`（feature/dev / 0.24.6）；同步经过独立 merge 和基线记录提交 `cf3c3ad`。详见 [WG1_BASELINE.md](WG1_BASELINE.md)。
最终测试提交：`3f5ed767de53c5ea74afac651f3223aa590a324c`，三次运行均为干净工作树，源码前后摘要一致。

相对于该上游基线，原生产文件变更列表为空。同步带来的咬食/规则/版本改动来自主游戏已有提交；本轮水域只改私有实现与预览工具。原主游戏工作树在交付时为 main / 0.24.6，工作区干净，本轮没有切换或修改它。

引擎：Godot `4.7.2.stable.official.ed1daf0bf`（完整 SHA `ed1daf0bf001b61586d9930840f2f1394092c079`）；Windows 10.0.26100，AMD Ryzen 7 7735H / AMD Radeon(TM) Graphics，原生 OpenGL Compatibility，Dummy 音频。manifest 起止时间按 Asia/Shanghai 记录。

## 交付与边界

新增单一 `forest_pond_v1` profile、严格校验、逐对象视觉随机流、纯值 ScenePlan、六层 CPU 像素烘焙、最多两个 bundle 的缓存、静态生成预览、私有检查和本地画廊。状态/内容流见 [WG1_README.md](WG1_README.md)。

新增实现均为 GREEN。WG-0 私有预览中仅抽取原木石/植物准备函数供新预览复用；原画家、交互木石/草、Layout、View、生产主场景、网络/规则/版本没有水域侧改动。共享注册表保持原样。

原 JSON Schema 草案、原示例与交付 profile 结构校验通过。唯一阶段差异：交付 profile 的 parallax_compensation 全部为零；非零值明确拒绝（`PARALLAX_REQUIRES_WG2`），留给 WG-2 的留边/视差方案。用户原资料未修改。其余色板、光束、构图、各类数量字段均生效。

生成器版本：`wg-1.0`。
profile 规范化 SHA-256：`6abe2dbea38c35da69001305b8454e3a7bafdcb02cfe113f931980fd25568ac6`。
公开地图 SHA-256：`ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d`（与 WG-0 相同）。
四个公开视觉种子：42、731、2649、713284；时间固定为 0。

生成核心依赖图只有 public_map_context、profile、seed、generator、raster、baker、cache 七个纯水域模块，无 Layout / authority / 网络 / 档案依赖。只读适配器和原交互几何画家留在预览边界。该静态检查不能替代 WG-3 的隐藏真值等价和 authority 重放。

## 样片与人工待确认

- [四组样片画廊](../../artifacts/watergen/wg1-final-01/gallery.html)：每组可查看五个 640×360 镜头、整世界及各层。
- [Seed 42 整世界](../../artifacts/watergen/wg1-final-01/seed-42/world-with-geometry.png)。
- [Seed 731 整世界](../../artifacts/watergen/wg1-final-01/seed-731/world-with-geometry.png)。
- [Seed 2649 整世界](../../artifacts/watergen/wg1-final-01/seed-2649/world-with-geometry.png)。
- [Seed 713284 整世界](../../artifacts/watergen/wg1-final-01/seed-713284/world-with-geometry.png)。

每组 14 张图：六层、五镜头、含固定几何整世界、纯环境整世界、保护区诊断图；主交付共 **56 张 PNG**，另附四份 ScenePlan、profile/map JSON、逐层/逐镜头像素摘要。镜头为 `(0,0)`、`(320,60)`、`(640,120)`、`(0,120)`、`(640,0)`。

画面采用青绿水体、稀疏柔光、两侧植被、中央留空、上缘浮叶/长茎/垂根和低对比泥沙碎石。原木石/交互草保持原样。开发目视检查查看了四个种子的整世界或原生镜头；曾发现首版床面周期斜纹，已改为非线性散列的低频泥沙斑块。

仍需用户确认：是否接受整体色调与明暗；哪组构图更合适；中央空间与两侧密度是否自然；根茎连接和接地是否满意。没有已确认的 WG-PF 反馈，人工状态 NOT_RUN。当前预览没有真实鱼、饵、线、网和 HUD，不能据此宣布真实游戏可读性通过。

## 自动检查

| 项目 | 状态 | 证据与范围 |
|---|---|---|
| WG-T01 输入校验 | PASS（WG-1 范围） | 未知/私有字段、非法 seed、NaN/Infinity、预算、倒置范围、色值、版本、非零视差拒绝；最大合法预算可烘焙，过大画布提前拒绝 |
| WG-T02 数据不可变 | PASS | 生成/烘焙/显示后 map/profile/Layout/运行时目标均保持相同，修改输出不影响输入 |
| WG-T03 可重现 | PASS | 四种 seed 的纯值计划可重复；固定环境三次独立原生进程的全部计划、六层 RGBA 和五镜头像素摘要一致 |
| WG-T04 随机隔离 | PASS | 增加悬浮颗粒只改变 distance 的对应对象；光束及草簇不重排，其余五层像素相同；增加碎石保留既有碎石前缀 |
| WG-T05 固定几何 | PASS | WG-0 的 40 个 target / 公开摘要检查通过，原生产文件无水域差异 |
| WG-T08 静态六层/镜头 | PASS（静态范围） | 四组五镜头、重复帧、水体不透明网格/四角检查；动态视差留边 NOT_RUN |
| WG-T11 缓存初步检查 | PASS（WG-1 范围） | 同 seed 复用纹理、不再烘焙；缓存条目不超过二；记录内存与资源原始数值。20 次切换及对局生命周期 NOT_RUN |
| WG-0 旧画面回归 | PASS | 81 项地图契约 + 44 项原生检查；六层及五镜头像素均与 WG-0 初始捕获一致 |
| 现行注册表 | PASS | 原 `tools/run_tests.py --list` 成功；私有子目录不改变 103 个顶层套件 |
| WG-T06/07/09/10/12/13/14/15 | NOT_RUN | 对局 authority/RNG、隐藏真值、真实交互顺序/辨识、生产回退、current/native 全量游戏回归、网络与包体属于后续阶段 |
| WG-T16 人工确认 | NOT_RUN | 等待用户选择方向，不以自动通过代替 |

计数：WG-1 主运行 **58 项契约断言 + 140 项原生断言 = 198 项全部通过**；另有 WG-0 125 项通过，合计四个检查入口、323 项断言。两次额外 native 运行各 140 项通过，用于独立进程复现/重复计时，不算新的用例覆盖。

主要复现命令：

```powershell
& 'D:\python\python.exe' tools/watergen/run_wg1.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg1-final-01 --timeout 60
```

重跑须换新的 run-id。其余两次用 `--mode native`、run-id 为 `wg1-final-02` / `wg1-final-03`。WG-0 回归记录在 `wg1-legacy-regression`。所有命令、退出码、错误扫描与日志保留在对应运行目录。

开发失败证据保留：`wg1-dev-01` 的两个 GDScript 类型推断错误导致限时失败，已补显式 float；`wg1-validation-01` 发现 RNG 浮点精度使固定区间强度略出端点，已将采样结果钳制回声明范围。没有删除失败断言或覆盖失败记录。

## 性能与证据

三次独立原生进程中，各 seed 的阶段耗时中位数：

| Seed | 描述生成 ms | CPU 烘焙 ms | 纹理创建 API ms |
|---|---:|---:|---:|
| 42 | 4.896 | 619.375 | 2.399 |
| 731 | 4.500 | 620.729 | 1.545 |
| 2649 | 4.614 | 969.845 | 1.812 |
| 713284 | 10.535 | 1046.198 | 1.897 |

12 个烘焙样本范围 609.311–1214.141 ms。纹理列是 CPU API 调用耗时，不是 GPU 完成时间；静态内存计数不是实测显存。原始内存/资源记录在每次 native evidence。没有测稳态对局 p95、GPU fence 时间或发布构建，没有把这些数据当作性能最终通过或冻结门槛。

主证据：[run-manifest.json](../../artifacts/watergen/wg1-final-01/run-manifest.json)、[按配套模板填写的清单](../../artifacts/watergen/wg1-final-01/delivery-run-manifest.json)、[native evidence](../../artifacts/watergen/wg1-final-01/wg1-native-evidence.json)、[跨进程/旧图/依赖/Schema 对照](../../artifacts/watergen/wg1-final-01/audit.json)。源码 SHA/dirty diff 与文件摘要区分记录，未将 Git blob SHA 冒充文件 SHA-256。

## 回退与停止点

关闭生成预览或启动 WG-0 的 `Open-Preview.ps1` 即可查看原环境；正常游戏入口一直保持上游状态，无需重置主线、覆盖档案或删除文件。日志和样片仅保存在本地 artifacts，源码、schema/profile、说明和本报告提交到水域分支。

本轮停止于 **WAITING_FOR_PLAYTEST**。用户选定构图/色彩方向后才进入 WG-2 动态预览、视差留边与真实样本可读性夹具；正式游戏接入仍属 WG-3。未发布新的游戏版本，未解锁主游戏 Phase 3。
