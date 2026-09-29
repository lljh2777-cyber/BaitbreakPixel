# 完整像素前臂素材 · 0.15.5

使用内置 `image_gen` 编辑工具，透明背景；没有使用 CLI/API。项目文件为 `assets/first_person/angler_hand_forearm.png`，原 `angler_hand_pixel.png` 保留。

目标是完整延长像素袖子，让手和卷线轮上移后仍能自然连接到画面外。手、袖口、前臂作为一张完整贴图刚性移动，不拼接程序绘制的袖子，不对手腕使用权重变形。运行时采用 112×112 像素层、16 色固定色板与最近邻采样。

输入图（编辑目标）：`assets/first_person/angler_hand_pixel.png`。

输出原图：`C:/Users/Thomas Wade/.codex/generated_images/01a0c79b-dc6c-71a0-869c-f95ef95120c4/exec-f5d80314-8583-4e8b-b0eb-9b2c069af55b.png`。

完整最终提示词：

```text
Use case: precise-object-edit. Asset type: transparent first-person 2D pixel game sprite. Image 1 is the edit target. Recompose this exact existing right hand, cork fishing-rod handle and reel on a larger square transparent canvas: uniformly scale the existing artwork to 70% of the canvas dimensions, anchored at the top-left, preserving the hand anatomy, grip, reel, colors, and diagonal orientation exactly. Continue ONLY the olive-green sleeved forearm naturally farther down-right from the old cropped canvas edge until it exits the new bottom-right edge. The longer forearm must be part of a cohesive hand-painted pixel sprite, matching the original stepped pixel outline, broad olive/dark-green shade clusters, and a few cloth folds; it must not look like a flat vector polygon or a straight rigid tube. The intended layout has the sleeve cuff/wrist near 49% canvas width and 39% canvas height, and the rod's small metal socket tip near 6.5% width and 5.3% height; the forearm occupies the diagonal lower-right half. True low-resolution pixel art look, roughly a 112 by 112 native pixel grid enlarged with hard nearest-neighbor edges, limited 16-color palette, opaque pixel clusters, no gradient, no thin realistic texture, no antialiasing. Preserve the orange-tan skin, golden cork, blue-grey reel and olive sleeve. No rod shaft beyond the existing short metal ferrule; game code draws the shaft. No background, no shadow plane, no text, no extra hands or fingers, no border. Genuine transparent alpha outside the sprite. Keep the hand and wrist straight in one anatomically coherent forearm pose; do not bend or twist the wrist.
```
