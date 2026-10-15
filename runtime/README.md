# BottleShip startup investigation

This source-only patch targets BottleShip
`2e1746cdf196a0b57d605ac3519040cc2a1f9406`, with its v86 submodule at
`2e9d1a2c16ee12899891f3e68ded05402c566710`.
It adds diagnostics and tests, **not a confirmed MBAACC crash fix**.

It is kept as a pinned patch here because MBAACC-Browser does not embed the
BottleShip execution runtime. Applying changes only to this static frontend
cannot change the code running at bottleship.pages.dev.

## Apply to a clean local runtime checkout

Clone BottleShip with its submodule and check out the revision above. From
MBAACC-Browser, validate the patch first:

```
node tools/apply-runtime-debug.mjs <BottleShip-checkout>
node tools/apply-runtime-debug.mjs --apply <BottleShip-checkout>
```

The helper requires Git on PATH (or `GIT` set to its executable). It refuses a
different revision or tracked source changes and never resets an installation.
Install the runtime's development dependencies with the normal upstream workflow
only if authorized. In the BottleShip checkout, run:

```
bun test tools/tests/callback-flow.test.ts tools/tests/nested-dialog-x86.test.ts tools/tests/dxdiag-availability.test.ts tools/tests/guest-routine.test.ts tools/tests/thunk-dispatcher.test.ts tools/tests/dialog-showwindow.test.ts tools/tests/modal-dialog-pump-lifetime.test.ts tools/tests/oleaut32-ordinal-150.test.ts
bun run typecheck
bun run build
```

The synthetic test executes handwritten x86 using v86, the actual callback
manager, and the actual VariantInit implementation. It covers the dialog ABI
seam, not user32's full template/window/message-pump behavior. It must not be
presented as a reproduction of MBAACC itself. The DxDiag test characterizes the
existing class-not-registered behavior; it intentionally does not pretend that
unsupported COM activation succeeds.

## Capture the real game trace

In PowerShell, from BottleShip:

```powershell
$env:VITE_BS_CALLBACK_FLOW = '1'
bun run dev -- --host 127.0.0.1
```

Open the printed localhost URL in Chrome/Edge. Import the **same private WGB** and
keep its settings unchanged. Do not upload or commit the bundle. Record the
browser version and the BottleShip commit/patch state. When it crashes, copy the
report: it now includes `callback control-flow trace (newest last)`.

Tracing is off by default and bounded to 128 events. It records thread/frame IDs,
callback target/stub and return addresses, actual/expected ESP, cleanup bytes,
async restores, VariantInit pointer validity/argument count, and COM class/IID,
HRESULT and output-object pointer. It does not dump guest bytes or argument
payloads. Existing crash reports may still contain stack dumps; keep raw reports
private and review/redact them before sharing. The new trace does not make an
entire old report safe to publish automatically.

For an existing development harness, the worker commands are
`dbgCall("callbackFlow", true)` and `dbgCall("callbackFlowReport")` (see upstream
`docs/harness.md` for transport syntax). Arm before loading the game. No JIT,
antivirus, Windows, or security setting needs to change.

Remove the environment variable after testing:

```powershell
Remove-Item Env:VITE_BS_CALLBACK_FLOW
```

See [the investigation](../docs/RUNTIME-DEBUGGING.md) for observations and the
remaining blocker. The patch contains upstream source context licensed under
Apache-2.0; the license is in `licenses/BottleShip-Apache-2.0.txt`.
