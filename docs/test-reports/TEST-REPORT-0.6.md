# 2D 0.6 抄网验证

日期：2026-09-26。Windows，Godot 4.7.2 Compatibility / OpenGL 3.3，AMD Radeon(TM) Graphics。

## 实现

- 横向扫网和从水面斜向下探交替出现，红光指示来向，范围与倒计时预警，路线锁定后不追踪玩家。
- 网口碰撞使用椭圆，木石裁剪终点；红色轮廓覆盖整条捕获扫掠体。低处横扫从岸边石头上方进入，防止网口生成在石头内部。
- 网袋、菱形网眼、木柄、入水颗粒与声音、撤回和捕获提网动画。
- 练习可按 N 或点击暂停页的“抄网练习”，支持连续五次以上。捕获期间锁定移动，提网后保留食物并回巢边；挑战则在提网后失败。
- 首次挑战抄网约在离巢 18 秒后，补饵、上钩及脱钩后的短暂恢复会推迟新攻击。

## 验证结果

最终源码与发布包的 `tests/smoke.gd` 均 **114 项通过，0 项失败**。新增覆盖默认出生位置试网、两种路线、横向与纵向躲避、预警后不追踪、网口被木石阻挡、五次连续触发、练习捕获保留食物、捕获锁定与暂停、挑战提网失败及预警轮廓覆盖。完整挑战实际吃饵、躲网并回巢通过，未直接赋分。

发布包的 `tests/nets_v06.gd` 输出 `NATIVE_NET_V06_PASS`，退出码 0。通过实际 N 输入和暂停页按钮点击触发网，检查默认出生处、准备、横扫预警与运动、下探预警与运动、捕获提起、练习回巢、掩体和挑战结算截图。旧功能的原生 F2、滑杆、恢复默认、QTE 和持续 Shift 输入检查也通过。

抄网网格与水流同时渲染时，120 帧抽样用时约 1,967 ms，报告 60 FPS；仅代表本机短时抽样。验证为自动逻辑、原生输入事件和截图检查，难度与手感仍可依据人工试玩调整。

日志：

- `artifacts/tests-v06.log`
- `artifacts/package-tests-v06.log`
- `artifacts/native-tests-v06.log`
- `artifacts/native-regression-v06.log`
- `artifacts/package-launch-v06.log`

截图：`artifacts/net-starting-area-v06.png`、`net-sweep-warning-v06.png`、`net-sweep-v06.png`、`net-drop-v06.png`、`net-caught-v06.png`、`pause-net-button-v06.png` 等。

## 发布物

相对工作区 `E:/Fish_catches_people`：

- `Releases/BaitbreakPixel-0.6/BaitbreakPixel.exe`：180,858,888 字节。
- 同目录 `BaitbreakPixel.pck`：88,096 字节。
- 同目录包含 `开始试玩.txt` 与 `GODOT-NOTICES.txt`。
- `Releases/BaitbreakPixel-0.6.zip`：87,688,160 字节。

发布主场景可直接启动，最终验证日志没有脚本错误或警告。ZIP 内资源包与发布目录资源包的 SHA-256 相同：

`E0F8019533C73FA8C6D88A06740E19CC05B469382EF1EEA3BE8C04C936A02404`
