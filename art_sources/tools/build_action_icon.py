"""Unit action button icons (64 and 45 px) from a white glyph picture.

usage: python art_sources/tools/build_action_icon.py <source.png> <out_name>
The source may have a baked background (e.g. a checkerboard): only near-white pixels count as the glyph.
The glyph is fitted to 72% of the cell, centred, with a soft dark shadow like the base action icons,
and written uncompressed (B8G8R8A8, one mip) to LEKMOD/Art/Lekmod (v 1)/Art/UnitActions/<out_name>_<size>.dds.
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
OUT = os.path.join(REPO, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "UnitActions")
FIT, WHITE = 0.72, 235


def glyph_mask(src):
    g = src.convert("RGB")
    w, h = g.size
    px = g.load()
    m = Image.new("L", (w, h), 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            r, gg, b = px[x, y]
            v = min(r, gg, b)
            mp[x, y] = 255 if v >= WHITE else max(0, (v - 215) * 255 // (WHITE - 215)) if v > 215 else 0
    return m.crop(m.getbbox())


def icon(mask, size):
    s = FIT * size
    k = s / max(mask.size)
    gm = mask.resize((max(1, round(mask.size[0] * k)), max(1, round(mask.size[1] * k))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox, oy = (size - gm.size[0]) // 2, (size - gm.size[1]) // 2
    shadow = Image.new("L", (size, size), 0)
    shadow.paste(gm, (ox + 1, oy + 2))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size / 40.0))
    out.paste((0, 0, 0, 255), (0, 0), shadow.point(lambda a: a * 160 // 255))
    white = Image.new("RGBA", gm.size, (255, 255, 255, 255))
    out.paste(white, (ox, oy), gm)
    return out


def main(src_path, name):
    os.makedirs(OUT, exist_ok=True)
    mask = glyph_mask(Image.open(src_path))
    tmp = tempfile.mkdtemp()
    for size in (64, 45):
        p = os.path.join(tmp, "%s_%d.png" % (name, size))
        icon(mask, size).save(p)
        subprocess.check_call([TEXCONV, "-nologo", "-y", "-f", "B8G8R8A8_UNORM", "-m", "1", "-o", OUT, p], stdout=subprocess.DEVNULL)
    print("built", name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
