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
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TEXCONV = os.environ.get('TEXCONV', os.path.join(os.path.dirname(REPO), 'texconv.exe'))
KINDS = {
    # kind: (output folder, sizes, (diameter, x, y) in a 256 px cell)
    'buildings': (os.path.join(REPO, 'LEKMOD', 'Art', 'Lekmod (v 1)', 'Art', 'Buildings'),
                  (32, 45, 64, 80, 128, 214, 256), (175, 41, 40)),
    'units': (os.path.join(REPO, 'LEKMOD', 'Art', 'Units'),
              (32, 45, 64, 80, 128, 256), (177, 39, 40)),
}
DARK, MARGIN, R_MIN, R_MAX = 20, 0.05, 0.38, 0.47
RADIUS = {
    'barlas_cavalry': 0.435,  # gold ring painted on from radius 0.455
    'bajoras': 0.435,         # gold ring painted on from radius 0.455
    'vanguard_corps': 0.5,    # soldier on black, shown whole
    'mahamatras_office': 0.5, # full-bleed scene, shown whole
}
# sources delivered as a cut-out on white: the white connected to the edges becomes this background colour
WHITE_BACKGROUND = {'ministry_of_truth': (22, 22, 24)}


def icon(src, size, layout):
    s = 4
    big = size * s
    d = int(round(layout[0] / 256.0 * big))
    x, y = int(round(layout[1] / 256.0 * big)), int(round(layout[2] / 256.0 * big))
    art = src.resize((d, d), Image.LANCZOS)
    mask = Image.new('L', (d, d), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d - 1, d - 1), fill=255)
    art.putalpha(Image.composite(art.getchannel('A'), Image.new('L', (d, d), 0), mask))
    canvas = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    canvas.alpha_composite(art, (x, y))
    return canvas.resize((size, size), Image.LANCZOS)


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
    out_dir, sizes, layout = KINDS[kind]
    src = Image.open(largest_source(os.path.join(REPO, 'art_sources', kind, name))).convert('RGBA')
    if name in WHITE_BACKGROUND:
        src = replace_white_background(src, WHITE_BACKGROUND[name])
    cx, cy, r = picture_circle(src, name)
    d = r * src.size[0]
    src = src.crop((int(round(cx - d)), int(round(cy - d)), int(round(cx + d)), int(round(cy + d))))
    tmp = tempfile.mkdtemp()
    for sz in sizes:
        p = os.path.join(tmp, '%s_%d.png' % (name, sz))
        img = icon(src, sz, layout)
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
