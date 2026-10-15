# MBAACC: retain first WebGPU pipeline/shader error in recent debug logs.
# Requires Windows PowerShell 5.1; run from BottleShip checkout.
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (-not (Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s = [System.IO.File]::ReadAllText($p)
$marker = '[MBAACC-FIRST-GPU-ERROR]'
if ($s.Contains($marker)) { Write-Host 'GPU error retention already installed.'; exit 0 }
$pipelineAnchor = '            const detail = error.message || String(error);'
$shaderAnchor = '            const detail = errors.map((message) => message.message).join("; ");'
$presentAnchor = '    async present(): Promise<number> {' + [Environment]::NewLine + '        d3d9PerfInc("present");'
if (([regex]::Matches($s, [regex]::Escape($pipelineAnchor))).Count -ne 1 -or
    ([regex]::Matches($s, [regex]::Escape($shaderAnchor))).Count -ne 1 -or
    -not $s.Contains($presentAnchor)) { throw 'Source version mismatch; nothing changed.' }
$storePipeline = @'
            const mbaaccGlobal = globalThis as typeof globalThis & { __mbaaccFirstGpuError?: string };
            if (!mbaaccGlobal.__mbaaccFirstGpuError) {
                mbaaccGlobal.__mbaaccFirstGpuError = 'pipeline site=' + site + ' detail=' + detail;
                Logger.error(LogCategory.D3D9, '[MBAACC-FIRST-GPU-ERROR] ' + mbaaccGlobal.__mbaaccFirstGpuError);
                console.error('[MBAACC-FIRST-GPU-ERROR] ' + mbaaccGlobal.__mbaaccFirstGpuError);
            }
'@
$storeShader = @'
            const mbaaccGlobal = globalThis as typeof globalThis & { __mbaaccFirstGpuError?: string };
            if (!mbaaccGlobal.__mbaaccFirstGpuError) {
                mbaaccGlobal.__mbaaccFirstGpuError = 'shader site=' + site + ' detail=' + detail;
                Logger.error(LogCategory.D3D9, '[MBAACC-FIRST-GPU-ERROR] ' + mbaaccGlobal.__mbaaccFirstGpuError);
                console.error('[MBAACC-FIRST-GPU-ERROR] ' + mbaaccGlobal.__mbaaccFirstGpuError);
            }
'@
$presentExtra = @'
        const mbaaccGlobal = globalThis as typeof globalThis & { __mbaaccFirstGpuError?: string; __mbaaccGpuPresentCount?: number };
        mbaaccGlobal.__mbaaccGpuPresentCount = (mbaaccGlobal.__mbaaccGpuPresentCount ?? 0) + 1;
        if (mbaaccGlobal.__mbaaccFirstGpuError && mbaaccGlobal.__mbaaccGpuPresentCount % 120 === 0) {
            Logger.error(LogCategory.D3D9, '[MBAACC-FIRST-GPU-ERROR] ' + mbaaccGlobal.__mbaaccFirstGpuError);
        }
'@
$s = $s.Replace($pipelineAnchor, $pipelineAnchor + [Environment]::NewLine + $storePipeline.TrimEnd())
$s = $s.Replace($shaderAnchor, $shaderAnchor + [Environment]::NewLine + $storeShader.TrimEnd())
$s = $s.Replace($presentAnchor, $presentAnchor + [Environment]::NewLine + $presentExtra.TrimEnd())
$b = $p + '.mbaacc-before-gpu-error-retention.bak'
if (-not (Test-Path $b)) { [System.IO.File]::Copy($p, $b) }
[System.IO.File]::WriteAllText($p, $s, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'GPU validation diagnostic installed. Restart BottleShip.' -ForegroundColor Green
