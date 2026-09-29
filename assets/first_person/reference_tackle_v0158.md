# 0.15.8 参考图持竿素材

来源：用户本轮提供的图 2，`codex-clipboard-c19cf88d-a432-4d1b-a8bc-bdaf0b41f07b.png`。

方式：内置 image_gen 图像编辑 / 背景提取。输出保存在本目录 `reference_tackle_v0158.png`，1448×1086，RGBA。不是重新设计握姿或更换渔具。

运行时使用最近邻采样及透明边缘阈值，保留原配色；手、握柄、卷线轮作为刚性区域，竿身用同一素材的纹理条带实现受力弯曲。

最终使用提示词：

> Use case: background-extraction. Input image is the exact edit target, not loose inspiration. Extract ONLY the existing foreground fishing rod, brown grip, black/grey reel, right hand and olive-brown sleeve from this supplied pixel art image, on a truly transparent background. Preserve the SAME exact pixel-art object, pose, silhouette, large blocky pixels, colors and proportions. Do not redraw into a different hand or different fishing equipment. Preserve its original lower-right placement and the full original image canvas/aspect ratio. Remove all landscape, water, vegetation, sky, fishing line, bobber and ripples. The rod tip is near (873,462), brown grip near (1085,842), hand near (1150,945), sleeve exits bottom edge of the original 1448x1086 image. Keep the complete rod connected to the original hand; keep the original black chunky compact reel on the left side of the grip. Keep the broad skin-color planes and blocky low-detail sleeve exactly as in the supplied reference. No thin sketchy outlines, no metallic filigree, no yellow cork, no new fingers, no smoothing, no new objects. This is faithful cutout work, not a creative redesign.
