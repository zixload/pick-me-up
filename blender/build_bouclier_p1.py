# Bouclier rond du héros pour Pick Me Up (Roblox), style P1 : planches de bois sombre légèrement bombées,
# cerclage et deux bandes d'acier, umbo et rivets d'argent bruni, sangle de cuir au dos.
# 1 unité = 1 stud. Face avant vers -Y (Blender), dos plat en y = DOS, centre du bouclier à l'origine.
# Chaque volume est une enveloppe convexe (une planche = boule ∩ dalle ∩ cylindre, donc convexe),
# normales recalculées puis contrôlées par le volume signé.
# Usage : blender -b --factory-startup --python build_bouclier_p1.py
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
    "Bois": material("Bouclier_Bois", (92, 64, 42), rough=0.8),
    "Metal": material("Bouclier_Metal", (120, 130, 145), metallic=1.0, rough=0.45),
    "Argent": material("Bouclier_Argent", (205, 212, 222), metallic=1.0, rough=0.3),
    "Cuir": material("Bouclier_Cuir", (58, 44, 34), rough=0.85),
}

# ---------------------------------------------------------------- cotes
R = 1.3                 # rayon du bouclier (cerclage compris)
R_PLANCHES = R - 0.06
DOS = 0.06              # plan du dos
Y_BORD = -0.06          # face avant au bord
BOMBE = 0.3             # la face avant avance de 0,3 au centre
RS = (R ** 2 + BOMBE ** 2) / (2 * BOMBE)   # rayon de la sphère qui donne ce bombé
YC = Y_BORD - BOMBE + RS                     # centre de cette sphère

def face(x, z, decalage=0.0):
    """Hauteur (y) de la face avant bombée au point (x, z), décalée vers l'avant si decalage > 0."""
    r2 = min(x * x + z * z, R * R)
    return YC - math.sqrt(RS * RS - r2) - decalage

def enveloppe(bm, points):
    verts = [bm.verts.new(Vector(p)) for p in points]
    res = bmesh.ops.convex_hull(bm, input=verts)
    bmesh.ops.delete(bm, geom=[v for v in res["geom_interior"] if isinstance(v, bmesh.types.BMVert)], context='VERTS')

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

# ---------------------------------------------------------------- planches : cinq bandes verticales
bm = bmesh.new()
N_PLANCHES, JOINT = 5, 0.035
largeur = 2 * R_PLANCHES / N_PLANCHES
for i in range(N_PLANCHES):
    x0 = -R_PLANCHES + i * largeur + JOINT / 2
    x1 = x0 + largeur - JOINT
    pts = []
    for k in range(5):
        x = x0 + (x1 - x0) * k / 4
        hz = math.sqrt(max(R_PLANCHES ** 2 - x * x, 0.0))
        for j in range(13):
            z = -hz + 2 * hz * j / 12
            pts.append((x, face(x, z), z))
            pts.append((x, DOS, z))
    enveloppe(bm, pts)
objets.append(piece("Bouclier_P1_Bois", "Bois", bm))

# ---------------------------------------------------------------- acier : cerclage et deux bandes
bm = bmesh.new()
N_CERCLE = 40
for i in range(N_CERCLE):
    a0, a1 = 2 * math.pi * i / N_CERCLE - 0.004, 2 * math.pi * (i + 1) / N_CERCLE + 0.004
    pts = []
    for a in (a0, a1):
        for r in (R - 0.11, R):
            x, z = r * math.cos(a), r * math.sin(a)
            pts.append((x, face(x, z, 0.035), z))
            pts.append((x, DOS + 0.02, z))
    enveloppe(bm, pts)
for zc in (-0.55, 0.55):   # bandes de renfort horizontales, posées sur la face bombée
    hx = math.sqrt(R_PLANCHES ** 2 - zc ** 2)
    pts = []
    for k in range(9):
        x = -hx + 2 * hx * k / 8
        for z in (zc - 0.09, zc + 0.09):
            pts.append((x, face(x, z, 0.03), z))
            pts.append((x, face(x, z, -0.03), z))
    enveloppe(bm, pts)
