# Bâton de la soigneuse 1 étoile (Pick Me Up, Roblox) : bâton de marche tordu et noueux, deux lianes fines
# enroulées autour du haut avec quelques feuilles plaquées, sans aucune lueur magique (apprentie, 1 étoile).
# Repère (coordonnées Roblox) : bâton le long de +Y, centre de la prise de main à l'origine ; le pied
# touche le sol quand le bras pend. Outils repris de build_tank_p1.py. Exporte export_p1/Baton_P1.fbx.
# Usage : blender -b --factory-startup --python build_baton_p1.py
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "build_tank_p1.py"), encoding="utf-8").read()
exec(_src[:_src.index("# ================================================================ GAMBISON")])   # outils et matières

def couleur(nom, rgb, rugo=0.85):
    m = bpy.data.materials.new("Baton_" + nom)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*[srgb(x) for x in rgb], 1)
    b.inputs["Roughness"].default_value = rugo
    m.use_backface_culling = True
    MAT[nom] = m
    LISSE.add(nom)
couleur("Bois", (112, 82, 56), 0.8)
couleur("Liane", (92, 118, 66))
couleur("Feuilles", (122, 152, 86))

# ---------------------------------------------------------------- bâton tordu
BAS, HAUT = -2.35, 1.55
pts, rayons = [], []
for i in range(15):
    t = i / 14
    y = BAS + (HAUT - BAS) * t
    # légères courbures irrégulières, et une crosse qui penche en haut
    x = 0.06 * math.sin(t * 5.1) + (0.12 * (t - 0.82) / 0.18 if t > 0.82 else 0.0)
    z = 0.05 * math.sin(t * 3.3 + 1.0)
    pts.append(Vector((x, y, z)))
    rayons.append(0.075 + 0.02 * t + (0.015 if 0.45 < t < 0.55 else 0.0))
ba = nouveau()
tube(ba, pts, rayons, seg=14, bouts="rond")
ellipsoide(ba, pts[-1], (rayons[-1] * 1.08,) * 3, seg=16, anneaux=10)   # sommet arrondi
for t, ang, r in ((0.22, 40, 0.045), (0.5, 200, 0.05), (0.63, 300, 0.04), (0.78, 110, 0.045), (0.35, 150, 0.035)):
    i = int(t * 14)
    d = Vector((math.cos(math.radians(ang)), 0, math.sin(math.radians(ang))))
    ellipsoide(ba, pts[i] + d * rayons[i] * 0.85, (r, r * 1.3, r))       # nœuds du bois
ba = organique(ba, voxel=0.016, lissage=4)
ajouter("Baton", "Bois", decimer(ba, 1400))

# ---------------------------------------------------------------- lianes enroulées en haut du bâton
# (retour de l'utilisateur, 02/10/2026 : le bouquet dépassait et ne ressemblait à rien ; des lianes simples)
def axe_a(y):
    """Point de l'axe du bâton et son rayon à la hauteur y."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if a.y <= y <= b.y:
            t = (y - a.y) / (b.y - a.y)
            return a.lerp(b, t), rayons[i] + (rayons[i + 1] - rayons[i]) * t
    return pts[-1], rayons[-1]

def feuille(bm, centre, longueur, largeur, axe_l, normale):
    """Petite feuille en amande, plaquée : longue selon axe_l, à plat selon la normale."""
    l = axe_l.normalized()
    n = (normale - l * normale.dot(l)).normalized()
    w = n.cross(l)
    m = Matrix((
        (w.x * largeur, l.x * longueur, n.x * 0.012, centre.x),
        (w.y * largeur, l.y * longueur, n.y * 0.012, centre.y),
        (w.z * largeur, l.z * longueur, n.z * 0.012, centre.z),
        (0, 0, 0, 1)))
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0, matrix=m)

li, fe = nouveau(), nouveau()
R_LIANE = 0.022
for brin, (y0, y1, tours, dephasage) in enumerate(((-0.1, 1.42, 3.2, 0.0), (0.25, 1.38, 2.4, math.pi * 0.9))):
    chemin = []
    for k in range(73):
        t = k / 72
        y = y0 + (y1 - y0) * t
        c, r = axe_a(y)
        a = dephasage + 2 * math.pi * tours * t
        chemin.append(c + Vector((math.cos(a), 0, math.sin(a))) * (r + R_LIANE * 0.7))   # collée au bois
    tube(li, chemin, [R_LIANE * (0.7 + 0.3 * min(1, 4 * (1 - abs(2 * k / 72 - 1)))) for k in range(73)], seg=6, bouts="rond")
    # quelques feuilles le long de la liane, couchées contre le bâton
    for k in range(6 + brin * 2, 70, 9):
        p0, p1 = chemin[k], chemin[k + 1]
        c, _ = axe_a(p0.y)
        dehors = (p0 - c)
        dehors.y = 0
        dehors.normalize()
        tangente = (p1 - p0).normalized()
        axe_feuille = (tangente * 0.6 + Vector((0, 1, 0)) * 0.4).normalized()
        centre = p0 + dehors * 0.02 + axe_feuille * 0.05
        feuille(fe, centre, 0.075, 0.035, axe_feuille, dehors)
ajouter("Baton", "Liane", decimer(organique(li, voxel=0.008, lissage=2), 1400))
ajouter("Baton", "Feuilles", fe)

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
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Baton_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 700, 1100
scene.view_settings.view_transform = 'AgX'
w = bpy.data.worlds.new("Ciel")
scene.world = w
w.node_tree.nodes["Background"].inputs[0].default_value = (0.36, 0.39, 0.44, 1)
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.4
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = B(Vector((1.2, 0.0, -6.5)))
cam.rotation_euler = (B(Vector((0, -0.3, 0))) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 42
scene.render.filepath = os.path.join(APERCUS, "baton_p1.png")
bpy.ops.render.render(write_still=True)
cam.location = B(Vector((0.6, 1.0, -2.0)))
cam.rotation_euler = (B(Vector((0, 0.75, 0))) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(APERCUS, "baton_p1_bouquet.png")
bpy.ops.render.render(write_still=True)
print("OK")
