import type { PeInfo } from "./pe";

export interface CompatibilityReport {
  schemaVersion: 1;
  analysis: "static-pe32-only";
  warning: string;
  executable: {
    machine: string;
    is32Bit: boolean;
    imageBase: string;
    entryPointRva: string;
    sizeOfImage: number;
    subsystem: number;
    sections: Array<{ name: string; virtualAddress: string; virtualSize: number }>;
    imports: Array<{ dll: string; functions: string[] }>;
  };
}

const hex = (n: number): string => `0x${n.toString(16)}`;

/** Exports metadata only. Never exports the executable's bytes or local file paths. */
export function makeCompatibilityReport(pe: PeInfo): CompatibilityReport {
  return {
    schemaVersion: 1,
    analysis: "static-pe32-only",
    warning: "No game code was executed. Runtime compatibility is untested.",
    executable: {
      machine: hex(pe.machine),
      is32Bit: pe.is32Bit,
      imageBase: hex(pe.imageBase),
      entryPointRva: hex(pe.entryPointRva),
      sizeOfImage: pe.sizeOfImage,
      subsystem: pe.subsystem,
      sections: pe.sections.map(s => ({
        name: s.name,
        virtualAddress: hex(s.virtualAddress),
        virtualSize: s.virtualSize,
      })),
      imports: pe.imports.map(i => ({ dll: i.dll, functions: [...i.functions] })),
    },
  };
}
