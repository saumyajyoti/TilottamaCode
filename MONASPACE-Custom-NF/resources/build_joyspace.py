r"""
build_joyspace.py
-----------------
Rename the base Monaspace faces into one style-linked **JoySpace** family.

JoySpace is a Monaspace derivative that uses:
  - **Argon** for the upright (Regular / Bold) faces, and
  - **Radon** (cursive/handwriting voice) for the Italic / Bold Italic faces.

This is **step 1** of the pipeline (see ../joyspace.bat): it rewrites the identity of the four
base OTFs (name table + OS/2 + head + CFF) so they form ONE family — Regular, Bold, Italic,
Bold Italic — with correct bold/italic style linking. The Nerd Fonts patcher then runs as step 2
on these JoySpace files, producing the "JoySpace Nerd Font" family.

Usage:
    python build_joyspace.py <out_dir> [src_dir]

The four base Monaspace OTFs are vendored next to this script (the resources/ folder);
<src_dir> defaults to that folder. Outputs
<out_dir>/JoySpace-{Regular,Bold,Italic,BoldItalic}.otf.

License: JoySpace is a modified derivative of Monaspace (Argon & Radon), which is licensed
under the SIL Open Font License 1.1 with Reserved Font Names. The new name "JoySpace" contains
none of the reserved names; the OFL name records (IDs 13/14) are preserved and a derivative
note is added to the copyright (ID 0).
"""

import os
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))

# Base name; the Nerd Fonts patcher (step 2) appends " Nerd Font" -> "JoySpace Nerd Font".
FAMILY = "JoySpace"

# Windows (3,1,0x409) + Mac (1,0,0) name records get written for each identity field.
_PLATFORMS = [(3, 1, 0x409), (1, 0, 0)]

DERIVATIVE_NOTE = (
    "JoySpace is a modified derivative of Monaspace (Argon & Radon), "
    "distributed under the SIL Open Font License 1.1."
)

# style key -> source face + target identity.
#   src = filename (vendored in resources/); weight = usWeightClass; bold/italic drive style bits.
STYLES = {
    "Regular":    dict(src="MonaspaceArgon-Regular.otf",
                       subfamily="Regular",     ps="JoySpace-Regular",    weight=400, bold=False, italic=False),
    "Bold":       dict(src="MonaspaceArgon-Bold.otf",
                       subfamily="Bold",        ps="JoySpace-Bold",       weight=700, bold=True,  italic=False),
    "Italic":     dict(src="MonaspaceRadon-Italic.otf",
                       subfamily="Italic",      ps="JoySpace-Italic",     weight=400, bold=False, italic=True),
    "BoldItalic": dict(src="MonaspaceRadon-BoldItalic.otf",
                       subfamily="Bold Italic", ps="JoySpace-BoldItalic", weight=700, bold=True,  italic=True),
}

# fsSelection bits we manage (everything else, e.g. USE_TYPO_METRICS, is preserved).
FS_ITALIC, FS_BOLD, FS_REGULAR = 0x01, 0x20, 0x40


def _set_name(name_table, value, name_id):
    for plat_id, enc_id, lang_id in _PLATFORMS:
        name_table.setName(value, name_id, plat_id, enc_id, lang_id)


def build_face(in_path, out_path, spec):
    full = FAMILY if spec["subfamily"] == "Regular" else f"{FAMILY} {spec['subfamily']}"
    print(f"\n--- {spec['subfamily']:<11} <- {os.path.basename(in_path)}")

    font = TTFont(in_path)
    name = font["name"]

    # --- name table: collapse to a clean RIBBI family ---------------------------------
    _set_name(name, FAMILY, 1)              # Family
    _set_name(name, spec["subfamily"], 2)   # Subfamily
    _set_name(name, full, 4)                # Full name
    _set_name(name, spec["ps"], 6)          # PostScript name
    _set_name(name, f"1.000;JOYS;{spec['ps']}", 3)  # Unique ID
    # Drop typographic family/subfamily so apps group the 4 faces via IDs 1/2 (RIBBI).
    name.removeNames(nameID=16)
    name.removeNames(nameID=17)

    # Preserve OFL records (13/14); append derivative note to copyright (0).
    existing_copyright = name.getDebugName(0) or ""
    if DERIVATIVE_NOTE not in existing_copyright:
        merged = f"{existing_copyright} | {DERIVATIVE_NOTE}".strip(" |")
        _set_name(name, merged, 0)

    # --- weight / style bits ----------------------------------------------------------
    os2 = font["OS/2"]
    os2.usWeightClass = spec["weight"]
    fs = os2.fsSelection & ~(FS_ITALIC | FS_BOLD | FS_REGULAR)
    if spec["italic"]:
        fs |= FS_ITALIC
    if spec["bold"]:
        fs |= FS_BOLD
    if not spec["bold"] and not spec["italic"]:
        fs |= FS_REGULAR
    os2.fsSelection = fs

    head = font["head"]
    mac = 0
    if spec["bold"]:
        mac |= 0x01
    if spec["italic"]:
        mac |= 0x02
    head.macStyle = mac

    # --- CFF internal names (avoid duplicate-PostScript-name install conflicts) --------
    if "CFF " in font:
        cff = font["CFF "].cff
        cff.fontNames = [spec["ps"]]
        top = cff.topDictIndex[0]
        for attr, val in (("FullName", full), ("FamilyName", FAMILY),
                          ("Weight", "Bold" if spec["bold"] else "Regular")):
            try:
                setattr(top, attr, val)
            except Exception:
                pass

    font.save(out_path)
    print(f"    saved {out_path}  (usWeightClass={spec['weight']}, "
          f"fsSelection=0x{fs:02X}, macStyle=0x{mac:02X})")


def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(__doc__)
        sys.exit(1)

    out_dir = sys.argv[1]
    src_dir = sys.argv[2] if len(sys.argv) > 2 else HERE
    os.makedirs(out_dir, exist_ok=True)

    for style, spec in STYLES.items():
        in_path = os.path.join(src_dir, spec["src"])
        if not os.path.isfile(in_path):
            print(f"ERROR: source not found: {in_path}")
            sys.exit(1)
        out_path = os.path.join(out_dir, f"JoySpace-{style}.otf")
        build_face(in_path, out_path, spec)

    print(f"\nDone. JoySpace family written to {out_dir}")


if __name__ == "__main__":
    main()
