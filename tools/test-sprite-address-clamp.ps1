# Reversible test for MBAACC sprite atlas sampling/addressing.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) { throw 'Run in BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p)
$marker='MBAACC-SPRITE-ADDRESS-CLAMP'
if ($s.Contains($marker)) { Write-Host 'Sprite clamp test already installed.'; exit 0 }
$needle='        const v = value >>> 0;'
$pos=$s.IndexOf('    setSamplerState(sampler: number, type: number, value: number): number {')
if ($pos -lt 0) { throw 'Sampler handler not found.' }
$ix=$s.IndexOf($needle,$pos)
if ($ix -lt 0 -or $ix - $pos -gt 500) {throw 'Sampler layout mismatch.'}
$replacement=@'
        // MBAACC-SPRITE-ADDRESS-CLAMP: A/B test, clamp U and V on texture stage 0.
        // D3DSAMP_ADDRESSU=1, ADDRESSV=2; D3DTADDRESS_CLAMP=3.
        const v = (sampler === 0 && (type === 1 || type === 2)) ? 3 : (value >>> 0);
'@
$s=$s.Substring(0,$ix)+$replacement.TrimEnd()+$s.Substring($ix+$needle.Length)
$bak=$p+'.mbaacc-before-sprite-clamp.bak'
if (!(Test-Path $bak)) { [IO.File]::Copy($p,$bak) }
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Sprite clamp test installed. Restart BottleShip.' -ForegroundColor Green
