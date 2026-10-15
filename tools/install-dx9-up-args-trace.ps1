# Diagnostic: record one DrawIndexedPrimitiveUP call's arguments.
# Run from the BottleShip checkout. Leaves a backup of the modified source.
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/modules/d3d9/device.ts'
if (-not (Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s = [System.IO.File]::ReadAllText($p)
if ($s.Contains('[MBAACC-DX9-UP-ARGS]')) { Write-Host 'UP argument tracing already installed.'; exit 0 }
$needle = '        const pVertexData = args[7] >>> 0;'
if (-not $s.Contains($needle)) { throw 'Expected DrawIndexedPrimitiveUP implementation not found; file unchanged.' }
$insert = @'
        if (!(globalThis as any).__mbaaccDx9UpArgsSeen) {
            (globalThis as any).__mbaaccDx9UpArgsSeen = true;
            Logger.log(LogCategory.D3D9, '[MBAACC-DX9-UP-ARGS] device=0x' +
                (args[0] >>> 0).toString(16) +
                ' primitiveType=' + (args[1] >>> 0) +
                ' minVertex=' + (args[2] >>> 0) +
                ' numVertices=' + (args[3] >>> 0) +
                ' primitiveCount=' + (args[4] >>> 0) +
                ' indexPtr=0x' + pIndexData.toString(16) +
                ' indexFormat=' + (args[6] >>> 0) +
                ' vertexPtr=0x' + pVertexData.toString(16) +
                ' stride=' + stride);
        }
'@
# Only modify the DrawIndexedPrimitiveUP handler; verify the unique insertion point.
if ($s.Split(@($needle), [System.StringSplitOptions]::None).Length -ne 2) {
    throw 'Unexpected number of insertion points; file unchanged.'
}
$backup = $p + '.mbaacc-before-up-args.bak'
if (-not (Test-Path $backup)) { [System.IO.File]::Copy($p, $backup) }
$s = $s.Replace($needle, $needle + [Environment]::NewLine + $insert)
[System.IO.File]::WriteAllText($p, $s, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'DrawIndexedPrimitiveUP argument trace installed.' -ForegroundColor Green
