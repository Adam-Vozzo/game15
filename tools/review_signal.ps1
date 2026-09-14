param([string]$Godot = 'godot', [switch]$Clip)
$ErrorActionPreference = 'Stop'
$signalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$signalLogs = Join-Path $signalRoot 'build-logs'
New-Item -ItemType Directory -Path $signalLogs -Force | Out-Null
function Invoke-Signal([string[]]$EngineArgs, [string]$Name) {
    $outLog = Join-Path $signalLogs "$Name.log"
    $errLog = Join-Path $signalLogs "$Name-errors.log"
    $proc = Start-Process -FilePath $Godot -ArgumentList (@('--path',('"'+$signalRoot+'"'),'--quit-after','1800')+$EngineArgs) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    Get-Content -LiteralPath $outLog
    $errors = Get-Content -LiteralPath $errLog -Raw
    if ($proc.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Shader compilation failed|Parse Error|ERROR:') { throw "$Name failed: $errors" }
}
Invoke-Signal @('--resolution','1280x800','--script','tests/signal_visual.gd','--',$(if ($Clip) {'--signal-clip'} else {'--clean-capture'})) 'signal-native'
foreach ($signalView in @('opening','close','reverse','side','under','trail','ground','foliage')) {
    Invoke-Signal @('--resolution','1280x800','--fixed-fps','60','--','--experience=signal',('--view='+$signalView),'--clean-capture',('--capture="'+(Join-Path $signalLogs "signal-$signalView.png")+'"')) "signal-review-$signalView"
}
Invoke-Signal @('--resolution','390x844','--fixed-fps','60','--','--experience=signal','--mobile-test',('--capture="'+(Join-Path $signalLogs 'signal-portrait.png')+'"')) 'signal-portrait'
Invoke-Signal @('--resolution','640x360','--fixed-fps','60','--','--experience=signal','--mobile-test',('--capture="'+(Join-Path $signalLogs 'signal-landscape.png')+'"')) 'signal-landscape'
Write-Host 'Native Signal Grove renders are in build-logs/.'
