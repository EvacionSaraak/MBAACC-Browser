# MBAACC high-volume draw handoff recorder; diagnostic only.
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-command-recorder.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-RECORDER-HANDOFF-V1')) {Write-Host 'Recorder handoff probe already installed.'; exit 0}
$import='import { RenderFrame, RenderFramePool, RenderCommandType, type ArenaDrawBinding } from "../render-frame";'
if (([regex]::Matches($s,[regex]::Escape($import))).Count -ne 1) {throw 'Recorder import mismatch; no changes made.'}
$anchor='    recordDraw(cmd: DrawCommand): void {'
if (([regex]::Matches($s,[regex]::Escape($anchor))).Count -ne 1) {throw 'Draw recording entry mismatch; no changes made.'}
$code=@'
        // MBAACC-RECORDER-HANDOFF-V1: inspect the exact command at record time.
        // Browser Console is intentionally verbose; this never modifies GPU state.
        {
            const g = globalThis as typeof globalThis & { __mbaaccRecorderCount?: number; __mbaaccRecorderOff?: boolean };
            const seq = (g.__mbaaccRecorderCount = (g.__mbaaccRecorderCount ?? 0) + 1);
            if (!g.__mbaaccRecorderOff && (seq <= 50000 || seq % 16 === 0)) {
                const bindings: string[] = [];
                if ("streams" in cmd) {
                    for (let i = 0; i < cmd.streams.count; i++) {
                        const b = cmd.streams.at(i);
                        bindings.push(b.slot + ':' + b.offset + '+' + b.size
                            + '/gpuSize=' + b.buffer.size + '/usage=' + b.buffer.usage
                            + '/label=' + b.buffer.label);
                    }
                } else {
                    bindings.push('0:' + cmd.bufferOffset + '+' + cmd.bufferSize
                        + '/gpuSize=' + cmd.gpuBuffer.size + '/usage=' + cmd.gpuBuffer.usage);
                }
                const ffp = cmd.ffpStateIndex === undefined ? null : this.frame.ffpStates[cmd.ffpStateIndex];
                const ps = cmd.bindStateIndex === undefined ? null : this.frame.programmableStates[cmd.bindStateIndex];
                const data = {
                    seq, pipelineId: cmd.pipelineId,
                    ffpIndex: cmd.ffpStateIndex ?? null, programIndex: cmd.bindStateIndex ?? null,
                    vertexCount: cmd.vertexCount, startVertex: cmd.startVertex,
                    ffpStageCount: ffp?.stageCount ?? null,
                    ffpTextures: ffp ? Array.from({length: Math.min(8, ffp.stageCount)}, (_,i) =>
                        Boolean(ffp.textures[i])) : null,
                    ffpSamplers: ffp ? Array.from({length: Math.min(8, ffp.stageCount)}, (_,i) =>
                        Boolean(ffp.samplers[i])) : null,
                    programmableCaptured: Boolean(ps),
                    bindings, viewport: cmd.viewport, scissor: cmd.scissorRect,
                    stencil: cmd.stencilReference, blendConstant: cmd.blendConstant,
                    frameCommands: this.frame.commandCount
                };
                Logger.log(LogCategory.D3D9, '[MBAACC-RECORDER] ' + JSON.stringify(data));
            }
        }
'@
$s=$s.Replace($import,$import+[Environment]::NewLine+'import { Logger, LogCategory } from "../../../core/logger";')
$s=$s.Replace($anchor,$anchor+[Environment]::NewLine+$code.TrimEnd())
$bak=$p+'.mbaacc-before-recorder-handoff.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Verbose recorder diagnostic installed. Restart BottleShip.' -ForegroundColor Green
Write-Host 'Disable while game runs: globalThis.__mbaaccRecorderOff = true (worker context).'
Write-Host "Rollback: Copy-Item -LiteralPath '$bak' -Destination '$p' -Force"
