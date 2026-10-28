"""Small gold star for special City-States: on the city banner (LekmodSpecialCityStateStar14.dds, 14x14) and as
the font icon [ICON_LEKMOD_SPECIAL_CS] for tooltips (LekmodSpecialCityStateStar_FontIcon.dds, 22x22, with its
glyph file LekmodSpecialCityStateStarFontIcon_22.ggxml, the pattern of the resource font icons).

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


def draw(size, star_frac=1.0):
    n = size * SS
    big = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    c = n / 2
    k = star_frac
    d.polygon(star(c, c + n * 0.04, n * 0.50 * k, n * 0.23 * k), fill=(25, 18, 5, 235))  # outline
    d.polygon(star(c, c + n * 0.04, n * 0.40 * k, n * 0.175 * k), fill=(244, 196, 64, 255))  # gold
    d.polygon(star(c, c + n * 0.01, n * 0.22 * k, n * 0.09 * k), fill=(255, 238, 150, 255))  # highlight
    return big.resize((size, size), Image.LANCZOS)


def write(img, name):
    png = os.path.join(OUT_DIR, name + ".png")
    img.save(png)
    subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, stdout=subprocess.DEVNULL)
    os.remove(png)
    print("wrote", os.path.join(OUT_DIR, name + ".dds"))


GGXML = """<?xml version="1.0" encoding="UTF-8" ?>
<glyphgen>
    <textures width="22" height="22">
        <texture name="" src="LekmodSpecialCityStateStar_FontIcon.dds" allowcolor="1" alloweffects="1" inuse="1" />
    </textures>
    <styles count="1">
        <style name="">
            <layers count="1">
                <layer tex="" />
            </layers>
        </style>
    </styles>
    <glyphs fudgeadv="0" ascadj="-6" spacing="0" count="1" height="0" ascent="0" descent="0">
        <glyph ch="1" u="0" v="0" width="22" height="22" a="0" b="22" c="0" originx="0" originy="22" />
    </glyphs>
    <imports />
    <toolonly>
        <metainfo pt="0.000000" width="256" height="256" alphabias="64" maxsize="256" bestfit="0" pow2="1" freetype="2" fontsrc="" />
        <glyphsets>
            <set name="GlyphSetAscii" />
        </glyphsets>
    </toolonly>
</glyphgen>
"""

os.makedirs(OUT_DIR, exist_ok=True)
banner = draw(SIZE)
banner.resize((SIZE * 8, SIZE * 8), Image.NEAREST).save(os.path.join(ROOT, "art_sources", "citystates", "preview_special_star_x8.png"))
write(banner, "LekmodSpecialCityStateStar14")
write(draw(22, 0.85), "LekmodSpecialCityStateStar_FontIcon")
with open(os.path.join(OUT_DIR, "LekmodSpecialCityStateStarFontIcon_22.ggxml"), "wb") as f:
    f.write(GGXML.replace(chr(10), chr(13) + chr(10)).encode("utf-8"))
