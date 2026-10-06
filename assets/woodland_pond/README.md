# 固定自然池塘素材

- `scene.png`：Watergen 工作树 `feature/watergen-v2` 中的 `docs/watergen/plants-round2/A-plant-communities.png`，2048×768。原画直接复制，不重新生成构图。
- `cleanplate.png`：内置 `image_gen` 工具编辑原画得到的遮挡后底图，2048×768。只用于原有倒木、石头、高草淡化或缠线形变后露出的区域。
- 工具模式：imagegen skill 的 **built-in edit**，不使用 CLI/API fallback。参考路径为上述 A 图；生成文件为 `C:/Users/Thomas Wade/.codex/generated_images/01a10a0b-f7e1-73c3-b8d4-3cc317bf1edc/exec-ae9ad208-8e64-45fa-884b-91f96b2d7d70.png`，随后复制进本目录。
- 编辑要求：保持原画的镜头、尺寸、像素笔触、光照、颜色、远景和池底坡形；移除近处横跨沟谷的主倒木、左侧树桩与相连枝干、主要前景大石以及左右高草；自然补出被遮住的水体和池底。不加入鱼、钩、线、文字或界面。

运行时用最近邻缩放到世界坐标 1280×480，依据 `woodland_pond_map.gd` 中独立的视觉蒙版组装缓存纹理。主干、枝条及附生苔藻共用淡化组；草丛保留原缠线条带变形。真实接触多边形与视觉蒙版分别定义，不从颜色或像素推断碰撞。

背景不访问隐藏钩、NPC 内部状态或比赛随机源。装饰动物沿用 Watergen 的 `decorative_fauna_layer.gd` 图案与锚点，本地时钟驱动；不创建权威实体。
