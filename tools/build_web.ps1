param(
    [string]$GodotBin = $env:GODOT_BIN
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $GodotBin) {
    $GodotBin = 'C:\Users\desai\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotBin)) { throw 'Set GODOT_BIN to your Godot 4.7.2 executable.' }
$buildRoot = Join-Path $projectRoot 'builds'
$webRoot = Join-Path $buildRoot 'web'
$submissionRoot = Join-Path $buildRoot 'submission'
$templateRoot = Join-Path $buildRoot 'templates'
New-Item -ItemType Directory -Path $webRoot,$submissionRoot,$templateRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $buildRoot '.gdignore') -Value '' -Encoding utf8
foreach ($templateName in @('web_nothreads_release.zip', 'web_nothreads_debug.zip')) {
    $target = Join-Path $templateRoot $templateName
    $installed = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\$templateName"
    if (-not (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $installed)) {
        Copy-Item -LiteralPath $installed -Destination $target
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $templateRoot 'web_nothreads_release.zip'))) {
    throw 'Install Godot 4.7.2 export templates in the editor, or put the official web_nothreads_release.zip in builds/templates.'
}
if (Get-ChildItem -LiteralPath $webRoot -File) {
    throw 'builds/web is not empty. Move the previous export aside before building so the upload contains no stale files.'
}
& $GodotBin --headless --log-file (Join-Path $buildRoot 'web-import.log') --path $projectRoot --editor --import 2>&1 | Tee-Object -FilePath (Join-Path $buildRoot 'web-import-output.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $GodotBin --headless --log-file (Join-Path $buildRoot 'web-export.log') --path $projectRoot --export-release Web (Join-Path $webRoot 'index.html') 2>&1 | Tee-Object -FilePath (Join-Path $buildRoot 'web-export-output.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed.' }
foreach ($logName in @('web-import-output.log', 'web-export-output.log')) {
    if (Select-String -LiteralPath (Join-Path $buildRoot $logName) -Pattern 'SCRIPT ERROR:|ERROR:') {
        throw "Godot reported an error in $logName. Inspect it before submitting."
    }
}
foreach ($fileName in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $webRoot $fileName))) { throw "Missing $fileName" }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'CREDITS.md'),(Join-Path $projectRoot 'LICENSE') -Destination $webRoot
$zipPath = Join-Path $submissionRoot 'siyaraj-web.zip'
Compress-Archive -Path (Join-Path $webRoot '*') -DestinationPath $zipPath -Force
$revision = git -C $projectRoot rev-parse HEAD
$changes = git -C $projectRoot status --short
$report = @("Source HEAD: $revision", 'Working tree at export:', $changes, '', 'Export files:')
Get-ChildItem -LiteralPath $webRoot -File | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    $report += "$($_.Name) $($_.Length) bytes SHA256 $hash"
}
$report += "Upload ZIP SHA256: $((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash)"
$report | Set-Content -LiteralPath (Join-Path $submissionRoot 'build-report.txt') -Encoding utf8
Write-Output "Ready to test and upload: $zipPath"
