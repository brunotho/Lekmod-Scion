"""Builds a 32 px unit map flag icon from a white silhouette picture.

usage: python art_sources/tools/build_unit_flag.py <source.png> <out name> [--max-w 22] [--max-h 18] [--cy 12]
       writes LEKMOD/Art/Units/<out name>_32.dds (BC3, one mip) and a preview PNG next to the source.

The silhouette (alpha > 0, any colour) is cropped, scaled to fit max-w x max-h, made pure white, and placed with its
centre at x = 16 + 2 px and y = cy in a transparent 32 px canvas: inside the tapering flag shape, like the Vanguard
Corps flag (18 px tall at y 4..22). The game tints it in the player's colours.
"""
import argparse, os, subprocess
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXCONV = os.path.join(os.path.dirname(ROOT), "texconv.exe")
OUT_DIR = os.path.join(ROOT, "LEKMOD", "Art", "Units")


def build(src, name, max_w, max_h, cy):
    im = Image.open(src).convert("RGBA")
    a = im.split()[3]
    im = im.crop(a.point(lambda v: 255 if v > 40 else 0).getbbox())
    s = min(max_w / im.width, max_h / im.height)
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    alpha = im.split()[3].resize((w, h), Image.LANCZOS)
    glyph = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    glyph.putalpha(alpha)
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.alpha_composite(glyph, (round(18 - w / 2), round(cy - h / 2)))
    preview = os.path.splitext(src)[0] + "_flag32_preview.png"
    canvas.save(preview)
    png = os.path.join(OUT_DIR, name + "_32.png")
    canvas.save(png)
    subprocess.run([TEXCONV, "-f", "BC3_UNORM", "-m", "1", "-y", "-o", OUT_DIR, png], check=True, capture_output=True)
    os.remove(png)
    print("wrote", os.path.join(OUT_DIR, name + "_32.dds"), "glyph %dx%d" % (w, h))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("name")
    ap.add_argument("--max-w", type=int, default=22)
    ap.add_argument("--max-h", type=int, default=18)
    ap.add_argument("--cy", type=float, default=12)
    a = ap.parse_args()
    build(a.src, a.name, a.max_w, a.max_h, a.cy)
