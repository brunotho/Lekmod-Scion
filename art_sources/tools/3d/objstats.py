import sys, collections
p = sys.argv[1]
v = []; vt = 0; groups = collections.OrderedDict(); cur = ('?', '?'); mtl = '?'; obj = '?'
tris = collections.Counter(); bbox = {}
for line in open(p, encoding='latin-1'):
    t = line.split()
    if not t: continue
    if t[0] == 'v':
        v.append(tuple(map(float, t[1:4])))
    elif t[0] == 'vt':
        vt += 1
    elif t[0] in ('o', 'g'):
        obj = ' '.join(t[1:]) or '?'
    elif t[0] == 'usemtl':
        mtl = ' '.join(t[1:])
    elif t[0] == 'f':
        n = len(t) - 1
        key = (obj, mtl)
        tris[key] += n - 2
        idx = [int(x.split('/')[0]) for x in t[1:]]
        b = bbox.setdefault(obj, [[1e9] * 3, [-1e9] * 3])
        for i in idx:
            x = v[i - 1 if i > 0 else len(v) + i]
            for k in range(3):
                b[0][k] = min(b[0][k], x[k]); b[1][k] = max(b[1][k], x[k])
print('vertices', len(v), 'uvs', vt, 'triangles', sum(tris.values()))
mins = [min(x[k] for x in v) for k in range(3)]; maxs = [max(x[k] for x in v) for k in range(3)]
print('size x/y/z', [round(maxs[k] - mins[k], 2) for k in range(3)])
by_obj = collections.Counter(); by_mtl = collections.Counter()
for (o, m), n in tris.items():
    by_obj[o] += n; by_mtl[m] += n
print('\nobjects/groups:', len(by_obj))
for o, n in by_obj.most_common(40):
    b = bbox[o]; c = [round((b[0][k] + b[1][k]) / 2, 2) for k in range(3)]; sz = [round(b[1][k] - b[0][k], 2) for k in range(3)]
    print(f'  {n:6} tris  {o[:40]:40} center {c} size {sz}')
print('\nmaterials:')
for m, n in by_mtl.most_common(): print(f'  {n:6} tris  {m}')
