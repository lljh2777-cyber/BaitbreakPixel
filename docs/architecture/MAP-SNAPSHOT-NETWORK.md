# P4.3 · 地图存档与联机契约（0.26.2）

## 范围

仅实现规格 §79 的 P4.3。仍只有内置 `pond_v2`，不发送完整地图、不下载地图、不把测试 fixture 注册为玩家地图。Presentation 继续使用既有 facade，P4.4 尚未开始。

## MapRef 与本机解析

MapRef 严格包含四个字段：

```text
id: String = "pond_v2"
revision: int = 1
contract_version: int = 1
content_hash: String = "794aea6774b6a6626a1f56a58a1e0db0811c30eb60ac35eb9c2f472788fa5ef4"
```

`MapRegistry.validate_ref` 首先验证完整 scalar shape，再核对本机注册地图。字段不可缺失、多余、类型转换或携带嵌套 geometry。revision、contract 与 hash 各自验证；同名地图不能代替内容一致。未知地图、错误 revision/contract/hash 都返回显式失败，不回退默认地图。

Registry 仅暴露已验证 definition 的 detached copy。注册数据与可复用只读 Context 缓存供投影/网络验证使用，避免每次状态包重新生成多边形、重算 hash。World 重开仍先获得地图，然后初始化实体与 RNG；接收方通过本机 Registry 获得公开几何。

## 权威 Snapshot schema16

顶层为 `schema / bait_profile_version / map_ref / state / rig / rng_seed / rng_state`。完整 MapDefinition、渲染资源和局部 UI/配置均不进入 Snapshot。capture 使用实际 World 的 `map_context.map_ref`，不能把未注册 fixture 伪装成 pond_v2。

恢复顺序：

1. 检查 schema16 与既有 bait profile guard3
2. 完整核对 MapRef，以本机 Registry 解析地图
3. 验证 value tree、全部原有状态/rig 字段和嵌套状态；几何约束使用被恢复地图，而非接收世界之前的地图
4. 验证全部通过后才安装地图和赋值；不 reset 实体，不消耗玩法 RNG，不发声音/胜负/档案事件

任何失败必须发生在 World、rig、RNG、地图与派生缓存变化前。相同 MapRef 的普通 restore 保留已安装 Context；换回可解析地图时同时更新 World 和 rig。循环/过深值、非有限数、Object/Callable、带 Object 类型元数据的容器及不可赋值 typed-array 均在赋值前拒绝。

旧 schema15 和更早版本明确拒绝。本轮没有迁移器，不从旧 `map_id` 推断 revision/hash，也不宣称可加载旧快照。保留 state 中旧 `net_aim` 的现有兼容值，不删除原本会影响回放字节的字段。

## 联机与角色隐私

- exact build 为 `0.26.2`
- hello、welcome、start、start_ack 核对 build 和完整 MapRef
- 仅 ENet 连接成功不能授权 ready、开局、输入或世界状态；地图验证完成后才允许推进
- 会话地图引用冻结，重开重新核对；未知/不匹配地图拒绝进入比赛，绝不静默回退
- 握手拒绝进入failed后最多保留1秒传输排空，为明确版本/地图原因的可靠发送留出时间；期间禁止新hello和任何对局推进，断开/到期保留错误caption
- 状态包及其内部角色快照必须与会话地图一致
- 鱼端 public schema 从1升级到2，仅将 `map_id` 换为 `map_ref`；bait profile1 / NPC profile2 保留
- 钓鱼人 public projection 沿用权威字段布局版本，因此随之为 schema16；bait profile3 / NPC profile4 保留
- Snapshot schema、fish public schema、Map contract、Map revision 与 network build 是独立概念

鱼端继续只接收列出的公开字段与本机公开地图引用，不新增隐藏钩真值、种子、NPC 脑状态或完整 geometry。钓鱼人继续裁去 NPC 私有脑/随机状态。原有命令净化、时序/编号/历史 QTE 核验与严格 float guard 不因地图重构放宽。

## 验证边界

[本轮报告](../test-reports/PHASE04-MAP-SNAPSHOT-NETWORK-0.26.2.md)记录 formal current / native、真实 ENet 两种角色、恶意引用、原子拒绝、重放和旧版等价结果。历史 schema15 baseline harness 与 P4.1/P4.2 comparator 保留原文，必须在其目标提交运行；新 schema-aware 对照仅排除明确变化的顶层身份元数据，并仍验证每个版本完整恢复与重放。

这不代表随机地图、任意 fixture 网络支持、Windows 发行包或真人手感验收。本轮完成后等待 P4.3 人工确认。
