# MBAACC: read-only texture state inspection for the existing geometry probe.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-TEX-STATE-PROBE')) {Write-Host 'Texture state probe already installed.';exit 0}
$needle="                ' tex0Index=' + String(this.stateTracker.getTexture(0)) + // MBAACC-TEX-BIND-PROBE"
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) {throw 'Texture binding probe not found; no changes made.'}
$insert=@'
                ' tex0Dirty=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.isDirty(this.stateTracker.getTexture(0)!))) +
                ' tex0Size=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.textures.getWidth(this.stateTracker.getTexture(0)!)) + 'x' + String(this.textures.getHeight(this.stateTracker.getTexture(0)!))) +
                ' tex0RtConflict=' + (this.stateTracker.getTexture(0) === null ? '-' : String(this.isTextureConflictingWithActiveRt(this.stateTracker.getTexture(0)!))) + // MBAACC-TEX-STATE-PROBE
'@
$s=$s.Replace($needle,$needle+[Environment]::NewLine+$insert.TrimEnd())
$bak=$p+'.mbaacc-before-tex-state-probe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Read-only texture state probe installed. Restart BottleShip.' -ForegroundColor Green
