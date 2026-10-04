# 项目协作约定

用户已授权：完成每次修改并通过相应检查后，按请求分别提交，并自行推送到当前工作分支对应的远端，无需再次询问确认。

提交前检查差异，仅纳入本次授权的改动；将必要的代码、验证和文档放入对应提交。完成后报告提交和推送结果。

# 版本与试玩包命名

新版本使用递增版本号区分。试玩目录统一为 `Releases/BaitbreakPixel-<版本号>`，ZIP 统一为 `BaitbreakPixel-<版本号>.zip`；不要追加分支名、功能名或日期等长后缀。

发布新的本地试玩版时，同步更新项目版本、菜单显示、运行日志、联机 build、默认打包目录和当前试玩文档。历史版本的报告保留原记录。

每次 GitHub Release 成功发布并核验附件后，检查本地 `E:\Fish_catches_people\Releases` 中的试玩目录及对应 ZIP，按数字版本号排序，仅保留最新 3 个已发布版本。多余本地版本可以清理；GitHub 历史 Releases、标签、源码和历史验证报告继续保留。发布失败或附件核验未通过时，不清理旧包。执行清理仍须遵守下方文件操作限制：需要删除多个文件或目录时，列出明确路径，请用户手动处理。

# 环境与文件操作

- 选择命令或路径前，先检测当前环境是 Windows 还是 WSL/Linux。
- Windows Python 使用 `D:\python\python.exe`。
- WSL/Linux Python 使用 `python3`；WSL 确需 Windows Python 时使用 `/mnt/d/python/python.exe`。
- 关闭不再需要的浏览器标签页。
- 禁止批量或递归删除，禁止通过通配符、循环或脚本删除多个文件。
- 不得使用 `del /s`、`rd /s`、`rmdir /s`、`Remove-Item -Recurse`、`rm -r`、`rm -rf` 或 `find ... -delete`。
- 每次只能删除一个明确指定的文件；多个文件或目录需要删除时，请用户手动处理。

Windows 单文件删除使用 `Remove-Item -LiteralPath "C:\path\to\file.txt"`；WSL/Linux 使用 `rm -- "/path/to/file.txt"`。
