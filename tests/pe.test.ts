import { describe, expect, it } from "vitest";
import { parsePe, PeError } from "../src/pe";

/** Builds a tiny synthetic PE32 with one import (kernel32!ExitProcess). */
function buildPe(): ArrayBuffer {
  const b = new ArrayBuffer(0x400);
  const dv = new DataView(b);
  const u8 = new Uint8Array(b);
  const str = (o: number, s: string) => [...s].forEach((c, i) => (u8[o + i] = c.charCodeAt(0)));
  dv.setUint16(0, 0x5a4d, true);
  dv.setUint32(0x3c, 0x80, true);
  dv.setUint32(0x80, 0x4550, true);
  dv.setUint16(0x84, 0x14c, true);
  dv.setUint16(0x86, 1, true);
  dv.setUint16(0x94, 224, true);
  const opt = 0x98;
  dv.setUint16(opt, 0x10b, true);
  dv.setUint32(opt + 28, 0x400000, true);
  dv.setUint32(opt + 56, 0x2000, true);
  dv.setUint32(opt + 92, 16, true);
  dv.setUint32(opt + 96 + 8, 0x1000, true); // import dir RVA
  const sec = opt + 224;
  str(sec, ".idata");
  dv.setUint32(sec + 8, 0x200, true);
  dv.setUint32(sec + 12, 0x1000, true);
  dv.setUint32(sec + 16, 0x200, true);
  dv.setUint32(sec + 20, 0x200, true);
  // raw 0x200 == rva 0x1000
  dv.setUint32(0x200 + 0, 0x1040, true); // OriginalFirstThunk
  dv.setUint32(0x200 + 12, 0x1060, true); // Name
  dv.setUint32(0x200 + 16, 0x1040, true);
  dv.setUint32(0x240, 0x1070, true); // thunk
  str(0x260, "kernel32.dll");
  str(0x272, "ExitProcess");
  return b;
}

describe("parsePe", () => {
  it("parses imports", () => {
    const pe = parsePe(buildPe());
    expect(pe.is32Bit).toBe(true);
    expect(pe.imageBase).toBe(0x400000);
    expect(pe.imports).toEqual([{ dll: "kernel32.dll", functions: ["ExitProcess"] }]);
  });
  it("rejects non-PE data", () => {
    expect(() => parsePe(new ArrayBuffer(128))).toThrow(PeError);
  });
});

describe("parsePe errors", () => {
  it("rejects truncated files", () => {
    expect(() => parsePe(new ArrayBuffer(8))).toThrow(PeError);
  });
  it("rejects PE32+ magic", () => {
    const b = buildPe();
    new DataView(b).setUint16(0x98, 0x20b, true);
    expect(() => parsePe(b)).toThrow(/PE32 required/);
  });
  it("rejects import dir outside sections", () => {
    const b = buildPe();
    new DataView(b).setUint32(0x98 + 96 + 8, 0x9000, true);
    expect(() => parsePe(b)).toThrow(PeError);
  });
});
