"""Small gold star for special City-States on the city banner (LekmodSpecialCityStateStar14.dds, 14x14).

Drawn from scratch in the style of the capital star font icon ([ICON_CAPITAL]): a gold five-pointed star
with a dark outline, supersampled 16x and scaled down. Written uncompressed (B8G8R8A8) with texconv.

usage: python art_sources/tools/build_cs_special_star.py
"""
import math, os, subprocess
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "CityStates")
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
SIZE = 14
SS = 16
N = SIZE * SS


def star(cx, cy, r_out, r_in):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


big = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
c = N / 2
d.polygon(star(c, c + N * 0.04, N * 0.50, N * 0.23), fill=(25, 18, 5, 235))  # outline
d.polygon(star(c, c + N * 0.04, N * 0.40, N * 0.175), fill=(244, 196, 64, 255))  # gold
d.polygon(star(c, c + N * 0.01, N * 0.22, N * 0.09), fill=(255, 238, 150, 255))  # highlight
out = big.resize((SIZE, SIZE), Image.LANCZOS)
os.makedirs(OUT_DIR, exist_ok=True)
png = os.path.join(OUT_DIR, "LekmodSpecialCityStateStar14.png")
out.save(png)
out.resize((SIZE * 8, SIZE * 8), Image.NEAREST).save(os.path.join(ROOT, "art_sources", "citystates", "preview_special_star_x8.png"))
subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, stdout=subprocess.DEVNULL)
os.remove(png)
print("wrote", os.path.join(OUT_DIR, "LekmodSpecialCityStateStar14.dds"))
