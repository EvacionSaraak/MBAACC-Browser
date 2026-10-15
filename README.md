# MBAACC-Browser

**GitHub Pages site:** [https://evacionsaraak.github.io/MBAACC-Browser/](https://evacionsaraak.github.io/MBAACC-Browser/)

> The site is an experimental executable analyzer, **not a playable version of MBAACC**. Pages deployment may need to be enabled or verified in repository settings.

Goal: play the original **MELTY BLOOD Actress Again Current Code** in a browser, hosted as a static GitHub Pages site, by running the real Windows executable through an existing browser-based Win32/DirectX runtime ([BottleShip](https://github.com/jenissimo/bottleship), built on a fork of [v86](https://github.com/copy/v86)). No emulator install, no streaming, no backend.

> **Status: Phase 1 (foundation). The game does not run yet.** Nothing here claims MBAACC compatibility; see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## What works today
- Static TypeScript/Vite frontend with a folder picker for your own legally obtained MBAACC files (processed locally, never uploaded, never committed).
- Static PE32 analysis of `MBAA.exe` (headers, sections, imported DLLs/functions) with a log of components needing emulation. **No code is executed.**
- Environment diagnostics (WebGPU, SharedArrayBuffer, OPFS) and a copyable log.
- Downloadable JSON compatibility report listing PE headers and imports only (no executable bytes).
- GitHub Pages deployment via Actions.

## Development
```
npm ci
npm run dev     # local server
npm test        # unit tests
npm run build   # typecheck + static build into dist/
```
Enable Pages: repository Settings → Pages → Source: **GitHub Actions**.

## Rules
No game executables, sprites, audio or other proprietary assets may be committed (`.gitignore` blocks common extensions). No fake demos or recorded video presented as gameplay.

## Roadmap
Startup crash investigation and the source-only BottleShip tracing patch:
[docs/RUNTIME-DEBUGGING.md](docs/RUNTIME-DEBUGGING.md),
[runtime/README.md](runtime/README.md). A related browser startup crash was
reproduced; no fix or title-screen compatibility is claimed.

See [docs/ROADMAP.md](docs/ROADMAP.md). Third-party licenses: [THIRD_PARTY.md](THIRD_PARTY.md). This project is MIT licensed (see [LICENSE](LICENSE)) and is unaffiliated with the MBAACC rights holders.
