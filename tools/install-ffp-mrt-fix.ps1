# MBAACC: fixed-function shaders output location 0 only; disable writes on MRT slots 1+.
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (-not (Test-Path $p)) { throw 'Run from BottleShip checkout.' }
$s = [System.IO.File]::ReadAllText($p)
$marker = 'MBAACC-FFP-MRT-FIX'
if ($s.Contains($marker)) { Write-Host 'FFP MRT fix already installed.'; exit 0 }
$anchor = '        const colorTargets = this.activeColorTargetStates();' + [Environment]::NewLine + '        if (!colorTargets) return -1;'
$position = $s.IndexOf($anchor)
if ($position -lt 0) { throw 'Expected FFP color target setup missing; no file modified.' }
$next = $s.IndexOf('        const declElements =', $position)
if ($next -lt 0 -or $next - $position -gt 400) { throw 'Unexpected FFP source layout; no file modified.' }
$replacement = @'
        const colorTargets = this.activeColorTargetStates();
        if (!colorTargets) return -1;
        // MBAACC-FFP-MRT-FIX: fixed-function fs_main only emits @location(0).
        // D3D9 may leave RT1/RT2 bound; WebGPU forbids nonzero write masks
        // for color attachments without matching fragment outputs.
        for (let i = 1; i < colorTargets.length; i++) {
            if (colorTargets[i]) {
                colorTargets[i] = { ...colorTargets[i]!, writeMask: 0 };
            }
        }
'@
$s = $s.Substring(0,$position) + $s.Substring($position).Replace($anchor,$replacement.TrimEnd())
$b = $p + '.mbaacc-before-ffp-mrt-fix.bak'
if (-not (Test-Path $b)) { [System.IO.File]::Copy($p,$b) }
[System.IO.File]::WriteAllText($p,$s,(New-Object System.Text.UTF8Encoding($false)))
Write-Host 'FFP MRT pipeline fix installed. Restart BottleShip.' -ForegroundColor Green
