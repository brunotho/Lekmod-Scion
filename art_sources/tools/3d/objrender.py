"""Tiny flat-shaded OBJ preview with Pillow: painter's algorithm, colour = texture sampled at the triangle's UV centroid.
usage: objrender.py <obj> <tex dir> <out.png>"""
import sys, os, math
from PIL import Image, ImageDraw
obj, texdir, out = sys.argv[1:4]
V, VT, F = [], [], []
mtl_tex = {}
mtlfile = os.path.splitext(obj)[0] + '.mtl'
cur = None
for line in open(mtlfile, encoding='latin-1'):
    t = line.split()
    if not t: continue
    if t[0] == 'newmtl': cur = ' '.join(t[1:])
    elif t[0] == 'map_Kd' and cur: mtl_tex[cur] = os.path.basename(t[1].replace('\\', '/'))
texcache = {}
def tex(name):
    if name not in texcache:
        try: texcache[name] = Image.open(os.path.join(texdir, name)).convert('RGBA')
        except Exception: texcache[name] = None
    return texcache[name]
mtl = None
for line in open(obj, encoding='latin-1'):
    t = line.split()
    if not t: continue
    if t[0] == 'v': V.append(tuple(map(float, t[1:4])))
    elif t[0] == 'vt': VT.append(tuple(map(float, t[1:3])))
    elif t[0] == 'usemtl': mtl = ' '.join(t[1:])
    elif t[0] == 'f':
        idx = [x.split('/') for x in t[1:]]
        vs = [int(a[0]) - 1 for a in idx]; ts = [int(a[1]) - 1 if len(a) > 1 and a[1] else -1 for a in idx]
        for k in range(1, len(vs) - 1):
            F.append(((vs[0], vs[k], vs[k + 1]), (ts[0], ts[k], ts[k + 1]), mtl))

def view(yaw, pitch, W=700, H=520):
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    def rot(p):
        x, y, z = p                      # y is up in this model
        x, z = x * cy - z * sy, x * sy + z * cy
        y, z = y * cp - z * sp, y * sp + z * cp
        return x, y, z
    P = [rot(p) for p in V]
    xs = [p[0] for p in P]; ys = [p[1] for p in P]
    sc = 0.9 * min(W / (max(xs) - min(xs)), H / (max(ys) - min(ys)))
    ox, oy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    img = Image.new('RGB', (W, H), (70, 90, 70)); d = ImageDraw.Draw(img)
    light = (0.4, 0.8, -0.45)
    tris = []
    for vs, ts, m in F:
        a, b, c = (P[i] for i in vs)
        n = ((b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]), (b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]), (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))
        ln = math.sqrt(sum(x * x for x in n)) or 1
        shade = 0.35 + 0.65 * abs(sum(n[k] / ln * light[k] for k in range(3)))
        col = (150, 150, 140)
        im = tex(mtl_tex.get(m, ''))
        if im is not None and min(ts) >= 0:
            u = sum(VT[i][0] for i in ts) / 3 % 1; v = sum(VT[i][1] for i in ts) / 3 % 1
            px = im.getpixel((min(im.width - 1, int(u * im.width)), min(im.height - 1, int((1 - v) * im.height))))
            if px[3] < 40: continue
            col = px[:3]
        col = tuple(int(x * shade) for x in col)
        tris.append(((a[2] + b[2] + c[2]) / 3, [(W / 2 + (p[0] - ox) * sc, H / 2 - (p[1] - oy) * sc) for p in (a, b, c)], col))
    for _, pts, col in sorted(tris, key=lambda t: -t[0]):
        d.polygon(pts, fill=col)
    return img

a = view(math.radians(30), math.radians(-50))   # high three-quarter, like the game camera
b = view(math.radians(90), math.radians(0))     # side
c = view(math.radians(0), math.radians(-90))    # top
sheet = Image.new('RGB', (1400, 1040), (40, 40, 40))
sheet.paste(a, (0, 0)); sheet.paste(b, (700, 0)); sheet.paste(c, (0, 520))
sheet.paste(a.resize((140, 104)), (900, 700))   # about game size
sheet.save(out)
print('saved', out)
