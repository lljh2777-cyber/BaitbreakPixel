# WG-0 交付报告

状态：**WAITING_FOR_REVIEW**。WG-0 已实现并完成以下自动检查；人工确认 NOT_RUN，WG-1 尚未开始。

## 本轮范围

任务 ID / 获准阶段：WG-0。
用户要求：依据水域文档，在 `E:\Fish_catches_people\aquatic_system` 开发；使用已解压配套资料。
交付：独立旧环境预览、PublicMapContext 只读适配器、旧六层/固定镜头基线、私有验证入口、后续注册方案。

源码工作树：`E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen`，分支 `feature/watergen`。
基线 SHA：`9c447e7210987472d108ce284b9df5cd057f2dc7`（feature/dev / 0.24.5）。
文档基线 SHA：`a4a1f538860cb37741a49ccd9fdb078d7b39b8b0`（0.24.4）。
实际测试 SHA：`15f26680356210b0d9105f0516403921e1dba76b`；三次最终运行均为干净工作树，执行前后源码摘要相同。该提交之后的本报告为交付记录，不改变运行代码。
详细差异见 [BASELINE_DIFF.md](BASELINE_DIFF.md)。

引擎：`4.7.2.stable.official.ed1daf0bf`；完整引擎 SHA `ed1daf0bf001b61586d9930840f2f1394092c079`。
系统：Windows 10.0.26100；CPU：AMD Ryzen 7 7735H；GPU：AMD Radeon(TM) Graphics；渲染器：原生 OpenGL 3.3 / gl_compatibility；音频 Dummy。
日期和运行时间以 manifest 的 Asia/Shanghai 时间记录。

## 变更与边界

全部改动为新增水域私有文件（GREEN）：

- `scripts/watergen/`：公开契约校验/规范化、地图字段复制适配器。
- `tools/watergen/`、`scenes/watergen/`：旧画家静态显示、原生捕获、有限时运行器、交互启动脚本。
- `tests/watergen/`：非法输入、嵌套复制隔离及目标顺序/几何/分组验证。
- `data/watergen/`：来源基线、固定引擎六层像素基线。
- `docs/watergen/`：任务单、基线差异、使用说明、注册方案和本报告。

原生产文件变更列表为空，包括 project.godot、主入口、Layout、View、已有画家、世界模拟、协议、规则、注册表、runner 和版本文件。原 `BaitbreakPixel` 工作树保持 main / `c9f3c4c7...`。

未实例化 authority；未接入网络、摄食或存档。源码依赖检查未发现 world_simulation/world_snapshot/network/rules_store/pond/main 场景进入预览依赖图。该检查是辅助证据，不能替代 WG-3 信息等价/实际 authority 重放。

预览使用旧 `Water.layers()`、旧木石和植物画家；源字段与运行时 40 个 interaction targets 在准备及绘制后保持相同。公开地图摘要（前/后相同）：

`ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d`

生成器版本 / VisualProfile / visual_seed：均不适用（null）；本阶段仅 legacy 基线，不伪造四个 seed 候选。

## 自动验证与证据

主证据目录：[wg0-final-01](../../artifacts/watergen/wg0-final-01/)。
运行清单：[run-manifest.json](../../artifacts/watergen/wg0-final-01/run-manifest.json)。
像素/硬件/用户目录证据：[native-evidence.json](../../artifacts/watergen/wg0-final-01/native-evidence.json)。
跨进程对照与依赖检查：[audit.json](../../artifacts/watergen/wg0-final-01/audit.json)。

