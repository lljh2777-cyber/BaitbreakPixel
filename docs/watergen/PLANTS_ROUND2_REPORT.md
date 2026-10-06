# 自然池塘视觉重做 · 第二轮植物群落

日期：2026-10-06。用户在第一轮推荐 A 后要求“继续”，本轮按该推荐推进 A「沟谷倒木」；不把这视为对最终美术或密度的人工确认。

[前后对照画廊](plants-round2/gallery.html) · [第二轮原图](plants-round2/A-plant-communities.png)

## 本轮内容

使用内置 image_gen 编辑第一轮 A，保留非对称沟谷、低位倒木与右侧大石的主要形体，增加植物群落。没有使用旧游戏场景作为美术输入；[完整提示词](plants-round2/prompt.json) 随提交保存。第一轮原图没有覆盖。

| 位置 | 植物与分布 |
|---|---|
| 两侧坡脚、石块根部 | 高草、宽叶植物、小型莲座，丛簇大小与间距不一 |
| 沟底沉积区 | 矮草、细藻、地毯状藻；保留泥地与碎石间隙 |
| 倒木表面与枝节 | 断续苔藻、附生细叶，木纹和轮廓仍清楚 |
| 木头下缘 | 少量短垂藻，沿木头生长，不悬浮在水中 |
| 远景岸坡 | 青绿、低对比植物剪影，避免重复草墙 |
| 顶部两端 | 少量浮叶与长短不一的垂根，中央水体保持开阔 |

当前仍是 **2048×768 静态构图稿**，在预览中映射到 1280×480。植物依据图中的视觉地势生长，尚未拆成独立视差/摆动图层，也未将它们适配到真实 MapContext。此阶段不宣称已经实现可用于所有地图种子的植物生成器。没有加入小虾、蜗牛或远景鱼群。

## 查看与验证

```powershell
& 'E:\Fish_catches_people\aquatic_system\BaitbreakPixel-watergen-v2\tools\watergen\Open-Plant-Communities.ps1'
```

`1` 看第一轮地势，`2` 看第二轮植物；`Tab` 切全景/游戏镜头，方向键平移，`P` 开关识别样本，`G` 看留白参考框，`Home` 居中，`Esc` 退出。网页另有滑杆前后对照和五个同位置镜头。

Godot 4.7.2 原生预览：第二轮 **64/64** 检查通过，输出 24 张截图；共用预览器调整后重跑第一轮 **65/65**。检查涵盖加载、两幅图的区别、五镜头、样本叠加、重复帧稳定。结果见[第二轮日志](plants-round2/evidence/run.txt)、[运行结果](plants-round2/evidence/run-results.json)、[第一轮回归](plants-round2/evidence/terrain-regression.json)。

已查看中部、左坡与右上样片：中央玩家鱼、食物色块和细线仍可辨认，HUD/QTE 样本使用不透明底板；新增植物没有形成中央草墙。木纹与底部密集植物区仍是后续接入时的重点检查区。固定样本不能替代正式食物、缠线、抄网和 QTE 全流程验收。

## 文件改动与玩法隔离

- `docs/watergen/plants-round2/`：植物稿、编辑提示词、对照画廊、代表样片和验证记录。
- `tools/watergen/terrain_direction_preview.gd`：复用第一轮预览，增加地势/植物两张图切换和五镜头捕获。
- `tools/watergen/run_terrain_directions.py`：增加 `--stage plants`；第一轮默认行为保留。
- `tools/watergen/Open-Plant-Communities.ps1`、`scenes/watergen/plant_community_preview.tscn`：第二轮独立入口。
- 本报告与文档导航；工作区外层导航同步指向本轮。

生产 `scripts/`、地图数据、主场景、项目配置和网络协议零修改。预览仅使用图片与现有玩家像素贴图工厂，不创建 World，不读取钩/观察/快照数据，无碰撞节点，不使用 world/NPC RNG。图片先绘制，识别样本和面板后绘制。正式版本仍为 0.27.5，旧 `feature/watergen@63112b1` 保持冻结。

这一轮完成植物视觉方向与对照交付；动画分层、真实地图适配和正式试玩接入尚未进行。第三轮装饰动物也尚未开始。
