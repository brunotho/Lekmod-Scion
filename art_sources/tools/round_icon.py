"""Round icons for buildings/wonders and unit portraits, laid out like the base game's.

Base layouts (256 px cell, transparent around the circle, no frame baked in; the UI draws its own ring):
- buildings: a circle 171 px wide at (43,42), measured on BuildingPortraits3_*_Exp2Patch.dds and WonderAtlas
  (256: 43..214, 128: 22..107, 64: 11..54, 45: 8..38)
- units: a circle 173 px wide at (41,42) (the layout of all Lekmod unit portraits)
Both are drawn 4 px wider around the same centre: the ring of the city screen and the city banner covers the outer
pixels, and a picture that ended exactly at the measured edge showed a dark gap inside the ring (user, 2026-10-14).

The delivered art is usually a rounded-square picture on black with a darker edge (vignette). The crop is centred on
the picture's bounding box (pixels brighter than DARK) and its radius keeps MARGIN inside the picture's nearest edge,
so the circle shows picture right up to the ring. Art with a ring painted on, or art meant to be shown whole, gets a
fixed radius in RADIUS (fraction of the source width).

Usage (from the repo root):
    python art_sources/tools/round_icon.py buildings <name> [<name> ...]
    python art_sources/tools/round_icon.py units <name> [<name> ...]
Reads the largest image (.dds or .png) directly in art_sources/<kind>/<name>/ (subfolders such as flag/ are ignored)
and writes <name>_<size>.dds (BC3, one mip) to the kind's output folder. The sources stay untouched, so this can be
rerun. Without texconv.exe (e.g. a Linux cloud session) Pillow writes the BC3 file instead.
"""
import os, struct, subprocess, sys, tempfile
from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TEXCONV = os.environ.get('TEXCONV', os.path.join(os.path.dirname(REPO), 'texconv.exe'))
KINDS = {
    # kind: (output folder, sizes, circle box (left, top, right, bottom) in a 256 px cell, exact boxes per size)
    # Buildings: the base circles of BuildingPortraits3_<size>_Exp2Patch.dds (alpha > 127), measured 2026-10-24; other
    # sizes scale the 256 box. Units: the 173 px layout at (41,42) (no loose base unit atlas to measure).
    'buildings': (os.path.join(REPO, 'LEKMOD', 'Art', 'Lekmod (v 1)', 'Art', 'Buildings'),
                  (32, 45, 64, 80, 128, 214, 256), (43, 42, 214, 214),
                  {256: (43, 42, 214, 214), 128: (22, 21, 107, 107), 64: (11, 11, 54, 54), 45: (8, 8, 38, 38)}),
    'units': (os.path.join(REPO, 'LEKMOD', 'Art', 'Units'),
              (32, 45, 64, 80, 128, 256), (41, 42, 214, 215), {}),
}


# The base game's own circle masks (alpha of BuildingPortraits3_<size>_Exp2Patch.dds), copied into the repo so the
# tool runs without the game. Buildings use them as their alpha (2026-10-24, user: our crisp circle still looked a
# hair smaller than the Monument in the city banner; the base edge has a faint partial pixel on each side).
MASK_DIR = os.path.join(HERE, 'base_masks')
GAME_ICONS = r"C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V\Assets\UI\Art\Icons"


def base_mask(kind, size):
    """the base alpha mask for this size (measured sizes as they are, others scaled from 256), or None"""
    if kind != 'buildings':
        return None
    exact = KINDS[kind][3]
    src_size = size if size in exact else 256
    path = os.path.join(MASK_DIR, 'building_%d.png' % src_size)
    if not os.path.exists(path):
        dds = os.path.join(GAME_ICONS, 'BuildingPortraits3_%d_Exp2Patch.dds' % src_size)
        if not os.path.exists(dds):
            return None
        os.makedirs(MASK_DIR, exist_ok=True)
        Image.open(dds).convert('RGBA').getchannel('A').crop((0, 0, src_size, src_size)).save(path)
    m = Image.open(path).convert('L')
    return m if src_size == size else m.resize((size, size), Image.LANCZOS)


