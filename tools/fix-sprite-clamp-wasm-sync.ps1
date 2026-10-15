# MBAACC: ensure sprite clamp reaches WASM arena as well as JS sampler state.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) { throw 'Run from your BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p)
if (!$s.Contains('MBAACC-SPRITE-ADDRESS-CLAMP')) { throw 'Install the sprite clamp test first; nothing modified.' }
$needle='            d3d9WasmArena.setSamplerState(sampler, type, value);'
$replacement='            d3d9WasmArena.setSamplerState(sampler, type, v); // MBAACC: use the clamped value'
if ($s.Contains($replacement)) { Write-Host 'WASM clamp sync already installed.'; exit 0 }
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) { throw 'Sampler source mismatch; no changes made.' }
$bak=$p+'.mbaacc-before-wasm-clamp-sync.bak'
if (!(Test-Path $bak)) { [IO.File]::Copy($p,$bak) }
$s=$s.Replace($needle,$replacement)
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Sprite clamp now synchronized with WASM arena. Restart BottleShip.' -ForegroundColor Green
