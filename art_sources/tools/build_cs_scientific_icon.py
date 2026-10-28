"""City-State trait icon for Scientific City-States (CityStateScientific.dds, 32x32).

Source: the flask of the base game's Research Info button (MainTechButton.dds, 45x45, from
Resource/DX9/Expansion2UITextures.fpk), saved as art_sources/citystates/main_tech_button_base_45.png.
The flask is keyed out of the button's dark blue disc by brightness, scaled up to the size of the
other trait glyphs and written uncompressed (B8G8R8A8) with texconv.

usage: python art_sources/tools/build_cs_scientific_icon.py
"""
import os, subprocess
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art_sources", "citystates", "main_tech_button_base_45.png")
OUT_DIR = os.path.join(ROOT, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "CityStates")
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
SIZE = 32
GLYPH = 26  # glyph height inside the 32 px icon

src = Image.open(SRC).convert("RGBA")
w, h = src.size
cx, cy, r = w / 2, h / 2, 14.5  # the dark disc inside the gold rim
glyph = Image.new("RGBA", src.size, (0, 0, 0, 0))
for y in range(h):
    for x in range(w):
        if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > r * r:
            continue
        R, G, B, A = src.getpixel((x, y))
        lum = 0.299 * R + 0.587 * G + 0.114 * B
        a = max(0.0, min(1.0, (lum - 70) / 110.0))
        if a > 0:
            glyph.putpixel((x, y), (min(255, int(R * 1.15) + 20), min(255, int(G * 1.15) + 20), min(255, int(B * 1.05) + 10), int(255 * a)))
bbox = glyph.getbbox()
glyph = glyph.crop(bbox)
scale = GLYPH / glyph.size[1]
glyph = glyph.resize((max(1, round(glyph.size[0] * scale)), GLYPH), Image.LANCZOS)
out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
out.paste(glyph, ((SIZE - glyph.size[0]) // 2, (SIZE - glyph.size[1]) // 2), glyph)
os.makedirs(OUT_DIR, exist_ok=True)
png = os.path.join(OUT_DIR, "CityStateScientific.png")
out.save(png)
out.resize((SIZE * 4, SIZE * 4), Image.NEAREST).save(os.path.join(ROOT, "art_sources", "citystates", "preview_scientific_x4.png"))
subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, stdout=subprocess.DEVNULL)
os.remove(png)
print("wrote", os.path.join(OUT_DIR, "CityStateScientific.dds"))
