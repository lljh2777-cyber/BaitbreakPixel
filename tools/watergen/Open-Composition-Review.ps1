param([string]$GodotDirectory='E:\chrome下载\Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $runtime -WindowStyle Normal -WorkingDirectory $projectRoot -ArgumentList @('--path', ('"'+$projectRoot+'"'), 'res://scenes/watergen/composition_review.tscn', '--', '--test-profile')
