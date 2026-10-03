param([string]$Godot = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$watergenPython = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { 'D:\python\python.exe' } else { 'python3' }
& $watergenPython (Join-Path $PSScriptRoot 'run_wg1.py') --godot $Godot --mode preview
if ($LASTEXITCODE -ne 0) { throw 'Generated preview failed; inspect the printed run directory.' }
