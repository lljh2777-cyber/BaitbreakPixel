# 自然池塘视觉重做 · 第三轮装饰生态

日期：2026-10-06。沿用 A「沟谷倒木」及第二轮植物底图，增加独立、可开关和暂停的动物图层。

[前后对照与局部样片](fauna-round3/gallery.html)

## 本轮内容

| 装饰 | 数量与表现 |
|---|---|
| 小虾 | 3 只，14×6 逻辑像素；暖褐色身体、腿与触须，停留后短移 6–8 像素 |
| 蜗牛 | 2 只，11×6 逻辑像素；落在倒木和石面，主体停留、触角轻微变化 |
| 远景鱼群 | 2 组，每组 5 条，单条 8×3 逻辑像素；低对比蓝青色、46% 不透明度，缓慢限幅游动 |

动物使用代码像素精灵组成的一张 **96×8 图集**。第二轮植物 PNG 完全复用，前后模式共享同一张底图纹理。没有重新生成或覆盖地势、木石、植物图片。

独立视觉时间与本地种子控制姿态；换种子只改变节奏。没有追食、响应鱼钩、逃避抄网、碰撞或音效。所有动物在角色/食物/细线识别样本之前绘制，HUD/QTE 样本仍在不透明面板上。

## 查看

```powershell
& 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen-v2\tools\watergen\Open-Decorative-Fauna.ps1'
```

`1` 只看植物、`2` 加入动物；`空格` 暂停/继续，`R` 回到 0 秒；`Tab` 全景/镜头，方向键平移，`Home` 居中，`P` 识别样本，`G` 动物位置/中央留白标记，`Esc` 退出。网页是原生捕获帧；连续动画请打开这个 Godot 预览。

## 验证

第三轮 **97/97** 原生检查通过；第一轮回归 **65/65**，第二轮回归 **64/64**。覆盖确定性、暂停/恢复/跳时、181 个时间样本中的数量及范围、中央留白、图集复用、五镜头和原生像素变化。第三轮输出 33 张 PNG，包含三张 3 倍放大局部图。

0 秒整世界前后图直接比较，仅 319 个像素因动物变化；中央参考区 `Rect2(320,77,679,230)` 的像素完全不变。[像素比较记录](fauna-round3/evidence/pixel-review.json) · [原生日志](fauna-round3/evidence/run.txt) · [结果](fauna-round3/evidence/run-results.json)。首次检查发现种子相位过近，调整整数相位派生后已复测通过；小虾色调也已调整以区别于石面。

已观察局部体型、中央识别样本与侧边画面。远景鱼比玩家/NPC 小，虾与蜗牛集中在底部及木石上；固定样本仍不能替代真实食物、缠线、抄网和 QTE 全流程验收。

## 文件改动与玩法隔离

- `tools/watergen/decorative_fauna_layer.gd`：精灵图集、视觉挂点和纯时间采样/绘制。
- `tools/watergen/terrain_direction_preview.gd`：动物开关、时钟、捕获及检查；前两轮继续共用。
- `tools/watergen/run_terrain_directions.py`：增加 `--stage fauna`。
- `tools/watergen/Open-Decorative-Fauna.ps1`、`scenes/watergen/decorative_fauna_preview.tscn`：独立启动入口。
- `docs/watergen/fauna-round3/`、本报告和导航：样片、画廊、验证记录；外层工作区导航更新。

生产 `scripts/`、真实地图、主场景、项目配置、网络和快照文件零修改。动物模块是 RefCounted，不为动物创建 Node，也不读取 World、NPC、食物或隐藏钩数据。只接收 `visual_time` 与 `visual_seed`；不使用世界/NPC RNG。图集初始化上传一次，采样、镜头移动和动画不重建纹理。

当前成果是 **静态地势/植物底图 + 动态装饰动物层** 的独立视觉预览。挂点仍是 A 构图的美术坐标，尚未适配真实生成地图或接入正式试玩；原 WG-6.2 程序化植物也未替换。正式版本保持 0.27.5，旧 `feature/watergen@63112b1` 继续冻结。三轮视觉探索已交付，后续分层与接入需要针对实际地图继续验证。
