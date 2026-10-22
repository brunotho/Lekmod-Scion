"""Civilopedia top tab (and its 256 px page picture) from a glyph picture on transparency.

usage: python art_sources/tools/build_pedia_tab.py <source.png> <out_name> [--preview out.png]
The tab buttons are 46x50 (CivilopediaScreen.xml). The texture holds the button states stacked at 50 px steps:
normal (y 0), mouseover (y 50, also the selected tab: SelectedCategoryTab uses TextureOffset 0,50), pressed (y 100),
disabled (y 150), on a 64x256 canvas, uncompressed (B8G8R8A8, one mip). The base tab textures are packed (compressed)
in Expansion2UITextures.fpk and could not be decoded, so the tab body (navy, blue when highlighted, thin gold rim)
is drawn here to fit the bar's colours.
Writes LEKMOD/Art/Lekmod (v 1)/Art/Civilopedia/<out_name>.dds and <out_name>256.dds (BC3, full mips).
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXCONV = os.environ.get("TEXCONV", r"C:/Users/bbruno/civ-tools/texconv.exe")
OUT = os.path.join(REPO, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "Civilopedia")
W, H, SS = 46, 50, 4                       # frame size, supersampling
BODY = (2, 5, 43, 49)                      # tab body inside the frame
GLYPH_BOX = (36, 30)                       # glyph fits into this, centred on the body
STATES = {                                 # top colour, bottom colour, rim colour
    "normal": ((34, 52, 82), (14, 24, 42), (150, 122, 66)),
    "hover": ((70, 120, 170), (26, 58, 98), (230, 196, 112)),
    "pressed": ((52, 96, 142), (20, 44, 76), (230, 196, 112)),
}


def glyph(src):
    a = src.getchannel("A").point(lambda v: 255 if v > 10 else 0)
    return src.crop(a.getbbox())


def fit(img, box):
    k = min(box[0] / img.size[0], box[1] / img.size[1])
    return img.resize((max(1, round(img.size[0] * k)), max(1, round(img.size[1] * k))), Image.LANCZOS)


def tab_body(top, bottom, rim):
    w, h = W * SS, H * SS
    x0, y0, x1, y1 = [v * SS for v in BODY]
    grad = Image.new("RGBA", (w, h))
    gp = grad.load()
    for y in range(h):
        t = min(1.0, max(0.0, (y - y0) / float(y1 - y0)))
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            gp[x, y] = c
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((x0, y0, x1, y1 + 8 * SS), radius=6 * SS, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    rim_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(rim_mask).rounded_rectangle((x0, y0, x1, y1 + 8 * SS), radius=6 * SS, outline=255, width=SS)
    out.paste(rim + (255,), (0, 0), rim_mask)
    return out.resize((W, H), Image.LANCZOS)


def with_glyph(body, g):
    gs = fit(g, (GLYPH_BOX[0] * SS, GLYPH_BOX[1] * SS))
    gs = gs.resize((max(1, round(gs.size[0] / SS)), max(1, round(gs.size[1] / SS))), Image.LANCZOS)
    cx, cy = (BODY[0] + BODY[2]) // 2 + 1, (BODY[1] + BODY[3]) // 2 + 1
    ox, oy = cx - gs.size[0] // 2, cy - gs.size[1] // 2
    shadow = Image.new("RGBA", body.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 255), (ox + 1, oy + 1), gs.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.8))
    out = Image.alpha_composite(body, shadow)
    layer = Image.new("RGBA", body.size, (0, 0, 0, 0))
    layer.paste(gs, (ox, oy), gs)
    return Image.alpha_composite(out, layer)


def tab_sheet(g):
    sheet = Image.new("RGBA", (64, 256), (0, 0, 0, 0))
    frames = [with_glyph(tab_body(*STATES[s]), g) for s in ("normal", "hover", "pressed")]
    disabled = ImageEnhance.Color(frames[0]).enhance(0.2)
    disabled = ImageEnhance.Brightness(disabled).enhance(0.6)
    for i, f in enumerate(frames + [disabled]):
        sheet.paste(f, (0, i * H))
    return sheet


def page_picture(g):
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    gs = fit(g, (200, 200))
    out.paste(gs, ((256 - gs.size[0]) // 2, (256 - gs.size[1]) // 2), gs)
    return out


def main(args):
    preview = None
    if "--preview" in args:
        i = args.index("--preview")
        preview = args[i + 1]
        del args[i:i + 2]
    src_path, name = args
    g = glyph(Image.open(src_path).convert("RGBA"))
    sheet, pic = tab_sheet(g), page_picture(g)
    if preview:
        big = Image.new("RGBA", (64 * 6 + 16 + 256, 256 * 6 // 2), (30, 30, 30, 255))
        big.paste(sheet.crop((0, 0, 64, 200)).resize((64 * 3, 200 * 3), Image.NEAREST), (0, 0))
        big.paste(pic, (64 * 3 + 16, 0), pic)
        big.save(preview)
        print("preview", preview)
        return
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    p = os.path.join(tmp, name + ".png")
    sheet.save(p)
    subprocess.check_call([TEXCONV, "-nologo", "-y", "-f", "B8G8R8A8_UNORM", "-m", "1", "-o", OUT, p], stdout=subprocess.DEVNULL)
    p = os.path.join(tmp, name + "256.png")
    pic.save(p)
    subprocess.check_call([TEXCONV, "-nologo", "-y", "-f", "BC3_UNORM", "-m", "0", "-o", OUT, p], stdout=subprocess.DEVNULL)
    print("built", name)


if __name__ == "__main__":
    main(sys.argv[1:])
