# Comprehensive MBAACC renderer telemetry: read-only, sampled, reversible.
# Does not upload game assets, modify rendering, or contact external services.
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
$p=Join-Path $root 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from the BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
$marker='MBAACC-OMNIPROBE-20261016'
if ($s.Contains($marker)) {Write-Host 'Comprehensive probe already installed.';exit 0}
$methodStart=$s.IndexOf('    drawIndexedPrimitiveUP(')
$methodEnd=$s.IndexOf('    private upSourceInRange(', $methodStart)
if ($methodStart -lt 0 -or $methodEnd -le $methodStart) {throw 'Indexed-UP method unavailable; no changes made.'}
$method=$s.Substring($methodStart,$methodEnd-$methodStart)
$anchor="' poolCreates=' + (this.vbPool?.creates ?? 0) +"
if (([regex]::Matches($method,[regex]::Escape($anchor))).Count -ne 1) {throw 'Current geometry probe not found; no changes made.'}
# Insert one diagnostic fragment in the already sampled draw logging.
$extra=@'
                ' renderTargets=' + this.renderTargetIndices.map((x, i) => i + ':' + String(x)).join(',') +
                ' rtFaces=' + this.renderTargetFaces.join(',') +
                ' depthTarget=' + String(this.depthTextureIndex) +
                ' depthFmt=' + String(this.activeDepthTargetFormat()) +
                ' zEnable=' + this.getRS(D3DRS_ZENABLE) +
                ' zFunc=' + this.getRS(D3DRS_ZFUNC) +
                ' cull=' + this.getRS(D3DRS_CULLMODE) +
                ' scissor=' + this.getRS(D3DRS_SCISSORTESTENABLE) +
                ' srgbWrite=' + this.getRS(D3DRS_SRGBWRITEENABLE) +
                ' texStages=' + Array.from({ length: 4 }, (_, stage) => {
                    const id = this.stateTracker.getTexture(stage);
                    if (id === null) return stage + ':none';
                    const gpu = this.textures.getGpuTexture(id);
                    const raw = this.textures.getData(id);
                    let hash = 2166136261 >>> 0;
                    if (raw && raw.length > 0) {
                        for (let k = 0; k < 256; k++) {
                            hash = Math.imul(hash ^ raw[Math.floor(k * (raw.length - 1) / 255)]!, 16777619) >>> 0;
                        }
                    }
                    return stage + ':id' + id + '/h' + this.textures.getHandle(id).toString(16) +
                        '/fmt' + this.textures.getFormat(id).toString(16) +
                        '/dirty' + Number(this.textures.isDirty(id)) +
                        '/locked' + Number(this.textures.isLocked(id)) +
                        '/gpu' + (gpu?.format ?? 'missing') +
                        '/view' + Number(!!this.textures.getView(id)) +
                        '/sparseHash' + (raw ? hash.toString(16) : 'missing');
                }).join(',') +
                ' sampler0=' + [1, 2, 3, 5, 6, 7, 11].map(t => t + ':' + this.getSamplerState(0, t)).join(',') +
                ' omni=' + 'MBAACC-OMNIPROBE-20261016' +
'@
$method=$method.Replace($anchor,$extra.TrimEnd()+[Environment]::NewLine+'                '+$anchor)
$out=$s.Substring(0,$methodStart)+$method+$s.Substring($methodEnd)
$bak=$p+'.mbaacc-before-omniprobe.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$out,(New-Object Text.UTF8Encoding($false)))
# Environment snapshot is small metadata only. Never read or copy the WGB.
$report=Join-Path $env:TEMP 'mbaacc-omniprobe-environment.txt'
@(
 'MBAACC comprehensive diagnostic'
 ('Timestamp: '+(Get-Date -Format o))
 ('Root: '+$root)
 ('OS: '+[Environment]::OSVersion.VersionString)
 ('PowerShell: '+$PSVersionTable.PSVersion.ToString())
 ('Renderer SHA256: '+(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash)
 ('Existing geometry sampling: '+[bool]($s.Contains('MBAACC-UP-GEOMETRY')))
 ('Existing MRT mirror active before patch: '+[bool]($s.Contains('MBAACC-MRT-MIRROR-TEST')))
) | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host 'Comprehensive read-only diagnostic installed. Restart BottleShip.' -ForegroundColor Green
Write-Host "Environment report: $report"
Write-Host 'Collect 30-60 [MBAACC-UP-GEOMETRY] lines, plus any GPU validation errors.'
Write-Host "Rollback: Copy-Item -LiteralPath '$bak' -Destination '$p' -Force"
