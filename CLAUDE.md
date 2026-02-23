# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**TilottamaCode** is a font-build pipeline (not an application) for a small family of coding
fonts with a Kolkata / "City of Joy" identity. It currently produces two custom monospace fonts —
**JoySevka** and **Riosevka** (rounded variant) — by building [Iosevka](https://github.com/be5invis/Iosevka)
from custom build plans, merging in selected Victor Mono italic glyphs, then patching the
result with [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) symbols. A third font,
**JoySpace** (a cursive monospace derived from GitHub's Monaspace — Argon upright + Radon
italics), is built by a separate pipeline under `MONASPACE-Custom-NF/`. The repo contains the
build plans, helper scripts, vendored tooling, and license/installer files — the actual Iosevka
source is cloned at build time into `%temp%\Iosevka`, not stored here.

There are two independent build pipelines:
- **`IOSEVKA-Custom-NF/`** — JoySevka + Riosevka, via Iosevka build plans (`nerdfont.bat`).
- **`MONASPACE-Custom-NF/`** — JoySpace, via Monaspace OTFs (`joyspace.bat` →
  `resources/build_joyspace.py`): Nerd-patch the source faces, then rewrite their name/OS-2/head/CFF
  tables into one style-linked RIBBI family (rename done last so patching can't break the linking).
  The 4 base Monaspace OTFs are vendored in `resources/`; output OTFs land in the gitignored `dist/`.

Note: `TilottamaCode` is the umbrella/repo brand; `JoySevka` and `Riosevka` are the individual
Iosevka build-plan `family` values.

## Build pipeline

Everything is orchestrated by `IOSEVKA-Custom-NF/nerdfont.bat` (Windows batch, run from that
directory). It performs, in order:

1. Clone/sync Iosevka into `%temp%\Iosevka` (`--depth=1`), then `npm install`.
2. For each variant: copy `<variant>-build-plans.toml` to Iosevka's `private-build-plans.toml`,
   then `npm run build -- ttf::<Variant>`.
3. Merge Victor Mono italic glyphs into JoySevka's Italic TTF only (`merge_vm_glyphs.py`); the
   BoldItalic face is left as pure Iosevka.
4. Patch every built TTF with the Nerd Fonts patcher via FontForge's `ffpython`, launched as
   parallel background jobs (`start /B`); the script then polls `tasklist` for `ffpython.exe`
   to know when patching finishes.
5. Copy licenses + `Install-Font.ps1` + all TTFs to the output dir
   (`IOSEVKA-Custom-NF/dist/TilottamaCode<N>`, gitignored) and `tar`-zip it alongside in `dist/`.

`FONTVERNUM` at the top of `nerdfont.bat` is the release version number and gates the output path.

### Prerequisites (per comments in `nerdfont.bat`)
- Node.js (tested v22.x), FontForge with `ffpython` (path hardcoded to a Scoop install:
  `%USERPROFILE%\scoop\apps\fontforge\current\bin\ffpython.exe`), Python 3 with `fontTools`.
- The Nerd Fonts patcher is vendored at `bin/nerdfont/font-patcher` (v3.4.0); `bin/` is prepended
  to PATH so the bundled `ttfautohint.exe` / `FontReg.exe` are available.

## Key files

- `IOSEVKA-Custom-NF/joysevka-build-plans.toml`, `riosevka-build-plans.toml` — Iosevka build
  plans. Glyph shapes are configured under `[buildPlans.<Variant>.variants.design]` (upright) and
  `[...variants.italic]` (italic overrides). This is where you change letterforms (e.g. the `g`/`h`
  style tweaks in recent commits). Riosevka differs from JoySevka mainly in rounded `design` shapes.
- `IOSEVKA-Custom-NF/resources/merge_vm_glyphs.py` — copies glyphs (default `s l r e f`) from a
  Victor Mono italic TTF into a JoySevka italic TTF, scaling by `mi_upm/vm_upm` and re-centering
  into the 600u monospace cell. Run per file: `python merge_vm_glyphs.py <mi.ttf> <vm.ttf> [out.ttf]`,
  or with no args to process the hardcoded `PAIRS`. Edit the `GLYPHS` list to change which glyphs merge.
- `IOSEVKA-Custom-NF/resources/font_info.py` — debug helper; prints OS/2 ascender/descender,
  italic angle, and unitsPerEm for every TTF/OTF in a folder. `python font_info.py [folder]`.
- `Install-Font.ps1` — installs every TTF in its own folder on Windows 11 (copies to Fonts, writes
  the registry entry, broadcasts `WM_FONTCHANGE`). Must run **as Administrator**.
- `release.ps1` — packages a release: collects built fonts from both `dist/` folders + every root
  `*LICENSE*` file + `Install-Font.ps1` into `dist/release/TilottamaCode-v<N>.zip`, then creates an
  annotated git tag `v<N>` (integer auto-increment from the latest `v*` tag, else `FONTVERNUM`).
  Packages existing output — run the build scripts first. `-Push` also pushes the tag.

## Conventions

- JoySevka's monospace cell is **600 units** wide at **1000 upm**; merge logic and advance-width
  fixes depend on these constants. Victor Mono is 1100 upm (scale factor 0.9091).
- The build is Windows-only and path-sensitive: output goes to `IOSEVKA-Custom-NF/dist/`, FontForge
  is expected at the Scoop path above. Adjust the `SET` lines at the top of `nerdfont.bat` for a
  different setup.
- `dist/`, `node_modules/`, `.build/` are gitignored — built fonts are not committed.
- Licensing: produced fonts are OFL 1.1 (`LICENSE`, with Reserved Font Names JoySevka/Riosevka/
  JoySpace/TilottamaCode); build scripts/tooling are MIT (`LICENSE-SCRIPTS.txt`); upstream
  OFL/MIT/GPL licenses are retained at the repo root and bundled into every release.
