# MBAACC D3D9 indexed-UP fate probe; Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$p = Join-Path $root 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (-not (Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s = [System.IO.File]::ReadAllText($p)
if ($s.Contains('[MBAACC-DX9-UP-FATE]')) { Write-Host 'UP fate probe already installed.'; exit 0 }
$start = $s.IndexOf('    drawIndexedPrimitiveUP(')
$finish = $s.IndexOf('    private upSourceInRange(', $start)
if ($start -lt 0 -or $finish -le $start) { throw 'Expected D3D9 draw method not found; no changes made.' }
$before = $s.Substring(0, $start)
$method = $s.Substring($start, $finish - $start)
$after = $s.Substring($finish)
$anchor = '        if (this.gpuGone) return d3d9DropDraw("drawIndexedPrimitiveUP:deviceLost");'
if (-not $method.Contains($anchor)) { throw 'Unexpected BottleShip method version; no changes made.' }
$trace = @'
        const mbaaccTrace = !(globalThis as any).__mbaaccUpFateLogged;
        if (mbaaccTrace) {
            (globalThis as any).__mbaaccUpFateLogged = true;
            Logger.log(LogCategory.D3D9,
                '[MBAACC-DX9-UP-FATE] entered role=' + this.role +
                ' gpuGone=' + this.gpuGone +
                ' fvf=0x' + this.stateTracker.getFVF().toString(16) +
                ' topology=' + primitiveType +
                ' vertices=' + numVertices +
                ' primitives=' + primitiveCount +
                ' index32=' + indexIs32 +
                ' stride=' + stride);
        }
'@
$method = $method.Replace($anchor, $trace + [Environment]::NewLine + $anchor)
$last = '        return this.recordConvertedDraw(finalData, finalVertexCount, stride, topology, UP_STREAM_SLOTS);'
if (-not $method.Contains($last)) { throw 'Expected final draw path missing; no changes made.' }
$replacement = @'
        const mbaaccDrawResult = this.recordConvertedDraw(finalData, finalVertexCount, stride, topology, UP_STREAM_SLOTS);
        if (mbaaccTrace) {
            Logger.log(LogCategory.D3D9,
                '[MBAACC-DX9-UP-FATE] reached converted draw result=' + mbaaccDrawResult +
                ' vertices=' + finalVertexCount + ' stride=' + stride);
        }
        return mbaaccDrawResult;
'@
$method = $method.Replace($last, $replacement.TrimEnd())
$out = $before + $method + $after
$backup = $p + '.mbaacc-before-up-fate.bak'
if (-not (Test-Path $backup)) { [System.IO.File]::Copy($p, $backup) }
[System.IO.File]::WriteAllText($p, $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Installed D3D9 indexed-UP fate probe. Restart the server.' -ForegroundColor Green
