# MBAACC browser runtime debugging

## Current evidence (2026-10-15)

A private full-game WGB was imported successfully into BottleShip and launched. Guest code executed; the application crashed before a confirmed rendered MBAACC title screen.

- Fault: `Unhandled access violation`; `EIP=0x8680`, accessed address `0x0`, thread T1.
- Last thunk: `oleaut32:ord_8` (VariantInit), returned `0x0`.
- Earlier: `ole32:CoCreateInstance` returned `0x80040154` (class not registered); this may be expected, not necessarily causal.
- Suspicious warning entering `user32:CreateDialogParamA`: EBP outside stack range. EBP can be used as a non-frame register in optimized code, so this warning is not alone proof of stack corruption.
- In-flight or recent calls: `CreateDialogParamA`, `MoveWindow`, `SendMessageA`, `SetTimer`.
- Guest backtrace has `CALLBACK_STUB` frames.
- No evidence yet that the crash is caused by `VariantInit`, D3D, asset corruption, or the selected emulated OS.

## Upstream source code to review

BottleShip repository: https://github.com/jenissimo/bottleship

- `src/worker/api/oleaut32.api.ts`: declares ordinal 8 as VariantInit (one pointer argument).
- `src/worker/modules/oleaut32.ts`: implementation zeroes the 16-byte VARIANT when the pointer is non-null and in bounds.
- `src/worker/modules/user32/dialog.ts`: asynchronous dialog pump and `CreateDialogParamA` flow.
- `src/worker/core/thunking/callback-manager.ts`: callback invocation, nested contexts, guest stack cleanup and return stubs.
- `src/worker/core/thunking/types/async-restore.ts` and `src/worker/core/scheduler/`: async thunk/guest context restore.

## Next reproducible test

This requires a local machine with an existing private WGB; **do not upload the game bundle or executable**.

1. Record the BottleShip commit being tested and the browser version. Keep game import settings unchanged.
2. Re-run the same full WGB and confirm the fault signature. Save the crash report and developer console output privately.
3. In a *local BottleShip development checkout*, add conditional diagnostic traces (disabled by default) to the callback manager and dialog code. Log the guest thread ID, callback target and return EIP, ESP before/after callbacks, intended stack cleanup, nested frame ID, and EIP/ESP before/after async restore. Avoid logging user content or memory dumps.
4. Add a small **synthetic x86 guest callback regression** that invokes and exits nested dialog callbacks with a call to VariantInit, then checks correct EIP/ESP return, register preservation, and return-stub cleanup. The test must not require proprietary MBAACC files.
5. If a generic runtime defect is demonstrated, fix it in a BottleShip branch and run upstream callback/dialog regression tests. Retest the same WGB.
6. If control flow is sound, check whether the error involves unregistered COM class handling or an unsupported game expectation. Treat missing COM registration as a separate hypothesis.
7. Record the new first failure (or title screen success) here with a timestamp, exact build, and anonymized diagnostics.

### Instrumentation checkpoints

- At `CreateDialogParamA` entry: callback address, callback parameters, owning thread.
- Before guest DLGPROC invoke: guest ESP, return stub address, frame ID, cleanup bytes.
- After nested WIN32 thunk returns: expected vs actual ESP, original EIP, restored thread ID.
- Immediately before `oleaut32:ord_8`: VARIANT pointer validity and argument count (avoid reading or exporting game payload).
- On access violation: previous control-flow target/source, callback stack depth and return-stub identity.

## Boundaries

Do not patch proprietary executable bytes, disable antivirus, or claim playback is working before observing an interactive frame. Do not merge speculative Win32 fixes without a failing reproducible test. Store only source code, tests and scrubbed diagnostics in GitHub.

The game-specific asset bundle is intentionally kept local. GitHub Pages remains a static frontend and is not currently executing MBAACC.

## Follow-up investigation (2026-10-15)

The existing private `mbaacc-full.wgb` was imported and launched in BottleShip's
public v0.7.0 UI using the Codex in-app browser (WebGPU reported ready). This
reproduced a **related, but not identical** failure:

- `Execution escaped to bootloader at 0x7c07 (stack corruption or thunk return bug)`;
  accessed address `0x0`, T1, last thunk `oleaut32:ord_8`.
