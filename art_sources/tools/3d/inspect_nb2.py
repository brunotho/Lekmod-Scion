# blender -b --python inspect_nb2.py -- <file.nb2> <out.blend>
import bpy, sys, addon_utils
addon_utils.enable('io_import_nb2'); addon_utils.enable('io_export_br2')
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:]
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_shape.nb2(filepath=argv[0])
for o in bpy.data.objects:
    print('OBJ', o.type, o.name, 'loc', tuple(round(x, 3) for x in o.location), 'rot', tuple(round(x, 3) for x in o.rotation_euler), 'scale', tuple(round(x, 3) for x in o.scale))
    if o.type == 'ARMATURE':
        for b in o.data.bones:
            h = o.matrix_world * b.head_local; t = o.matrix_world * b.tail_local
            print('  BONE', b.name, 'head', tuple(round(x, 2) for x in h), 'tail', tuple(round(x, 2) for x in t), 'parent', b.parent.name if b.parent else None)
    if o.type == 'MESH':
        ws = [o.matrix_world * v.co for v in o.data.vertices]
        mn = [min(v[k] for v in ws) for k in range(3)]; mx = [max(v[k] for v in ws) for k in range(3)]
        print('  BBOX min', [round(x, 2) for x in mn], 'max', [round(x, 2) for x in mx], 'size', [round(mx[k] - mn[k], 2) for k in range(3)])
        print('  TRIS', sum(len(p.vertices) - 2 for p in o.data.polygons), 'mods', [m.type for m in o.modifiers])
        for g in o.vertex_groups:
            vs = [o.matrix_world * v.co for v in o.data.vertices if any(x.group == g.index and x.weight > 0.5 for x in v.groups)]
            if vs:
                c = [round(sum(v[k] for v in vs) / len(vs), 2) for k in range(3)]
                mn = [round(min(v[k] for v in vs), 1) for k in range(3)]; mx = [round(max(v[k] for v in vs), 1) for k in range(3)]
                print('  VG', g.name, len(vs), 'verts, centre', c, 'min', mn, 'max', mx)
bpy.ops.wm.save_as_mainfile(filepath=argv[1])
