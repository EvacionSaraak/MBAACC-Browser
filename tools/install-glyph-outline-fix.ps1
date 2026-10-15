# MBAACC GetGlyphOutlineA: metrics + aligned monochrome glyph bitmap.
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
$p=Join-Path $root 'src/worker/modules/gdi32/painting.ts'
$a=Join-Path $root 'src/worker/api/gdi32.api.ts'
if (!(Test-Path $p) -or !(Test-Path $a)) { throw 'Run this from the BottleShip checkout.' }
$s=[IO.File]::ReadAllText($p); $api=[IO.File]::ReadAllText($a)
if ($s.Contains('MBAACC-GLYPH-OUTLINE-FIX')) { Write-Host 'Glyph fix already installed.'; exit 0 }
$needle="    exports['GetTextMetricsA'] = (ctx, mem, args): number => {"
if (!$s.Contains($needle) -or !$api.Contains('makeFunc("GetTextMetricsA", 2),')) { throw 'Source mismatch. No changes made.' }
$patch=@'
    // MBAACC-GLYPH-OUTLINE-FIX: support the basic Win32 GGO_METRICS / GGO_BITMAP contract.
    exports['GetGlyphOutlineA'] = (ctx, mem, args): number => {
        const hdc = args[0] >>> 0;
        const code = args[1] >>> 0;
        const format = args[2] >>> 0;
        const gm = args[3] >>> 0;
        const cbBuffer = args[4] >>> 0;
        const out = args[5] >>> 0;
        const mode = format & 0x7f;
        if (mode !== 0 && mode !== 1) return 0xffffffff; // GDI_ERROR
        const gdi = System.getInstance().gdiContext;
        const context = gdi.getMeasureContext(hdc);
        const char = String.fromCharCode(code & 0xffff);
        let advance = 8, ascent = 12, descent = 4, left = 0, right = 8;
        if (context) {
            try {
                const m = context.measureText(char);
                advance = Math.max(1, Math.ceil(m.width || 8));
                ascent = Math.max(1, Math.ceil(m.actualBoundingBoxAscent || m.fontBoundingBoxAscent || 12));
                descent = Math.max(0, Math.ceil(m.actualBoundingBoxDescent || 0));
                left = Math.max(0, Math.ceil(m.actualBoundingBoxLeft || 0));
                right = Math.max(1, Math.ceil(m.actualBoundingBoxRight || advance));
            } catch (_) { /* stable fallback font metrics */ }
        }
        const width = Math.max(1, Math.min(4096, left + right));
        const height = Math.max(1, Math.min(4096, ascent + descent));
        if (gm && gm + 16 <= mem.length) {
            const v = new DataView(mem.buffer, mem.byteOffset, mem.byteLength);
            v.setUint32(gm, width, true);
            v.setUint32(gm + 4, height, true);
            v.setInt16(gm + 8, -left, true);
            v.setInt16(gm + 10, ascent, true);
            v.setInt16(gm + 12, advance, true);
            v.setInt16(gm + 14, 0, true);
        }
        if (mode === 0) return 0; // GGO_METRICS
        const pitch = ((width + 31) >>> 5) * 4;
        const bytes = pitch * height;
        if (out && cbBuffer >= bytes && out + bytes <= mem.length) {
            mem.fill(0, out, out + bytes);
            // Rasterize via the selected GDI font, matching GGO_BITMAP's 1bpp MSB-first rows.
            if (context) {
                try {
                    const canvas = new OffscreenCanvas(width, height);
                    const c = canvas.getContext('2d', { willReadFrequently: true });
                    if (c) {
                        c.font = context.font;
                        c.textBaseline = 'alphabetic';
                        c.fillStyle = '#ffffff';
                        c.fillText(char, left, ascent);
                        const rgba = c.getImageData(0, 0, width, height).data;
                        for (let y = 0; y < height; y++)
                            for (let x = 0; x < width; x++)
                                if (rgba[(y * width + x) * 4 + 3] >= 128)
                                    mem[out + y * pitch + (x >>> 3)] |= 0x80 >>> (x & 7);
                    }
                } catch (_) { /* zero bitmap is still a valid buffer */ }
            }
        }
        return bytes >>> 0;
    };

'@
$s=$s.Replace($needle,$patch+$needle)
$api=$api.Replace('makeFunc("GetTextMetricsA", 2),','makeFunc("GetGlyphOutlineA", 7),'+[Environment]::NewLine+'        makeFunc("GetTextMetricsA", 2),')
[IO.File]::Copy($p,$p+'.mbaacc-before-glyph-outline.bak',$true)
[IO.File]::Copy($a,$a+'.mbaacc-before-glyph-outline.bak',$true)
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($p,$s,$utf8)
[IO.File]::WriteAllText($a,$api,$utf8)
Write-Host 'GetGlyphOutlineA implemented. Restart BottleShip.' -ForegroundColor Green
