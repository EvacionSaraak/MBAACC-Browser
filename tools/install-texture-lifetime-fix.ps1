# MBAACC texture lifetime workaround: leave GPU textures to JS GC instead of
# destroying them while queued WebGPU commands may still reference them.
$ErrorActionPreference='Stop'
$base=(Get-Location).Path
$p=Join-Path $base 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
$q=Join-Path $base 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
if (!(Test-Path $p) -or !(Test-Path $q)) { throw 'Run from BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p)
$t=[IO.File]::ReadAllText($q)
$mark='MBAACC-DEFER-TEXTURE-DESTROY'
if ($s.Contains($mark)) { Write-Host 'Texture lifetime patch already installed.'; exit 0 }
$a='            tex.gpuTexture.destroy();'
$b='            this.offscreenTexture.destroy();'
if (([regex]::Matches($s,[regex]::Escape($a))).Count -ne 1 -or ([regex]::Matches($t,[regex]::Escape($b))).Count -ne 1) {throw 'Source mismatch; no changes made.'}
$s=$s.Replace($a,'            // MBAACC-DEFER-TEXTURE-DESTROY: queued draws can still use this texture.'+[Environment]::NewLine+'            // Let JS/GPU garbage collection reclaim it after references expire.')
$t=$t.Replace($b,'            // MBAACC-DEFER-TEXTURE-DESTROY: queued render work may still reference it.'+[Environment]::NewLine+'            // Avoid invalidating submitted-but-not-executed command buffers.')
foreach ($f in @($p,$q)) { $bak=$f+'.mbaacc-before-texture-lifetime.bak';if (!(Test-Path $bak)) { [IO.File]::Copy($f,$bak) } }
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($p,$s,$utf8)
[IO.File]::WriteAllText($q,$t,$utf8)
Write-Host 'MBAACC texture lifetime patch installed. Restart BottleShip.' -ForegroundColor Green
