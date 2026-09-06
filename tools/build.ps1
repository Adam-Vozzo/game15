param([string]$Godot = 'godot', [string]$Blender = 'blender', [switch]$RebuildAssets)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logRoot = Join-Path $projectRoot 'build-logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
if ($RebuildAssets) {
    & $Blender --background --python (Join-Path $projectRoot 'blender/build_assets.py')
    if ($LASTEXITCODE -ne 0) { throw 'Blender asset build failed.' }
}
function Invoke-Engine([string[]]$EngineArgs, [string]$Stage) {
    $outLog = Join-Path $logRoot "$Stage.log"
    $errLog = Join-Path $logRoot "$Stage-errors.log"
    $quotedRoot = '"' + $projectRoot + '"'
    $proc = Start-Process -FilePath $Godot -ArgumentList (@('--headless','--path',$quotedRoot) + $EngineArgs) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    Get-Content -LiteralPath $outLog
    $errors = Get-Content -LiteralPath $errLog -Raw
    if ($errors) { Write-Host $errors }
    if ($proc.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Shader compilation failed|Parse Error|ERROR:') { throw "$Stage failed; inspect build-logs." }
}
Invoke-Engine @('--editor','--import','--quit') 'import'
Invoke-Engine @('--script','tests/run.gd') 'tests'
Invoke-Engine @('--export-release','Web','docs/index.html') 'export'
Set-Content -LiteralPath (Join-Path $projectRoot 'docs/.nojekyll') -Value ''
Write-Host 'Web export ready in docs/. Commit the source and docs together.'
