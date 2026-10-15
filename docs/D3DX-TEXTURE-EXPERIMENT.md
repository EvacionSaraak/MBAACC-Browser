# D3DXCreateTexture implementation experiment

The first white-screen snapshot shows the game opening its packed asset files and then initializing D3D9. Runtime logs also report `UNIMPLEMENTED: d3dx9:D3DXCreateTexture` (five calls) and a `D3DXCreateFontA` stub returning an error. This is evidence of missing functionality, **not proof** of the white screen's sole cause.

This change adds `D3DXCreateTexture` as a declared eight-argument stdcall API and delegates its allocation to BottleShip's existing `createGuestTexture`. It does not fabricate a success, load arbitrary textures, modify the original executable, or change font handling.

## Local application

Use the same pinned, clean BottleShip revision listed in [runtime/README.md](../runtime/README.md). After applying the existing startup patch, apply `runtime/bottleship-d3dx-create-texture.patch` to that **same local checkout**:

```powershell
git -C "PATH_TO_BOTTLESHIP" apply --check "PATH_TO_MBAACC_BROWSER\runtime\bottleship-d3dx-create-texture.patch"
git -C "PATH_TO_BOTTLESHIP" apply "PATH_TO_MBAACC_BROWSER\runtime\bottleship-d3dx-create-texture.patch"
```

Do not reapply the existing startup patch to an already modified checkout. The supplemental patch targets source files not touched by the earlier startup patch. After applying, run the BottleShip tests and typecheck, then launch the **corrected-entrypoint private WGB**, confirm the setup dialog appears, press Enter, and record a bounded log snapshot and Debug GPU statistics. Do not use live log streaming.

Expected diagnostic: the `UNIMPLEMENTED: d3dx9:D3DXCreateTexture` message should disappear. The game may still be white because other APIs or initialization steps remain unsupported. No successful rendering is claimed.

**Safety:** The patch contains source code only and remains in MBAACC-Browser; it does not alter the public BottleShip deployment.
