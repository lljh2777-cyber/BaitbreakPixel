param([string]$Godot = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe', [switch]$Legacy)
$ErrorActionPreference = 'Stop'
$watergenPython = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { 'D:\python\python.exe' } else { 'python3' }
$watergenArgs = @('-X', 'utf8', (Join-Path $PSScriptRoot 'run_wg6.py'), '--godot', $Godot, '--mode', 'preview')
if ($Legacy) { $watergenArgs += '--legacy' }
& $watergenPython @watergenArgs
if ($LASTEXITCODE -ne 0) { throw 'Terrain preview failed; inspect the printed run directory.' }
