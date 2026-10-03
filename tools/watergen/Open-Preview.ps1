param(
    [string]$Godot = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    $watergenPython = 'D:\python\python.exe'
} else {
    $watergenPython = 'python3'
}
& $watergenPython (Join-Path $PSScriptRoot 'run_wg0.py') --godot $Godot --mode preview
if ($LASTEXITCODE -ne 0) { throw 'Watergen preview failed; inspect the printed run directory.' }
