# 回归测试入口

推荐使用有超时保护的 Python 3 入口，不要把 `tests/*.gd` 全部直接逐个启动：部分历史套件依赖已经移除的玩法或方法，Godot 的运行时错误会中止测试函数，却不一定退出进程。

```sh
python3 tools/run_tests.py --import
python3 tools/run_tests.py --profile native
python3 tools/run_tests.py --suite rules_v020
python3 -m unittest discover -s tests/runner -v
```

Windows 可使用 `D:\python\python.exe`；用 `--godot "引擎可执行文件路径"` 或环境变量 `GODOT` 指定 Godot。Linux/WSL 使用 `python3`。原生测试需要可用的图形显示，例如桌面终端或已安装的 Xvfb；运行器不会把无窗口执行误报成原生验证。测试显式使用 Dummy 音频驱动，只验证逻辑/画面，不验证真实声卡输出。

## 注册表与状态

[`suite_registry.json`](suite_registry.json) 显式登记全部 81 个顶层 GDScript 入口。新增/改名后必须同步注册表，否则运行器拒绝运行。

- `current`：当前有效的回归门禁；不按文件名版本新旧决定。`--profile current` 运行无窗口套件，`--profile native` 运行图形套件。已重新验证的 effort、net_animation、rules_network 等较早版本仍在当前门禁中
- `historical`：当前检出复现了失败的诊断套件。保留原断言，失败仍返回非零；这不是“已证明所有断言过时”，更不是通过。具体原因和结果见[维护报告](../docs/test-reports/TEST-INFRASTRUCTURE-MAINTENANCE-2026-10-02.md)
- `retired`：只有证据充分、依赖已删除 API/已移除玩法的 `rules_v019` 和 `net_route_v0102`。保留完整历史测试体，直接执行入口打印替代套件并退出 2；注册表选择也明确报告 RETIRED 并返回非零
- `manual`：AI 探针、双进程 peer 配对脚本和纯截图序列。单独启动不能代表完整回归；保留显式原因，不算通过

```sh
python3 tools/run_tests.py --list
python3 tools/run_tests.py --profile historical
python3 tools/run_tests.py --profile all-headless
python3 tools/run_tests.py --suite shore_native_v015
```

历史诊断预期会有红项；不要把 `--profile current` 的通过写成“全仓库所有历史测试通过”。报告中逐项保留具体失败和未覆盖范围。

## 超时、退出与日志

每个进程使用注册表的有限超时（通常 90 秒，联网/大型图像测试 120 秒），可以通过 `--timeout 30` 覆盖。超时后终止进程组；Ctrl+C 也清理当前测试。Unix 进程组清理已验证；Windows 使用 `taskkill /T /F` 尽力清理进程树，本次未验证 Windows 原生执行。

标准输出写入临时文件，避免残留子进程持有管道而卡住回收。非零退出、`SCRIPT ERROR`、`ERROR:`、失败标记或失败计数均不会显示为绿项。没有测试完成证据也算失败。无汇总计数的老套件只能统计日志标记，`summary.json` 的 `count_basis` 会注明 `log_markers`，不要把它与断言数混为一谈。

日志默认在 `artifacts/test-runs/`，包括每个套件的 `.log`、命令、耗时和 `summary.json`。使用 `--output-directory` 为不同运行保留独立记录。运行器总是添加 `--test-profile`；Linux 还将 XDG 数据、配置、缓存目录隔离到输出目录，避免读写正常游戏档案。

## 原生与打包截图

所有 30 个使用原生画面、且会写 PNG 的脚本都接受：

```sh
godot --path . --script res://tests/wood_fade_native.gd -- --test-profile --capture-output-directory=/absolute/writable/captures
```

默认路径不变。目录会创建，空值、建目录失败、PNG 写入失败都返回非零。5 个旧脚本继续支持 `--visual-output=`，同时提供时以 `--capture-output-directory=` 为准。

计数说明：31 个脚本使用原生渲染/画面回读，其中 `reel_hand_native_v016` 只验证像素连通性，不写图片。另一个会写图的 `plant_art` 是无窗口图像测试：默认不写图，保留 `--preview=文件名`，也支持公共目录参数生成 `plant-art-preview.png`；显式 `--preview` 优先。因此所有 31 个会写图片的入口均有可写路径选择，不需要给不写文件的测试增加空参数。

发行 PCK 故意不包含 `tests/` 和 `tools/`。运行器用外部绝对 `--script` 加载测试，让 `res://scripts/` 和素材来自包内：

```sh
python3 tools/run_tests.py --profile native --pack /path/to/BaitbreakPixel.pck --output-directory artifacts/packed-native
```

每个脚本的路径配置在自身内部，不依赖包内不存在的测试 helper。`net_v021`、`untangle_v021`、旧 hand_rig 等继承 `res://tests/...` 的包装脚本不能这样外部加载；注册表把它们明确标为包模式 BLOCKED，需在源码模式执行。这个限制不会被当作通过，也不会把测试源码偷偷加入发行包。
