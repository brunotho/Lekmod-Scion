"""Civilopedia top tab (and its 256 px page picture) from a glyph picture on transparency.

usage: python art_sources/tools/build_pedia_tab.py <source.png> <out_name> [--preview out.png]
The tab buttons are 46x50 (CivilopediaScreen.xml). The texture holds the button states stacked at 50 px steps:
normal (y 0), mouseover (y 50, also the selected tab: SelectedCategoryTab uses TextureOffset 0,50), pressed (y 100),
disabled (y 150), on a 64x256 canvas, uncompressed (B8G8R8A8, one mip).
The base tab textures are stored compressed in Expansion2UITextures.fpk and could not be decoded, so the tab is rebuilt
from an in-game screenshot of the tab row at 1:1 scale (REF, the user's screenshot of 2026-10-22):
- normal: the Home tab's rim and stalk; its glass disc replaced by the darkest pixel of six normal tabs (drops their
  icons, keeps the gloss, which is the same on every tab)
- selected: the raised Promotions tab; its blue disc with the icon filled in from the surrounding disc pixels
The background around a tab is made transparent by a flood fill from the frame's top and sides.
Writes LEKMOD/Art/Lekmod (v 1)/Art/Civilopedia/<out_name>.dds and <out_name>256.dds (BC3, full mips).
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageEnhance

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXCONV = os.environ.get("TEXCONV", r"C:/Users/bbruno/civ-tools/texconv.exe")
OUT = os.path.join(REPO, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "Civilopedia")
REF = os.path.join(REPO, "art_sources", "civilopedia", "reference_tab_row_2026-10-22.png")
W, H = 46, 50                              # frame size
SLOT_X0, SLOT_STEP, FRAME_Y0 = 9, 47, 10   # frame of tab slot 1 in REF; slots are 47 px apart
HOME_SLOT, SELECTED_SLOT = 1, 6            # in REF: Home (normal) and Promotions (selected)
NORMAL_SLOTS = (1, 3, 4, 5, 7, 8)          # normal tabs whose discs are combined
NORMAL_DISC = (24.0, 28.0, 16.5)           # centre x, y and radius of the glass disc in a normal frame
SELECTED_DISC = (24.4, 21.7, 16.5)         # the same for the raised (selected) frame
GLYPH_BOX = (29, 18)                       # the glyph fits into this, centred on the disc
PANEL = (42, 39, 29, 255)                  # the panel colour behind the tabs (preview only)
# the base icons' colour (mean of their bright pixels in REF): warm cream, lighter on the selected tab;
# GLYPH_TINT moves the glyph that far towards it (0 = the art's own colours, 1 = the same mean colour)
ICON_COLOUR_NORMAL = (225, 227, 199)
ICON_COLOUR_SELECTED = (242, 244, 233)
GLYPH_TINT = 0.8


def frame(ref, slot):
    x0 = SLOT_X0 + SLOT_STEP * (slot - 1)
    return ref.crop((x0, FRAME_Y0, x0 + W, FRAME_Y0 + H)).convert("RGBA")


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def cut_background(img):
    """Transparent where the panel behind the tab shows (dark, unsaturated), reached from the top and sides."""
    px = img.load()
    def bg(x, y):
        r, g, b, _ = px[x, y]
        return lum((r, g, b)) < 75 and max(r, g, b) - min(r, g, b) < 26
    seen, todo = set(), [(x, 0) for x in range(W)] + [(0, y) for y in range(H)] + [(W - 1, y) for y in range(H)]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < W and 0 <= y < H) or not bg(x, y):
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for x, y in seen:
        px[x, y] = (0, 0, 0, 0)
    return img


def in_disc(x, y, disc):
    cx, cy, r = disc
    return (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r


def darkest(frames):
    out = frames[0].copy()
    px, fps = out.load(), [f.load() for f in frames]
    for y in range(H):
        for x in range(W):
            px[x, y] = min((fp[x, y] for fp in fps), key=lum)
    return out


def smooth_disc(img, disc):
    """Icons sit in the middle of the disc, so the darkest-pixel disc still has bits of their dark outlines there.
    The disc shading is mostly vertical: towards the middle, use the row's median over the central band instead."""
    cx, cy, r = disc
    px = img.load()
    out = img.copy()
    opx = out.load()
    for y in range(H):
        band = sorted((px[x, y] for x in range(W) if in_disc(x, y, disc) and abs(x + 0.5 - cx) < r * 0.75), key=lum)
        if not band:
            continue
        med = band[len(band) // 2]
        for x in range(W):
            if in_disc(x, y, disc):
                d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5 / r
                w = min(1.0, max(0.0, (1.0 - d) / 0.2))   # 1 in the middle, 0 at the rim
                opx[x, y] = tuple(round(med[i] * w + px[x, y][i] * (1 - w)) for i in range(4))
    return out


def fill_icon(img, disc):
    """Fill the icon (unsaturated pixels on the saturated blue disc) from the surrounding disc pixels."""
    px = img.load()
    icon = set()
    for y in range(H):
        for x in range(W):
            if in_disc(x, y, disc):
                r, g, b, _ = px[x, y]
                if max(r, g, b) - min(r, g, b) < 45:
                    icon.add((x, y))
    icon |= {(x + dx, y + dy) for x, y in icon for dx in (-1, 0, 1) for dy in (-1, 0, 1) if in_disc(x + dx, y + dy, disc)}
    vals = {}
    for _ in range(300):
        new = {}
        for x, y in icon:
            ns = [vals.get(n, px[n] if n not in icon else None) for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                  if 0 <= n[0] < W and 0 <= n[1] < H]
            ns = [n for n in ns if n is not None]
            if ns:
                new[(x, y)] = tuple(sum(c[i] for c in ns) // len(ns) for i in range(4))
        vals = new
    for p, c in vals.items():
        px[p] = c
    return img


def glyph(src):
    a = src.getchannel("A").point(lambda v: 255 if v > 10 else 0)
    return src.crop(a.getbbox())


def fit(img, box):
    k = min(box[0] / img.size[0], box[1] / img.size[1])
    return img.resize((max(1, round(img.size[0] * k)), max(1, round(img.size[1] * k))), Image.LANCZOS)


def tint(g, target, strength):
    """Scale each colour channel so the glyph's bright pixels move towards the target colour; shading is kept."""
    px = g.load()
    v = [px[x, y][:3] for y in range(g.height) for x in range(g.width) if px[x, y][3] > 200 and lum(px[x, y]) > 170]
    if not v or not strength:
        return g
    mean = [sum(c[i] for c in v) / float(len(v)) for i in range(3)]
    f = [(target[i] / mean[i]) ** strength for i in range(3)]
    out = g.copy()
    opx = out.load()
    for y in range(g.height):
        for x in range(g.width):
            r, gg, b, a = px[x, y]
            opx[x, y] = (min(255, round(r * f[0])), min(255, round(gg * f[1])), min(255, round(b * f[2])), a)
    return out


def put_glyph(img, g, disc, target):
    gs = tint(fit(g, GLYPH_BOX), target, GLYPH_TINT)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    layer.paste(gs, (round(disc[0] - gs.size[0] / 2.0), round(disc[1] - gs.size[1] / 2.0)), gs)
    return Image.alpha_composite(img, layer)


def tab_sheet(g):
    ref = Image.open(REF).convert("RGB")
    normal = frame(ref, HOME_SLOT)
    disc = smooth_disc(darkest([frame(ref, s) for s in NORMAL_SLOTS]), NORMAL_DISC)
    npx, dpx = normal.load(), disc.load()
    for y in range(H):
        for x in range(W):
            if in_disc(x, y, NORMAL_DISC):
                npx[x, y] = dpx[x, y]
    normal = put_glyph(cut_background(normal), g, NORMAL_DISC, ICON_COLOUR_NORMAL)
    selected = fill_icon(frame(ref, SELECTED_SLOT), SELECTED_DISC)
    selected = put_glyph(cut_background(selected), g, SELECTED_DISC, ICON_COLOUR_SELECTED)
    disabled = ImageEnhance.Brightness(ImageEnhance.Color(normal).enhance(0.2)).enhance(0.6)
    sheet = Image.new("RGBA", (64, 256), (0, 0, 0, 0))
    for i, f in enumerate((normal, selected, selected, disabled)):
        sheet.paste(f, (0, i * H))
    return sheet


def page_picture(g):
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    gs = fit(g, (200, 200))
    out.paste(gs, ((256 - gs.size[0]) // 2, (256 - gs.size[1]) // 2), gs)
    return out


def preview_image(sheet):
    """The tab row of REF with the new tab in slot 2 (normal) and over slot 6 (selected), 4x."""
    ref = Image.open(REF).convert("RGBA")
    x2 = SLOT_X0 + SLOT_STEP
    both = Image.new("RGBA", (ref.width, ref.height * 2 + 4), (255, 255, 255, 255))
    for i in (0, 1):
        row = ref.copy()
        row.paste(PANEL, (x2, 0, x2 + W, FRAME_Y0 + H))   # REF has an older NQ tab in slot 2
        row.alpha_composite(sheet.crop((0, i * H, W, (i + 1) * H)), (x2, FRAME_Y0))
        both.paste(row, (0, i * (ref.height + 4)))
    return both.resize((both.width * 3, both.height * 3), Image.NEAREST)


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
        preview_image(sheet).save(preview)
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
