# Add D3DXMatrixRotationYawPitchRoll, preserving existing BottleShip patches.
$ErrorActionPreference='Stop'
$p='src/worker/modules/d3dx9/math.ts'
$a='src/worker/api/d3dx9.api.ts'
if (!(Test-Path $p) -or !(Test-Path $a)) { throw 'Run from the BottleShip checkout.' }
$s=[IO.File]::ReadAllText((Resolve-Path $p))
$d=[IO.File]::ReadAllText((Resolve-Path $a))
$mark='MBAACC-YAW-PITCH-ROLL'
if ($s.Contains($mark)) { Write-Host 'Yaw/pitch/roll fix already present.'; exit 0 }
$anchor="    exports['D3DXMatrixRotationY'] = (_ctx, _mem, args) => {"
$apiAnchor='        makeFunc("D3DXMatrixRotationY", 2),'
if (!$s.Contains($anchor) -or !$d.Contains($apiAnchor)) { throw 'Unexpected BottleShip version; nothing changed.' }
$insert=@'
    // MBAACC-YAW-PITCH-ROLL: D3DX row-vector convention, Rz(roll)*Rx(pitch)*Ry(yaw).
    exports['D3DXMatrixRotationYawPitchRoll'] = (_ctx, _mem, args) => {
        const out = args[0] >>> 0;
        const yaw = u32AsFloat(args[1]);
        const pitch = u32AsFloat(args[2]);
        const roll = u32AsFloat(args[3]);
        const cy = Math.cos(yaw), sy = Math.sin(yaw);
        const cp = Math.cos(pitch), sp = Math.sin(pitch);
        const cr = Math.cos(roll), sr = Math.sin(roll);
        const rz = new Float32Array([
            cr, sr, 0, 0,
            -sr, cr, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]);
        const rx = new Float32Array([
            1, 0, 0, 0,
            0, cp, sp, 0,
            0, -sp, cp, 0,
            0, 0, 0, 1,
        ]);
        const ry = new Float32Array([
            cy, 0, -sy, 0,
            0, 1, 0, 0,
            sy, 0, cy, 0,
            0, 0, 0, 1,
        ]);
        return writeMatrix(out, multiplyMatrices(multiplyMatrices(rz, rx), ry)) ? out : 0;
    };

'@
$s=$s.Replace($anchor,$insert+$anchor)
$d=$d.Replace($apiAnchor,$apiAnchor+[Environment]::NewLine+'        makeFunc("D3DXMatrixRotationYawPitchRoll", 4),')
$enc=New-Object System.Text.UTF8Encoding($false)
foreach($x in @($p,$a)){ $bk="$x.mbaacc-before-ypr.bak"; if(!(Test-Path $bk)){[IO.File]::Copy((Resolve-Path $x),[IO.Path]::GetFullPath($bk))} }
[IO.File]::WriteAllText((Resolve-Path $p),$s,$enc)
[IO.File]::WriteAllText((Resolve-Path $a),$d,$enc)
Write-Host 'D3DX yaw/pitch/roll patch installed. Restart BottleShip.' -ForegroundColor Green
