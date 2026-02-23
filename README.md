# TilottamaCode

![Sample JoySevka](Miosevka-Sample2.png)

**TilottamaCode** is a family of custom coding fonts with a Kolkata — the City of Joy — identity.
Each font is built from a high-quality open-source base, tuned with custom letterforms, and
patched with [Nerd Font](https://github.com/ryanoasis/nerd-fonts) symbols (Nerd Fonts v3.4.0).

## Fonts

- **JoySevka** — Iosevka-derived, wide chars; italics blend in cursive glyphs from Victor Mono.
- **Riosevka** — rounded Iosevka variant.
- **JoySpace** — a cursive monospace derived from GitHub's
  [Monaspace](https://github.com/githubnext/monaspace): Argon upright + Radon cursive italics.

### Build

- **JoySevka / Riosevka** — `IOSEVKA-Custom-NF/nerdfont.bat`
  ([Iosevka](https://github.com/be5invis/Iosevka) build plans + Victor Mono italics + Nerd Fonts).
- **JoySpace** — `MONASPACE-Custom-NF/joyspace.bat` (Monaspace OTFs + Nerd Fonts).

Each pipeline writes to its own gitignored `dist/`. To package a release, run `release.ps1`
(see [Releases](#releases)).

### Sample Image (V14)
![Sample JoySevka](Screenshot-MIOSEVKA-Nerdfont.png)
![Sample Riosevka](Screenshot-RIOSEVKA-Nerdfont.png)

## Releases

`release.ps1` bundles the built fonts from both `dist/` folders, **every** license file, and
`Install-Font.ps1` into `dist/release/TilottamaCode-v<N>.zip`, then creates an annotated git tag
`v<N>` (incrementing integer). It packages existing build output, so build first:

```pwsh
IOSEVKA-Custom-NF\nerdfont.bat      # builds JoySevka + Riosevka
MONASPACE-Custom-NF\joyspace.bat    # builds JoySpace
pwsh .\release.ps1                  # auto-increments the tag; add -Push to push it to origin
```

## License

- **Fonts** (JoySevka, Riosevka, JoySpace) — SIL Open Font License 1.1, © Saumyajyoti Mukherjee,
  with Reserved Font Names "JoySevka", "Riosevka", "JoySpace", "TilottamaCode". See `LICENSE`.
- **Build scripts / tooling** (`*.bat`, `*.py`, `*.ps1`) — MIT License. See `LICENSE-SCRIPTS.txt`.

Upstream licenses (retained, and bundled into every release):
- Iosevka — `IOSEVKA-LICENSE.md` (OFL 1.1)
- Victor Mono — `victor-mono-LICENSE.txt` (OFL 1.1)
- Monaspace — `MONASPACE-LICENSE.txt` (OFL 1.1)
- Nerd Fonts — `NERDFONT-LICENSE.txt` (MIT + OFL 1.1)
- ttfautohint — `TTFAH-LICENSE.txt` (GPLv2 / FreeType License)
