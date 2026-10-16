# MBAACC executor GPU draw trace + optional HEAP spill result trace, v4.
# PowerShell 5.1. Works even if the local Process allocator differs from upstream.
# Never uploads game assets and never changes rendering or allocation decisions.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$exec = Join-Path $root 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
$memory = Join-Path $root 'src/worker/core/process.ts'
if (!(Test-Path -LiteralPath $exec)) { throw "Missing $exec. Run from the BottleShip checkout." }
$e = [IO.File]::ReadAllText($exec)
$alreadyExec = $e.Contains('MBAACC-EXEC-TRACE-20261016')
$anchor = '        const frameSerial = ++this.executeFrameSerial;'
$bindAnchor = '                        if (fs) this.bindFfpDrawState(renderPass, device, fs);'
$drawAnchor = '                        renderPass.draw(vertexCount, instanceCount, startVertex, 0);'
if (-not $alreadyExec) {
    foreach ($a in @($anchor, $bindAnchor, $drawAnchor)) {
        if (([regex]::Matches($e, [regex]::Escape($a))).Count -ne 1) {
            throw "Executor source anchor absent or duplicated; nothing changed: $a"
        }
    }
$before=@'
        // MBAACC-EXEC-TRACE-20261016: identify GPU resources by object identity across frames.
        const mbaaccG = globalThis as typeof globalThis & {
            __mbaaccExecTrace?: {
                seq: number;
                nextId: number;
                objects: WeakMap<object, number>;
                off?: boolean;
            };
        };
        const mbaaccTrace = mbaaccG.__mbaaccExecTrace ??= {
            seq: 0, nextId: 1, objects: new WeakMap<object, number>()
        };
        const mbaaccId = (obj: object | null | undefined): number => {
            if (!obj) return 0;
            let id = mbaaccTrace.objects.get(obj);
            if (id === undefined) {
                id = mbaaccTrace.nextId++;
                mbaaccTrace.objects.set(obj, id);
            }
            return id;
        };
        let mbaaccFfpIndex = -1;
        let mbaaccDrawOrdinal = 0;
        Logger.log(LogCategory.D3D9, '[MBAACC-EXEC-BEGIN] ' + JSON.stringify({
            frameSerial: this.executeFrameSerial + 1,
            commandCount: frame.commandCount,
            ffpCount: frame.ffpStateCount,
            programmableCount: frame.drawStateCount,
            bufferRefs: frame.bufferRefs.length
        }));
'@

    $e = $e.Replace($anchor, $before.TrimEnd() + [Environment]::NewLine + $anchor)
    $e = $e.Replace($bindAnchor, '                        mbaaccFfpIndex = frame.commandA[i] | 0;' + [Environment]::NewLine + $bindAnchor)
$drawBlock=@'
                        // MBAACC-EXEC-TRACE-20261016: state immediately before the REAL GPU draw.
                        {
                            mbaaccDrawOrdinal++;
                            const seq = ++mbaaccTrace.seq;
                            const buf = this.boundVbBuffer[0];
                            const fs = mbaaccFfpIndex >= 0 ? frame.ffpStates[mbaaccFfpIndex] : null;
                            const sampled = seq <= 200000 || seq % 8 === 0;
                            if (!mbaaccTrace.off && sampled) {
                                Logger.log(LogCategory.D3D9, '[MBAACC-EXEC-DRAW] ' + JSON.stringify({
                                    seq, frameSerial, drawOrdinal: mbaaccDrawOrdinal, command: i,
                                    pipeline: this.currentPipelineId,
                                    requestedVertices: frame.commandA[i],
                                    effectiveVertices: vertexCount, startVertex,
                                    instanceCount,
                                    ffpIndex: mbaaccFfpIndex,
                                    ffpStageCount: fs?.stageCount ?? null,
                                    ffpTextureIds: fs ? fs.textures.slice(0,fs.stageCount).map(v=>mbaaccId(v)) : null,
                                    ffpSamplerIds: fs ? fs.samplers.slice(0,fs.stageCount).map(v=>mbaaccId(v)) : null,
                                    uniformArenaOffset: this.ffpArena?.lastOffset ?? null,
                                    uniformArenaCursor: this.ffpArena?.position() ?? null,
                                    bufferId: mbaaccId(buf),
                                    bufferSize: buf?.size ?? null,
                                    vertexOffset: this.boundVbOffset[0],
                                    boundVertexBytes: this.boundVbSize[0],
                                    gpuBufferUsage: buf?.usage ?? null,
                                    frameGpuBufferRefs: frame.bufferRefs.length,
                                    arenaDrawLinked: Boolean(arenaBinding),
                                    arenaUsable,
                                    paddingCount: this.padCursor - padStart
                                }));
                            }
                            if (!buf || this.boundVbSize[0] < 1 || vertexCount < 1) {
                                Logger.warn(LogCategory.D3D9, '[MBAACC-EXEC-ANOMALY] ' +
                                    JSON.stringify({seq,frameSerial,command:i,hasVertexBuffer:Boolean(buf),
                                        boundBytes:this.boundVbSize[0],vertexCount}));
                            }
                        }
'@

    $e = $e.Replace($drawAnchor, $drawBlock.TrimEnd() + [Environment]::NewLine + $drawAnchor)
}
# The allocator differs across BottleShip versions. Never block the GPU trace for it.
$memPatched = $false
$memoryOriginal = $null
$m = $null
if (Test-Path -LiteralPath $memory) {
    $memoryOriginal = [IO.File]::ReadAllText($memory)
    $m = $memoryOriginal
    $spillAnchor = "                if (addr !== 0) usedBucketKind = 'HEAP_HIGH';"
    if ($m.Contains('MBAACC-HEAP-SPILL-V4')) {
        Write-Host 'HEAP spill trace already installed.'
    } elseif (([regex]::Matches($m, [regex]::Escape($spillAnchor))).Count -eq 1) {
        $spillTrace = @'
                // MBAACC-HEAP-SPILL-V4: low bucket refused; report whether high heap succeeded.
                Logger.log(LogCategory.SYSTEM, '[MBAACC-HEAP-SPILL] ' + JSON.stringify({
                    requested: aligned,
                    succeeded: addr !== 0,
                    result: addr,
                    lowNext: bucket.next,
                    lowLimit: bucket.limit,
                    highNext: high.next,
                    highLimit: high.limit
                }));
'@
        $m = $m.Replace($spillAnchor, $spillAnchor + [Environment]::NewLine + $spillTrace.TrimEnd())
        $memPatched = $true
    } else {
        Write-Warning 'Local allocator differs: skipping optional HEAP spill trace. GPU executor trace can still install.'
    }
} else {
    Write-Warning 'Memory manager source missing: skipping optional HEAP spill trace.'
}
if ($alreadyExec) {
    Write-Host 'GPU executor trace already present.'
} else {
    $bakE = $exec + '.mbaacc-before-exec-trace-v4.bak'
    if (!(Test-Path -LiteralPath $bakE)) { [IO.File]::Copy($exec, $bakE) }
}
if ($memPatched) {
    $bakM = $memory + '.mbaacc-before-exec-trace-v4.bak'
    if (!(Test-Path -LiteralPath $bakM)) { [IO.File]::Copy($memory, $bakM) }
}
try {
    if (-not $alreadyExec) { [IO.File]::WriteAllText($exec, $e, (New-Object Text.UTF8Encoding($false))) }
    if ($memPatched) { [IO.File]::WriteAllText($memory, $m, (New-Object Text.UTF8Encoding($false))) }
} catch {
    if (-not $alreadyExec) { Copy-Item -LiteralPath $bakE -Destination $exec -Force }
    if ($memPatched) { Copy-Item -LiteralPath $bakM -Destination $memory -Force }
    throw
}
if (-not ([IO.File]::ReadAllText($exec)).Contains('MBAACC-EXEC-TRACE-20261016')) {
    throw 'Post-install verification failed: GPU executor trace marker missing.'
}
Write-Host 'SUCCESS: GPU executor replay diagnostic is present.' -ForegroundColor Green
if ($memPatched) { Write-Host 'SUCCESS: Optional HEAP spill diagnostic installed.' -ForegroundColor Green }
Write-Host 'Log tags: MBAACC-EXEC-BEGIN, MBAACC-EXEC-DRAW, MBAACC-EXEC-ANOMALY, MBAACC-HEAP-SPILL.'
Write-Host 'Restart BottleShip (Ctrl+C, then your normal Vite command).'
