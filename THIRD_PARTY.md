# Third-party software

| Project | Use | License |
|---|---|---|
| [Vite](https://github.com/vitejs/vite), [TypeScript](https://github.com/microsoft/TypeScript), [Vitest](https://github.com/vitest-dev/vitest) | Dev tooling | MIT / Apache-2.0 |
| [BottleShip](https://github.com/jenissimo/bottleship) | Pinned runtime diagnostic patch (execution runtime not integrated) | Apache-2.0; see `licenses/BottleShip-Apache-2.0.txt` |
| [v86](https://github.com/copy/v86) | Used by BottleShip (fork) | BSD-2-Clause (verify upstream) |
| [MeltyLib](https://github.com/PCvolt/MeltyLib) | Planned reference for game memory/format knowledge (not yet used) | Verify before integrating |

Licenses of planned dependencies must be confirmed before any code is vendored or linked.

`runtime/bottleship-callback-flow.patch` contains source context from BottleShip
commit `2e1746cdf196a0b57d605ac3519040cc2a1f9406`, with diagnostic instrumentation
and synthetic regression tests added locally. It contains no proprietary game
files. v86 code/binaries are not included in the patch; the synthetic test uses
the upstream runtime checkout's existing submodule.
