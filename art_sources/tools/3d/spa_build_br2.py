# blender -b --python spa_build_br2.py -- <modernarmor_ref.blend> <spa_prepared.blend> <out.br2> <out.blend>
# Puts the prepared SPA mesh on the Modern Armor skeleton (imported from Nexus Buddy's NB2) and exports BR2.
import bpy, sys, math, addon_utils
from mathutils import Matrix, Vector
addon_utils.enable('io_export_br2')
argv = sys.argv[sys.argv.index('--') + 1:]
REF, SPA, OUT_BR2, OUT_BLEND = argv

bpy.ops.wm.open_mainfile(filepath=REF)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
ref_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')
ref_pts = [ref_mesh.matrix_world * v.co for v in ref_mesh.data.vertices]
ref_min = [min(p[k] for p in ref_pts) for k in range(3)]
ref_max = [max(p[k] for p in ref_pts) for k in range(3)]
bpy.data.objects.remove(ref_mesh, do_unlink=True)

with bpy.data.libraries.load(SPA) as (src, dst):
    dst.objects = ['SPA']
spa = dst.objects[0]
bpy.context.scene.objects.link(spa)

# face -Y like the tank (the Ha-To's gun end is +X), match the tank's length, centre on X/Y, stand on its ground level
pts = [spa.matrix_world * v.co for v in spa.data.vertices]   # the OBJ importer keeps its Y-up turn as object rotation
rot = Matrix.Rotation(math.radians(-90), 4, 'Z')
pts = [rot * p for p in pts]
length = max(p.y for p in pts) - min(p.y for p in pts)
s = (ref_max[1] - ref_min[1]) * 0.97 / length
cx = (max(p.x for p in pts) + min(p.x for p in pts)) / 2
cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2
mz = min(p.z for p in pts)
ref_cy = (ref_max[1] + ref_min[1]) / 2
for v, p in zip(spa.data.vertices, pts):
    v.co = Vector(((p.x - cx) * s, (p.y - cy) * s + ref_cy, (p.z - mz) * s + ref_min[2]))
spa.matrix_world = Matrix.Identity(4)
spa.data.update()
spa.data.calc_normals()

# bones: everything on tank_bone_body; the lowest track vertices also on tank_bone_main (meshes need 2+ bones)
for g in list(spa.vertex_groups):
    spa.vertex_groups.remove(g)
body = spa.vertex_groups.new('tank_bone_body')
main = spa.vertex_groups.new('tank_bone_main')
zs = sorted(v.co.z for v in spa.data.vertices)
zcut = zs[int(len(zs) * 0.02)]
low = [v.index for v in spa.data.vertices if v.co.z <= zcut]
body.add([v.index for v in spa.data.vertices if v.co.z > zcut], 1.0, 'REPLACE')
main.add(low, 1.0, 'REPLACE')

spa.parent = arm
for m in list(spa.modifiers):
    spa.modifiers.remove(m)
mod = spa.modifiers.new('Armature', 'ARMATURE')
mod.object = arm

p2 = [v.co for v in spa.data.vertices]
print('SCALE', round(s, 3))
print('SPA BBOX min', [round(min(p[k] for p in p2), 1) for k in range(3)], 'max', [round(max(p[k] for p in p2), 1) for k in range(3)])
print('REF BBOX min', [round(x, 1) for x in ref_min], 'max', [round(x, 1) for x in ref_max])
print('GROUPS body', len(spa.data.vertices) - len(low), 'main', len(low))

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.export_shape.br2(filepath=OUT_BR2)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print('BR2', OUT_BR2)
