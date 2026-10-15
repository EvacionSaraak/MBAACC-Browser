import type { PeInfo } from "./pe";
import type { Logger } from "./logger";

/** DLLs that need high-level emulation (HLE) by a runtime such as BottleShip. */
const HLE_NOTES: Record<string, string> = {
  "d3d9.dll": "Direct3D 9 graphics (needs D3D9 -> WebGPU translation)",
  "d3d8.dll": "Direct3D 8 graphics",
  "ddraw.dll": "DirectDraw graphics",
  "dsound.dll": "DirectSound audio",
  "dinput8.dll": "DirectInput 8 input",
  "dinput.dll": "DirectInput input",
  "winmm.dll": "Windows multimedia (timers, waveOut, joystick)",
  "ws2_32.dll": "Winsock networking (online play; out of scope for now)",
  "wsock32.dll": "Winsock networking (online play; out of scope for now)",
};

/** Files expected in a MBAACC install directory (names only, no content is bundled). */
export const EXPECTED_FILES = ["MBAA.exe"];

/** Logs a static analysis of the executable. This does NOT execute it. */
export function reportCompatibility(pe: PeInfo, log: Logger): void {
  log.info(`PE machine=0x${pe.machine.toString(16)} imageBase=0x${pe.imageBase.toString(16)} entry=0x${pe.entryPointRva.toString(16)} sizeOfImage=${pe.sizeOfImage}`);
  if (!pe.is32Bit) log.error("Executable is not 32-bit x86; BottleShip targets x86 PE32 only.");
  for (const s of pe.sections) log.info(`section ${s.name} va=0x${s.virtualAddress.toString(16)} vsize=0x${s.virtualSize.toString(16)}`);
  let total = 0;
  for (const imp of pe.imports) {
    total += imp.functions.length;
    const note = HLE_NOTES[imp.dll.toLowerCase()];
    (note ? log.warn : log.info).call(log, `import ${imp.dll} (${imp.functions.length} functions)${note ? ` - requires HLE: ${note}` : ""}`);
  }
  log.info(`Total imported functions: ${total}`);
  log.warn("Static analysis only: no code was executed. Actual runtime compatibility is UNTESTED.");
}
