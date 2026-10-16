# MBAACC render target load/clear diagnosis and controlled explicit RT0 A/B test.
# PowerShell 5.1. No Git executable or game bundle access required.
param(
    [ValidateSet('Trace','ForceRT0','Restore')]
    [string]$Mode = 'Trace'
)
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
if (!(Test-Path -LiteralPath $p)) { throw 'Run from BottleShip checkout; executor file not found.' }
$backup = $p + '.mbaacc-before-rt-clear-test.bak'
$mark = 'MBAACC-RT-PASS-PROBE-20261016'
if ($Mode -eq 'Restore') {
    if (!(Test-Path -LiteralPath $backup)) { throw 'Backup does not exist; no change.' }
    Copy-Item -LiteralPath $backup -Destination $p -Force
    Write-Host 'Original pre-RT-test executor restored. Restart BottleShip.' -ForegroundColor Green
    exit 0
}
$current = [IO.File]::ReadAllText($p)
if (Test-Path -LiteralPath $backup) {
    $s = [IO.File]::ReadAllText($backup)
    if ($s.Contains($mark)) { throw 'Backup already contains probe; refusing to overwrite.' }
} else {
    if ($current.Contains($mark)) { throw 'Existing probe found but no backup; refusing to overwrite.' }
    $s = $current
}
$loadAnchor='                    loadOp: (frame.hasClear && clearTarget) ? "clear" : "load",'
$colorStart='            const colorAttachments: Array<GPURenderPassColorAttachment | null> = target'
$colorEnd='            const depthFormat ='
$start=$s.IndexOf($colorStart)
$end=if($start -ge 0){$s.IndexOf($colorEnd,$start)}else{-1}
if($start -lt 0 -or $end -lt 0 -or $end -le $start){throw 'Color-attachment pass structure differs; no files changed.'}
$block=$s.Substring($start,$end-$start)
# Two branches contain this loadOp; alter only first (target.map), not the implicit backbuffer.
$first=$block.IndexOf($loadAnchor)
$second=if($first -ge 0){$block.IndexOf($loadAnchor,$first+$loadAnchor.Length)}else{-1}
if($first -lt 0 -or $second -lt 0){throw 'Expected explicit/implicit loadOps absent; no files changed.'}
$force = if($Mode -eq 'ForceRT0'){'true'}else{'false'}
$flag = "            const mbaaccForceExplicitRt0Clear = $force; // $mark" + [Environment]::NewLine
$replacement='                    loadOp: ((frame.hasClear && clearTarget) || (index === 0 && mbaaccForceExplicitRt0Clear && target?.backbuffer === false)) ? "clear" : "load",'
$block=$block.Substring(0,$first)+$replacement+$block.Substring($first+$loadAnchor.Length)
$s=$s.Substring(0,$start)+$flag+$block+$s.Substring($end)
$trace=@'
            // MBAACC-RT-PASS-PROBE-20261016: before any draw, report real load behavior.
            Logger.log(LogCategory.D3D9, '[MBAACC-RT-PASS] ' + JSON.stringify({
                frameSerial, present, commands: frame.commandCount,
                ffpDrawStates: frame.ffpStateCount, frameHasClear: frame.hasClear,
                clearFlags: frame.clear.flags,
                clearColor: frame.clear.color,
                hasExplicitTarget: Boolean(target && target.backbuffer === false),
                isBackbuffer: target?.backbuffer ?? true,
                rtIdentities: target?.rtIdentities ?? null,
                rtFormats: target?.colorFormats ?? null,
                colorLoadOps: colorAttachments.map(a => a?.loadOp ?? null),
                hasMsaa: Boolean(passMultisample),
                forceExplicitRT0: mbaaccForceExplicitRt0Clear
            }));
'@
if(([regex]::Matches($s,[regex]::Escape($colorEnd))).Count -lt 1){throw 'Missing insertion point.'}
$pos=$s.IndexOf($colorEnd,$start)
$s=$s.Substring(0,$pos)+$trace.TrimEnd()+[Environment]::NewLine+$s.Substring($pos)
if (!(Test-Path -LiteralPath $backup)) { [IO.File]::Copy($p,$backup) }
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host "Installed RT pass diagnostic, mode: $Mode" -ForegroundColor Green
Write-Host 'Log tag: MBAACC-RT-PASS'
if ($Mode -eq 'ForceRT0') {
    Write-Warning 'A/B rendering change: every explicit-RT0 pass begins with a clear. Visual changes are diagnostic, not a permanent fix.'
}
Write-Host ('Restore with: powershell -NoProfile -ExecutionPolicy Bypass -File ' + $PSCommandPath + ' -Mode Restore')
Write-Host 'Restart BottleShip.'
