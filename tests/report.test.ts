import { describe, expect, it } from "vitest";
import { makeCompatibilityReport } from "../src/report";
import type { PeInfo } from "../src/pe";

describe("compatibility report", () => {
  it("exports static metadata without file paths or executable bytes", () => {
    const pe: PeInfo = {
      machine: 0x14c, is32Bit: true, imageBase: 0x400000,
      entryPointRva: 0x1000, sizeOfImage: 8192, subsystem: 2,
      sections: [{ name: ".text", virtualAddress: 4096, virtualSize: 2048, rawOffset: 512, rawSize: 2048 }],
      imports: [{ dll: "kernel32.dll", functions: ["ExitProcess"] }],
    };
    const output = makeCompatibilityReport(pe);
    expect(output.analysis).toBe("static-pe32-only");
    expect(output.executable.imports[0].functions).toEqual(["ExitProcess"]);
    expect(JSON.stringify(output)).not.toContain("rawOffset");
    expect(JSON.stringify(output)).not.toContain("C:\\");
  });
});
