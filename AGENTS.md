# 项目协作约定

用户已授权：完成每次修改并通过相应检查后，按请求分别提交，并自行推送到当前工作分支对应的远端，无需再次询问确认。

提交前检查差异，仅纳入本次授权的改动；将必要的代码、验证和文档放入对应提交。完成后报告提交和推送结果。

# 环境与文件操作

- 选择命令或路径前，先检测当前环境是 Windows 还是 WSL/Linux。
- Windows Python 使用 `D:\python\python.exe`。
- WSL/Linux Python 使用 `python3`；WSL 确需 Windows Python 时使用 `/mnt/d/python/python.exe`。
- 关闭不再需要的浏览器标签页。
- 禁止批量或递归删除，禁止通过通配符、循环或脚本删除多个文件。
- 不得使用 `del /s`、`rd /s`、`rmdir /s`、`Remove-Item -Recurse`、`rm -r`、`rm -rf` 或 `find ... -delete`。
- 每次只能删除一个明确指定的文件；多个文件或目录需要删除时，请用户手动处理。

Windows 单文件删除使用 `Remove-Item -LiteralPath "C:\path\to\file.txt"`；WSL/Linux 使用 `rm -- "/path/to/file.txt"`。
