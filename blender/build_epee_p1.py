# Épée de départ du héros pour Pick Me Up (Roblox), style P1 : lame d'acier clair à section en losange,
# garde et pommeau d'argent bruni, poignée de cuir sombre. 1 unité = 1 stud.
# Origine au centre de la poignée (là où la main la tient), lame vers le haut (+Z Blender = +Y Roblox).
# Toutes les pièces sont convexes : enveloppes convexes, normales recalculées puis contrôlées.
# Usage : blender -b --factory-startup --python build_epee_p1.py
import bpy, bmesh, math, os
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, metallic=0.0, rough=0.5):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[srgb(c) for c in rgb255], 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    m.use_backface_culling = True
    return m

M = {
    "Lame": material("Epee_Lame", (214, 222, 232), metallic=1.0, rough=0.25),
    "Garde": material("Epee_Garde", (150, 160, 176), metallic=1.0, rough=0.4),
    "Poignee": material("Epee_Poignee", (58, 44, 34), rough=0.85),
}

# ---------------------------------------------------------------- cotes
POIGNEE_R, POIGNEE_H = 0.11, 0.9          # rayon et longueur de la poignée, centrée sur l'origine
GARDE_Z0, GARDE_Z1 = 0.45, 0.62
LAME_Z0, LAME_EPAULE, LAME_POINTE = 0.62, 3.1, 3.45
LAME_L, LAME_E = 0.3, 0.075               # largeur et épaisseur à la base

def enveloppe(bm, points):
    verts = [bm.verts.new(Vector(p)) for p in points]
    res = bmesh.ops.convex_hull(bm, input=verts)
    # sommets restés à l'intérieur de l'enveloppe
    bmesh.ops.delete(bm, geom=[v for v in res["geom_interior"] if isinstance(v, bmesh.types.BMVert)], context='VERTS')

def cercle(r, z, n=12, rot=0.0):
    return [(r * math.cos(rot + 2 * math.pi * i / n), r * math.sin(rot + 2 * math.pi * i / n), z) for i in range(n)]

def piece(nom, cle, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / 2, loop.vert.co[b] / 2)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[cle])
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    return ob

objets = []

# lame : section en losange (fil des deux côtés), légère conicité, épaulement puis pointe
bm = bmesh.new()
def losange(l, e, z):
    return [(l / 2, 0, z), (0, e / 2, z), (-l / 2, 0, z), (0, -e / 2, z)]
enveloppe(bm, losange(LAME_L, LAME_E, LAME_Z0) + losange(LAME_L * 0.8, LAME_E * 0.85, LAME_EPAULE)
          + [(0, 0, LAME_POINTE)])
objets.append(piece("Epee_P1_Lame", "Lame", bm))

# garde : traverse évasée aux extrémités, renflement central, deux pièces convexes
bm_garde = bmesh.new()
enveloppe(bm_garde, [(x * s, y, z) for x in (0.65,) for s in (1, -1) for y in (0.1, -0.1) for z in (GARDE_Z0 + 0.02, GARDE_Z1 - 0.02)]
          + [(x * s, y, z) for x in (0.45,) for s in (1, -1) for y in (0.08, -0.08) for z in (GARDE_Z0 + 0.04, GARDE_Z1 - 0.04)]
          + [(0.67 * s, 0, z) for s in (1, -1) for z in (GARDE_Z0 + 0.04, GARDE_Z1 - 0.04)])
# renflement central, dans le même maillage d'argent (chaque enveloppe reste une pièce à part)
enveloppe(bm_garde, [(0.18 * s, 0, z) for s in (1, -1) for z in (GARDE_Z0, GARDE_Z1)]
          + [(0, 0.15 * s, z) for s in (1, -1) for z in (GARDE_Z0, GARDE_Z1)] + [(0, 0, GARDE_Z0 - 0.08)])
# pommeau : octaèdre arrondi sous la poignée
pz = -POIGNEE_H / 2 - 0.15
enveloppe(bm_garde, cercle(0.16, pz, 10) + cercle(0.1, pz + 0.12, 10, 0.3) + cercle(0.1, pz - 0.12, 10, 0.3)
          + [(0, 0, pz + 0.16), (0, 0, pz - 0.17)])
objets.append(piece("Epee_P1_Garde", "Garde", bm_garde))

# poignée : cylindre de cuir légèrement renflé au milieu, bagues aux deux bouts
bm = bmesh.new()
h = POIGNEE_H / 2
enveloppe(bm, cercle(POIGNEE_R * 0.92, -h, 12) + cercle(POIGNEE_R, 0, 12) + cercle(POIGNEE_R * 0.92, h, 12))
objets.append(piece("Epee_P1_Poignee", "Poignee", bm))

# ---------------------------------------------------------------- contrôle
print("\n=== MAILLAGES ===")
for ob in objets:
    me = ob.data
    me.calc_loop_triangles()
    vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
              for t in me.loop_triangles)
    print(f"{ob.name} : {len(me.loop_triangles)} triangles, {'à l envers' if vol < 0 else 'ok'}")

for ob in bpy.data.objects:
    ob.select_set(ob in objets)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Epee_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçu
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 900, 1200
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.36, 0.42, 1)
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = Vector((3.2, -6.0, 2.2))
cam.rotation_euler = (Vector((0, 0, 1.35)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(APERCUS, "epee_p1.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "epee_p1.blend"))
print("OK")
