# JoySpace

**JoySpace** is a cursive monospace font in the **TilottamaCode** family, derived from GitHub's
[Monaspace](https://github.com/githubnext/monaspace). It combines two Monaspace "voices" into one
style-linked family:

| Style       | Source face                     |
|-------------|---------------------------------|
| Regular     | Monaspace **Argon** Regular     |
| Bold        | Monaspace **Argon** Bold        |
| Italic      | Monaspace **Radon** Italic (cursive) |
| Bold Italic | Monaspace **Radon** Bold Italic (cursive) |

Argon (a humanist sans) carries the upright text; Radon (the handwriting/cursive voice) is used
for the italics — so toggling italics in an editor switches to a flowing cursive. All Monaspace
voices are metric-compatible, so the four faces share one cell and link cleanly as a RIBBI family.

## Build

```bat
MONASPACE-Custom-NF\joyspace.bat
```

Pipeline (`joyspace.bat`):

1. **Step 1 — `resources/build_joyspace.py`** reads the four base OTFs vendored in `resources/`
   (normal-width Argon Regular/Bold + Radon Italic/BoldItalic) and rewrites their identity
   (name table + OS/2 + head + CFF) into one style-linked **JoySpace** family, written to the
   scratch dir `dist/_joyspace/JoySpace-*.otf`.
2. **Step 2 — Nerd Fonts patcher** (`../bin/nerdfont/font-patcher`, via FontForge `ffpython`)
   patches the four JoySpace faces in parallel, writing the results straight into the single
   output dir `dist/`. The patcher appends "Nerd Font" to the family, yielding the
   **JoySpace Nerd Font** family.
3. The scratch dir is removed, leaving only the final OTFs + bundled licenses
   (`MONASPACE-LICENSE.txt`, `NERDFONT-LICENSE.txt`) in `dist/`.

Output stays **OTF** (CFF outlines, Monaspace's native format) in `MONASPACE-Custom-NF/dist/`,
which is gitignored. The base family name is the `FAMILY` constant at the top of
`resources/build_joyspace.py`; the patcher derives the "… Nerd Font" name from it.

### Prerequisites
- FontForge with `ffpython` (Nerd Fonts patcher) and Python 3 with `fontTools` — same as the
  Iosevka pipeline in `../IOSEVKA-Custom-NF/`.
- The four base Monaspace **OTF** files are vendored in `resources/` — no external download needed.

## License note

Monaspace is licensed under the **SIL Open Font License 1.1 with a Reserved Font Name**
("Monaspace", incl. subfamilies "Argon"/"Radon"). The OFL permits modifying and redistributing
the font **under a different name** — hence **JoySpace**, which contains none of the reserved
names. `build_joyspace.py` preserves the OFL name records (IDs 13/14) and adds a derivative note
to the copyright; `joyspace.bat` bundles the upstream `MONASPACE-LICENSE.txt` (OFL) and
`NERDFONT-LICENSE.txt` into `dist/` alongside the fonts.