def circle_box(kind, size):
    """the circle's pixel box at this size: the measured base box, else the 256 box scaled and rounded"""
    _, _, box256, exact = KINDS[kind]
    if size in exact:
        return exact[size]
    return tuple(int(round(v * size / 256.0)) for v in box256)
DARK, MARGIN, R_MIN, R_MAX = 20, 0.05, 0.38, 0.47
RADIUS = {
    'barlas_cavalry': 0.435,  # gold ring painted on from radius 0.455
    'bajoras': 0.435,         # gold ring painted on from radius 0.455
    'mahamatras_office': 0.5, # full-bleed scene, shown whole
}
# zoom into the picture (crop radius / zoom) so the subject looks as big as in the base game's icons, whose subjects
# fill the circle (user, 2026-10-22: ours looked smaller in the tech tree and production list at the same circle size)
ZOOM = {'self_propelled_artillery': 1.35, 'vanguard_corps': 1.25}
# parts of the picture that break out of the circle, like the base game's Machine Gun (user, 2026-10-22): a polygon in
# source pixels; where it lies outside the circle, the picture is drawn there too (it must stay inside the 256 cell)
BREAKOUT = {'self_propelled_artillery': [(830, 415), (900, 375), (965, 350), (985, 342), (1010, 345), (1030, 365),
                                         (1042, 400), (1040, 430), (1025, 448), (1000, 455), (930, 495), (890, 540),
                                         (830, 550)]}
# sources delivered as a cut-out on white: the white connected to the edges becomes this background colour
WHITE_BACKGROUND = {# round pictures on white (2026-10-22; appletree, war_college, ministry_of_truth came on black on 2026-10-23)
                    'self_propelled_artillery': (22, 22, 24), 'jongmyo_shrine': (22, 22, 24), 'mi6': (22, 22, 24)}


def icon(full, crop, size, cbox, poly=None, circle=None):
    """full: the source; crop: the source square shown in the circle; cbox: the circle's pixel box at this size;
    poly: source polygon of a picture part drawn outside the circle (breakout).
    The picture is scaled with Lanczos over the whole cell (no dark rim bleeds in at the circle's edge); the alpha is
    the circle (plus breakout) drawn 8x larger and box-filtered, so the edge is antialiased over one pixel like the base
    icons, with no halo (2026-10-24: the old Lanczos-filtered alpha was soft and asymmetric at small sizes)."""
    s = 8
    big = size * s
    l, t, r, b = [v * s for v in cbox]
    k = (r - l) / float(crop[2] - crop[0])          # source px -> 8x px
    ky = (b - t) / float(crop[3] - crop[1])
    ox, oy = l - crop[0] * k, t - crop[1] * ky
    # the source region that covers the whole cell (clamped to the source; edge pixels repeat beyond it)
    fw, fh = full.size
    sx0, sy0 = max(0, int((0 - ox) / k)), max(0, int((0 - oy) / ky))
    sx1, sy1 = min(fw, int((big - ox) / k) + 1), min(fh, int((big - oy) / ky) + 1)
    region = full.crop((sx0, sy0, sx1, sy1))
    canvas = Image.new('RGBA', (big, big), (0, 0, 0, 255))
    w, h = int(round((sx1 - sx0) * k)), int(round((sy1 - sy0) * ky))
    canvas.paste(region.resize((w, h), Image.LANCZOS), (int(round(ox + sx0 * k)), int(round(oy + sy0 * ky))))
    mask = Image.new('L', (big, big), 0)
    if poly:
        ImageDraw.Draw(mask).polygon([(px * k + ox, py * ky + oy) for px, py in poly], fill=255)
    if circle is None:
        ImageDraw.Draw(mask).ellipse((l, t, r - 1, b - 1), fill=255)
    rgb = canvas.convert('RGB').resize((size, size), Image.LANCZOS)
    alpha = mask.resize((size, size), Image.BOX).point(lambda v: 0 if v < 8 else v)
    if circle is not None:
        alpha = ImageChops.lighter(alpha, circle)
    rgb.putalpha(alpha)
    return rgb


