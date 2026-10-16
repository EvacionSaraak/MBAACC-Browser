# MBAACC A/B fixed-function bind-group cache and uniform dedup test.
# PowerShell 5.1. This intentionally changes rendering code for testing.
param(
    [ValidateSet('Both','BindGroups','Uniforms','Restore')]
    [string]$Mode = 'Both'
)
$ErrorActionPreference = 'Stop'
$p = Join-Path (Get-Location).Path 'src/worker/backends/webgpu/d3d9/d3d9-backend-executor.ts'
if (!(Test-Path -LiteralPath $p)) { throw "Missing $p; run in BottleShip checkout." }
$backup = $p + '.mbaacc-before-ffp-cache-ab.bak'
$current = [IO.File]::ReadAllText($p)
$markA = 'MBAACC-FFP-A-BINDGROUPS-20261016'
$markB = 'MBAACC-FFP-A-UNIFORMS-20261016'
if ($Mode -eq 'Restore') {
    if (!(Test-Path -LiteralPath $backup)) { throw 'No A/B backup found. Nothing changed.' }
    [IO.File]::Copy($backup, $p, $true)
    Write-Host 'Restored pre-A/B renderer. Restart BottleShip.' -ForegroundColor Green
    exit 0
}
if (Test-Path -LiteralPath $backup) {
    $s = [IO.File]::ReadAllText($backup)
    if ($s.Contains($markA) -or $s.Contains($markB)) { throw 'Backup contains A/B modifications. Refusing to apply.' }
} else {
    if ($current.Contains($markA) -or $current.Contains($markB)) { throw 'Existing A/B patch without backup. Refusing to overwrite.' }
    $s = $current
}
if ($Mode -eq 'Both' -or $Mode -eq 'BindGroups') {
    $start = $s.IndexOf('    private acquireFfpAutoBindGroup(')
    $finish = $s.IndexOf('    /** Entry object', $start)
    if ($start -lt 0 -or $finish -le $start) { throw 'FFP bind-group routine not found. Nothing changed.' }
    $section = $s.Substring($start, $finish-$start)
    $needle = '        if (bucket !== undefined) {'
    if (([regex]::Matches($section,[regex]::Escape($needle))).Count -ne 1) { throw 'FFP cache lookup differs; no files modified.' }
    $section = $section.Replace($needle, '        if (false && bucket !== undefined) { // ' + $markA)
    $s = $s.Substring(0,$start)+$section+$s.Substring($finish)
}
if ($Mode -eq 'Both' -or $Mode -eq 'Uniforms') {
    $start = $s.IndexOf('    private sameAsLastBlock(')
    $finish = $s.IndexOf('    private rememberBlock(', $start)
    if ($start -lt 0 -or $finish -le $start) { throw 'FFP uniform memo routine not found. Nothing changed.' }
    $section = $s.Substring($start,$finish-$start)
    $needle = '        return true;'
    if (([regex]::Matches($section,[regex]::Escape($needle))).Count -ne 1) { throw 'FFP uniform dedup differs; no files modified.' }
    $section = $section.Replace($needle,'        return false; // '+$markB)
    $s = $s.Substring(0,$start)+$section+$s.Substring($finish)
}
if (!(Test-Path -LiteralPath $backup)) { [IO.File]::Copy($p, $backup) }
[IO.File]::WriteAllText($p, $s, (New-Object Text.UTF8Encoding($false)))
Write-Host "Installed fixed-function A/B mode: $Mode" -ForegroundColor Green
Write-Host "Original version: $backup"
Write-Host 'Restart BottleShip and check whether character flickering changes.'
Write-Host ('Restore with: powershell -NoProfile -ExecutionPolicy Bypass -File ' + $PSCommandPath + ' -Mode Restore')
