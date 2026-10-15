# MBAACC: bypass split D3D9 to isolate lost render-twin work.
# Safe, reversible local test. Run from BottleShip checkout.
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/modules/d3d9/device.ts'
if (-not (Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s = [System.IO.File]::ReadAllText($p)
$old = 'if (d3d9SplitWanted() && process.dispatcher) {'
$new = 'if (false && d3d9SplitWanted() && process.dispatcher) { // MBAACC: single-device render test'
if ($s.Contains($new)) { Write-Host 'Single-device test already enabled.'; exit 0 }
$hits = ([regex]::Matches($s, [regex]::Escape($old))).Count
if ($hits -ne 1) { throw ('Expected exactly one split-device gate; found ' + $hits + '. No changes made.') }
$backup = $p + '.mbaacc-before-single-device.bak'
if (-not (Test-Path $backup)) { [System.IO.File]::Copy($p, $backup) }
$s = $s.Replace($old, $new)
[System.IO.File]::WriteAllText($p, $s, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Single-device D3D9 test enabled. Restart BottleShip.' -ForegroundColor Green
Write-Host 'To undo: Copy-Item -Force src/worker/modules/d3d9/device.ts.mbaacc-before-single-device.bak src/worker/modules/d3d9/device.ts'
