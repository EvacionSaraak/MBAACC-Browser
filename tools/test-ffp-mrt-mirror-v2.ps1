# Corrected MRI mirror experiment (the FFP WGSL is emitted before buildShader).
$ErrorActionPreference='Stop'
$p=Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-device.ts'
if (!(Test-Path $p)) {throw 'Run from BottleShip checkout.'}
$s=[IO.File]::ReadAllText($p)
if ($s.Contains('MBAACC-MRT-MIRROR-TEST')) {Write-Host 'MRT mirror experiment already installed.';exit 0}
$old='fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {'
$replacement=@'
struct MbaaccMrtColor {
    @location(0) color0: vec4<f32>,
    @location(1) color1: vec4<f32>,
    @location(2) color2: vec4<f32>,
};
fn fs_main(input: VertexOutput) -> MbaaccMrtColor {
'@
$shaderPos=$s.IndexOf($old)
$shaderEnd=$s.IndexOf('function buildShader(', $shaderPos)
if ($shaderPos -lt 0 -or $shaderEnd -lt $shaderPos -or $shaderEnd-$shaderPos -gt 3000) {throw 'Fixed-function fragment shader not found; no changes made.'}
$piece=$s.Substring($shaderPos,$shaderEnd-$shaderPos)
if (([regex]::Matches($s,[regex]::Escape($old))).Count -ne 1 -or ([regex]::Matches($piece,'return _c;')).Count -ne 1) {throw 'Unexpected shader source; no changes made.'}
$mask='colorTargets[i] = { ...colorTargets[i]!, writeMask: 0 };'
if (([regex]::Matches($s,[regex]::Escape($mask))).Count -ne 1) {throw 'FFP MRT fix was not found; no changes made.'}
$piece=$piece.Replace($old,$replacement.TrimEnd()).Replace('    return _c;', '    return MbaaccMrtColor(_c, _c, _c); // MBAACC-MRT-MIRROR-TEST')
$newSource=$s.Substring(0,$shaderPos)+$piece+$s.Substring($shaderEnd)
$newSource=$newSource.Replace($mask,'colorTargets[i] = { ...colorTargets[i]!, writeMask: 0xF }; // MBAACC-MRT-MIRROR-TEST')
$backup=$p+'.mbaacc-before-mrt-mirror-test.bak'
if (!(Test-Path $backup)) {[IO.File]::Copy($p,$backup)}
[IO.File]::WriteAllText($p,$newSource,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Experimental MRT mirror installed. Restart BottleShip.' -ForegroundColor Green
