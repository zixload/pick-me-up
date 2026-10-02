# Touffes d'herbe haute pour la base de Pick Me Up (Roblox) : la hauteur des brins du Terrain est
# un réglage global, donc la variation de hauteur vient de ces touffes semées par plaques.
# Trois variantes (A, B, C), un maillage chacune, origine au sol au centre ; exportées ensemble,
# écartées de 10 studs. Usage : blender -b --factory-startup --python build_herbe_haute_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(31)

def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[srgb(c) for c in rgb255], 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    m.use_backface_culling = True
    return m

def oriente(bm, faces):
    vol = 0.0
    for f in faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1]))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=faces)

def brin(bm, x, y, h, largeur):
    """Brin courbé : section triangulaire qui s'affine sur deux segments, pointe penchée."""
    a = rnd.uniform(0, 2 * math.pi)
    penche = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.15, 0.45) * h
    rot = rnd.uniform(0, 2 * math.pi)
    def section(t, w):
        c = Vector((x, y, 0)) + penche * (t ** 1.8) + Vector((0, 0, h * t))
        return [bm.verts.new(c + Vector((math.cos(rot + k * 2.094), math.sin(rot + k * 2.094), 0)) * w) for k in range(3)]
    s0, s1 = section(0.0, largeur), section(0.55, largeur * 0.6)
    pointe = bm.verts.new(Vector((x, y, 0)) + penche + Vector((0, 0, h)))
    faces = [bm.faces.new(list(reversed(s0)))]
    for i in range(3):
        j = (i + 1) % 3
        faces.append(bm.faces.new((s0[i], s0[j], s1[j], s1[i])))
        faces.append(bm.faces.new((s1[i], s1[j], pointe)))
    oriente(bm, faces)

VARIANTES = [("A", (90, 144, 62), 2.6), ("B", (106, 156, 70), 3.2), ("C", (82, 132, 56), 2.2)]
COLL = bpy.data.collections.new("HERBE_HAUTE")
scene.collection.children.link(COLL)
objets = []
for i, (lettre, couleur, hmax) in enumerate(VARIANTES):
    bm = bmesh.new()
    ox = i * 10.0
    for _ in range(rnd.randint(30, 40)):
        a, d = rnd.uniform(0, 2 * math.pi), 1.1 * math.sqrt(rnd.random())
        h = hmax * rnd.uniform(0.55, 1.0) * (1.0 - 0.35 * d / 1.1)   # plus haut au centre
        brin(bm, ox + d * math.cos(a), d * math.sin(a), h, rnd.uniform(0.05, 0.09))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(f"HerbeHaute_{lettre}")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material(f"HerbeHaute_{lettre}", couleur))
    ob = bpy.data.objects.new(f"HerbeHaute_{lettre}", me)
    COLL.objects.link(ob)
    objets.append(ob)

total, negatifs = 0, []
for ob in objets:
    me = ob.data
    me.calc_loop_triangles()
    total += len(me.loop_triangles)
    if sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
           for t in me.loop_triangles) < 0:
        negatifs.append(ob.name)
print(f"{len(objets)} maillages, {total} triangles pour les 3 touffes")
print("Maillages à l'envers :", negatifs if negatifs else "aucun")

for ob in bpy.data.objects:
    ob.select_set(False)
for ob in objets:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Herbe_Haute_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# aperçu
sol = bpy.data.meshes.new("Sol")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
bm.to_mesh(sol)
bm.free()
sol.materials.append(material("Herbe", (98, 150, 72)))
o = bpy.data.objects.new("Sol", sol)
o.location = (10, 0, 0)
scene.collection.objects.link(o)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 600
scene.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.76, 1)
sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 3.5
sun = bpy.data.objects.new("Soleil", sun_data)
sun.rotation_euler = (math.radians(45), 0, math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.data.lens = 35
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (10, -15, 4)
cam.rotation_euler = (Vector((10, 0, 1.2)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = os.path.join(APERCUS, "herbe_haute_p1.png")
bpy.ops.render.render(write_still=True)
print("OK")
