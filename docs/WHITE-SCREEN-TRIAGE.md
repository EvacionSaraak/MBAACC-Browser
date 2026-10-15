# White-screen log triage

After PR #8, the patched local BottleShip can display MBAACC's setup dialog, but the following screen is white. Its GPU diagnostic showed presents without draw calls or textures. This suggests the game may not be submitting geometry; it does **not** prove a Direct3D API defect.

Use the already-running **patched local** BottleShip, not the public deployment. At the setup dialog, take a **Debug Logs → Load Recent** snapshot. Press Enter, wait for the white screen, then take another **Load Recent** snapshot. Do not enable continuous **Start Stream**; it previously froze a tab.

If the UI allows saving plaintext log files, you can classify each one without exposing their contents:

```powershell
node tools/triage-bottleship-log.mjs "C:\\path\\before.txt"
node tools/triage-bottleship-log.mjs "C:\\path\\after.txt"
node --test tests/triage-bottleship-log.test.mjs
```

The output reports mention counts and line numbers for device creation, draw calls, Present, resource creation, file access, failures, and fatal faults. It **does not** print log lines, filenames or memory contents. Review source log files for sensitive paths or proprietary data before sharing them.

Compare **before versus after**. A zero count is **not proof** that an operation never occurred: BottleShip may not log that API. If both snapshots have no draw/resource evidence, the next engineering change should add focused *bounded, opt-in* tracing around game-window D3D9 calls and asset opens, rather than making a speculative rendering fix.

This tool does not run MBAACC or alter BottleShip. It only summarizes local text logs; no files are uploaded.