def replace_white_background(src, colour):
    rgb = src.convert('RGB')
    w, h = rgb.size
    seeds = [(x, 0) for x in range(0, w, 8)] + [(x, h - 1) for x in range(0, w, 8)] + \
            [(0, y) for y in range(0, h, 8)] + [(w - 1, y) for y in range(0, h, 8)]
    marker = (255, 0, 255)
    for seed in seeds:
        if min(rgb.getpixel(seed)) >= 225:
            ImageDraw.floodfill(rgb, seed, marker, thresh=40)
    out = Image.new('RGBA', (w, h))
    px_in, px_out = rgb.load(), out.load()
    for yy in range(h):
        for xx in range(w):
            px_out[xx, yy] = colour + (255,) if px_in[xx, yy] == marker else px_in[xx, yy] + (255,)
    return out


def picture_circle(src, name):
    w, h = src.size
    if name in RADIUS:
        return (w - 1) / 2.0, (h - 1) / 2.0, RADIUS[name]
    box = src.convert('L').point(lambda v: 255 if v > DARK else 0).getbbox() or (0, 0, w, h)
    cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
    half = min(box[2] - box[0], box[3] - box[1]) / 2.0 / w
    r = max(R_MIN, min(R_MAX, half - MARGIN))
    # keep the crop inside the source
    cx = min(max(cx, r * w), w - r * w)
    cy = min(max(cy, r * w), h - r * w)
    return cx, cy, r


def largest_source(folder):
    best = None
    for f in os.listdir(folder):
        if f.lower().endswith(('.dds', '.png')):
            p = os.path.join(folder, f)
            w = Image.open(p).size[0]
            if best is None or w > best[0]:
                best = (w, p)
    return best[1]


def write_bc3(img, out_path):
    """BC3 (DXT5) with one mip level, like texconv -f BC3_UNORM -m 1, using Pillow"""
    img.convert('RGBA').save(out_path, pixel_format='DXT5')
    b = bytearray(open(out_path, 'rb').read())
    flags = struct.unpack_from('<I', b, 8)[0] | 0x20000  # DDSD_MIPMAPCOUNT
    struct.pack_into('<I', b, 8, flags)
    struct.pack_into('<I', b, 28, 1)
    open(out_path, 'wb').write(bytes(b))


def build(kind, name):
    out_dir, sizes = KINDS[kind][0], KINDS[kind][1]
    src = Image.open(largest_source(os.path.join(REPO, 'art_sources', kind, name))).convert('RGBA')
    if name in WHITE_BACKGROUND:
        src = replace_white_background(src, WHITE_BACKGROUND[name])
    cx, cy, r = picture_circle(src, name)
    r /= ZOOM.get(name, 1.0)
    d = r * src.size[0]
    box = (cx - d, cy - d, cx + d, cy + d)
    tmp = tempfile.mkdtemp()
    for sz in sizes:
        p = os.path.join(tmp, '%s_%d.png' % (name, sz))
        img = icon(src, box, sz, circle_box(kind, sz), BREAKOUT.get(name), base_mask(kind, sz))
        if not os.path.exists(TEXCONV):
            write_bc3(img, os.path.join(out_dir, '%s_%d.dds' % (name, sz)))
            continue
        img.save(p)
        subprocess.check_call([TEXCONV, '-nologo', '-y', '-f', 'BC3_UNORM', '-m', '1', '-o', out_dir, p],
                              stdout=subprocess.DEVNULL)
    print('built %s %s (picture radius %.3f)' % (kind, name, r))


if __name__ == '__main__':
    if len(sys.argv) < 3 or sys.argv[1] not in KINDS:
        sys.exit(__doc__)
    for n in sys.argv[2:]:
        build(sys.argv[1], n)
