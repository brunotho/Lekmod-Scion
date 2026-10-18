# Blender 2.79 background script: Ha-To OBJ -> one mesh, ~3,000 triangles, one baked 512 texture,
# vertex groups MAIN / GUN for the later bone binding.
#   blender.exe -b --python spa_prepare.py -- <obj> <out_dir>
import bpy, sys, os, bmesh

argv = sys.argv[sys.argv.index('--') + 1:]
OBJ, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)

# empty scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.obj(filepath=OBJ)
scene = bpy.context.scene

GUN_PARTS = ('gun', 'gun_rot')
RATIO = {'body': 0.75, 'gun': 0.5, 'turret': 0.8, 'engine': 1.0, 'gun_rot': 1.0, 'doorl': 0.8, 'doorr': 0.8,
         'trackl': 0.8, 'trackr': 0.8, 'wheelsl': 0.4, 'wheelsr': 0.4}
WHEEL_RATIO = 0.18

def base(name):
    return name.split('.')[0].split('#')[0]

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in meshes:
    if base(o.name).startswith('enumerator'):
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']

def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
print('IMPORTED', len(meshes), 'objects', tris(meshes), 'triangles')

for o in meshes:
    scene.objects.active = o
    n = base(o.name)
    vg = o.vertex_groups.new('GUN' if n in GUN_PARTS else 'MAIN')
    vg.add(range(len(o.data.vertices)), 1.0, 'REPLACE')
    r = RATIO.get(n, WHEEL_RATIO if n.startswith('wheel') else 1.0)
    if r < 1.0:
        m = o.modifiers.new('dec', 'DECIMATE')
        m.ratio = r
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier='dec')

# Cycles nodes for every material: original texture through the original UV map -> emission
scene.render.engine = 'CYCLES'
bake_img = bpy.data.images.new('spa_diff', 512, 512, alpha=False)
for mat in bpy.data.materials:
    img = None
    for ts in mat.texture_slots:
        if ts and ts.texture and ts.texture.type == 'IMAGE' and ts.texture.image and ts.use_map_color_diffuse:
            img = ts.texture.image
            break
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(em.outputs[0], out.inputs[0])
    if img:
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
        nt.links.new(uv.outputs[0], tex.inputs[0]); nt.links.new(tex.outputs[0], em.inputs[0])
    else:
        em.inputs[0].default_value = (0.35, 0.35, 0.3, 1)
    target = nt.nodes.new('ShaderNodeTexImage'); target.image = bake_img
    for nd in nt.nodes:
        nd.select = False
    target.select = True
    nt.nodes.active = target

# join into one object
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    if o.name in bpy.data.objects:
        o.select = True
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
scene.objects.active = meshes[0]
for o in meshes:
    o.select = True
bpy.ops.object.join()
spa = scene.objects.active
spa.name = 'SPA'
for uvl in spa.data.uv_textures:
    pass
print('JOINED', tris([spa]), 'triangles,', len(spa.data.vertices), 'vertices, uv layers', [u.name for u in spa.data.uv_textures])

# new UV layout for the single texture
orig_uv = spa.data.uv_textures[0].name
for nd_mat in bpy.data.materials:
    for nd in nd_mat.node_tree.nodes:
        if nd.type == 'UVMAP':
            nd.uv_map = orig_uv
bake_uv = spa.data.uv_textures.new('BakeUV')
spa.data.uv_textures.active = bake_uv
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=60, island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')

scene.cycles.samples = 4
scene.render.bake.margin = 4
bpy.ops.object.bake(type='EMIT')
bake_img.filepath_raw = os.path.join(OUT, 'spa_diff_bake.png')
bake_img.file_format = 'PNG'
bake_img.save()
print('BAKED', bake_img.filepath_raw)

# keep only the new UV layout and one material with the baked texture
spa.data.uv_textures.active = bake_uv
spa.data.uv_textures.remove(spa.data.uv_textures[orig_uv])
final = bpy.data.materials.new('SPA_DIFF')
final.use_nodes = True
spa.data.materials.clear()
spa.data.materials.append(final)
tslot = final.texture_slots.add()
tex = bpy.data.textures.new('spa_diff', 'IMAGE'); tex.image = bake_img
tslot.texture = tex
tslot.texture_coords = 'UV'

bpy.ops.export_scene.obj(filepath=os.path.join(OUT, 'spa_prepared.obj'), use_selection=True, use_materials=True,
                         use_triangles=True, path_mode='RELATIVE')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'spa_prepared.blend'))
print('DONE', tris([spa]), 'triangles; groups', [g.name for g in spa.vertex_groups])
