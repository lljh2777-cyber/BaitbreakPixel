# WG-2.1 视觉氛围迭代交付报告

状态：**IMPLEMENTED / WAITING_FOR_REVIEW**。独立预览及自动验证完成，人工视觉评审未完成。用户明确要求暂不接入试玩，本轮没有进入 WG-3。

## 本轮范围与基线

- 任务：保持现有碰撞和玩法，改善 WG-2 的视觉丰富度、动态氛围及种子差异；默认仍用用户选定的 713284。
- 迭代基线：`77732863da30e02d87e3fa048ab94a031d65beda`；底层游戏冻结于 `4e8a7b9011b65e53e1971cf3ddcba38880fbd6c8`（0.24.6）。本轮 fetch 发现的上游 `f32d2dc250e2fcb468d9f404120dc671b22522c9` 含 NPC 鱼、协议和 View 变化，没有合入。
- 视觉实现：`d86fb35de8a982e8ebd17dee8335f6ed640dd674`；图集合并和视口剔除：`0ff06bc8b7bf1e5b2c441a6154dd5f0c28e21b46`。
- 最终三组验证均测试 `0ff06bc8b7bf1e5b2c441a6154dd5f0c28e21b46`，开始时 `dirty=false`，diff 摘要为 SHA-256 空串摘要，运行前后源文件摘要一致。后续交付提交只改 Markdown 文档。
- 引擎：Godot `4.7.2-stable (official)`，hash `ed1daf0bf001b61586d9930840f2f1394092c079`。Windows / GL Compatibility / OpenGL 3.3，AMD Radeon(TM) Graphics，Ryzen 7 7735H。Dummy 音频，声音未验收。

## 变更与边界

全部改动位于私有 watergen 目录，属于配套文档的 GREEN 范围。没有修改共享生产接口，不涉及 YELLOW/RED 批准。主游戏检出保持干净，相对冻结上游的原有生产文件修改清单为空。

| 文件/模块 | 变化及目的 |
|---|---|
| `forest_pond_atmosphere.json`、`water_atmosphere.gd` | 新增 wg-2.1 profile；四类构图、左右优势、光域开口、群落疏密及轻微色相差异 |
| `water_foliage.gd` | 丰富蕨叶、带状叶轮廓和低对比床面落叶，保留中央可读空间 |
| dynamic generator / baker | 延续原公开地图，生成新装饰；18 处动画小图合入单张带间隔图集 |
| visual frame / cache | 显式时间、固定锚点、整数像素分段；两个 bundle 上限，无逐帧烘焙/上传 |
| dynamic preview / runner | 默认展示新版；V 同镜头同时间前后对照，原生截图与 100 帧动态样片导出 |
| atmosphere contract / 文档 | 确定性、随机隔离、图集和逐行位移等价验证，保留旧版回归 |

四类种子为：713284「蕨叶庭」、2649「长叶湾」、42「浮叶荫」、731「垂根岸」。同类其他种子继续通过命名随机流改变位置、尺寸、左右分布及相位，不调用世界 RNG。

默认 18 处装饰动画分为 6 株远景草、8 株中景草、2 株前景草、2 组垂根。草底部与垂根顶部固定；最大摆幅分别为 4/3/3/3 px，周期和相位错开。没有增加流向提示、食物状金色闪点、鱼影或可碰撞物。水体、光束和装饰颗粒仍静态烘焙。

authority、信息协议、世界 RNG、碰撞和 40 个公开交互目标的坐标/顺序/分组、原木石、交互草、食物视觉规则均不变。未改项目入口、游戏版本、发布包、共享测试注册表及存档。

- 生成器：`wg-2.1`；栅格：`rgba8-rich-foliage-atlas-v2`；profile：`forest_pond_v1`。
- 规范化 profile SHA-256：`64ab73ec313938ec12a4135d40ac1e0b623180345015b0110a46e6dca5c542b0`。
- 公开地图前/后 SHA-256：`ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d`，一致。
- 原 WG-2.0 profile、栅格语义及 WG-1 生成器保留。新版本缓存键独立；共享绘制优化没有更新旧黄金图。

## 自动验证

完整命令、源文件摘要和日志保存在各组 `run-manifest.json`。以下命令均在水域 worktree 中执行，复跑需更换 run-id，已有产物不覆盖。

```powershell
& D:\python\python.exe tools/watergen/run_wg2.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --clip --run-id wg21-final-02 --timeout 240
& D:\python\python.exe tools/watergen/run_wg2.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --baseline --mode all --test-seconds 1 --run-id wg21-legacy-atlas-final --timeout 120
& D:\python\python.exe tools/watergen/run_wg1.py --godot 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --mode all --run-id wg21-wg1-atlas-final --timeout 120
```