| 检查 | 状态 | 证据与边界 |
|---|---|---|
| WG-T01 当前地图契约 | PASS | 未知/私有和嵌套字段、版本、类型、负尺寸、NaN/Infinity、空地图、超限数量、错序与非法分组均被拒绝；VisualProfile 校验留 WG-1 |
| WG-T02 输入不可变 | PASS | 嵌套输出修改不影响 Layout/另一份上下文；绘制前后原数据相同；生成器/烘焙器尚无新实现 |
| WG-T05 地图几何与目标顺序 | PASS | 18 木石、22 植物，逐一比较 polygon、bounds、索引与 fade group；生产 Layout 未修改 |
| 旧六层基线 | PASS | 六层 1280×480 RGBA8，原始像素摘要匹配冻结基线 |
| 原生镜头与重复绘制 | PASS | 五个 640×360 视口；同镜头重复像素相同，跨三次独立进程也相同 |
| 用户目录隔离 | PASS | 原生进程实际 OS.get_user_data_dir() 位于该 run 的 isolated-user/appdata/BaitbreakPixel |
| 测试注册检查 | PASS | 原 runner `--list` 成功，103 个顶层入口不变；私有子目录由单独入口启动 |
| 现有 Python runner 测试 | PASS（部分跳过） | 28 项中 23 通过、5 跳过：4 个可选 Godot 测试因未设置该测试发现用的 GODOT 环境变量，1 个为 POSIX 专用。跳过不计通过 |
| WG-T03/04 新生成器复现与随机流 | NOT_RUN | WG-1 尚无实现；旧画家像素重复不冒充新生成器通过 |
| WG-T06/07/09/10/11/12/13/14/15 | NOT_RUN | authority/RNG、隐藏真值、真实游戏绘制/可读性、资源切换、回退、current/native 全量游戏回归、网络与包体属后续阶段 |
| WG-T08 新层视差与留边 | NOT_RUN | 已采旧画家极限镜头，未实现/验收 generated 留边 |
| WG-T16 人工确认 | NOT_RUN | 等待用户复核；自动截图成功不是美术通过 |

计数：最终主运行 **2 个私有检查入口，81 + 44 = 125 项断言全部通过**。两次额外 native 运行各 44 项通过，用于独立进程像素对照和初始化计时；不累加成新的用例覆盖。Python 28 项是另一个测试集。

复现主命令（在工作树下）：

```powershell
& 'D:\python\python.exe' tools/watergen/run_wg0.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg0-final-01 --timeout 40
```

重跑时须使用新的 run-id。另外两次使用 `--mode native --run-id wg0-final-02` / `wg0-final-03`。完整参数保存在各运行清单。registry 和 Python runner 原始输出分别保存在主证据目录 `registry.log`、`runner-tests.log`。

## 画面与性能

每次 native 输出 14 张 PNG：六个原层、五个固定镜头、整世界、纯环境中心图、诊断中心图。

- 镜头 `(0,0)`、`(320,60)`、`(640,120)`、`(0,120)`、`(640,0)`。
- [中心视口](../../artifacts/watergen/wg0-final-01/viewport-320-60.png)。
- [整世界图](../../artifacts/watergen/wg0-final-01/world-static.png)。
- [公开地图 JSON](../../artifacts/watergen/wg0-final-01/public-map-context.json)。

人工目视检查已查看整世界和中心/右上视口，未见黑底或画家资源缺失；这是开发检查，不是用户确认。

三次独立原生进程的旧 `Water.layers()`（CPU 生成 + 纹理创建合计）分别为 **538.897 / 648.986 / 544.800 ms**。这些是固定环境下的单次初始化原始样本，不是稳态帧耗时或 GPU 独立上传时间。完整描述生成/烘焙/上传/稳态 p95、冷暖启动矩阵、内存和切 seed 资源测试仍为 NOT_RUN；没有据此冻结性能门槛。

预览明确省略动态水流粒子、活动钓组水面铺板、巢穴美术/进度、角色/食物/线网/HUD。这些依赖主游戏状态；保留它们的生产实现不变。因此样片只能作为静态环境基线，不能称为完整对局截图。

历史开发运行仍保留：`wg0-validation-01` 有一次引擎短 SHA/完整 SHA 的 fixture 比较失败，随后修正为完整引擎 SHA；最终三个运行全部通过。未删除或覆盖失败证据。

## 人工验收、交付与停止点

待确认：工作树隔离方式、旧画面预览基线、是否进入 WG-1 静态视觉生成。尚无 WG-PF 已确认反馈，不自行填写 CONFIRMED。

运行预览见 [使用说明](README.md) 和 [Open-Preview.ps1](../../tools/watergen/Open-Preview.ps1)。产物和完整日志保留在本地 artifacts，不加入生产 PCK；Git 提交包含实现、冻结摘要和本报告。

回退：关闭独立预览，继续使用原主游戏目录即可。生产主场景未改，无需重置分支、覆盖存档或删除文件。

本轮停止于 **WAITING_FOR_REVIEW**。下一阶段为 WG-1；依据用户指定的里程碑，需要先确认 WG-0 基线与隔离方案，才生成新的静态视觉样片。未开始 WG-1/2/3，未发布游戏版本。
