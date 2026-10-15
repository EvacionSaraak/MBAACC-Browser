# MBAACC: reduce transient WebGPU vertex-buffer churn.
# Safe reversible A/B test; no game assets changed.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/dynamic-vb-pool.ts'
if (!(Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p)
$old='const MAX_FREE_PER_BUCKET = 64;'
$new='const MAX_FREE_PER_BUCKET = 4096; // MBAACC-LARGE-VB-POOL'
if ($s.Contains($new)) { Write-Host 'Large vertex buffer pool already installed.'; exit 0 }
if (([regex]::Matches($s,[regex]::Escape($old))).Count -ne 1) {throw 'Unexpected buffer pool source; no changes made.'}
$bak=$p+'.mbaacc-before-large-pool.bak'
if (!(Test-Path $bak)) { [IO.File]::Copy($p,$bak) }
$s=$s.Replace($old,$new)
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Large vertex buffer pool installed. Restart BottleShip.' -ForegroundColor Green
Write-Host 'Rollback: Copy-Item -Force .\src\worker\backends\webgpu\d3d9\dynamic-vb-pool.ts.mbaacc-before-large-pool.bak .\src\worker\backends\webgpu\d3d9\dynamic-vb-pool.ts'
