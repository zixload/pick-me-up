# Armes du tank 1 étoile, en pièces détachées (02/10/2026) : le gourdin noueux et le bouclier de planches
# clouées, fendu et ceinturé de corde, repris de build_tank_p1.py (mêmes outils, même dessin) mais
# modélisés seuls, pour être soudés aux mains du tank TRELLIS riggé par Avatar Setup.
# Repères (coordonnées Roblox) : gourdin le long de +Y, centre de la poignée à l'origine ;
# bouclier face vers -Z, poignée horizontale le long de X passant par l'origine.
# Exporte export_p1/Armes_Tank_P1.fbx (Gourdin_Bois, Bouclier_Bois, Bouclier_Fer, Bouclier_Corde).
# Usage : blender -b --factory-startup --python build_armes_tank_p1.py
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "build_tank_p1.py"), encoding="utf-8").read()
exec(_src[:_src.index("# ================================================================ GAMBISON")])   # outils et matières

# ---------------------------------------------------------------- gourdin
axe = Vector((0, 1, 0))
go = nouveau()
profil = [(-0.42, 0.13), (-0.36, 0.14), (-0.3, 0.115), (0.0, 0.11), (0.3, 0.115), (0.6, 0.13), (0.9, 0.16),
          (1.2, 0.2), (1.45, 0.235), (1.65, 0.25), (1.8, 0.24), (1.88, 0.2)]
tube(go, [axe * t for t, _ in profil], [r for _, r in profil], seg=18, bouts="rond")
u_, w_ = repere(axe)
for t, ang, r in ((0.95, 30, 0.07), (1.3, 160, 0.08), (1.55, 260, 0.075), (1.7, 70, 0.06), (0.55, 220, 0.05)):
    base_r = 0.11 + (t / 1.88) * 0.13
    d = u_ * math.cos(math.radians(ang)) + w_ * math.sin(math.radians(ang))
    ellipsoide(go, axe * t + d * base_r * 0.9, (r, r, r * 0.8))     # nœuds du bois
go = organique(go, voxel=0.018, lissage=4)
ajouter("Gourdin", "Bois", decimer(go, 1500))

# ---------------------------------------------------------------- bouclier
N_B, T_B, Y_B = Vector((0, 0, -1)), Vector((1, 0, 0)), Vector((0, 1, 0))
hc = Vector((0, 0, 0))
CENTRE_B = hc + N_B * 0.46
RAYON_B = 0.95
rnd.seed(7)
def point_b(uu, ww, dn=0.0):
    return CENTRE_B + T_B * uu + Y_B * ww + N_B * dn
bo = nouveau()
largeurs = [(-0.95, -0.47), (-0.45, 0.02), (0.04, 0.5), (0.52, 0.95)]
for idx, (u0, u1) in enumerate(largeurs):
    bas_arc = [(u0 + (u1 - u0) * k / 8, -math.sqrt(max(RAYON_B ** 2 - (u0 + (u1 - u0) * k / 8) ** 2, 0.0))) for k in range(9)]
    haut_arc = [(u0 + (u1 - u0) * k / 8, math.sqrt(max(RAYON_B ** 2 - (u0 + (u1 - u0) * k / 8) ** 2, 0.0)))
                for k in range(8, -1, -1)]
    if idx == 3:   # planche cassée en bas, en dents de scie
        cassure = [(0.52, -0.22), (0.6, -0.33), (0.57, -0.45), (0.68, -0.52), (0.66, -0.63), (0.78, -0.5),
                   (0.86, -0.36), (math.sqrt(RAYON_B ** 2 - 0.2 ** 2), -0.2)]
        contour = cassure + haut_arc
    else:
        contour = bas_arc + haut_arc
    dec = rnd.uniform(-0.02, 0.02)
    prisme(bo, [point_b(uu, ww, dec) for uu, ww in contour], CENTRE_B, N_B, 0.1)
for ww in (-0.45, 0.42):   # traverses clouées au dos
    larg = math.sqrt(RAYON_B ** 2 - ww ** 2) - 0.1
    larg_d = 0.45 if ww < 0 else larg
    c = point_b(0, ww, -0.075)
    pts = [c - T_B * larg - Y_B * 0.08, c + T_B * larg_d - Y_B * 0.08, c + T_B * larg_d + Y_B * 0.08, c - T_B * larg + Y_B * 0.08]
    prisme(bo, pts, c, N_B, 0.11)
tube(bo, [hc - T_B * 0.32, hc + T_B * 0.32], 0.1, seg=12)          # poignée
for sgn in (-1, 1):
    a_ = hc + T_B * sgn * 0.3
    tube(bo, [a_, a_ + N_B * 0.36], 0.07, seg=8)                      # tenons de la poignée
ajouter("Bouclier", "Bois", bo)
fe = nouveau()
for ww in (-0.45, 0.42):
    for uu in (-0.71, -0.22, 0.27, 0.72):
        if abs(uu) < math.sqrt(RAYON_B ** 2 - ww ** 2) - 0.1 and not (uu > 0.5 and ww < -0.2):
            ellipsoide(fe, point_b(uu, ww, 0.07), (0.035, 0.035, 0.035), seg=8, anneaux=5)
ajouter("Bouclier", "Fer", fe)
cr = nouveau()
pts = [point_b(math.cos(math.radians(15 + 150 * k / 23)) * (RAYON_B + 0.02),
               math.sin(math.radians(15 + 150 * k / 23)) * (RAYON_B + 0.02), 0.0) for k in range(24)]
tube(cr, pts, 0.045, seg=8, bouts="rond", torsade=(0.2, 0.1))
ajouter("Bouclier", "Corde", cr)

# ---------------------------------------------------------------- finition et export
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
    print(f"  {ob.name}: {len(ob.data.loop_triangles)}")
print(f"{len(OBJETS)} maillages, {total} triangles")
for ob in bpy.data.objects:
    ob.select_set(ob in OBJETS)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Armes_Tank_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# aperçu : les deux armes côte à côte
for ob in OBJETS:
    if ob.name.startswith("Gourdin"):
        ob.location = B(Vector((-1.6, -0.7, 0)))
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1100, 900
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
cam.location = B(Vector((-1.8, 0.9, -6.5)))
cam.rotation_euler = (B(Vector((-0.8, 0.1, -0.3))) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 45
scene.render.filepath = os.path.join(APERCUS, "armes_tank_p1.png")
bpy.ops.render.render(write_still=True)
print("OK")
