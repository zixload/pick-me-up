# Touffes de fleurs pour la base de Pick Me Up (Roblox) : quatre variantes basses et légères
# (blanche, lilas, jaune, mélangée) à semer par centaines le long des allées et dans l'herbe.
# 1 unité = 1 stud, origine au sol au centre de chaque touffe. Les touffes sont exportées
# ensemble, écartées de 10 studs ; dans Studio, elles se regroupent par préfixe (Fleurs_A_...).
# Usage : blender -b --factory-startup --python build_fleurs_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(77)

def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, rough=0.7):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[srgb(c) for c in rgb255], 1)
    bsdf.inputs["Roughness"].default_value = rough
    m.use_backface_culling = True
    return m

M_TIGE = material("Fleurs_Tige", (72, 122, 52))
M_COEUR = material("Fleurs_Coeur", (236, 184, 64))
PETALES = {
    "Blanc": (246, 244, 236),
    "Lilas": (184, 160, 226),
    "Jaune": (242, 210, 92),
}
M_PETALES = {k: material(f"Fleurs_Petales_{k}", v) for k, v in PETALES.items()}

def oriente(bm, faces):
    vol = 0.0
    for f in faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1]))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=faces)

def prisme_local(bm, pts, epaisseur, mat):
    """Polygone plat (x, y) d'épaisseur donnée, transformé par la matrice mat."""
    bas = [bm.verts.new(mat @ Vector((x, y, 0))) for x, y in pts]
    haut = [bm.verts.new(mat @ Vector((x, y, epaisseur))) for x, y in pts]
    faces = [bm.faces.new(list(reversed(bas))), bm.faces.new(haut)]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((bas[i], bas[j], haut[j], haut[i])))
    oriente(bm, faces)

def tige(bm, base, sommet, r=0.035):
    """Tige : prisme triangulaire fin entre deux points."""
    d = (sommet - base).normalized()
    u = d.orthogonal().normalized()
    v = d.cross(u)
    pts = [base + (u * math.cos(a) + v * math.sin(a)) * r for a in (0, 2.09, 4.19)]
    top = [sommet + (u * math.cos(a) + v * math.sin(a)) * r * 0.7 for a in (0, 2.09, 4.19)]
    b = [bm.verts.new(p) for p in pts]
    t = [bm.verts.new(p) for p in top]
    faces = [bm.faces.new(list(reversed(b))), bm.faces.new(t)]
    for i in range(3):
        j = (i + 1) % 3
        faces.append(bm.faces.new((b[i], b[j], t[j], t[i])))
    oriente(bm, faces)

def feuille(bm, x, y, h):
    """Feuille : lame plate inclinée vers l'extérieur."""
    a = rnd.uniform(0, 2 * math.pi)
    mat = Matrix.Translation((x, y, 0.02)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(rnd.uniform(25, 45)), 4, 'Y')
    pts = [(-0.12, 0), (0.12, 0), (0.1, h * 0.55), (0, h), (-0.1, h * 0.55)]
    prisme_local(bm, [(p[0], p[1]) for p in pts], 0.02, mat @ Matrix.Rotation(math.radians(-90), 4, 'X'))

def fleur(bm_p, bm_c, centre, r, inclinaison):
    """Fleur à cinq pétales (étoile plate) et cœur bombé."""
    pts = []   # cinq pétales arrondis : rayon modulé en |cos(2,5 a)|
    for k in range(20):
        a = 2 * math.pi * k / 20
        rr = r * (0.45 + 0.55 * abs(math.cos(2.5 * a)))
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    mat = (Matrix.Translation(centre) @ Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 4, 'Z')
           @ Matrix.Rotation(inclinaison, 4, 'X'))
    prisme_local(bm_p, pts, 0.05, mat)
    bmesh.ops.create_uvsphere(bm_c, u_segments=6, v_segments=4, radius=1.0,
                              matrix=mat @ Matrix.Translation((0, 0, 0.06)) @ Matrix.Diagonal((r * 0.32, r * 0.32, r * 0.2, 1)))

def finish(bm, name, mat, coll):
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob

COLL = bpy.data.collections.new("FLEURS")
scene.collection.children.link(COLL)
VARIANTES = [("A", ["Blanc"]), ("B", ["Lilas"]), ("C", ["Jaune"]), ("D", ["Blanc", "Lilas", "Jaune"])]
OBJETS = []
for i, (lettre, couleurs) in enumerate(VARIANTES):
    ox = i * 10.0
    bm_t, bm_c = bmesh.new(), bmesh.new()
    bm_p = {c: bmesh.new() for c in couleurs}
    for _ in range(rnd.randint(12, 16)):
        a, d = rnd.uniform(0, 2 * math.pi), 1.1 * math.sqrt(rnd.random())
        x, y = ox + d * math.cos(a), d * math.sin(a)
        h = rnd.uniform(0.45, 1.05)
        sommet = Vector((x + rnd.uniform(-0.15, 0.15), y + rnd.uniform(-0.15, 0.15), h))
        tige(bm_t, Vector((x, y, -0.05)), sommet)
        fleur(bm_p[rnd.choice(couleurs)], bm_c, sommet, rnd.uniform(0.22, 0.32), math.radians(rnd.uniform(-20, 20)))
    for _ in range(rnd.randint(14, 18)):   # feuillage fourni au pied
        a, d = rnd.uniform(0, 2 * math.pi), 1.3 * math.sqrt(rnd.random())
        feuille(bm_t, ox + d * math.cos(a), d * math.sin(a), rnd.uniform(0.5, 0.95))
    for _ in range(3):                      # petit coussin de feuilles
        a, d = rnd.uniform(0, 2 * math.pi), 0.5 * rnd.random()
        bmesh.ops.create_uvsphere(bm_t, u_segments=7, v_segments=4, radius=1.0,
            matrix=Matrix.Translation((ox + d * math.cos(a), d * math.sin(a), 0.05)) @ Matrix.Diagonal((rnd.uniform(0.5, 0.75), rnd.uniform(0.5, 0.75), 0.28, 1)))
    OBJETS.append(finish(bm_t, f"Fleurs_{lettre}_Tige", M_TIGE, COLL))
    OBJETS.append(finish(bm_c, f"Fleurs_{lettre}_Coeur", M_COEUR, COLL))
    for c, bm in bm_p.items():
        OBJETS.append(finish(bm, f"Fleurs_{lettre}_Petales{c}", M_PETALES[c], COLL))

total, negatifs = 0, []
for ob in OBJETS:
    me = ob.data
    me.calc_loop_triangles()
    total += len(me.loop_triangles)
    vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
              for t in me.loop_triangles)
    if vol < 0:
        negatifs.append(ob.name)
print(f"{len(OBJETS)} maillages, {total} triangles pour les 4 touffes")
print("Maillages à l'envers :", negatifs if negatifs else "aucun")

for ob in bpy.data.objects:
    ob.select_set(False)
for ob in OBJETS:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Fleurs_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# aperçu
sol = bpy.data.meshes.new("Sol")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
bm.to_mesh(sol)
bm.free()
sol.materials.append(material("Herbe", (98, 150, 72), 0.9))
o = bpy.data.objects.new("Sol", sol)
o.location = (15, 0, 0)
scene.collection.objects.link(o)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 700
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
cam.data.lens = 28
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (15, -20, 7)
cam.rotation_euler = (Vector((15, 0, 0.6)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = os.path.join(APERCUS, "fleurs_p1.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "fleurs_p1.blend"))
print("OK")
