# 版本与包索引说明

[返回项目首页](../../README.md) · [开发历史](CHANGELOG.md) · [测试报告](../test-reports/README.md)

## 三种版本信息

- **源码版本**：以当前检出的 `project.godot` 为准；当前为未发行的 0.22.6。项目、菜单、启动日志、联机 build、默认构建目录和当前试玩说明应一致；源码提交并不等于已经生成可运行包。
- **本地试玩包**：由构建脚本生成，并在对应报告中记录检查结果和包体信息。0.21.0–0.22.5 的记录均明确为 Windows 本地试玩，报告当时未发布 GitHub Releases；这些 EXE、PCK 和 ZIP 不纳入源码仓库。
- **公开发行包**：以 GitHub Releases 实际附件为准。截至 2026-10-02，最新公开包是 [v0.20.1](https://github.com/lljh2777-cyber/BaitbreakPixel/releases/tag/v0.20.1)。它是历史归档，上传日期不代表原始开发日期；同页 `Source code` 也不是可直接运行的包。

## `history/releases.json` 的范围

[JSON 索引](../../history/releases.json)保留原有恢复数据，并将后续本地试玩记录分开存放：

- `releases`：2026-09-29 从 42 个保留包恢复的 0.1–0.20.1 清单。原有条目及 `pack_sha256`、`script_sha256`、`decoded_texture_sha256`、`exported_resources` 保持不变。顶层 `recovery_date`、`method`、`validation` 仅描述这组恢复数据，不能套用到后续版本。详情见[历史恢复说明](HISTORY-RECOVERY.md)。
- `local_playtests`：0.21 起的本地试玩包。`source_commit` 标识对应版本的源码提交，`report_date` 是原报告日期，`test_report` 是相对仓库根目录的证据路径。`pack_sha256`、`pack_bytes`、`zip_bytes` 转录自该报告；本次补索引没有重新读取历史包复算。`github_release_published_at_report` 仅记录报告当时的发布状态。
- `public_release_snapshot`：带核验日期的 GitHub 最新公开发行快照，提供发行页、附件和查询来源。它不表示任何本地试玩版已经公开发布。
- 所有 PCK 哈希统一为 64 位小写十六进制。没有记录或重新计算过的 ZIP 哈希、脚本哈希与纹理哈希不填入，不使用空值或推测值代替证据。报告日期、Git 提交日期与实际公开发布时间分别对待。

## 后续更新检查表

1. 只补文档、调整测试或修复开发工具且未生成新试玩包时，可以保留现有游戏版本，在新的维护报告中记录变更与验证。涉及实际应用修复时可先递增开发版本，但必须标明未发行；不要重写旧报告的原始结果或替换历史包哈希。
2. 发布新的本地试玩版时使用递增版本号，同步 `project.godot`、菜单、启动日志、联机 build、`Build-Pixel.ps1`、README、当前玩法/联机说明与相关架构文档。历史测试报告和恢复标签继续保留原版本。
3. 目录统一为 `Releases/BaitbreakPixel-<版本号>`，ZIP 为 `BaitbreakPixel-<版本号>.zip`；按 `AGENTS.md` 约定不追加分支、功能或日期后缀。
4. 分别验证源码与独立包；原生截图检查使用图形窗口和 `--test-profile`。报告必须注明操作系统、实际 Godot 版本、执行范围、失败/跳过项，以及包内代码与当前源码的核对结果。检查受阻时如实写明，不能沿用上一版本的通过结论。
5. 只有实际生成并检查包后才登记其文件大小与 SHA-256，同时链接报告、补充 CHANGELOG、文档导航和测试报告索引。文档中的本地路径表示构建位置，不能用作公开下载链接。
6. 只有确认 GitHub Release 与对应附件确实存在后，才更新公开下载版本、精确链接及 `public_release_snapshot`。推送源码或创建 Git 标签不等于上传发行包。
