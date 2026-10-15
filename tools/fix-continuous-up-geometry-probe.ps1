# MBAACC: keep UP geometry samples active throughout gameplay.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
$old='mbaaccSampleNo <= 20000 && (mbaaccSampleNo <= 6 || mbaaccSampleNo % 600 === 0)'
$new='(mbaaccSampleNo <= 6 || mbaaccSampleNo % 2048 === 0)'
if ($s.Contains($new)) {Write-Host 'Continuous geometry sampling already enabled.';exit 0}
if (!$s.Contains($old)) {throw 'Original geometry probe not found. No changes made.'}
$bak=$p+'.mbaacc-before-continuous-geometry.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
$s=$s.Replace($old,$new)
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Continuous geometry sampling enabled. Restart BottleShip.' -ForegroundColor Green
