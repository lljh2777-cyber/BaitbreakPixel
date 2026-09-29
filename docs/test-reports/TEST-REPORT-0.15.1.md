# 0.15.1 手臂与握姿重绘

日期：2026-09-27。Windows / Godot 4.7.2 / Compatibility OpenGL。

重绘第一人称右手、手腕、针织袖口、橄榄色衣袖、软木握柄和金属卷线轮。新增透明 PNG `assets/first_person/angler_hand.png`；内置图像工具的完整提示词与制作方式见 `assets/first_person/HAND-GENERATION.md`。

`scripts/angler_hand.gd` 用一张纹理及二维网格驱动握姿：手掌和握柄一起转向鱼竿，袖口以下逐渐降低转角，使前臂保持连续。竿身和贴图使用同一个套筒接口坐标，避免横移时断开。收放线时保留轻微握持动作和沿真实方向流动的金属高光，安静时停止。原来的多边形手和矩形手指不再绘制。画面使用最近邻采样。

本次只修改本地显示，保留鱼线、捕获、输入、QTE、双向坐标转换及网络快照。项目版本 0.15.1，网络兼容标识仍是 0.15，可与上一版互联。原 0.15 发布包保留。

## 验证

- 源码及独立发布包分别运行已有 `tests/shore_native_v015.gd`：各 16 项通过，0 失败。覆盖实际 Q 下钩、D 横移、上钩 QTE、原生鼠标路线、拐角行进、松 E 取消、提鱼与小鱼视角。
- 发布包调用 `tools/capture_hand.gd` 完成静止、左右极限、受力收线、动画推进、放线等 7 张预览，人工核对握姿、纹理透明、竿柄连接和袖口。
- `hand-closeup-v0151.png` 是在游戏渲染中将视图放大 3 倍的局部预览，未修改原素材；其余截图是正常 640×360 逻辑画面。
- 最终构建、发布包操作及预览日志无脚本解析或资源加载错误。
- 使用 `--test-profile` 和隔离配置，不修改玩家存档。发布包在自身目录运行，资源由新 PCK 加载，未用 `--path` 回指源码。

日志：`artifacts/build-v0151.log`、`artifacts/package-hand-native-v0151.log`、`artifacts/package-hand-preview-v0151.log`。早期素材导入日志中的类名冲突已修复，最终结果以上述日志为准。

输出：`../Releases/BaitbreakPixel-0.15.1/BaitbreakPixel.exe`。

- ZIP：`../Releases/BaitbreakPixel-0.15.1.zip`，89,800,685 字节。
- PCK SHA256：`2085D3D9307339B16ABBAB06CA58545E7CCF16E616FFAC8F31043B102CECE9DE`。
