"""
merge_vm_glyphs.py
------------------
Copy specific glyphs from Victor Mono Italic variants into JoySevka Italic TTFs.

Usage (single pair):
    python merge_vm_glyphs.py <joysevka.ttf> <victormono.ttf> [output.ttf]

Usage (both pairs, files must be in the same directory):
    python merge_vm_glyphs.py

Glyphs merged: s  l  r  e  f  (edit GLYPHS list to change)

Transform applied to each VM glyph before insertion:
  - Scale X and Y by (joysevka_upm / vm_upm)  = 1000/1100 = 0.9091
  - Shift X right by half the leftover advance to centre in 600u cell
  - Advance width forced to JoySevka standard   (600u)
"""

import sys
import os
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen

GLYPHS = ['s', 'l', 'r', 'e', 'f']

HERE = os.path.dirname(os.path.abspath(__file__))

PAIRS = [
    (
        os.path.join(HERE, 'JoySevkaNerdFont-Italic.ttf'),
        os.path.join(HERE, 'VictorMono-MediumItalic.ttf'),
        os.path.join(HERE, 'JoySevkaNerdFont-Italic-VMmerged.ttf'),
    ),
    (
        os.path.join(HERE, 'JoySevkaNerdFont-BoldItalic.ttf'),
        os.path.join(HERE, 'VictorMono-BoldItalic.ttf'),
        os.path.join(HERE, 'JoySevkaNerdFont-BoldItalic-VMmerged.ttf'),
    ),
]


def merge_pair(mi_path, vm_path, out_path):
    print(f"\n--- Merging: {os.path.basename(vm_path)} -> {os.path.basename(mi_path)} ---")

    mi = TTFont(mi_path)
    vm = TTFont(vm_path)

    mi_upm = mi['head'].unitsPerEm
    vm_upm = vm['head'].unitsPerEm
    mi_adv = 600                             # JoySevka monospace cell width

    scale = mi_upm / vm_upm

    mi_cmap = mi.getBestCmap()
    vm_cmap = vm.getBestCmap()
    vm_gs   = vm.getGlyphSet()

    skipped = []
    merged  = []

    for char in GLYPHS:
        cp = ord(char)
        if cp not in vm_cmap:
            print(f"  SKIP '{char}': not in Victor Mono cmap")
            skipped.append(char)
            continue
        if cp not in mi_cmap:
            print(f"  SKIP '{char}': not in JoySevka cmap")
            skipped.append(char)
            continue

        vm_gname = vm_cmap[cp]
        mi_gname = mi_cmap[cp]

        # Use actual VM advance width for correct centering
        vm_adv_actual = vm['hmtx'][vm_gname][0]
        vm_adv_scaled = vm_adv_actual * scale
        dx = (mi_adv - vm_adv_scaled) / 2

        # Draw VM glyph through scale+centre transform into a new TTGlyphPen
        pen = TTGlyphPen(None)
        vm_gs[vm_gname].draw(
            TransformPen(pen, (scale, 0, 0, scale, dx, 0))
        )

        new_glyph = pen.glyph()

        # Replace glyph outline in JoySevka
        mi['glyf'][mi_gname] = new_glyph

        # Update advance width; recalculate LSB from new bounding box
        new_glyph.recalcBounds(mi['glyf'])
        lsb = new_glyph.xMin if hasattr(new_glyph, 'xMin') else int(dx)
        mi['hmtx'][mi_gname] = (mi_adv, lsb)

        print(f"  OK  '{char}'  {vm_gname} -> {mi_gname}  "
              f"(scale={scale:.4f}, vm_adv={vm_adv_actual}->{vm_adv_scaled:.1f}, "
              f"dx=+{dx:.1f}u, adv={mi_adv})")
        merged.append(char)

    mi.save(out_path)
    print(f"Saved : {out_path}")
    print(f"Merged : {merged}")
    if skipped:
        print(f"Skipped: {skipped}")


def main():
    if len(sys.argv) == 1:
        # No args: process both predefined pairs
        for mi_path, vm_path, out_path in PAIRS:
            merge_pair(mi_path, vm_path, out_path)
    elif len(sys.argv) >= 3:
        mi_path  = sys.argv[1]
        vm_path  = sys.argv[2]
        out_path = sys.argv[3] if len(sys.argv) > 3 else mi_path.replace('.ttf', '-VMmerged.ttf')
        merge_pair(mi_path, vm_path, out_path)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
