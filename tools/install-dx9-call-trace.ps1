# MBAACC DX9 call-path trace. Windows PowerShell 5.1 compatible (ASCII).
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$deviceRel = 'src/worker/modules/d3d9/device.ts'
$fastRel = 'src/worker/modules/d3d9/fast-path.ts'
$devicePath = Join-Path $root $deviceRel
$fastPath = Join-Path $root $fastRel
if (-not (Test-Path $devicePath) -or -not (Test-Path $fastPath)) {
    throw 'Run this script from the BottleShip checkout containing src/worker/modules/d3d9.'
}
$helper = @'
const mbaaccDx9TraceSeen = new Set<string>();
function mbaaccDx9Trace(name: string): void {
    if (mbaaccDx9TraceSeen.has(name)) return;
    mbaaccDx9TraceSeen.add(name);
    Logger.log(LogCategory.D3D9, '[MBAACC-DX9-TRACE] ' + name);
}
'@
function Add-Trace([string]$text, [string]$needle, [string]$label) {
    if (-not $text.Contains($needle)) { throw ('Cannot locate hook: ' + $label) }
    $replacement = $needle + [Environment]::NewLine + "        mbaaccDx9Trace('$label');"
    return $text.Replace($needle, $replacement)
}
function Save-Source([string]$path, [string]$newText) {
    $backup = $path + '.mbaacc-before-trace.bak'
    if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $path -Destination $backup }
    [System.IO.File]::WriteAllText($path, $newText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ('Patched: ' + $path) -ForegroundColor Green
}
$source = [System.IO.File]::ReadAllText($devicePath)
if ($source.Contains('[MBAACC-DX9-TRACE]')) {
    Write-Host 'Normal DX9 handlers already instrumented.'
} else {
    $anchor = 'export function createDeviceExports(): Record<string, ThunkImplementation> {'
    if (-not $source.Contains($anchor)) { throw 'Unsupported BottleShip version: device exports missing' }
    $source = $source.Replace($anchor, $helper + [Environment]::NewLine + $anchor)
    foreach ($name in @('BeginScene','EndScene','Clear','Present','DrawPrimitive','DrawIndexedPrimitive','DrawPrimitiveUP','DrawIndexedPrimitiveUP')) {
        $needle = "exports['IDirect3DDevice9_" + $name + "'] = "
        $start = $source.IndexOf($needle)
        if ($start -lt 0) { throw ('Missing normal DX9 handler: ' + $name) }
        $body = $source.IndexOf('=> {', $start)
        if ($body -lt 0 -or ($body - $start) -gt 160) { throw ('Missing body of ' + $name) }
        $point = $body + 4
        $source = $source.Insert($point, [Environment]::NewLine + "        mbaaccDx9Trace('$name / normal');")
    }
    Save-Source $devicePath $source
}
$source = [System.IO.File]::ReadAllText($fastPath)
if ($source.Contains('[MBAACC-DX9-TRACE]')) {
    Write-Host 'Fast DX9 handlers already instrumented.'
} else {
    $anchor = 'export function registerFastPathD3D9Functions(dispatcher: HleDispatcher): void {'
    if (-not $source.Contains($anchor)) { throw 'Unsupported BottleShip version: fast path registration missing' }
    $source = $source.Replace($anchor, $helper + [Environment]::NewLine + $anchor)
    foreach ($name in @('DrawPrimitive','DrawIndexedPrimitive','DrawPrimitiveUP')) {
        $needle = "dispatcher.registerFastPath('d3d9', 'IDirect3DDevice9_" + $name + "',"
        $start = $source.IndexOf($needle)
        if ($start -lt 0) { throw ('Missing fast DX9 handler: ' + $name) }
        $body = $source.IndexOf('=> {', $start)
        if ($body -lt 0 -or ($body - $start) -gt 180) { throw ('Missing fast handler body: ' + $name) }
        $source = $source.Insert($body + 4, [Environment]::NewLine + "        mbaaccDx9Trace('$name / fast');")
    }
    foreach ($name in @('DrawPrimitive','DrawIndexedPrimitive')) {
        $count = if ($name -eq 'DrawPrimitive') { '4' } else { '7' }
        $needle = "dispatcher.registerWriteBufferFunction('d3d9', 'IDirect3DDevice9_" + $name + "', " + $count + ","
        $start = $source.IndexOf($needle)
        if ($start -lt 0) { throw ('Missing buffered DX9 handler: ' + $name) }
        $body = $source.IndexOf('=> {', $start)
        if ($body -lt 0 -or ($body - $start) -gt 210) { throw ('Missing buffered handler body: ' + $name) }
        $source = $source.Insert($body + 4, [Environment]::NewLine + "                mbaaccDx9Trace('$name / buffer');")
    }
    Save-Source $fastPath $source
}
Write-Host 'DX9 tracing installed. Restart Vite and check Debug Logs for [MBAACC-DX9-TRACE].' -ForegroundColor Cyan
