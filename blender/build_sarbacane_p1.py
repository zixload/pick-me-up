# Sarbacane du gobelin sarbacanier (Pick Me Up, Roblox) : tube de bambou clair à nœuds plus foncés, prise en deux
# bandes de cuir avec une cordelette enroulée, embout en os évasé côté bouche, bague de fer au bout.
# Repère (coordonnées Roblox) : tube le long de +Y, embout (bouche) en haut, centre de la prise de main à l'origine.
# Taille pour le gobelin importé à l'échelle 2 (8 studs de haut) : 4,5 studs ; le jeu le réduit avec le gobelin.
# Outils repris de build_tank_p1.py, comme le bâton. Exporte export_p1/Sarbacane_P1.fbx.
# Usage : blender -b --factory-startup --python build_sarbacane_p1.py
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "build_tank_p1.py"), encoding="utf-8").read()
# Blender 4.5 crée les matières sans nœuds : on les active dans les outils repris du tank
_outils = _src[:_src.index("# ================================================================ GAMBISON")]
_outils = _outils.replace('m = bpy.data.materials.new("Tank_" + nom)', 'm = bpy.data.materials.new("Tank_" + nom); m.use_nodes = True')
exec(_outils)   # outils et matières

def couleur(nom, rgb, rugo=0.85, metal=0.0):
    m = bpy.data.materials.new("Sarbacane_" + nom)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*[srgb(x) for x in rgb], 1)
    b.inputs["Roughness"].default_value = rugo
    b.inputs["Metallic"].default_value = metal
    m.use_backface_culling = True
    MAT[nom] = m
    LISSE.add(nom)
couleur("Bambou", (176, 148, 92), 0.7)
couleur("Noeuds", (128, 100, 58), 0.75)
couleur("Cuir", (86, 58, 40), 0.9)
couleur("Corde", (150, 128, 96), 0.95)
couleur("Os", (226, 214, 184), 0.6)
couleur("Fer", (78, 78, 84), 0.45, 0.6)

HAUT, BAS = 1.0, -3.5          # embout (bouche) en haut, bout du tir en bas ; prise à l'origine
def rayon_a(y):
    t = (HAUT - y) / (HAUT - BAS)
    return 0.112 - 0.016 * t   # s'affine légèrement vers le bout

# ---------------------------------------------------------------- tube de bambou
pts, rayons = [], []
for i in range(19):
    y = HAUT - (HAUT - BAS) * i / 18
    pts.append(Vector((0, y, 0)))
    rayons.append(rayon_a(y))
tb = nouveau()
tube(tb, pts, rayons, seg=16, bouts="plat")
ajouter("Sarbacane", "Bambou", tb)

# nœuds du bambou : anneaux un peu plus épais tous les 0,9 stud
nd = nouveau()
y = HAUT - 0.55
while y > BAS + 0.3:
    if abs(y) > 0.45:   # pas de nœud sous la main
        r = rayon_a(y)
        tube(nd, [Vector((0, y + 0.05, 0)), Vector((0, y - 0.05, 0))], [r * 1.09, r * 1.09], seg=16, bouts="plat")
    y -= 0.9
ajouter("Sarbacane", "Noeuds", nd)

# prise : deux bandes de cuir et une cordelette enroulée entre elles
cu = nouveau()
for y0, y1 in ((0.38, 0.12), (-0.12, -0.38)):
    r = rayon_a((y0 + y1) / 2) * 1.14
    tube(cu, [Vector((0, y0, 0)), Vector((0, y1, 0))], [r, r], seg=16, bouts="plat")
ajouter("Sarbacane", "Cuir", cu)
co = nouveau()
spirale = []
for i in range(41):
    t = i / 40
    a = t * math.pi * 2 * 4      # quatre tours
    yy = 0.11 - 0.22 * t
    r = rayon_a(yy) * 1.05
    spirale.append(Vector((math.cos(a) * r, yy, math.sin(a) * r)))
tube(co, spirale, [0.018] * len(spirale), seg=6, bouts="rond")
ajouter("Sarbacane", "Corde", co)

# embout en os, évasé côté bouche
os_ = nouveau()
tube(os_, [Vector((0, HAUT - 0.02, 0)), Vector((0, HAUT + 0.18, 0)), Vector((0, HAUT + 0.3, 0))],
     [rayon_a(HAUT) * 1.08, rayon_a(HAUT) * 1.25, rayon_a(HAUT) * 1.5], seg=18, bouts="plat")
ajouter("Sarbacane", "Os", os_)

# bague de fer au bout du tir
fe = nouveau()
r = rayon_a(BAS)
tube(fe, [Vector((0, BAS + 0.14, 0)), Vector((0, BAS - 0.02, 0))], [r * 1.16, r * 1.16], seg=16, bouts="plat")
ajouter("Sarbacane", "Fer", fe)

# ---------------------------------------------------------------- export
def box_uv(bm, tile=2.0):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / tile, loop.vert.co[b] / tile)
def B(p):
    return Vector((-p.x, p.z, p.y))
OBJETS = []
for (piece_, matiere), bm in sorted(PIECES.items()):
    normales(bm)
    for v in bm.verts:
        v.co = B(v.co)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    box_uv(bm)
    nom = f"{piece_}_{matiere}"
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(MAT[matiere])
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    OBJETS.append(ob)
total = 0
for ob in OBJETS:
    ob.data.calc_loop_triangles()
    total += len(ob.data.loop_triangles)
print(f"{len(OBJETS)} maillages, {total} triangles")
for ob in bpy.data.objects:
    ob.select_set(ob in OBJETS)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Sarbacane_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 600, 1100
scene.view_settings.view_transform = 'AgX'
w = bpy.data.worlds.new("Ciel")
w.use_nodes = True
scene.world = w
w.node_tree.nodes["Background"].inputs[0].default_value = (0.36, 0.39, 0.44, 1)
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.4
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = B(Vector((8.5, -1.25, -3.0)))
cam.rotation_euler = (B(Vector((0, -1.25, 0))) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(APERCUS, "sarbacane_p1.png")
bpy.ops.render.render(write_still=True)
cam.location = B(Vector((0.9, 0.9, -1.1)))
cam.rotation_euler = (B(Vector((0, 0.3, 0))) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(APERCUS, "sarbacane_p1_prise.png")
bpy.ops.render.render(write_still=True)
print("OK")
