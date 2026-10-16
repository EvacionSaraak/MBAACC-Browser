# MBAACC final-composition isolation test. Requires BottleShip checkout.
# PowerShell 5.1. Reversible; does not touch WGB or MRT write-mask workaround.
param(
    [ValidateSet('ClearBackbuffer','SkipFirst','SkipSecond','Trace','Restore')]
    [string]$Mode = 'ClearBackbuffer'
)
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
if (!(Test-Path -LiteralPath $p)) { throw 'Run from BottleShip checkout.' }
$backup = $p + '.mbaacc-before-composition-isolation.bak'
$mark = 'MBAACC-COMPOSITION-ISOLATION-20261016'
$previousMarker = 'MBAACC-RT-PASS-PROBE-20261016'
if ($Mode -eq 'Restore') {
    if (!(Test-Path -LiteralPath $backup)) { throw 'No composition-test backup; nothing changed.' }
    Copy-Item -LiteralPath $backup -Destination $p -Force
    Write-Host 'Pre-composition-test renderer restored. Restart BottleShip.' -ForegroundColor Green
    exit 0
}
if (Test-Path -LiteralPath $backup) {
    $s = [IO.File]::ReadAllText($backup)
} else {
    $s = [IO.File]::ReadAllText($p)
}
if ($s.Contains($mark)) { throw 'Unclean backup contains composition test; refusing to alter source.' }
if ($s.Contains($previousMarker)) {
    throw 'Previous RT clear A/B still installed. Restore its backup first: Copy-Item ".\src\worker\backends\webgpu\d3d9\d3d9-backend-executor.ts.mbaacc-before-rt-clear-test.bak" ".\src\worker\backends\webgpu\d3d9\d3d9-backend-executor.ts" -Force'
}
$frameAnchor = '        const frameSerial = ++this.executeFrameSerial;'
$colorStart = '            const colorAttachments: Array<GPURenderPassColorAttachment | null> = target'
$colorEnd = '            const depthFormat ='
$drawAnchor = '                        renderPass.draw(vertexCount, instanceCount, startVertex, 0);'
$loadAnchor = '                    loadOp: (frame.hasClear && clearTarget) ? "clear" : "load",'
$begin = $s.IndexOf($colorStart)
$end = if ($begin -ge 0) { $s.IndexOf($colorEnd, $begin) } else { -1 }
if ($begin -lt 0 -or $end -le $begin) { throw 'Color attachment structure differs; nothing changed.' }
$area = $s.Substring($begin, $end - $begin)
if (([regex]::Matches($area, [regex]::Escape($loadAnchor))).Count -ne 2) { throw 'Expected two loadOp branches not found; nothing changed.' }
foreach ($anchor in @($frameAnchor,$drawAnchor)) {
    if (([regex]::Matches($s,[regex]::Escape($anchor))).Count -ne 1) {
        throw "Draw/serial anchor missing or duplicated: $anchor. Nothing changed."
    }
}
$clear = if ($Mode -eq 'ClearBackbuffer') {'true'} else {'false'}
$skipFirst = if ($Mode -eq 'SkipFirst') {'true'} else {'false'}
$skipSecond = if ($Mode -eq 'SkipSecond') {'true'} else {'false'}
$vars = @"
        const mbaaccClearBackbuffer = $clear;
        const mbaaccSkipFirst = $skipFirst;
        const mbaaccSkipSecond = $skipSecond;
        let mbaaccCompositeDrawOrdinal = 0; // $mark
"@
$s = $s.Replace($frameAnchor, $frameAnchor + [Environment]::NewLine + $vars.TrimEnd())
$loadFirst = '                    loadOp: ((frame.hasClear && clearTarget) || (mbaaccClearBackbuffer && present && target?.backbuffer === true)) ? "clear" : "load",'
$loadSecond = '                    loadOp: ((frame.hasClear && clearTarget) || (mbaaccClearBackbuffer && present)) ? "clear" : "load",'
$index0 = $area.IndexOf($loadAnchor)
$area = $area.Substring(0,$index0) + $loadFirst + $area.Substring($index0+$loadAnchor.Length)
$index1 = $area.IndexOf($loadAnchor)
if ($index1 -lt 0) { throw 'Second loadOp lost during patch. Nothing changed.' }
$area = $area.Substring(0,$index1) + $loadSecond + $area.Substring($index1+$loadAnchor.Length)
$s = $s.Substring(0,$begin) + $area + $s.Substring($end)
$trace = @'
            // MBAACC-COMPOSITION-ISOLATION-20261016: effective framebuffer load and discard state.
            Logger.log(LogCategory.D3D9, '[MBAACC-COMPOSITION-PASS] ' + JSON.stringify({
                frameSerial, present, commands: frame.commandCount,
                ffpStates: frame.ffpStateCount, hasClear: frame.hasClear,
                clearFlags: frame.clear.flags, clearColor: frame.clear.color,
                discardAfterPresent: discardBackbufferAfterPresent,
                explicitTarget: Boolean(target && target.backbuffer === false),
                backbuffer: target?.backbuffer ?? true,
                rtIdentities: target?.rtIdentities ?? null,
                attachments: colorAttachments.map((a, i) => ({
                    slot: i, load: a?.loadOp ?? null,
                    format: target?.colorFormats?.[i] ?? null
                })),
                clearBackbuffer: mbaaccClearBackbuffer,
                skipFirst: mbaaccSkipFirst,
                skipSecond: mbaaccSkipSecond
            }));
'@
$insert=$s.IndexOf($colorEnd, $begin)
if ($insert -lt 0) { throw 'Trace insertion location missing.' }
$s = $s.Substring(0,$insert) + $trace.TrimEnd() + [Environment]::NewLine + $s.Substring($insert)
$drawReplacement = @'
                        mbaaccCompositeDrawOrdinal++;
                        const mbaaccComposeSkip = present && (target?.backbuffer ?? true) &&
                            ((mbaaccSkipFirst && mbaaccCompositeDrawOrdinal === 1) ||
                             (mbaaccSkipSecond && mbaaccCompositeDrawOrdinal === 2));
                        if (mbaaccComposeSkip) {
                            Logger.log(LogCategory.D3D9,
                                '[MBAACC-COMPOSITION-SKIP] ' + JSON.stringify({
                                    frameSerial, draw: mbaaccCompositeDrawOrdinal,
                                    pipeline: this.currentPipelineId, vertices: vertexCount
                                }));
                        } else {
                            renderPass.draw(vertexCount, instanceCount, startVertex, 0);
                        }
'@
$s = $s.Replace($drawAnchor,$drawReplacement.TrimEnd())
if (!(Test-Path -LiteralPath $backup)) { [IO.File]::Copy($p,$backup) }
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
if (!([IO.File]::ReadAllText($p)).Contains($mark)) { throw 'Post-install verification failed.' }
Write-Host "Installed MBAACC composition test: $Mode" -ForegroundColor Green
Write-Host 'Log markers: MBAACC-COMPOSITION-PASS and MBAACC-COMPOSITION-SKIP.'
Write-Host ('Restore: powershell -NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Mode Restore')
Write-Host 'Restart BottleShip.'
