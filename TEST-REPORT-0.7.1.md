# 0.7.1 按键调整验证

日期：2026-09-26。Windows，Godot 4.7.2 Compatibility。

变更：钩尖入口、缠线、松线三种 QTE 统一按空格；持续加速改为按住鼠标右键；E 保留回巢功能。同步更新 HUD、QTE 中央按键、帮助和中文说明。

输入优先级：已有 QTE 时，空格只判定当前 QTE；没有 QTE 时才可启动缠线。开始缠线的第一次按下不同时完成判定。长按空格不会自动判定随后出现的新 QTE。

验证脚本：

- `tests/smoke.gd`：146 项逻辑检查，覆盖既有玩法与统一空格后的状态冲突、E 回巢及右键绑定。
- `tests/controls_v071.gd`：22 项原生检查，实际发送键盘和鼠标输入。验证三种空格判定、按住右键持续加速、移动中判定、Shift 不再加速、左右键同时吸食和加速、松开右键后保持左键吸食、无方向输入不消耗加速体力，以及 E 回巢。
- 5 张截图检查入口、松线、缠线、右键加速和帮助说明。旧版 E / Shift 脚本保留为历史记录。

源码日志：`artifacts/tests-v071.log`、`artifacts/native-controls-v071.log`。
Windows 包验证日志：`artifacts/package-tests-v071.log`、`artifacts/native-package-v071.log`。
发布目录：`Releases/BaitbreakPixel-0.7.1`。

结果：源码和发布包均通过 146 项逻辑检查与 22 项原生检查，日志无错误或警告。ZIP 内的资源包与发布目录 SHA256 一致，并包含可执行文件、中文说明和引擎许可。
