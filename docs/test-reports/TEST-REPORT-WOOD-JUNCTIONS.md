# 树枝与主干连接优化

日期：2026-10-01。基于 `44b1517`；验证环境为 Linux / Godot 4.6.3 / 原生 OpenGL Compatibility。项目声明的 Godot 4.7.2 和 Windows 发行包未在本轮重新验证。

## 改动

- 把同一棵树、倒木及分枝作为一组连续的世界坐标材质场，仍按原来的独立障碍物贴图绘制。
- 分枝纹理沿平滑曲线弯入主干，分叉处的树皮纹理、明暗与枝领连续过渡；只在整棵树的外边界绘制边缘阴影和水藻，去掉分枝根部横切主干的接缝。
- 保留原碰撞/缠线多边形、独立淡出目标和抄网行为，没有扩大遮挡范围或填上分叉间的水域。石头、水草和玩法代码未修改。
- 增加枝干共享像素、反向绘制顺序和组合遮罩回归测试。

## 检查

| 检查 | 通过 | 失败 |
| --- | ---: | ---: |
| obstacle_art | 92 | 0 |
| wood_junctions | 17 | 0 |
| plant_art（176 帧） | 16,578 | 0 |
| pond_v021 | 31 | 0 |
| net_v021 | 43 | 0 |
| untangle_v021 | 43 | 0 |
| grass_binding_v021 | 70 | 0 |
| feeding_movement_v0221 | 28 | 0 |
| architecture_v020 | 44 | 0 |
| line_motion_v021 | 29 | 0 |
| pond_native_v021 | 9 | 0 |
| obstacle_visuals_native | 16 | 0 |

额外逐字节比对：8 个石头贴图保持不变；三处真实游戏截图的所有变化都位于既有木头遮罩内部。10 个木头贴图在性能优化前后逐字节一致。三组树木共 1,597 个重叠像素的颜色完全一致，反转枝干绘制顺序也不会出现接缝。

原生验证覆盖草木透明度、草根固定、确定性绘制、绘制不修改世界、远岸镜头、抄网选择和动画。原生环境有不支持 VSync 的驱动警告；第一次场景测试使用无硬件音频的 Dummy 回退，后续显式使用 Dummy。pond_native_v021 结束有既有 ObjectDB 退出清理警告，9 项断言均通过。

材质仅在启动时生成，逐帧继续使用缓存贴图。枝条范围裁剪和预计算线段数据将中间版本的 18 个障碍物生成耗时从约 1.54 秒降至约 0.66 秒；旧材质约 0.14 秒。后续增加零权重主干区域裁剪，保持相同像素输出。没有新增逐帧材质计算。

截图及日志在忽略目录 `artifacts/wood-junctions-before/` 和 `artifacts/wood-junctions-after/`。前后对比使用相同冻结时刻、机位的原生截图，以最近邻放大，不是重新绘制的概念图。

```sh
# 无窗口检查（使用隔离的可写 XDG 路径及 --test-profile）
godot --headless --path . --script tests/wood_junctions.gd -- --test-profile
godot --headless --path . --script tests/obstacle_art.gd -- --test-profile
# 原生截图检查需图形窗口
godot --audio-driver Dummy --path . --script tests/obstacle_visuals_native.gd -- --test-profile
```
