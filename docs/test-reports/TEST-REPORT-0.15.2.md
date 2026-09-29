# 0.15.2 手臂像素风修正

日期：2026-09-27。Windows / Godot 4.7.2 / Compatibility OpenGL。

0.15.1 的手臂包含过细的皮肤渐变和金属纹理，与像素场景不一致。本版用内置图像工具将握姿重绘为大色块、阶梯轮廓和简化明暗，替换成 `assets/first_person/angler_hand_pixel.png`。完整提示词及素材路径见 `assets/first_person/HAND-PIXEL-GENERATION.md`。

新增一次性的 80×80 透明绘制层及 16 色材质，关闭平滑采样，将透明度限制为 0 或 1。此层渲染后复用，网格转动继续使用同一份低分辨率纹理，动态金属高光也使用色板内颜色。鱼竿接口根据新稿套筒位置微调，原世界坐标、输入和联机兼容标识不变。旧素材与旧发布包保留。

## 发布包验证

- 在发布目录用自身 exe / PCK 运行，未通过 `--path` 使用源码资源。
- 已有 `shore_native_v015.gd`：16 项通过，0 失败，覆盖下钩、横移、上钩 QTE、鼠标抄网路线与取消、提鱼和小鱼视角。
- 读取实际 GPU 渲染后的手臂层：尺寸 **80×80**，**16 种不透明颜色**，**0 个半透明像素**。
- 人工检查正常视图、3 倍游戏内局部预览、左右极限、受力收线及放线，共 7 张截图。局部图为游戏绘制视图放大，未经图片编辑。
- 最终构建及发布包日志无脚本、着色器或资源加载错误。
- 使用 `--test-profile` 和隔离配置。没有改动物理或协议，本轮未重复整套网络回归。

截图：`artifacts/hand-*-v0152.png`。日志：`artifacts/build-v0152.log`、`artifacts/package-hand-native-v0152.log`、`artifacts/package-hand-preview-v0152.log`。

输出：`../Releases/BaitbreakPixel-0.15.2/BaitbreakPixel.exe`。

- ZIP：`../Releases/BaitbreakPixel-0.15.2.zip`，90,334,713 字节。
- PCK SHA256：`4200BC1BBAC4010E1631BE414A961346083557A6C4C1154D4E279609FFBDE14B`。
