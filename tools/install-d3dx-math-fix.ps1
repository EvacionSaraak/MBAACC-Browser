# Install four D3DX math functions needed by MBAACC.
# Run in a local BottleShip checkout. No game binaries are modified.
$ErrorActionPreference = 'Stop'
$mathFile = Join-Path (Get-Location).Path 'src/worker/modules/d3dx9/math.ts'
$apiFile = Join-Path (Get-Location).Path 'src/worker/api/d3dx9.api.ts'
if (-not (Test-Path $mathFile) -or -not (Test-Path $apiFile)) { throw 'Run from the BottleShip checkout directory.' }
$m = [System.IO.File]::ReadAllText($mathFile)
$a = [System.IO.File]::ReadAllText($apiFile)
if ($m.Contains("exports['D3DXVec3TransformArray']") -and $a.Contains('makeFunc("D3DXVec3TransformArray"')) {
    Write-Host 'D3DX math fixes already installed.' -ForegroundColor Green
    exit 0
}
$mathAnchor = "    exports['D3DXMatrixRotationY'] ="
$apiAnchor = '        makeFunc("D3DXMatrixRotationY", 2),'
if (-not $m.Contains($mathAnchor) -or -not $a.Contains($apiAnchor)) {
    throw 'Unexpected BottleShip source version; source files unchanged.'
}
foreach ($name in @('D3DXMatrixRotationX','D3DXMatrixRotationZ','D3DXMatrixScaling','D3DXVec3TransformArray')) {
    if ($m.Contains("exports['" + $name + "']")) { throw ('Unexpected existing implementation: ' + $name) }
}
$mathCode = @'
    // MBAACC: D3DX row-vector, row-major matrix helpers.
    exports['D3DXMatrixRotationX'] = (_ctx, _mem, args) => {
        const out = args[0] >>> 0;
        const angle = u32AsFloat(args[1]);
        const c = Math.cos(angle), s = Math.sin(angle);
        const m = new Float32Array([
            1, 0, 0, 0,
            0, c, s, 0,
            0, -s, c, 0,
            0, 0, 0, 1,
        ]);
        return writeMatrix(out, m) ? out : 0;
    };

    exports['D3DXMatrixRotationZ'] = (_ctx, _mem, args) => {
        const out = args[0] >>> 0;
        const angle = u32AsFloat(args[1]);
        const c = Math.cos(angle), s = Math.sin(angle);
        const m = new Float32Array([
            c, s, 0, 0,
            -s, c, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]);
        return writeMatrix(out, m) ? out : 0;
    };

    exports['D3DXMatrixScaling'] = (_ctx, _mem, args) => {
        const out = args[0] >>> 0;
        const x = u32AsFloat(args[1]), y = u32AsFloat(args[2]), z = u32AsFloat(args[3]);
        const m = new Float32Array([
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        ]);
        return writeMatrix(out, m) ? out : 0;
    };

    // D3DXVec3TransformArray writes D3DXVECTOR4 (16 bytes) for each D3DXVECTOR3.
    // Input and output strides are bytes. Snapshot input first for in-place calls.
    exports['D3DXVec3TransformArray'] = (_ctx, _mem, args) => {
        const out = args[0] >>> 0, outStride = args[1] >>> 0;
        const input = args[2] >>> 0, inputStride = args[3] >>> 0;
        const matrix = readMatrix(args[4] >>> 0);
        const count = args[5] >>> 0;
        if (!out || !input || !matrix) return 0;
        if (!count) return out;
        if (outStride < 16 || inputStride < 12 || count > 1048576) return 0;
        const endOut = out + (count - 1) * outStride + 16;
        const endIn = input + (count - 1) * inputStride + 12;
        if (!Number.isSafeInteger(endOut) || endOut > 0xffffffff ||
            !Number.isSafeInteger(endIn) || endIn > 0xffffffff) return 0;
        const values: Array<[number, number, number]> = [];
        for (let i = 0; i < count; i++) {
            const v = readVec3(input + i * inputStride);
            if (!v) return 0;
            values.push(v);
        }
        for (let i = 0; i < count; i++) {
            const v = values[i];
            const p = out + i * outStride;
            const x = v[0], y = v[1], z = v[2];
            if (!Mem.writeFloat32(p, x * matrix[0] + y * matrix[4] + z * matrix[8] + matrix[12]) ||
                !Mem.writeFloat32(p + 4, x * matrix[1] + y * matrix[5] + z * matrix[9] + matrix[13]) ||
                !Mem.writeFloat32(p + 8, x * matrix[2] + y * matrix[6] + z * matrix[10] + matrix[14]) ||
                !Mem.writeFloat32(p + 12, x * matrix[3] + y * matrix[7] + z * matrix[11] + matrix[15])) return 0;
        }
        return out;
    };

'@
$apiCode = @'
        makeFunc("D3DXMatrixRotationX", 2),
        makeFunc("D3DXMatrixRotationZ", 2),
        makeFunc("D3DXMatrixScaling", 4),
        makeFunc("D3DXVec3TransformArray", 6),
'@
$newMath = $m.Replace($mathAnchor, $mathCode + [Environment]::NewLine + $mathAnchor)
$newApi = $a.Replace($apiAnchor, $apiAnchor + [Environment]::NewLine + $apiCode)
$enc = New-Object System.Text.UTF8Encoding($false)
foreach ($f in @($mathFile, $apiFile)) {
    $b = $f + '.mbaacc-before-math-fix.bak'
    if (-not (Test-Path $b)) { [System.IO.File]::Copy($f, $b) }
}
[System.IO.File]::WriteAllText($mathFile, $newMath, $enc)
[System.IO.File]::WriteAllText($apiFile, $newApi, $enc)
Write-Host 'Installed four D3DX math functions; backups saved.' -ForegroundColor Green
Write-Host 'Restart the BottleShip Vite server to test rendering.' -ForegroundColor Cyan
