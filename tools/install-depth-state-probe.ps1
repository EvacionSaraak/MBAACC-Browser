# MBAACC: read-only depth-state sample for translucent sprite draws.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-DEPTH-STATE-PROBE')) {Write-Host 'Depth-state probe already installed.';exit 0}
$needle="' zWrite=' + this.getRS(D3DRS_ZWRITEENABLE) + // MBAACC-ALPHA-STATE-PROBE"
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) {throw 'Alpha probe not found; no changes made.'}
$extra=@'
                ' zEnable=' + this.getRS(D3DRS_ZENABLE) +
                ' zFunc=' + this.getRS(D3DRS_ZFUNC) +
                ' depthFormat=' + String(this.activeDepthTargetFormat()) + // MBAACC-DEPTH-STATE-PROBE
'@
$s=$s.Replace($needle,$needle+[Environment]::NewLine+$extra.TrimEnd())
$bak=$p+'.mbaacc-before-depth-state-probe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Depth-state diagnostic installed. Restart BottleShip.' -ForegroundColor Green
