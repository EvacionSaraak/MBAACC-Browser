# MBAACC experimental MRT output test.
# Fixed-function shader emits one color; mirror it to slots 1/2 to test whether
# unwritten MRT attachments cause flashing sprites. Reversible A/B test.
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (-not (Test-Path $p)) { throw 'Run from the BottleShip checkout.' }
$s = [IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-MRT-MIRROR-TEST')) { Write-Host 'MRT mirror test already installed.'; exit 0 }
$shaderStart = $s.IndexOf('function buildShader(')
$shaderEnd = $s.IndexOf('function buildShaderFromDecl(', $shaderStart)
if ($shaderStart -lt 0 -or $shaderEnd -le $shaderStart) {throw 'Fixed-function shader generator not found; no changes made.'}
$piece = $s.Substring($shaderStart,$shaderEnd-$shaderStart)
$old = 'fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {'
$new = @'
struct MbaaccMrtColor {
    @location(0) color0: vec4<f32>,
    @location(1) color1: vec4<f32>,
    @location(2) color2: vec4<f32>,
};
fn fs_main(input: VertexOutput) -> MbaaccMrtColor {
'@
if (([regex]::Matches($piece,[regex]::Escape($old))).Count -ne 1) {throw 'Expected one FFP fragment function; no changes made.'}
if (([regex]::Matches($piece,'return _c;')).Count -ne 1) {throw 'Expected one FFP fragment return; no changes made.'}
$piece=$piece.Replace($old,$new.TrimEnd())
$piece=$piece.Replace('    return _c;', '    return MbaaccMrtColor(_c, _c, _c); // MBAACC-MRT-MIRROR-TEST')
$s=$s.Substring(0,$shaderStart)+$piece+$s.Substring($shaderEnd)
# Earlier FFP pipeline fix zeroed secondary attachment masks; restore them for this experiment.
$mask='colorTargets[i] = { ...colorTargets[i]!, writeMask: 0 };'
if (([regex]::Matches($s,[regex]::Escape($mask))).Count -ne 1) {throw 'Earlier MRT pipeline fix not found; no changes made.'}
$s=$s.Replace($mask,'colorTargets[i] = { ...colorTargets[i]!, writeMask: 0xF }; // MBAACC-MRT-MIRROR-TEST')
$bak=$p+'.mbaacc-before-mrt-mirror-test.bak'
if (!(Test-Path $bak)) {[IO.File]::Copy($p,$bak)}
[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Experimental FFP MRT mirror installed. Restart BottleShip.' -ForegroundColor Green
Write-Host 'Rollback: Copy-Item -Force .\src\worker\backends\webgpu\d3d9\d3d9-device.ts.mbaacc-before-mrt-mirror-test.bak .\src\worker\backends\webgpu\d3d9\d3d9-device.ts'
