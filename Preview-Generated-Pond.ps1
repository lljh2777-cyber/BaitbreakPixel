param(
    [ValidateRange(0, 2147483647)][long]$MapSeed = 42,
    [string]$GodotDirectory = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$previewEngine = Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $previewEngine)) { throw 'Specify the installed Godot 4.7.2 directory.' }
& $previewEngine --path $PSScriptRoot --script res://tools/preview_generated_pond.gd -- "--map-seed=$MapSeed"
