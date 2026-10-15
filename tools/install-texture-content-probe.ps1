# MBAACC read-only texture-content fingerprint probe.
# Extends the existing geometry sampler; does not change rendering.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-TEX-CONTENT-PROBE')) {Write-Host 'Texture content probe already installed.';exit 0}
$needle="                ' tex0RtConflict=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.isTextureConflictingWithActiveRt(this.stateTracker.getTexture(0)!))) + // MBAACC-TEX-STATE-PROBE"
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) {throw 'Existing texture-state diagnostic not found. No changes made.'}
$addon=@'
                ' tex0Fmt=' + (this.stateTracker.getTexture(0) === null ? '-' : '0x' + this.textures.getFormat(this.stateTracker.getTexture(0)!).toString(16)) +
                ' tex0Pitch=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.getPitch(this.stateTracker.getTexture(0)!))) +
                ' tex0Locked=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.isLocked(this.stateTracker.getTexture(0)!))) +
                ' tex0GpuFmt=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.getGpuTexture(this.stateTracker.getTexture(0)!)?.format ?? 'missing')) +
                ' tex0Mips=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.getGpuTexture(this.stateTracker.getTexture(0)!)?.mipLevelCount ?? 'missing')) +
                ' tex0CpuHash=' + (this.stateTracker.getTexture(0) === null ? '-' : (this.textures.getData(this.stateTracker.getTexture(0)!)?.subarray(0, 1024).reduce((h, b) => (Math.imul(h, 33) ^ b) >>> 0, 5381).toString(16) ?? 'missing')) + // MBAACC-TEX-CONTENT-PROBE
'@
$s=$s.Replace($needle,$needle+[Environment]::NewLine+$addon.TrimEnd())
$bak=$p+'.mbaacc-before-tex-content-probe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Read-only texture content fingerprint probe installed. Restart BottleShip.' -ForegroundColor Green