- The report still showed `CreateDialogParamA` and `MoveWindow` in flight and two
  `CALLBACK_STUB` frames. `CoCreateInstance` returned `0x80040154` before VariantInit.
- No title screen or main menu was observed. The previous `0x8680` access violation
  was not reproduced exactly. The public deployment's commit and browser version
  were not captured, so its code cannot be equated with the local revision below.
- The original WGB and installation were not modified. Raw crash data remains
  local; the public notes contain only selected control-flow metadata.

### What the tests establish

Local runtime source: BottleShip
`2e1746cdf196a0b57d605ac3519040cc2a1f9406`, v86
`2e9d1a2c16ee12899891f3e68ded05402c566710`, Bun 1.4.3.

A new handwritten synthetic x86 regression executes on the actual v86 CPU. It
enters two nested modeless-dialog **ABI seams**, invokes the real VariantInit
implementation in each callback, returns to the expected EIP/ESP, preserves
EBX/ESI/EDI/EBP, and releases all callback/suspended frames. It passes. It does
not exercise the full user32 template, window, activation or message-pump code,
and does not reproduce MBAACC's crash.

The failed COM request's CLSID/IID in the local startup path correspond to
`CLSID_DxDiagProvider` / `IID_IDxDiagProvider`, confirmed against
[Microsoft's SDK header](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/dxdiag.h).
An additional test confirms BottleShip currently returns `REGDB_E_CLASSNOTREG`
and a null output object for that provider. This is an unsupported API, **not yet
proof it caused the crash**: the program's failure handling and the later
control-flow transfer need to be observed in the same instrumented run.

There is consequently no confirmed generic callback defect to fix yet. Neither
VariantInit nor dialog callbacks have been patched to return artificial success,
skip game initialization, or jump past the fault.

### Added debugging tools

[runtime/bottleship-callback-flow.patch](../runtime/bottleship-callback-flow.patch)
adds opt-in tracing to the actual BottleShip runtime. It records a bounded ring of
128 events for dialog entry, saved frames, callback invoke/return, expected versus
actual ESP, target/return EIP, stub identity, thread/frame IDs, cleanup, async
restores, VariantInit pointer validity, and COM activation identifiers/results.
The fatal report includes this ring. No guest code bytes, stack payloads or game
files are added to this repository.

Use the revision-checking [patch helper](../tools/apply-runtime-debug.mjs) and
follow [runtime/README.md](../runtime/README.md). Diagnostics are off by default;
enable with `VITE_BS_CALLBACK_FLOW=1` before starting the local dev server, or
the worker's `dbgCall("callbackFlow", true)` command before loading a game.

Validation:

- 81 targeted runtime tests passed across 8 files, including real x86 execution,
  callback/thunk, dialog-pump lifetime and OLEAUT tests.
- Runtime TypeScript check passed; Vite production build passed (existing large
  chunk warnings remain).
- The source patch passed `git apply --check` against a clean checkout at the
  pinned BottleShip revision.
- The runtime's native/Bun test API registry logs a known `import.meta.glob`
  warning outside Vite; the tests still pass. This does not validate every HLE
  export in a browser build.

### Blocker and next action

An instrumented local Vite server was started on loopback. The in-app browser
could not reach it (`ERR_CONNECTION_TIMED_OUT`). A native-browser fallback ended
because the computer-use tool could not reliably determine the current browser
URL; no further browser input was attempted. No firewall, antivirus, Windows or
browser security settings were changed.

**The instrumented full-game run is still required.** Start the patched runtime
from a normal local terminal, import the same WGB, keep its configuration
unchanged, and copy the new crash report's `callback control-flow trace` section
along with the first fault line. Include browser version and exact runtime
revision. Review any full report before sharing because its pre-existing stack
dump can contain game/user data. Do not send the bundle or executable.

Compare the COM failure, subsequent callback/async events, and the first bad
target/ESP before implementing a runtime fix. Then retest the same WGB and record
the next failure or an actually rendered, interactive title/main menu. Packaging,
passing synthetic tests, and a crash at a different address are not menu progress.
