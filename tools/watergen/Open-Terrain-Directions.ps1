param([string]$Godot = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$terrainPython = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { 'D:\python\python.exe' } else { 'python3' }
& $terrainPython -X utf8 (Join-Path $PSScriptRoot 'run_terrain_directions.py') --godot $Godot
if ($LASTEXITCODE -ne 0) { throw 'Terrain preview failed; inspect the printed run directory.' }
