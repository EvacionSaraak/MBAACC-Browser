# Compatibility status

## Completed
- Frontend folder import and static PE32 parsing of `MBAA.exe`.

## Untested / unknown (do not assume)
- Whether BottleShip can load and run `MBAA.exe` (not attempted yet).
- Direct3D 9 (or other graphics API) coverage required by the game.
- DirectSound/waveOut audio, DirectInput/keyboard/gamepad, file loading from OPFS.
- 60 FPS performance.

## BottleShip feasibility notes (from its public README, unverified against MBAACC)
- Loads real x86 PE32 executables, HLE of Win32, DirectDraw/Direct3D 3–9 → WebGPU, DirectSound → WebAudio, files in OPFS.
- Requires WebGPU (Chrome/Edge 113+) and SharedArrayBuffer (cross-origin isolation headers). **GitHub Pages cannot set COOP/COEP headers**; a service-worker shim (e.g. coi-serviceworker) will likely be needed. This is a key blocker to investigate.
- Integration options: (1) vendor/depend on a BottleShip build and feed it the imported files; (2) link as a submodule. License must be checked first.

## Blockers
1. No integration with a runtime yet.
2. COOP/COEP on static hosting.
3. Need a legal MBAACC copy for testing; CI cannot test against it.

## Next step (Phase 2)
Use the import log from `MBAA.exe` to list required APIs, then attempt a BottleShip load and record each missing API here.


## Community Edition executable report — 2026-10-15

A user-generated local PE32 metadata report from `MBAA.exe` was reviewed. **This is a static import scan, not an execution test.** No proprietary executable or game assets were received or committed.

- Machine: `0x14c` (32-bit x86 PE32); Windows GUI subsystem `2`.
- Image base: `0x400000`; entry RVA: `0xe3d7e`; image size: `3887104` bytes.
- Sections: `.text`, `.rdata`, `.data`, `.rsrc`, `.new00`.
- 13 imported DLLs / 247 imported functions (including imports by ordinal).
- Win32 core: `KERNEL32.dll` (112), `USER32.dll` (68), `GDI32.dll` (6).
- Graphics: `d3d9.dll` (Direct3DCreate9), `d3dx9_36.dll` (22 functions, including D3DXCreateEffect, D3DXCreateTextureFromFileInMemoryEx, D3DXCreateFontA).
- Input/audio/timing: `DINPUT8.dll` (DirectInput8Create), `DSOUND.dll` (ordinal #11), `WINMM.dll` (timeBeginPeriod, timeGetTime).
- Networking: `WS2_32.dll` (22 imports, many by ordinal); online functionality remains out of scope.
- Additional: `SHELL32.dll`, `ole32.dll`, `OLEAUT32.dll`, `SHLWAPI.dll`.

### BottleShip assessment

BottleShip 0.7 has modules for D3DX9, DirectInput, DirectSound and 32-bit Windows execution; its D3DX9 API descriptor explicitly aliases versioned `d3dx9_24` through `d3dx9_43` DLL names. That is encouraging but **does not verify implementation completeness**. Its compatibility list does not document MBAACC as playable.

**Next practical experiment:** on a machine holding an extracted Community Edition installation, import the complete game folder into BottleShip's browser interface and attempt to launch `MBAA.exe`. Preserve runtime logs, missing-API errors and screenshots. Do not upload proprietary files to GitHub or make claims of gameplay until confirmed.

The report alone cannot detect dynamic DLL loading, file format assumptions, packer behavior, graphics correctness, or runtime timing issues.

## First actual BottleShip execution trace — 2026-10-15

A full community-edition WGB completed the import wizard and attempted to execute `rom/MBAA.exe` in BottleShip. **The game did not reach the title screen.** This supersedes earlier statements that no execution had been attempted.

Observed crash:
- `Unhandled access violation — EIP 0x8680, address 0x0`, thread T1.
- Last completed thunk: `oleaut32:ord_8` (VariantInit), returning `0x0`.
- A prior warning during `user32:CreateDialogParamA`: `wild EBP` outside the guest stack, with an explicit caveat that EBP may be used as scratch in frame-pointer-omitting code.
- `ole32:CoCreateInstance` returned `0x80040154` (class not registered); not established as causal.
- User32 dialog APIs, timer, thread creation and filesystem APIs were exercised; no confirmed menu or D3D initialization.

Upstream BottleShip's `src/worker/api/oleaut32.api.ts` maps `ord_8` to VariantInit, and `src/worker/modules/oleaut32.ts` implements it by clearing 16 bytes for a non-null valid pointer. The latest thunk is a proximity clue, **not proof that VariantInit itself caused the fault**.

Investigation priority: reproduce with the same full WGB locally; preserve an intact crash report, then inspect guest code around the failing EIP and the caller near `0x41720d`. Trace the dialog callback and async guest/host stack restoration around `CreateDialogParamA` / `MoveWindow`. Determine whether the fault is an invalid return/jump, callback convention mismatch, or unrelated memory corruption. Avoid game-specific hacks and do not assume this is a D3D failure.

No proprietary assets or executable bytes are committed. This section contains derived diagnostic metadata only.
