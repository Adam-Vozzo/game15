param([switch]$ImportAssets, [switch]$AllViews, [switch]$Tests)
$ErrorActionPreference = 'Stop'
$engine = 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Run-Review([string]$Name, [string[]]$EngineArgs) {
    $outLog = Join-Path $taskRoot "build-logs/$Name.log"
    $errLog = Join-Path $taskRoot "build-logs/$Name-errors.log"
    $job = Start-Process -FilePath $engine -ArgumentList (@('--path',('"'+$taskRoot+'"'))+$EngineArgs) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    $errors = Get-Content -LiteralPath $errLog -Raw
    Get-Content -LiteralPath $outLog
    if ($errors) { Write-Host $errors }
    if ($job.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Shader compilation failed|Parse Error|ERROR:') { throw "$Name failed" }
}
if ($ImportAssets) { Run-Review 'interior-import' @('--headless','--editor','--import','--quit') }
if ($Tests) {
    Run-Review 'interior-regression' @('--headless','--script','tests/interiors.gd')
    Run-Review 'interior-visual' @('--resolution','1280x800','--script','tests/interiors_visual.gd')
}
$views = if ($AllViews) { @('opening','reverse','ceiling','detail','portrait','later') } else { @('opening') }
foreach ($scene in @('laundry','reservoir')) {
    foreach ($angle in $views) {
        $name = "$scene-$angle"
        $shape = if ($angle -eq 'portrait') { '390x844' } else { '1280x800' }
        $args = @('--resolution',$shape,'--fixed-fps','60','--quit-after','180','--',"--experience=$scene",'--clean-capture',('--capture="'+$taskRoot+"/build-logs/$name.png"+'"'))
        if ($angle -eq 'detail') { $args += ('--view='+ $(if ($scene -eq 'laundry') {'machines'} else {'water'})) }
        if ($angle -in @('ceiling','reverse')) { $args += "--view=$angle" }
        if ($angle -eq 'later') { $args += '--interior-time=25' }
        if ($angle -eq 'portrait') { $args += '--mobile-test' }
        Run-Review $name $args
    }
}
