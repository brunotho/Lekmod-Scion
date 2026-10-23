"""Build Lekmod promotion icons from their original sources (art_sources/promotions/manifest.csv).

Usage (from the repo root):
    python art_sources/tools/build_promotion_icons.py [--preview out.png] [name ...]
No names = every icon in the manifest. Writes LEKMOD/Art/Promotions/<name>_{256,64,45,32}.dds.
Needs Pillow and texconv.exe (civ-tools\texconv.exe, or set TEXCONV).

Pipeline (see art_sources/README.md for the reasons behind each step):
 1. load the source (any size), upscale to 256 px
 2. key out the background: only background connected to the border becomes transparent (reshape_icons.reshape);
    manifest column key=all also clears enclosed dark areas (outline shapes such as the Nuke Resistance shield)
 3. crop to the glyph and fit it into <scale> of the 256 px canvas (0.72 normally), centred
 4. even out the baked-in lighting: gold/orange pixels get the same bright gold, dark details stay
 5. shift the glyph 4 px right (1 px at 64 px, where the promotion choice looked off-centre; 8 px looked too far right)
 6. 256 px: BC3 (DXT5) with mips;  64/45 px: LANCZOS downscale, uncompressed B8G8R8A8, one mip
 7. 32 px: blue square tile (base-game earned-promotion style) with the gold glyph, uncompressed
"""
import colorsys, csv, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SRC_DIR = os.path.join(REPO, 'art_sources', 'promotions')
OUT_DIR = os.path.join(REPO, 'LEKMOD', 'Art', 'Promotions')
TEXCONV = os.environ.get('TEXCONV', os.path.join(os.path.dirname(REPO), 'texconv.exe'))
sys.path.insert(0, HERE)
import reshape_icons  # noqa: E402

SHIFT_X = 4          # at 256 px (8 until 2026-10-23: then they looked a hair too far right)
TILE = (4, 5, 27, 28)  # 32 px tile box


def key_dark_everywhere(im):
    """Also clear enclosed dark areas (e.g. the inside of an outline shield): same alpha ramp as reshape_icons."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if max(r, g) <= 90:
                px[x, y] = (r, g, b, min(a, max(0, min(255, (max(r, g) - 60) * 255 // 30))))
    return im


def key_out(src, scale, key='border'):
    im = src.convert('RGBA').resize((256, 256), Image.LANCZOS)
    glyph = reshape_icons.reshape(im)                       # transparent background, glyph at 72%
    if key == 'all':
        glyph = key_dark_everywhere(glyph)
    glyph = glyph.crop(glyph.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox())
    s = int(256 * scale)
    glyph.thumbnail((s, s), Image.LANCZOS)
    out = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    out.alpha_composite(glyph, ((256 - glyph.width) // 2, (256 - glyph.height) // 2))
    return out


def even(im, target_v=0.97):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 25 / 360 <= h <= 60 / 360 and s > 0.45 and v > 0.35:
                r2, g2, b2 = colorsys.hsv_to_rgb(max(h, 42 / 360), s, max(v, target_v))
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


def shift(im, dx):
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.alpha_composite(im, (dx, 0))
    return out


def tile32(icon256):
    S = 4
    w = 32 * S
    base = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    x0, y0, x1, y1 = [v * S for v in TILE]
    px = base.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = ((x - x0) / (x1 - x0) + (y - y0) / (y1 - y0)) / 2
            r, g, b = 28 + 22 * t, 50 + 50 * t, 88 + 22 * t
            if min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y) < S:
                r, g, b = r + 35, g + 35, b + 40
            px[x, y] = (int(r), int(g), int(b), 255)
    g = icon256.crop(icon256.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox())
    inner = (x1 - x0) - 5 * S
    g.thumbnail((inner, inner), Image.LANCZOS)
    base.alpha_composite(g, (x0 + ((x1 - x0) - g.width) // 2, y0 + ((y1 - y0) - g.height) // 2))
    return base.resize((32, 32), Image.LANCZOS)


def write(im, name, fmt, mips, tmp):
    p = os.path.join(tmp, name + '.png')
    im.save(p)
    subprocess.check_call([TEXCONV, '-nologo', '-y', '-f', fmt, '-m', str(mips), '-o', OUT_DIR, p], stdout=subprocess.DEVNULL)


def build(row, tmp):
    src = Image.open(os.path.join(SRC_DIR, row['source']))
    icon = shift(even(key_out(src, float(row['scale']), row.get('key') or 'border')), SHIFT_X + int(row.get('dx') or 0))  # dx: per-icon correction (manifest)
    n = row['name']
    write(icon, n + '_256', 'BC3_UNORM', 0, tmp)
    for sz in (64, 45):
        write(icon.resize((sz, sz), Image.LANCZOS), '%s_%d' % (n, sz), 'B8G8R8A8_UNORM', 1, tmp)
    write(tile32(icon), n + '_32', 'B8G8R8A8_UNORM', 1, tmp)
    return icon


def main(argv):
    preview = None
    if argv[:1] == ['--preview']:
        preview, argv = argv[1], argv[2:]
    rows = list(csv.DictReader(open(os.path.join(SRC_DIR, 'manifest.csv'), encoding='utf-8')))
    if argv:
        rows = [r for r in rows if r['name'] in argv]
    tmp = tempfile.mkdtemp()
    icons = []
    for r in rows:
        if preview:
            icons.append(shift(even(key_out(Image.open(os.path.join(SRC_DIR, r['source'])), float(r['scale']), r.get('key') or 'border')), SHIFT_X + int(r.get('dx') or 0)))
        else:
            icons.append(build(r, tmp))
            print('built', r['name'])
    if preview:
        sheet = Image.new('RGBA', (len(icons) * 140, 140), (25, 30, 45, 255))
        for i, im in enumerate(icons):
            sheet.alpha_composite(im.resize((64, 64), Image.LANCZOS).resize((128, 128), Image.NEAREST), (i * 140 + 6, 6))
        sheet.save(preview)


if __name__ == '__main__':
    main(sys.argv[1:])
