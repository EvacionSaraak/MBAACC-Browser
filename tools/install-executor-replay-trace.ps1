# MBAACC execution/replay + HEAP spill diagnostic, no rendering/allocator behavior changes.
# Applies to BottleShip checkout. PowerShell 5.1-compatible, reversible.
$ErrorActionPreference = 'Stop'
$root=(Get-Location).Path
$exec=Join-Path $root 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
$memory=Join-Path $root 'src/worker/core/process.ts'
foreach($p in @($exec,$memory)){if(!(Test-Path -LiteralPath $p)){throw "Missing source $p. Run from BottleShip checkout."}}
$e=[IO.File]::ReadAllText($exec)
$m=[IO.File]::ReadAllText($memory)
if($e.Contains('MBAACC-EXEC-TRACE-20261016')){Write-Host 'Executor trace already installed.';exit 0}
$anchor='        const frameSerial = ++this.executeFrameSerial;'
$bindAnchor='                        if (fs) this.bindFfpDrawState(renderPass, device, fs);'
$drawAnchor='                        renderPass.draw(vertexCount, instanceCount, startVertex, 0);'
$memAnchor='                return this.carveFromFreeList(bucketKind, size, alignment, Infinity)' + [Environment]::NewLine + '                    || this.allocateLargeFromReleased(bucketKind, size, alignment);'
foreach($pair in @(@($e,$anchor),@($e,$bindAnchor),@($e,$drawAnchor),@($m,$memAnchor))){
 if(([regex]::Matches($pair[0],[regex]::Escape($pair[1]))).Count -ne 1){throw "Source anchor missing or duplicated: $($pair[1]); nothing changed."}
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
$e=$e.Replace($anchor,$before+$anchor)
$e=$e.Replace($bindAnchor,'                        mbaaccFfpIndex = frame.commandA[i] | 0;'+[Environment]::NewLine+$bindAnchor)
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
$e=$e.Replace($drawAnchor,$drawBlock+$drawAnchor)
$memNew=@'
                const fallback = this.carveFromFreeList(bucketKind, size, alignment, Infinity)
                    || this.allocateLargeFromReleased(bucketKind, size, alignment);
                Logger.log(LogCategory.SYSTEM, '[MBAACC-HEAP-FALLBACK] ' + JSON.stringify({
                    bucket: bucketKind, requested: size, alignedAt: alignedStart,
                    lowBucketLimit: bucket.limit, fallbackAddress: fallback,
                    succeeded: fallback !== 0
                }));
                return fallback;
'@
$m=$m.Replace($memAnchor,$memNew.TrimEnd())
# All anchors validated and text substitutions complete before touching disk.
$bakE=$exec+'.mbaacc-before-exec-trace.bak'
$bakM=$memory+'.mbaacc-before-exec-trace.bak'
if(!(Test-Path $bakE)){[IO.File]::Copy($exec,$bakE)}
if(!(Test-Path $bakM)){[IO.File]::Copy($memory,$bakM)}
try {
 [IO.File]::WriteAllText($exec,$e,(New-Object Text.UTF8Encoding($false)))
 [IO.File]::WriteAllText($memory,$m,(New-Object Text.UTF8Encoding($false)))
} catch {
 Copy-Item -LiteralPath $bakE -Destination $exec -Force
 Copy-Item -LiteralPath $bakM -Destination $memory -Force
 throw
}
Write-Host 'GPU replay + allocator diagnostic installed. Restart BottleShip.' -ForegroundColor Green
Write-Host 'Capture tags: MBAACC-EXEC-BEGIN, MBAACC-EXEC-DRAW, MBAACC-EXEC-ANOMALY, MBAACC-HEAP-FALLBACK.'
Write-Host "Rollback: Copy-Item -LiteralPath '$bakE' -Destination '$exec' -Force; Copy-Item -LiteralPath '$bakM' -Destination '$memory' -Force"
