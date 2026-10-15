# Read-only MBAACC alpha state probe alongside the existing texture-content sample.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-ALPHA-STATE-PROBE')) {Write-Host 'Alpha-state probe already installed.';exit 0}
$needle="' tex0CpuHash=' + (this.stateTracker.getTexture(0) === null ? '-' : (this.textures.getData(this.stateTracker.getTexture(0)!)?.subarray(0, 1024).reduce((h, b) => (Math.imul(h, 33) ^ b) >>> 0, 5381).toString(16) ?? 'missing')) + // MBAACC-TEX-CONTENT-PROBE"
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) {throw 'Texture-content probe not found; no changes made.'}
$addon=@'
                ' alphaBlend=' + this.getRS(D3DRS_ALPHABLENDENABLE) +
                ' srcBlend=' + this.getRS(D3DRS_SRCBLEND) +
                ' dstBlend=' + this.getRS(D3DRS_DESTBLEND) +
                ' alphaTest=' + this.getRS(D3DRS_ALPHATESTENABLE) +
                ' alphaRef=' + this.getRS(D3DRS_ALPHAREF) +
                ' alphaFunc=' + this.getRS(D3DRS_ALPHAFUNC) +
                ' zWrite=' + this.getRS(D3DRS_ZWRITEENABLE) + // MBAACC-ALPHA-STATE-PROBE
'@
$s=$s.Replace($needle,$needle+[Environment]::NewLine+$addon.TrimEnd())
$bak=$p+'.mbaacc-before-alpha-state-probe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Read-only alpha render-state probe installed. Restart BottleShip.' -ForegroundColor Green
