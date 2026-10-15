# MBAACC: sample indexed-UP source geometry and GPU buffer pool activity.
# Reversible; writes only one BottleShip TypeScript file.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) { throw 'Run from BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-UP-GEOMETRY-PROBE')) { Write-Host 'UP geometry probe already installed.'; exit 0 }
$start=$s.IndexOf('    drawIndexedPrimitiveUP(')
$finish=$s.IndexOf('    private upSourceInRange(', $start)
if ($start -lt 0 -or $finish -lt $start) { throw 'Indexed UP method not found; no changes made.' }
$method=$s.Substring($start,$finish-$start)
$anchor='        const finalData = this.ensureConversionBuffer(finalVertexCount * stride);'
if (!$method.Contains($anchor)) { throw 'Indexed UP conversion anchor not found.' }
$inject=@'
        // MBAACC-UP-GEOMETRY-PROBE: sample 2D quad UV/position before GPU upload.
        const mbaaccAny = globalThis as typeof globalThis & { __mbaaccUpSampleCount?: number };
        const mbaaccSampleNo = (mbaaccAny.__mbaaccUpSampleCount = (mbaaccAny.__mbaaccUpSampleCount ?? 0) + 1);
        if (mbaaccSampleNo <= 20000 && (mbaaccSampleNo <= 6 || mbaaccSampleNo % 600 === 0)
            && primitiveType === D3DPT_TRIANGLELIST && numVertices >= 4 && stride === 32) {
            const view = new DataView(guestMem.buffer, guestMem.byteOffset, guestMem.byteLength);
            const vertices: string[] = [];
            for (let n = 0; n < Math.min(numVertices, 4); n++) {
                const at = vertexDataPtr + n * stride;
                vertices.push(n + ':' +
                    view.getFloat32(at, true).toFixed(1) + ',' +
                    view.getFloat32(at + 4, true).toFixed(1) + ' uv=' +
                    view.getFloat32(at + stride - 8, true).toFixed(4) + ',' +
                    view.getFloat32(at + stride - 4, true).toFixed(4));
            }
            Logger.log(LogCategory.D3D9, '[MBAACC-UP-GEOMETRY] sample=' + mbaaccSampleNo +
                ' fvf=0x' + this.stateTracker.getFVF().toString(16) +
                ' idx=[' + Array.from(scratch.subarray(0, Math.min(6, idxCount))).join(',') + ']' +
                ' v=[' + vertices.join(' | ') + ']' +
                ' poolCreates=' + (this.vbPool?.creates ?? 0) +
                ' poolReleases=' + (this.vbPool?.releases ?? 0));
        }
'@
$method=$method.Replace($anchor,$inject+$anchor)
$out=$s.Substring(0,$start)+$method+$s.Substring($finish)
$bak=$p+'.mbaacc-before-up-geometry-probe.bak'
if (!(Test-Path $bak)) { [IO.File]::Copy($p,$bak) }
[IO.File]::WriteAllText($p,$out,(New-Object Text.UTF8Encoding($false)))
Write-Host 'UP geometry probe installed. Restart BottleShip and capture log lines tagged MBAACC-UP-GEOMETRY.' -ForegroundColor Green
