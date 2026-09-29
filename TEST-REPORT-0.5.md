# 2D 0.5 验证记录

验证日期：2026-09-26。Windows，Godot 4.7.2 Compatibility / OpenGL 3.3，AMD Radeon(TM) Graphics。

## 本轮变更

- 场景鱼钩缩小 30%，钩尖仍与颗粒饵对齐；吸力牵动改为线性响应，牵动距离与跟随速度增大；钩尖扫掠接触判定半径由 5 增至 7 像素。
- 自由练习按 F2 或从暂停菜单打开收放线调节。灵敏度 25%—250% 影响响应，力度 0%—250% 影响速度上限，0% 关闭自动收放线。保存、恢复默认和继续当前局可用，挑战参数固定。
- 按参考图绘制金属鱼钩、钩眼、倒刺、绿色判定带和红白浮漂，入口、缠线和松线三种 QTE 共用。保留既有按键、判定时间及成功区间。

## 逻辑检查

源码与发布包执行 `tests/smoke.gd`，最终均 **101 项通过、0 项失败**。

覆盖小钩尺寸与真实钩尖对齐、扩大范围后的擦边咬钩、默认 35% 吸力可明显牵钩、无需游动即可因吸食导致入口判定；覆盖灵敏度和力度各自的实际效果、零力度立即停止自动调整、挑战隔离、配置跨重开与保存加载保留、滑杆回调、恢复默认和异常配置保护。

既有的缠线、移动中吐钩、持续加速、水流、抄网、食物、有限补饵、完整挑战胜负和菜单测试继续通过。

日志：`artifacts/tests-v05.log`、`artifacts/package-tests-v05.log`。

## 原生输入和视觉检查

源码与发布包执行 `tests/visuals_v05.gd`，均输出 `NATIVE_V05_PASS`，退出码 0。

使用原生 F2 按键打开面板，按实际窗口缩放后的鼠标坐标点击两个滑杆，灵敏度达到 195%、力度达到 50%；点击恢复默认后均回到 100%。Esc 正确返回暂停，再次 Esc 继续当前局。验证期间还修复了从已关闭的帮助页进入练习调节后，返回目的地可能沿用标题页的问题。

验证 Space 成功与失败、缠绕后松线 QTE、持续 Shift 加速、松键回常速及暂停。检查练习调节、饵钩对齐、鱼钩轨道、绿区、浮漂、成功与失败反馈等阶段截图，未见界面文字溢出。

关键截图：

- `artifacts/practice-adjusted-v05.png`
- `artifacts/qte-green-zone-v05.png`
- `artifacts/qte-success-v05.png`
- `artifacts/entry-hook-v05.png`
- `artifacts/bait-water-v05.png`

水流与 QTE 同时渲染的 120 帧抽样：源码 1,999 ms，发布包 1,998 ms，均报告 60 FPS。此结果仅为本机短时抽样，不代表所有硬件或长时间人工试玩手感。

日志：`artifacts/native-source-v05.log`、`artifacts/native-tests-v05.log`。

## 发布物

发布 exe 在不传项目路径和外部测试脚本的情况下成功加载版本 0.5，并生成主场景截图。最终验证日志无脚本错误或警告。

相对工作区 `E:/Fish_catches_people`：

- `Releases/BaitbreakPixel-0.5/BaitbreakPixel.exe`：180,858,888 字节。
- 同目录 `BaitbreakPixel.pck`：82,704 字节。
- 同目录含更新的 `开始试玩.txt` 与 `GODOT-NOTICES.txt`。
- `Releases/BaitbreakPixel-0.5.zip`：87,686,023 字节。

ZIP 内与发布目录 PCK 的 SHA-256 一致：

`B996B9E4E13439E53570C9537C925C9FE90A28419911C41D3AE930C63DF34AFD`
