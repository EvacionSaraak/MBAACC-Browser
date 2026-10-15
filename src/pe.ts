/** Minimal PE32 header/import parser used for the executable-loading test. */

export interface PeSection {
  name: string;
  virtualAddress: number;
  virtualSize: number;
  rawOffset: number;
  rawSize: number;
}

export interface PeImport {
  dll: string;
  functions: string[];
}

export interface PeInfo {
  machine: number;
  is32Bit: boolean;
  imageBase: number;
  entryPointRva: number;
  sizeOfImage: number;
  subsystem: number;
  sections: PeSection[];
  imports: PeImport[];
}

export class PeError extends Error {}

const IMAGE_FILE_MACHINE_I386 = 0x14c;
const MAX_IMPORT_DESCRIPTORS = 1024;
const MAX_FUNCTIONS_PER_DLL = 8192;
const MAX_NAME_LENGTH = 260;

export function parsePe(buf: ArrayBuffer): PeInfo {
  const dv = new DataView(buf);
  const u8 = new Uint8Array(buf);
  const need = (off: number, len: number, what: string) => {
    if (off < 0 || off + len > buf.byteLength) throw new PeError(`Truncated file while reading ${what}`);
  };

  need(0, 0x40, "DOS header");
  if (dv.getUint16(0, true) !== 0x5a4d) throw new PeError("Missing 'MZ' DOS signature");
  const peOff = dv.getUint32(0x3c, true);
  need(peOff, 24, "PE header");
  if (dv.getUint32(peOff, true) !== 0x4550) throw new PeError("Missing 'PE\\0\\0' signature");

  const machine = dv.getUint16(peOff + 4, true);
  const numSections = dv.getUint16(peOff + 6, true);
  const optSize = dv.getUint16(peOff + 20, true);
  const opt = peOff + 24;
  need(opt, optSize, "optional header");
  const magic = dv.getUint16(opt, true);
  if (magic !== 0x10b) throw new PeError(`Unsupported optional header magic 0x${magic.toString(16)} (PE32 required)`);

  const entryPointRva = dv.getUint32(opt + 16, true);
  const imageBase = dv.getUint32(opt + 28, true);
  const sizeOfImage = dv.getUint32(opt + 56, true);
  const subsystem = dv.getUint16(opt + 68, true);
  const numDirs = dv.getUint32(opt + 92, true);
  const importDirRva = numDirs > 1 ? dv.getUint32(opt + 96 + 8, true) : 0;

  const secStart = opt + optSize;
  need(secStart, numSections * 40, "section table");
  const sections: PeSection[] = [];
  for (let i = 0; i < numSections; i++) {
    const o = secStart + i * 40;
    let name = "";
    for (let j = 0; j < 8 && u8[o + j]; j++) name += String.fromCharCode(u8[o + j]);
    sections.push({
      name,
      virtualSize: dv.getUint32(o + 8, true),
      virtualAddress: dv.getUint32(o + 12, true),
      rawSize: dv.getUint32(o + 16, true),
      rawOffset: dv.getUint32(o + 20, true),
    });
  }

  const rvaToOffset = (rva: number): number => {
    for (const s of sections) {
      const size = Math.max(s.virtualSize, s.rawSize);
      if (rva >= s.virtualAddress && rva < s.virtualAddress + size) return rva - s.virtualAddress + s.rawOffset;
    }
    return rva < sections.reduce((m, s) => Math.min(m, s.virtualAddress), Infinity) ? rva : -1;
  };

  const readStr = (off: number): string => {
    let s = "";
    while (s.length < MAX_NAME_LENGTH && off < buf.byteLength && u8[off]) s += String.fromCharCode(u8[off++]);
    return s;
  };

  const imports: PeImport[] = [];
  if (importDirRva) {
    let d = rvaToOffset(importDirRva);
    if (d < 0) throw new PeError("Import directory RVA is outside all sections");
    for (let n = 0; n < MAX_IMPORT_DESCRIPTORS; n++, d += 20) {
      need(d, 20, "import descriptor");
      const origThunk = dv.getUint32(d, true);
      const nameRva = dv.getUint32(d + 12, true);
      const firstThunk = dv.getUint32(d + 16, true);
      if (!nameRva && !firstThunk) break;
      const nameOff = rvaToOffset(nameRva);
      const dll = nameOff >= 0 ? readStr(nameOff) : `<bad name rva 0x${nameRva.toString(16)}>`;
      const functions: string[] = [];
      let t = rvaToOffset(origThunk || firstThunk);
      while (t >= 0 && t + 4 <= buf.byteLength && functions.length < MAX_FUNCTIONS_PER_DLL) {
        const entry = dv.getUint32(t, true);
        if (!entry) break;
        if (entry >>> 31) functions.push(`#${entry & 0xffff}`);
        else {
          const hn = rvaToOffset(entry);
          functions.push(hn >= 0 ? readStr(hn + 2) : "<bad>");
        }
        t += 4;
      }
      imports.push({ dll, functions });
    }
  }

  return {
    machine,
    is32Bit: machine === IMAGE_FILE_MACHINE_I386,
    imageBase,
    entryPointRva,
    sizeOfImage,
    subsystem,
    sections,
    imports,
  };
}