| 检查 | 状态 | 实际结果与限制 |
|---|---|---|
| WG-T01/02 输入和不可变 | PASS | WG-2.1 headless 49 个断言，拒绝非法 seed/版本/字段；原生复核地图和 profile |
| WG-T03 确定性 | PASS | 同 seed 计划/像素复现；独立短测与正式运行的四种子计划及 76 张 PNG 一致 |
| WG-T04 随机隔离 | PASS（预览） | 增加 mote 不改变草、根、光及构图；原 WG-1 隔离检查通过 |
| WG-T05 几何 | PASS（静态） | 原公开地图/目标数据不变；生产运行态没有测试 |
| WG-T08 视差与边缘 | PASS | 四种子 × 五镜头，留边覆盖与原生位置探针；前后对照固定时间/镜头 |
| WG-T10 可读性 | NOT_RUN（人工） | 原生公开样本截图已提供，不能代替用户辨识判断 |
| WG-T11 生命周期 | PASS（预览） | 20 次切种子，资源数稳定、淘汰纹理 WeakRef 释放；60 秒暂停/恢复/移动镜头，无重建 |
| 图集/分段优化 | PASS | 图集区域逐字节等于原小图；六个采样时间下所有像素行位移等价，每对象至多 5 段；优化前后 176 张 PNG 全部一致 |
| WG-2.0 回归 | PASS | 78 headless + 170 native；74 张 PNG 与原 `wg2-final-02` 逐字节一致；本次定时仅 1 秒 smoke |
| WG-1 回归 | PASS | 58 headless + 140 native；56 张 PNG 与上轮 `wg2-wg1-regression` 逐字节一致 |
| WG-T06/07/09/12/13/14/15 | NOT_RUN | 权威逐 tick、隐藏真值、生产遮挡、回退、完整对局、网络与包体不在此次独立视觉迭代范围 |
| WG-T16 | NOT_RUN（本轮） | 713284 是已有选种子反馈；尚无新版人工视觉验收 |

最终三组共 **6 次套件执行、771 个通过断言、0 失败**：新版 49+276，WG-2.0 78+170，WG-1 58+140。日志分别有对应数量的 `_PASS` 标记和各一个完成汇总标记（共 6 个）。写文件检查亦计入断言，不能表述为 771 个独立玩法测试。开发及短测不重复计为新增覆盖。

证据入口：[最终 manifest](../../artifacts/watergen/wg21-final-02/run-manifest.json)、[模板交付 manifest](../../artifacts/watergen/wg21-final-02/delivery-run-manifest.json)、[交叉审计](../../artifacts/watergen/wg21-final-02/audit.json)。同目录保留 `audit-delivery.py`、原生日志、四种子 ScenePlan 与 RGBA 摘要。

## 画面与性能

[样片画廊](../../artifacts/watergen/wg21-final-02/gallery.html)含原 WG-2.0 / 新 WG-2.1 同镜头对照、四种子全景、五镜头与可读性样本。[动态视频](../../artifacts/watergen/wg21-final-02/atmosphere.mp4)来自引擎导出的 100 张 1280×480 PNG，显式时间 0–9.9 秒，以 10 fps 编码为 10 秒视频。实际预览随显示帧率绘制；精确证据是 PNG，视频仅用于观看。

| 实测项 | 丰富植被初版（final-01） | 图集及视口剔除后（final-02） |
|---|---:|---:|
| 定时运行 | 60.009443 s | 60.007257 s |
| 预热 / 绘制采样 | 120 / 1852 帧 | 120 / 7190 帧 |
| CPU 绘制提交中位数 / p95 | 0.904 / 1.151 ms | 0.759 / 1.177 ms |
| 帧间隔中位数 / p95 | 32.384 / 33.416 ms | 8.347 / 9.033 ms |
| 计时前/后计数 | `[29,25,25,584]` 不变 | `[29,25,25,176]` 不变 |

计数依次为计划调用、CPU 烘焙、bundle 上传、累计纹理创建；包含前置四种子和前后对照采样，不是同时驻留数量。新版每 bundle 为六张静态纹理加一张动画图集。

最终 24 次冷准备实测：计划 6.682–14.217 ms（中位数 8.759 ms），CPU 烘焙 687.115–916.701 ms（中位数 757.858 ms），上传 API 2.069–3.121 ms。冷切换仍有约一秒准备时间，应保留在加载/预览切种子阶段，不宜直接在对局帧内执行。

20 次切种子后资源计数始终 28；切换期引擎静态堆 39,215,456–40,102,372 bytes，计时期 39,299,620–39,765,792 bytes。日志及计时数组本身会分配内存；未见纹理累积，不据此推断任意时长无泄漏。

CPU 数据仅为绘制命令提交；帧间隔含显示同步和调度，上传 API 不是 GPU fence，静态堆不是显存。这里证明的是本机独立预览实测，不能代替完整游戏/GPU 性能或 0.25.0 兼容性验收。

## 开发记录、人工评审与停止点

失败记录保留：早期 `wg21-legacy-dev-01` 发现新叶片代码类型推断错误，已补明确类型；`wg21-dev-01` 的行覆盖断言缩进错误已修正。初版 `wg21-final-01` 自动断言通过，但实测帧间隔约 32 ms，因此继续做图集及视口剔除优化，没有把断言通过当作性能完成。

首次图集试验 `wg21-atlas-check` 在第 4 次种子切换后发生原生等待超时，日志无脚本错误，具体原因未定位。加入视口剔除和准备阶段日志后的短测、正式 60 秒运行及旧版回归均完成；不把该次超时归因于未经证实的硬件原因，也不隐藏其日志。

WG-PF-001 的「沿用 713284」反馈仍有效。本轮叶片密度、草与垂根摆幅、四类构图差异、食物/细线/QTE 辨识均等待用户看样片，**没有填写用户已确认**。

使用 [独立预览入口](../../tools/watergen/Open-Dynamic-Preview.ps1)：`[ ]` 换种子，空格暂停，`V` 暂停并切换原 WG-2.0 对照，逗号/句号前后采样，`F` 看可读性样本，Esc 退出。详情见 [使用说明](WG21_README.md)。关闭预览即可回退；没有生产补丁或试玩包需要撤销。

交付位于 `feature/watergen`；本机截图、视频、日志和审计在忽略的 artifacts 目录，随源码提交的文档保留其本地路径。本轮停止于 **WAITING_FOR_REVIEW**，继续遵守「暂不接入试玩」，不启动 WG-3。