pts = []                    # collerette de l'umbo, à pans comme lui, posée sur la face bombée
for i in range(12):
    a = 2 * math.pi * (i + 0.5) / 12
    for r, dy in ((0.56, -0.02), (0.56, 0.035), (0.5, 0.05)):
        x, z = r * math.cos(a), r * math.sin(a)
        pts.append((x, face(x, z, dy), z))
enveloppe(bm, pts)
objets.append(piece("Bouclier_P1_Metal", "Metal", bm))

# ---------------------------------------------------------------- argent : umbo et rivets
bm = bmesh.new()
# umbo : un col droit qui sort de la collerette d'acier, puis une calotte basse à douze pans qui se
# referme en petite pointe (profil carèné, pas une demi-boule)
y_col = face(0, 0, 0.05)    # dessus de la collerette
PROFIL = [(0.34, 0.0), (0.34, 0.07), (0.31, 0.11), (0.25, 0.16), (0.16, 0.2), (0.07, 0.235), (0.0, 0.27)]
pts = []
for r, h in PROFIL:
    for i in range(12 if r > 0 else 1):
        a = 2 * math.pi * (i + 0.5) / 12
        pts.append((r * math.cos(a), y_col - h, r * math.sin(a)))
pts += [(0.34 * math.cos(2 * math.pi * (i + 0.5) / 12), y_col + 0.04, 0.34 * math.sin(2 * math.pi * (i + 0.5) / 12))
        for i in range(12)]   # le col s'enfonce un peu dans la collerette
enveloppe(bm, pts)
for i in range(6):          # rivets de la collerette
    a = 2 * math.pi * i / 6
    cx, cz = 0.46 * math.cos(a), 0.46 * math.sin(a)
    yc = face(cx, cz, 0.07)
    enveloppe(bm, [(cx + 0.05 * math.cos(2 * math.pi * k / 6), yc + 0.03, cz + 0.05 * math.sin(2 * math.pi * k / 6))
                   for k in range(6)] + [(cx, yc - 0.035, cz)])
rivets = [(R - 0.055, 2 * math.pi * i / 10) for i in range(10)]
rivets += [(rx, None) for rx in (-0.85, 0.85)]
for r, a in rivets:         # rivets sur le cerclage, et aux bouts des bandes
    centres = [(r * math.cos(a), r * math.sin(a))] if a is not None else [(r, -0.55), (r, 0.55)]
    for cx, cz in centres:
        yc = face(cx, cz, 0.06)
        pts = [(cx + 0.06 * math.cos(2 * math.pi * i / 6), yc + 0.03, cz + 0.06 * math.sin(2 * math.pi * i / 6))
               for i in range(6)] + [(cx, yc - 0.04, cz)]
        enveloppe(bm, pts)
objets.append(piece("Bouclier_P1_Argent", "Argent", bm))

# ---------------------------------------------------------------- cuir : sangle et poignée au dos
bm = bmesh.new()
def boite(x0, x1, y0_, y1, z0, z1):
    enveloppe(bm, [(x, y, z) for x in (x0, x1) for y in (y0_, y1) for z in (z0, z1)])
boite(-0.9, 0.9, DOS, DOS + 0.05, -0.14, 0.14)          # sangle d'avant-bras
boite(-0.14, 0.14, DOS, DOS + 0.24, -0.45, -0.3)        # poignée : deux tenons et une barre
boite(-0.14, 0.14, DOS, DOS + 0.24, 0.3, 0.45)
boite(-0.1, 0.1, DOS + 0.18, DOS + 0.3, -0.45, 0.45)
objets.append(piece("Bouclier_P1_Cuir", "Cuir", bm))

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
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Bouclier_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçus (face et trois quarts dos)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1100, 1000
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.36, 0.42, 1)
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(60), math.radians(15), math.radians(-25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 50

def vue(loc, chemin):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

vue((1.6, -6.5, 1.4), os.path.join(APERCUS, "bouclier_p1_face.png"))
vue((2.6, -2.4, 0.9), os.path.join(APERCUS, "bouclier_p1_umbo.png"))
vue((-3.2, 5.2, 1.6), os.path.join(APERCUS, "bouclier_p1_dos.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "bouclier_p1.blend"))
print("OK")
