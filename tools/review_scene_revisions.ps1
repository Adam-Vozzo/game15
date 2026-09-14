param([switch]$Tests)
$ErrorActionPreference = 'Stop'
$reviewRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$engine = 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
function Render-Review([string]$name,[string[]]$arguments) {
    $outLog = Join-Path $reviewRoot "build-logs/revision-$name.log"
    $errLog = Join-Path $reviewRoot "build-logs/revision-$name-errors.log"
    $job = Start-Process -FilePath $engine -ArgumentList (@('--path',('"'+$reviewRoot+'"'))+$arguments) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    $errors = Get-Content -LiteralPath $errLog -Raw
    if ($job.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Shader compilation failed|Parse Error|ERROR:') { throw "$name failed: $errors" }
    Write-Host "Reviewed $name"
}
if ($Tests) {
    foreach ($test in @('lowwater_visual','interiors_visual','kasumi_lighting_visual','resize')) {
        Render-Review $test @('--resolution','1280x800','--script',"tests/$test.gd")
    }
}
$views = @{
    laundry=@('opening','street','machines','machine-side','rear-detail','reverse');
    lowwater=@('opening','shafts','canopy','reverse');
    town=@('opening','loop','loop-north','alley','roofs','lamplight','crossing');
    coast=@('opening','dock','hut','beach-detail','palm','under-pier');
    sea=@('opening')
}
foreach ($scene in @('laundry','lowwater','town','coast','sea')) {
    foreach ($view in $views[$scene]) {
        $name = "$scene-$view"
        Render-Review $name @('--resolution','1280x800','--fixed-fps','60','--quit-after','150','--',"--experience=$scene","--view=$view",'--clean-capture',('--capture="'+$reviewRoot+"/build-logs/revision-$name.png"+'"'))
    }
    Render-Review "$scene-portrait" @('--resolution','390x844','--fixed-fps','60','--quit-after','150','--',"--experience=$scene",'--mobile-test','--clean-capture',('--capture="'+$reviewRoot+"/build-logs/revision-$scene-portrait.png"+'"'))
}
foreach ($time in @(4,11,19,28)) {
    Render-Review "sea-time-$time" @('--resolution','1280x800','--fixed-fps','60','--quit-after','150','--','--experience=sea',"--sea-time=$time",'--clean-capture',('--capture="'+$reviewRoot+"/build-logs/revision-sea-time-$time.png"+'"'))
    Render-Review "lowwater-time-$time" @('--resolution','1280x800','--fixed-fps','60','--quit-after','150','--','--experience=lowwater',"--lowwater-time=$time",'--clean-capture',('--capture="'+$reviewRoot+"/build-logs/revision-lowwater-time-$time.png"+'"'))
}
