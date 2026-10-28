"""Round Clausewitz portrait for Berlin's "Clausewitz's Legacy" button in the city screen
(LekmodClausewitz45.dds, 45x45, in LEKMOD/Art/Lekmod (v 1)/Art/CityStates/).

Source: art_sources/citystates/clausewitz_portrait_v1.jpg (the user's picture, 2026-10-27; a public-domain portrait).
Cropped to head and collar, circle with the gold rim of round_icon.py, written uncompressed with texconv.

usage: python art_sources/tools/build_clausewitz_icon.py
"""
import os, subprocess, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from round_icon import gold_rim  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "art_sources", "citystates", "clausewitz_portrait_v1.jpg")
OUT_DIR = os.path.join(ROOT, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "CityStates")
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
SIZE = 45
CENTRE, RADIUS = (238, 250), 175  # source px: face, hair and the red collar

src = Image.open(SRC).convert("RGBA")
cx, cy = CENTRE
crop = src.crop((cx - RADIUS, cy - RADIUS, cx + RADIUS, cy + RADIUS))
s = 8
big = crop.resize((SIZE * s, SIZE * s), Image.LANCZOS)
mask = Image.new("L", big.size, 0)
ImageDraw.Draw(mask).ellipse((s, s, SIZE * s - s - 1, SIZE * s - s - 1), fill=255)
img = big.resize((SIZE, SIZE), Image.LANCZOS)
img.putalpha(mask.resize((SIZE, SIZE), Image.BOX))
img = gold_rim(img, (1, 1, SIZE - 1, SIZE - 1))
os.makedirs(OUT_DIR, exist_ok=True)
png = os.path.join(OUT_DIR, "LekmodClausewitz45.png")
img.save(png)
img.resize((SIZE * 4, SIZE * 4), Image.NEAREST).save(os.path.join(ROOT, "art_sources", "citystates", "preview_clausewitz_x4.png"))
subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, stdout=subprocess.DEVNULL)
os.remove(png)
print("wrote", os.path.join(OUT_DIR, "LekmodClausewitz45.dds"))
