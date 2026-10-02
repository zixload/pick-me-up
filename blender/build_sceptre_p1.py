# Bâton du mage 1 étoile (Pick Me Up, Roblox) : bâton de bois brut presque droit, qui se divise en haut en
# trois griffes recourbées serrant une petite pierre bleu pâle, terne et facettée (apprenti, rien de
# flamboyant), lanières de cuir sous l'enfourchure et à la prise. Repère (coordonnées Roblox) : le long de +Y,
# prise de main à l'origine ; le pied touche le sol quand le bras pend. Outils repris de build_tank_p1.py.
# Exporte export_p1/Sceptre_P1.fbx (Sceptre_Bois, Sceptre_Cuir, Sceptre_Cristal).
# Usage : blender -b --factory-startup --python build_sceptre_p1.py
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "build_tank_p1.py"), encoding="utf-8").read()
exec(_src[:_src.index("# ================================================================ GAMBISON")])   # outils et matières

def couleur(nom, rgb, rugo=0.85, metal=0.0):
    m = bpy.data.materials.new("Sceptre_" + nom)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*[srgb(x) for x in rgb], 1)
    b.inputs["Roughness"].default_value = rugo
    b.inputs["Metallic"].default_value = metal
    m.use_backface_culling = True
    MAT[nom] = m
    LISSE.add(nom)
couleur("Bois", (96, 72, 52), 0.8)
couleur("Cuir", (70, 50, 36), 0.85)
couleur("Cristal", (156, 204, 228), 0.25)
LISSE.discard("Cristal")   # facettes nettes

# ---------------------------------------------------------------- hampe
BAS, FOURCHE = -2.35, 1.42
pts, rayons = [], []
for i in range(13):
    t = i / 12
    y = BAS + (FOURCHE - BAS) * t
    pts.append(Vector((0.035 * math.sin(t * 4.2), y, 0.03 * math.sin(t * 2.7 + 0.8))))
    rayons.append(0.07 + 0.025 * t)
bo = nouveau()
tube(bo, pts, rayons, seg=14, bouts="rond")
for t, ang, r in ((0.3, 60, 0.04), (0.58, 230, 0.045), (0.8, 340, 0.035)):
    i = int(t * 12)
    d = Vector((math.cos(math.radians(ang)), 0, math.sin(math.radians(ang))))
    ellipsoide(bo, pts[i] + d * rayons[i] * 0.85, (r, r * 1.3, r))      # nœuds du bois
# trois griffes qui partent de l'enfourchure, s'écartent puis se referment sur la pierre
haut = pts[-1]
CENTRE_PIERRE = haut + Vector((0, 0.36, 0))
for k in range(3):
    a = math.radians(90 + 120 * k)
    radial = Vector((math.cos(a), 0, math.sin(a)))
    griffe = [haut + Vector((0, -0.05, 0)),
              haut + radial * 0.1 + Vector((0, 0.12, 0)),
              haut + radial * 0.16 + Vector((0, 0.3, 0)),
              CENTRE_PIERRE + radial * 0.13 + Vector((0, 0.14, 0)),
              CENTRE_PIERRE + radial * 0.06 + Vector((0, 0.24, 0))]
    tube(bo, griffe, [0.05, 0.045, 0.04, 0.03, 0.016], seg=10, bouts="rond")
bo = organique(bo, voxel=0.014, lissage=4)
ajouter("Sceptre", "Bois", decimer(bo, 1800))

# ---------------------------------------------------------------- pierre terne, facettée, serrée par les griffes
cr = nouveau()
facettes, h_haut, h_bas, r_milieu = 6, 0.2, 0.14, 0.1
anneau = [cr.verts.new(CENTRE_PIERRE + Vector((r_milieu * math.cos(2 * math.pi * k / facettes + 0.2), 0.02 * (k % 2),
                                                r_milieu * math.sin(2 * math.pi * k / facettes + 0.2)))) for k in range(facettes)]
pointe_h = cr.verts.new(CENTRE_PIERRE + Vector((0.01, h_haut, 0)))
pointe_b = cr.verts.new(CENTRE_PIERRE + Vector((0, -h_bas, 0.01)))
for k in range(facettes):
    j = (k + 1) % facettes
    cr.faces.new((anneau[k], anneau[j], pointe_h))
    cr.faces.new((anneau[j], anneau[k], pointe_b))
ajouter("Sceptre", "Cristal", cr)

# ---------------------------------------------------------------- lanières de cuir : sous l'enfourchure et à la prise
cu = nouveau()
def axe_a(y):
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if a.y <= y <= b.y:
            t = (y - a.y) / (b.y - a.y)
            return a.lerp(b, t), rayons[i] + (rayons[i + 1] - rayons[i]) * t
    return pts[-1], rayons[-1]
for y0, y1, tours in ((-0.22, 0.24, 5), (1.12, 1.34, 3)):
    chemin = []
    for k in range(tours * 12 + 1):
        t = k / (tours * 12)
        y = y0 + (y1 - y0) * t
        c, r = axe_a(y)
        a = 2 * math.pi * tours * t
        chemin.append(c + Vector((math.cos(a), 0, math.sin(a))) * (r + 0.012))
    tube(cu, chemin, 0.022, seg=6, bouts="rond")
c, r = axe_a(1.12)   # bout de lanière qui pend
tube(cu, [c + Vector((r + 0.02, 0, 0)), c + Vector((r + 0.06, -0.12, 0.02)), c + Vector((r + 0.05, -0.26, 0.05))],
     [0.02, 0.018, 0.014], seg=6, bouts="rond")
ajouter("Sceptre", "Cuir", decimer(organique(cu, voxel=0.01, lissage=2), 1400))

# ---------------------------------------------------------------- export et aperçus
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
        poly.use_smooth = matiere in LISSE
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
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Sceptre_P1.fbx"), use_selection=True, object_types={'MESH'},
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
def vue(loc, cible, nom, lens):
    cam.location = B(Vector(loc))
    cam.rotation_euler = (B(Vector(cible)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    scene.render.filepath = os.path.join(APERCUS, nom)
    bpy.ops.render.render(write_still=True)
vue((1.2, 0.0, -6.5), (0, -0.3, 0), "sceptre_p1.png", 42)
vue((0.7, 1.9, -1.4), (0, 1.55, 0), "sceptre_p1_tete.png", 50)
print("OK")
