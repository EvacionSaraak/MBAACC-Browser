# MBAACC: augment the existing quad probe with bound texture identity.
# Diagnostic only: does not alter rendering or texture state.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from your BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-TEX-BIND-PROBE')) {Write-Host 'Texture binding probe already installed.';exit 0}
$tag="                ' poolCreates=' + (this.vbPool?.creates ?? 0) +"
if (([regex]::Matches($s,[regex]::Escape($tag))).Count -ne 1) {throw 'Existing geometry probe not found; no changes made.'}
$newTag="                ' tex0Ptr=0x' + ((this.boundTexturePtrs[0] ?? 0) >>> 0).toString(16) +" + [Environment]::NewLine + "                ' tex0Index=' + String(this.stateTracker.getTexture(0)) + // MBAACC-TEX-BIND-PROBE" + [Environment]::NewLine + $tag
$s=$s.Replace($tag,$newTag)
$needle='        const unknown = texPtr !== 0 && index === null;'
if (([regex]::Matches($s,[regex]::Escape($needle))).Count -ne 1) {throw 'Texture binding entry not found; no changes made.'}
$insert=@'
        // MBAACC-TEX-BIND-PROBE: capture invalid texture bindings, capped to avoid log flood.
        if (unknown) {
            const probe = globalThis as typeof globalThis & { __mbaaccUnknownTex?: number };
            const count = (probe.__mbaaccUnknownTex = (probe.__mbaaccUnknownTex ?? 0) + 1);
            if (count <= 20 || count % 1024 === 0) {
                Logger.warn(LogCategory.D3D9, '[MBAACC-UNKNOWN-TEXTURE] count=' + count
                    + ' stage=' + stage + ' ptr=0x' + (texPtr >>> 0).toString(16));
            }
        }
'@
$s=$s.Replace($needle,$needle+[Environment]::NewLine+$insert.TrimEnd())
$bak=$p+'.mbaacc-before-tex-bind-probe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Texture binding probe installed. Restart BottleShip.' -ForegroundColor Green
