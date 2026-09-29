# 岸边第一人称湖面素材

日期：2026-09-27。素材：`sunset_lake.png`。

使用内置 `image_gen.imagegen` 生成原创背景；未使用 CLI、外部 API Key 或 Python 图像编辑。参考用户提供的落日像素湖面构图，单独生成无角色、无鱼竿、无浮漂的背景。原图复制到本目录，Godot 在 640×360 逻辑画面中以最近邻纹理采样显示。鱼竿、手、浮漂、抄网、动态水纹及水下影子由 `scripts/shore_view.gd` 根据实际游戏状态绘制。运行时只读取本地 PNG。

## 提交给生成工具的完整提示词

Use case: stylized-concept. Asset type: background-only bitmap for a 2D pixel-art fishing game. Generate a new 16:9 landscape, 1536x864 if possible, from a stationary fisher's first-person eye level on a lakeshore looking across a broad calm lake at sunset. Fine handcrafted pixel art, visibly stepped pixels and limited coherent palette, warm peach-orange sun near the horizon, lavender distant mountains, dark evergreen wooded banks framing both distant sides, teal-blue reflective water. Horizon precisely about 37 percent from the top. Water occupies the lower 63 percent. Bottom left and bottom right corners have only a little dark bank grass and reeds, leaving the central 90 percent of the width clear water for gameplay. The main fishing activity will be overlaid in a horizontal band at 63 percent of image height, so keep this area calm and legible with subdued reflections. The sun reflection should be offset right of center, not a bright blanket across the water. CRITICAL: background scenery only, no fishing rod, no hands, no people, no fishing line, no float, no fish, no underwater objects, no UI, no text, no border, no red rectangle. Surface is opaque blue green water with shallow subtle horizontal ripples, not a transparent underwater cutaway. The fish shadows and all interactive tackle will be drawn by game code later. Match the mood of the user's lakeside sunset pixel-art reference, but produce a clean original environment plate.
