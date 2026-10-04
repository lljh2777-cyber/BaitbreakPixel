param(
    [string]$GodotDirectory = 'E:\chrome下载\Godot_v4.7.2-stable_win64.exe',
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Releases\BaitbreakPixel-0.26.4')
)
$ErrorActionPreference = 'Stop'
$pixelConsole = Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64_console.exe'
$pixelRuntime = Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $pixelConsole) -or -not (Test-Path -LiteralPath $pixelRuntime)) {
    throw 'Specify the directory containing the installed Godot 4.7.2 executables.'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$pixelPack = Join-Path $OutputDirectory 'BaitbreakPixel.pck'
$pixelOutput = & $pixelConsole --headless --path $PSScriptRoot --editor --export-pack 'Windows Pixel' $pixelPack 2>&1
$pixelOutput | Write-Output
if ($LASTEXITCODE -ne 0 -or ($pixelOutput | Select-String 'SCRIPT ERROR|ERROR:')) {
    throw 'Resource pack export failed.'
}
Copy-Item -LiteralPath $pixelRuntime -Destination (Join-Path $OutputDirectory 'BaitbreakPixel.exe') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'docs\gameplay\PLAY.txt') -Destination (Join-Path $OutputDirectory '开始试玩.txt') -Force
& $pixelConsole --headless --path $PSScriptRoot --script res://tools/engine_notices.gd -- (Join-Path $OutputDirectory 'GODOT-NOTICES.txt')
if ($LASTEXITCODE -ne 0) { throw 'Engine notices export failed.' }
$pixelArchive = $OutputDirectory.TrimEnd('\') + '.zip'
Compress-Archive -LiteralPath $OutputDirectory -DestinationPath $pixelArchive -Force
Get-Item -LiteralPath $pixelArchive | Select-Object FullName,Length
