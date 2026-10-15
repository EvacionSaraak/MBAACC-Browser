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
