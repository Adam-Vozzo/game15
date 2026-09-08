param([string]$Godot = 'godot', [string]$Blender = 'blender', [string]$Aseprite = 'aseprite', [switch]$RebuildAssets, [switch]$RebuildTextures)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logRoot = Join-Path $projectRoot 'build-logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
if ($RebuildTextures) {
    $proc = Start-Process -FilePath $Aseprite -ArgumentList @('--batch','--script-param',('"out=' + $projectRoot + '"'),'--script',('"' + (Join-Path $projectRoot 'art/build_kasumi_atlas.lua') + '"')) -WindowStyle Hidden -PassThru -Wait
    if ($proc.ExitCode -ne 0) { throw 'Aseprite texture build failed.' }
}
if ($RebuildAssets) {
    foreach ($script in @('build_assets.py','build_places.py')) {
        $outLog = Join-Path $logRoot "$script.log"
        $errLog = Join-Path $logRoot "$script-errors.log"
        $scriptPath = '"' + (Join-Path $projectRoot "blender/$script") + '"'
        $proc = Start-Process -FilePath $Blender -ArgumentList @('--background','--python',$scriptPath) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog
        if ($proc.ExitCode -ne 0 -or (Get-Content $errLog -Raw) -match 'Traceback') { throw "Blender $script failed; inspect build-logs." }
    }
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
Invoke-Engine @('--script','tests/channels.gd') 'channels'
Invoke-Engine @('--script','tests/kasumi.gd') 'kasumi-tests'
Invoke-Engine @('--export-release','Web','docs/index.html') 'export'
Set-Content -LiteralPath (Join-Path $projectRoot 'docs/.nojekyll') -Value ''
Write-Host 'Web export ready in docs/. Commit the source and docs together.'
