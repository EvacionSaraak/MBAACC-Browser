# BottleShip startup investigation

This source-only patch targets BottleShip
`2e1746cdf196a0b57d605ac3519040cc2a1f9406`, with its v86 submodule at
`2e9d1a2c16ee12899891f3e68ded05402c566710`.
It includes opt-in diagnostics, a ZIP64 reader fix, partial DxDiag support, and
a confirmed fix for deferred cdecl callback returns. MBAACC reaches its settings
dialog and accepts Enter, but the next screen is white; no main menu is confirmed.

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
bun test tools/tests/callback-flow.test.ts tools/tests/nested-dialog-x86.test.ts tools/tests/dxdiag-availability.test.ts tools/tests/dxdiag-provider.test.ts tools/tests/zip64-reader.test.ts tools/tests/guest-routine.test.ts tools/tests/thunk-dispatcher.test.ts tools/tests/dialog-showwindow.test.ts tools/tests/modal-dialog-pump-lifetime.test.ts tools/tests/oleaut32-ordinal-150.test.ts
bun run typecheck
bun run build
```

The synthetic test executes handwritten x86 using v86, the actual callback
manager, and the actual VariantInit implementation. It covers the dialog ABI
seam, not user32's full template/window/message-pump behavior. It must not be
presented as a reproduction of MBAACC itself.
The deferred cdecl case fails without the callback fix. DxDiag tests cover actual
provider/container objects, initialization, reference counts, string properties,
and failure cases. Unsupported COM classes still fail.

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

Tracing is off by default and bounded to 128 events. When enabled, the ordinary
recent-log ring is expanded from 50 to 2048 entries. Raw logs remain private.
The callback trace records thread/frame IDs,
callback target/stub and return addresses, actual/expected ESP, cleanup bytes,
async restores, VariantInit pointer validity/signature argument count and argument-buffer capacity, and COM class/IID,
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

## Disk-backed local boot without a second full browser import

The pinned runtime already provides a range-streaming local bundle server. In
PowerShell, point it only at the directory containing your private test bundles:

```powershell
$env:VITE_BS_CALLBACK_FLOW = '1'
$env:BS_WGB_ROOTS = 'C:\path\to\private-test-bundles'
bun run dev -- --host 127.0.0.1 --port 5175 --strictPort
```

Open `http://127.0.0.1:5175/?game=dev`, choose **Bundles...**, and double-click the
local bundle. Do not use full-folder import for this test. Keep the server bound
to loopback. This serves byte ranges from disk; the runtime can use its bounded
synchronous I/O cache instead of staging another complete bundle in OPFS.
An existing OPFS copy may be reused. Do not delete saves or all browser storage.

For a bundle whose archive contains `rom/MBAA.exe`, its manifest entrypoint must
be `rom/MBAA.exe`, with `rom` set to `rom`. The local test used a separate copy
correcting only that entrypoint; original game files and WGB were retained. A
missing entrypoint can cause the upstream loader to fall back to full OPFS
staging, so fix manifest/layout errors before diagnosing storage quotas.

The ZIP64 fix accepts archives with a ZIP64 locator even when the classic EOCD
fields fit in 32 bits. This matters for writers that switch to ZIP64 around 2 GiB.

At the settings window, focus the game and press Enter. Current observed result:
a white screen with Direct3D presents but no draw calls/textures. This is a
remaining rendering/initialization investigation, not playable compatibility.
Use **Debug Logs > Load Recent** for snapshots. Avoid **Start Stream** for this
workload: a local run became unresponsive after enabling it.
