# Apply a bounded DX9 call-path probe to a local BottleShip checkout.
# Run from the BottleShip directory; no git, bun, or game files are touched.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$paths = @('src/worker/modules/d3d9/device.ts', 'src/worker/modules/d3d9/fast-path.ts')
foreach ($p in $paths) {
  if (-not (Test-Path (Join-Path $root $p))) { throw "Missing $p — run from your BottleShip checkout." }
}
function Install-Probe([string]$relative, [string]$entry, [string[]]$names, [bool]$fast) {
  $file = Join-Path $root $relative
  $source = [System.IO.File]::ReadAllText($file)
  if ($source.Contains('MBAACC-DX9-TRACE')) { Write-Host "Already patched: $relative"; return }
  $anchor = "export function $entry"
  if (-not $source.Contains($anchor)) { throw "Cannot find $anchor in $relative" }
  $helper = @'
const mbaaccDx9TraceSeen = new Set<string>();
function mbaaccDx9Trace(name: string): void {
    if (mbaaccDx9TraceSeen.has(name)) return;
    mbaaccDx9TraceSeen.add(name);
    Logger.log(LogCategory.D3D9, `[MBAACC-DX9-TRACE] ${name}`);
}
'@
  # Avoid PowerShell interpolating TypeScript backticks; use a simple string.
  $helper = @'
const mbaaccDx9TraceSeen = new Set<string>();
function mbaaccDx9Trace(name: string): void {
    if (mbaaccDx9TraceSeen.has(name)) return;
    mbaaccDx9TraceSeen.add(name);
    Logger.log(LogCategory.D3D9, '[MBAACC-DX9-TRACE] ' + name);
}
'@
  $updated = $source.Replace($anchor, $helper + [Environment]::NewLine + $anchor)
  foreach ($name in $names) {
    if ($fast) {
      $pattern = "(dispatcher\.registerFastPath\('d3d9', 'IDirect3DDevice9_$name', \(esp: number, view: DataView\): number => \{)"
      $tag = "$name / fastpath"
    } else {
      $pattern = "(exports\['IDirect3DDevice9_$name'\] = \([^\r\n]*=> \{)"
      $tag = "$name / normal"
    }
    $re = [regex]::new($pattern)
    if (-not $re.IsMatch($updated)) { throw "Could not instrument $name in $relative; nothing saved." }
    $updated = $re.Replace($updated, ('$1' + [Environment]::NewLine + "        mbaaccDx9Trace('$tag');"), 1)
  }
  if ($fast) {
    foreach ($name in @('DrawPrimitive','DrawIndexedPrimitive')) {
      $argCount = if ($name -eq 'DrawPrimitive') { 4 } else { 7 }
      $pattern = "(dispatcher\.registerWriteBufferFunction\('d3d9', 'IDirect3DDevice9_$name', $argCount,\s*\(_mem8: Uint8Array, mem32: Uint32Array, ptr: number\) => \{)"
      $re = [regex]::new($pattern)
      if (-not $re.IsMatch($updated)) { throw "Could not instrument WBUF $name; nothing saved." }
      $updated = $re.Replace($updated, ('$1' + [Environment]::NewLine + "                mbaaccDx9Trace('$name / WBUF');"), 1)
    }
  }
  [System.IO.File]::Copy($file, "$file.mbaacc-before-trace.bak", $true)
  [System.IO.File]::WriteAllText($file, $updated, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Patched $relative (backup saved)" -ForegroundColor Green
}
Install-Probe $paths[0] 'createDeviceExports(): Record<string, ThunkImplementation> {' @('BeginScene','EndScene','Clear','Present','DrawPrimitive','DrawIndexedPrimitive','DrawPrimitiveUP','DrawIndexedPrimitiveUP') $false
Install-Probe $paths[1] 'registerFastPathD3D9Functions(dispatcher: HleDispatcher): void {' @('DrawPrimitive','DrawIndexedPrimitive','DrawPrimitiveUP') $true
Write-Host 'DX9 probe installed. Restart the Vite server; then launch MBAACC and inspect Debug Logs > Load Recent for [MBAACC-DX9-TRACE].' -ForegroundColor Cyan
