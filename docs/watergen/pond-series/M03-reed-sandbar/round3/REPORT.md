# M03/A 暖光沙湾 · 第三轮独立装饰动物

2026-10-06。[原生对照与局部图](gallery.html) · [系列进度](../../README.md)

保留第二轮植物 PNG，复用已有像素动物图集和本地视觉时间，只新增本图美术挂点。

| 对象 | 数量 / 挂点（1280×480 美术坐标） | 行为 |
|---|---|---|
| 小虾 | 3 只：芦苇坡脚 (290,340)、浅沟 (790,430)、右沙坡 (1035,395) | 停留后短移 6–7 像素 |
| 蜗牛 | 2 只：左小石 (210,307)、右卵石 (1124,340) | 主体停留、触角变化 |
| 远景鱼 | 两组各 5 条：(520,326)、(1090,220) | 限幅游动、低对比 |

左组鱼已移到沙坡外侧水层，避免落在近处坡面。全景和三类局部已目视检查。挂点不是 MapContext 坐标、真实对象 ID 或新增交互体。

## 连续预览

```powershell
& 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen-v2\tools\watergen\Open-Reed-Sandbar-Fauna.ps1'
```

1 植物 / 2 动物；空格暂停、R 归零；Tab 切换全景/镜头，方向键平移，Home 居中；P 识别样本，G 标记，Esc 退出。网页仅比较固定捕获帧，连续动画在独立 Godot 预览中运行。

## 验证与边界

- M03 原生预览 **97/97** 通过，包括确定性、暂停/恢复、跳时、种子相位、181 个时间样本的范围和数量、中央留白、图集复用、五镜头与固定识别样本。[结果](evidence/results.json) · [日志](evidence/run.txt)
- M02 共享预览回归 **97/97** 通过。[记录](evidence/root-regression.json)
- 保存 33 张原生 PNG；0 秒植物/动物全景仅 319 像素变化，中央参考区 0 像素变化。[像素检查](evidence/pixel-review.json)

检查不替代实机玩法、联机、所有候选饵位/巢穴保护或用户视觉验收；网页交互未自动实测。固定识别样本不是正在运行的游戏。

动物只读取显式视觉时间和视觉种子，无 World、NPC、食物、钩或碰撞输入；不使用权威随机流，不写网络快照。不可吃、不可钓、不缠线、不挡网，不泄漏隐藏钩。蜗牛未来需跟随公开石块宿主变换与淡化，目前尚未绑定。

## 文件范围

新增 tools/watergen/reed_sandbar_fauna_layer.gd、Open-Reed-Sandbar-Fauna.ps1、scenes/watergen/reed_sandbar_fauna_preview.tscn；共享 terrain_direction_preview.gd 和 run_terrain_directions.py 增加 reed_fauna 模式。新增本目录画廊、报告和证据，更新文档导航。

未修改生产 scripts/、真实碰撞、可游区、缠线、抄网、饵位、NPC、网络或快照协议，也没有发布新试玩。下一步为 M03 单图分层交接，之后再开始 M04。
