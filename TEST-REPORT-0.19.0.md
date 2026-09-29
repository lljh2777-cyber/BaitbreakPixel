# 0.19.0 验证报告

## 结果

| 检查 | 通过 | 失败 | 日志 |
| --- | ---: | ---: | --- |
| 玩法规则与边界 | 177 | 0 | `artifacts/rules_v019-v019-final3.log` |
| 原生设置界面 | 8 | 0 | `artifacts/rules-native-v019-final3.log` |
| 自定义规则真实 ENet | 9 | 0 | `artifacts/rules_network_v019-v019-final2.log` |
| 架构与确定性快照 | 44 | 0 | `artifacts/architecture_v011-v019-final3.log` |
| 双方发力 QTE | 31 | 0 | `artifacts/effort_v013-v019-check.log` |
| 体力、收放线与抄网平衡 | 29 | 0 | `artifacts/balance_v014-v019-final2.log` |
| 双人联机回归 | 39 | 0 | `artifacts/network_v012-v019-final2.log` |
| 联机输入与状态校验 | 25 | 0 | `artifacts/network_rules_v012-v019-final.log` |
| 解线规则与状态机 | 43 | 0 | `artifacts/untangle_v018-v019-final.log` |
| 解线真实 ENet | 6 | 0 | `artifacts/untangle_network_v018-v019-final2.log` |
| 手动收放线 | 20 | 0 | `artifacts/reeling_v0122-v019-final.log` |
| 鱼竿弯曲与抬手 | 11 | 0 | `artifacts/rod_load_v017-v019-final.log` |
| 缠线解线显示 | 29 | 0 | `artifacts/line_motion_v0181-v019-final3.log` |
| 鱼线惯性与渔轮动画 | 26 | 0 | `artifacts/tackle_dynamics_v016-v019.log` |
| 鱼绕障碍物 | 75 | 0 | `artifacts/fish_orbit_v0182-v019.log` |
| 水草缠绕显示 | 58 | 0 | `artifacts/grass_binding_v0183-v019.log` |

以上 16 套检查共 630 项通过。另对发布目录中的 EXE/PCK 重跑规则 177 项、原生 UI 8 项，全部通过。构建和发布测试日志无 SCRIPT ERROR / ERROR。

## 关键行为

- 128 个选项均可通过 JSON、世界快照往返；全部最小值／最大值组合通过联动校验并可模拟。
- 容量、初始体力、恢复、消耗、移动、吸食区域、饵料收益、实际收放线、松线等待和断线持续时间验证了行为变化。
- 六类 QTE 读独立配置；当前判定保留开场参数。真实 UDP 中成功判定了原先 2.4 秒以后才到绿区的慢速 QTE。
- 抄网尺寸影响显示、障碍半径、捕获范围、预警轮廓；疲劳按新容量归一化。解线显示采用自定义时长。
- 原生窗口检查数字输入、搜索、随机／固定位置切换、方案保存、错误 JSON 提示、保存重开和只读房间规则；保存的截图已查看。
- 进入房间不会覆盖离线方案；回标题恢复个人参数。保存设置不改变当前对局；下一局应用。
- 保留 0.18.3 的默认手臂、绕线、绕鱼、水草动作回归结果。原有测试中旧版挑战强制默认、旧版配置路径的预期，已按本版规则更新。

## 结构边界

见 [规则架构](RULES-ARCHITECTURE.md) 与 [完整目录](RULES-CATALOG.md)。个人存档、方案文件操作留在应用与持久化模块；世界模拟继续不依赖输入、菜单或文件系统。

## 发布包

- 目录：`E:\Fish_catches_people\Releases\BaitbreakPixel-0.19.0`
- ZIP：91,263,426 字节。
- PCK：3,883,160 字节。
- PCK SHA-256：`27BCDD1A0AFAD8C791A94CF88F1E26805B53DA28D5BB510920D70A82F2C172ED`
- 协议 0.19，快照 schema 8。双方均需更新，不与 0.18 混连。

## 范围

仅在当前一条鱼／一名人类、固定地图的现有玩法中开放有效参数。没有新增地图生成、鱼种、装备、人的体力或线材磨损。参数边界保持计算有效，但自定义组合可以显著改变对局难度和胜负倾向。正式默认值不改。
