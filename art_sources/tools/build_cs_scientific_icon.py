"""City-State trait icon for Scientific City-States (CityStateScientific.dds, 32x32).

A cream Erlenmeyer flask like the one on the base game's Research Info button (MainTechButton.dds; the base
picture is kept as art_sources/citystates/main_tech_button_base_45.png for reference). The first version keyed
the flask out of that button, but at 32 px it came out faint and blotchy (user, 2026-10-28), so the glyph is
drawn from scratch: supersampled 16x, a filled flask with a lighter liquid, slightly up and right of centre
(it sat low-left in the banner circle). Written uncompressed (B8G8R8A8) with texconv.

usage: python art_sources/tools/build_cs_scientific_icon.py
"""
import os, subprocess
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "CityStates")
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
SIZE = 32
SS = 16
SHIFT = (0.5, -1.0)  # px at 32: up and right a bit

N = SIZE * SS


def P(x, y):
    return ((x + SHIFT[0]) * SS, (y + SHIFT[1]) * SS)


big = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
outline = (60, 45, 20, 200)
glass = (238, 232, 205, 255)
liquid = (255, 252, 230, 255)
# flask body: neck 13..19 wide from y 6 to 13, then widening to a flat bottom 7..25 at y 26
body = [P(13, 6), P(19, 6), P(19, 13), P(25.5, 24), P(25, 26.5), P(7, 26.5), P(6.5, 24), P(13, 13)]
lip = [P(11.5, 4.5), P(20.5, 4.5), P(20.5, 6.5), P(11.5, 6.5)]
# dark outline: the same shapes, grown by drawing them with a wide line first
d.polygon(body, fill=outline)
d.line(body + [body[0]], fill=outline, width=int(2.2 * SS), joint="curve")
d.polygon(lip, fill=outline)
d.line(lip + [lip[0]], fill=outline, width=int(2.2 * SS), joint="curve")
d.polygon(body, fill=glass)
d.polygon(lip, fill=glass)
# liquid in the lower part, with a little shine line
d.polygon([P(10.2, 18.5), P(21.8, 18.5), P(24.6, 23.6), P(24.2, 25.5), P(7.8, 25.5), P(7.4, 23.6)], fill=liquid)
d.line([P(14.5, 8), P(14.5, 13.5)], fill=(255, 255, 255, 200), width=int(1.0 * SS))
out = big.resize((SIZE, SIZE), Image.LANCZOS)
os.makedirs(OUT_DIR, exist_ok=True)
png = os.path.join(OUT_DIR, "CityStateScientific.png")
out.save(png)
prev = Image.new("RGBA", (SIZE, SIZE), (70, 150, 200, 255))
prev.alpha_composite(out)
prev.resize((SIZE * 8, SIZE * 8), Image.NEAREST).save(os.path.join(ROOT, "art_sources", "citystates", "preview_scientific_x4.png"))
subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, stdout=subprocess.DEVNULL)
os.remove(png)
print("wrote", os.path.join(OUT_DIR, "CityStateScientific.dds"))
