# 左手渔轮动画素材 · 0.16.0

使用内置 imagegen 工具，以已有右手素材 reference_tackle_v0158.png 为配色和像素风格参考，生成透明双格图，再用内置图像编辑移除握在手中的静态零件。摇柄与调节旋钮由游戏实时绘制，不会随手离开渔轮。

输出：left_reel_hands_v016.png，1774×887 RGBA。左格为收线握姿，右格为放线调节握姿。游戏内通过最近邻采样绘制到 128×64 透明纹理，每格 64×64；刚体旋转及锚点位移在 60 Hz 模拟中完成，未把动画烘焙到背景。

生成工具：built-in image_gen.imagegen。无需 API 密钥或运行时图像服务。

## 首次生成提示词

Use case: stylized-concept. Asset: two-cell sprite sheet on transparent background for an existing pixel fishing game. The input is a STYLE AND COLOR reference: match its chunky square skin planes, peach skin, dark warm brown outlines and olive-brown sleeve EXACTLY, without fine texture or smooth rendering. Produce a 1024x512 transparent PNG containing two separate 512x512 square cells. Each cell contains ONLY a LEFT hand with a SHORT cuff/forearm coming diagonally from lower-left toward upper-right, first-person palm turned toward a fishing reel to the right. Cell 1: thumb and curled fingers naturally grasp a small dark brown oval reel crank knob near (360,170) in its cell; the knob may be partly visible between fingers. Cell 2: same left hand, same scale, same wrist/cuff and light, but thumb and index finger make a natural pinching grip at (360,170) for a reel drag adjuster, remaining fingers relaxed and curled. This is the person's LEFT hand, not a mirrored right hand holding a rod. Anatomically coherent wrists, no broken bends. Upper-right hand should occupy approx 120x120 of each 512 cell; short forearm extends toward bottom-left and exits bottom edge, not a long detached arm. Genuine low resolution pixel art on an approximately 64x64 pixel grid per cell, enlarged with hard nearest-neighbor blocks. Restrained large connected color shapes, same warm skin and olive-brown clothes as the reference; no realistic pores, fine lines or highlights. No fishing rod, no reel body, no water, no background, no text, no separators, no cast shadow. Both cells actually transparent. Designed to be used as two rigid hand poses attached to a smoothly animated crank in code.

## 去除静态零件的编辑提示词

Edit only the held dark objects in this two-cell transparent pixel hand sprite sheet. Remove the dark reel knobs/objects from BOTH hands, replacing the object areas with genuine transparency so these become empty curled gripping hands. Preserve the hands, wrist anatomy, pixel blocks, skin colors, sleeve colors, cell positions, scale and canvas exactly. Reveal only the small finger surfaces necessarily hidden by those objects, in the same coarse pixel style. The left cell is an empty closed loose grip for grasping an in-game crank knob; the right cell is an empty thumb/index pinch for adjusting an in-game drag knob. Do not redraw the art, change gestures, enlarge hands, add anything or change transparency elsewhere.

## 原始输出

`C:/Users/Thomas Wade/.codex/generated_images/01a0c79b-dc6c-71a0-869c-f95ef95120c4/exec-01a7943b-c73c-4295-a6aa-98889d7f06fe.png`

