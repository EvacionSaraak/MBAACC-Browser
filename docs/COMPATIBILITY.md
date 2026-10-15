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
