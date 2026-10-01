# Kit modulaire « Rempart P1 » (palier 1) pour Pick Me Up (Roblox) : muraille monolithique
# en pierre gris-bleu, mousse en coulures, accents d'argent brossé.
# Même grille que le P4 : 1 unité Blender = 1 stud, entraxe des piliers 20, face avant = -Y,
# origine en bas au centre. Usage : blender -b --factory-startup --python build_rempart_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- matériaux
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, metallic=0.0, rough=0.6):
    m = bpy.data.materials.new(name)
    rgb = tuple(srgb(c) for c in rgb255)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1)
    return m

M_PIERRE = material("P1_Pierre", (84, 100, 122), rough=0.75)
M_ARGENT = material("P1_Argent", (205, 212, 222), metallic=1.0, rough=0.32)
M_MOUSSE = material("P1_Mousse", (88, 128, 56), rough=0.9)
M_SOL = material("Sol_Sable", (196, 186, 164), rough=0.9)

# ---------------------------------------------------------------- outils bmesh
def add_box(bm, x0, x1, y0, y1, z0, z1, bevel=0.08):
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    for v in verts:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    if bevel > 0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type='OFFSET',
                        profile_type='SUPERELLIPSE', segments=1, profile=0.5,
                        affect='EDGES', clamp_overlap=True)

def add_sphere(bm, center, r, u=8, v=6):
    mat = Matrix.Translation(center) @ Matrix.Diagonal((r, r, r, 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0, matrix=mat)

def add_prism(bm, pts, to3d, thickness, normal):
    """Polygone 2D extrudé : to3d(a, b) donne le point 3D de la face avant,
    normal est le vecteur (vers l'arrière) le long duquel on donne l'épaisseur."""
    front = [bm.verts.new(to3d(a, b)) for a, b in pts]
    back = [bm.verts.new(Vector(v.co) + normal * thickness) for v in front]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))

def box_uv(bm, tile=8.0):
    # projection cubique : chaque face prend les deux axes perpendiculaires à sa normale
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / tile, loop.vert.co[b] / tile)

def finish(bm, name, mat, coll, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])  # contours concaves de la mousse : triangulés ici plutôt qu'à l'import
    box_uv(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob

def collection(name, hide_render=False):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    c.hide_render = hide_render
    return c

KIT = collection("KIT_P1", hide_render=True)

# ---------------------------------------------------------------- cotes (studs)
MODULE = 20.0
H = MODULE / 2
VIS = 7.5                 # demi-largeur visible de la travée entre deux piliers
PANEL_Y = -1.0            # fond du panneau en retrait
CADRE_Y = -1.8            # face du cadre
COPING_Z0, COPING_Z1 = 29.0, 31.0
COPING_Y = -2.6           # face avant du chaperon
PIL_X, PIL_Y0, PIL_Y1 = 2.5, -4.2, 2.8
PIL_TOP = 35.8

# ---------------------------------------------------------------- travée
def build_travee():
    bm = bmesh.new()
    add_box(bm, -H, H, PANEL_Y, 2.0, 0, COPING_Z0, bevel=0)                 # masse du mur
    # cadre en relief autour du panneau
    add_box(bm, -VIS, -VIS + 1.2, CADRE_Y, PANEL_Y + 0.01, 3.0, COPING_Z0, bevel=0.08)
    add_box(bm, VIS - 1.2, VIS, CADRE_Y, PANEL_Y + 0.01, 3.0, COPING_Z0, bevel=0.08)
    add_box(bm, -VIS, VIS, CADRE_Y, PANEL_Y + 0.01, 3.0, 4.4, bevel=0.08)
    add_box(bm, -VIS, VIS, CADRE_Y, PANEL_Y + 0.01, 27.6, COPING_Z0, bevel=0.08)
    # deux nervures verticales : trois panneaux
    for x in (-2.0, 2.0):
        add_box(bm, x - 0.5, x + 0.5, -1.6, PANEL_Y + 0.01, 4.4, 27.6, bevel=0.06)
    # soubassement à deux ressauts
    add_box(bm, -H, H, -3.0, 2.6, 0, 1.6, bevel=0.12)
    add_box(bm, -H, H, -2.4, 2.4, 1.6, 3.0, bevel=0.1)
    # chaperon
    add_box(bm, -H, H, COPING_Y, 2.4, COPING_Z0, COPING_Z1, bevel=0.12)
    pierre = finish(bm, "P1_Travee_Pierre", M_PIERRE, KIT)

    bm = bmesh.new()   # liseré d'argent le long du chaperon
    add_box(bm, -H, H, COPING_Y - 0.12, COPING_Y + 0.05, 30.35, 30.75, bevel=0.03)
    add_box(bm, -H, H, COPING_Y - 0.02, 2.4, COPING_Z1, COPING_Z1 + 0.12, bevel=0.02)
    argent = finish(bm, "P1_Travee_Argent", M_ARGENT, KIT, smooth=True)
    return [pierre, argent]

# ---------------------------------------------------------------- pilier
def build_pilier():
    bm = bmesh.new()
    add_box(bm, -3.0, 3.0, PIL_Y0 - 0.6, PIL_Y1 + 0.4, 0, 2.2, bevel=0.14)       # socle
    add_box(bm, -PIL_X, PIL_X, PIL_Y0, PIL_Y1, 2.2, 34.0, bevel=0.1)              # fût
    add_box(bm, -1.9, 1.9, PIL_Y0 - 0.25, PIL_Y0 + 0.1, 3.6, 33.0, bevel=0.06)    # pan avant en ressaut
    add_box(bm, -2.85, 2.85, PIL_Y0 - 0.35, PIL_Y1 + 0.2, 34.0, 35.2, bevel=0.12) # chapeau
    add_box(bm, -2.4, 2.4, PIL_Y0 - 0.1, PIL_Y1, 35.2, PIL_TOP, bevel=0.08)
    pierre = finish(bm, "P1_Pilier_Pierre", M_PIERRE, KIT)

    bm = bmesh.new()
    for sx in (-1, 1):  # cornières sur les deux arêtes avant
        x0, x1 = (PIL_X - 0.3, PIL_X + 0.12) if sx > 0 else (-PIL_X - 0.12, -PIL_X + 0.3)
        add_box(bm, x0, x1, PIL_Y0 - 0.12, PIL_Y0 + 0.4, 3.6, 34.0, bevel=0.03)
    add_box(bm, -PIL_X - 0.12, PIL_X + 0.12, PIL_Y0 - 0.12, PIL_Y1 + 0.05, 2.2, 3.6, bevel=0.04)  # ceinture basse
    add_box(bm, -2.97, 2.97, PIL_Y0 - 0.47, PIL_Y1 + 0.3, 34.85, 35.2, bevel=0.03)              # cerclage du chapeau
    for x in (-1.8, -0.6, 0.6, 1.8):  # rivets
        add_sphere(bm, (x, PIL_Y0 - 0.14, 2.9), 0.13)
    argent = finish(bm, "P1_Pilier_Argent", M_ARGENT, KIT, smooth=True)
    return [pierre, argent]

# ---------------------------------------------------------------- mousse
def coulure(rnd, x, z_top, length, width, steps=7):
    """Contour 2D (x, z) d'une coulure : bords irréguliers qui s'amincissent en pointe."""
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        z = z_top - length * t
        w = width * (1 - 0.85 * t ** 1.4) * rnd.uniform(0.8, 1.15)
        dx = rnd.uniform(-0.12, 0.12) * width
        left.append((x - w / 2 + dx, z))
        right.append((x + w / 2 + dx, z))
    tip = (x + rnd.uniform(-0.1, 0.1), z_top - length - rnd.uniform(0.2, 0.6))
    return left + [tip] + list(reversed(right))

def profondeur(x):
    """Profondeur de la surface de la travée à l'abscisse x (cadre, nervures ou panneau)."""
    if abs(x) > VIS - 1.2 or any(abs(x - r) < 0.5 for r in (-2.0, 2.0)):
        return CADRE_Y if abs(x) > VIS - 1.2 else -1.6
    return PANEL_Y

def build_mousse_travee(seed, suffix):
    rnd = random.Random(seed)
    bm = bmesh.new()
    front_xz = lambda y: (lambda a, b: Vector((a, y, b)))
    back = Vector((0, 1, 0))
    # rideau irrégulier sur la face du chaperon
    x = -H
    while x < H - 0.5:
        w = rnd.uniform(1.5, 4.5)
        x1 = min(H, x + w)
        if rnd.random() < 0.75:
            bottom = [(x1 - (x1 - x) * k / 4, COPING_Z0 + rnd.uniform(0.0, 1.0)) for k in range(5)]
            pts = [(x, COPING_Z1 + 0.02), (x1, COPING_Z1 + 0.02)] + bottom
            add_prism(bm, pts, front_xz(COPING_Y - 0.06), 0.05, back)
        x = x1 + rnd.uniform(0.2, 1.5)
    # coulures sous le chaperon, posées à la profondeur de la surface qu'elles recouvrent
    for _ in range(rnd.randint(5, 9)):
        cx = rnd.uniform(-VIS + 0.4, VIS - 0.4)
        length = rnd.choice([rnd.uniform(2, 5), rnd.uniform(5, 11), rnd.uniform(11, 19)])
        pts = coulure(rnd, cx, COPING_Z0 + 0.1, length, rnd.uniform(0.5, 1.4))
        add_prism(bm, pts, front_xz(profondeur(cx) - 0.05), 0.04, back)
    # plaques sur le dessus du chaperon
    for _ in range(rnd.randint(2, 4)):
        cx, cy = rnd.uniform(-8, 8), rnd.uniform(-1.6, 1.4)
        r = rnd.uniform(1.2, 3.0)
        pts = [(cx + r * math.cos(a) * rnd.uniform(0.7, 1.1), cy + 0.45 * r * math.sin(a) * rnd.uniform(0.7, 1.1))
               for a in [2 * math.pi * k / 9 for k in range(9)]]
        pts = [(a, max(COPING_Y + 0.05, min(2.35, b))) for a, b in pts]
        add_prism(bm, pts, lambda a, b: Vector((a, b, COPING_Z1 + 0.13)), 0.1, Vector((0, 0, -1)))
    # mousse au pied : plaques sur la face du soubassement
    for _ in range(rnd.randint(2, 4)):
        cx = rnd.uniform(-8.5, 8.5)
        w = rnd.uniform(1.5, 4)
        pts = [(cx - w / 2, 0.05), (cx + w / 2, 0.05), (cx + w / 2 * 0.8, rnd.uniform(0.7, 1.5)),
               (cx, rnd.uniform(1.0, 1.6)), (cx - w / 2 * 0.8, rnd.uniform(0.6, 1.4))]
        add_prism(bm, pts, front_xz(-3.05), 0.04, back)
    return [finish(bm, f"P1_Mousse_Travee_{suffix}", M_MOUSSE, KIT)]

def build_mousse_pilier(seed, suffix):
    rnd = random.Random(seed)
    bm = bmesh.new()
    back = Vector((0, 1, 0))
    yf = PIL_Y0 - 0.45
    # bavure sur le chapeau puis coulures le long du fût
    pts = [(-2.85, 35.25), (2.85, 35.25)] + [(2.85 - 5.7 * k / 5, 34.1 + rnd.uniform(0, 0.8)) for k in range(6)]
    add_prism(bm, pts, lambda a, b: Vector((a, yf - 0.02, b)), 0.05, back)
    for _ in range(rnd.randint(2, 4)):
        cx = rnd.uniform(-1.6, 1.6)
        pts = coulure(rnd, cx, 34.1, rnd.uniform(3, 16), rnd.uniform(0.5, 1.1))
        add_prism(bm, pts, lambda a, b: Vector((a, PIL_Y0 - 0.3, b)), 0.04, back)
    # dessus du pilier
    r = rnd.uniform(1.4, 2.2)
    pts = [(r * math.cos(a) * rnd.uniform(0.75, 1.05), -0.7 + r * math.sin(a) * rnd.uniform(0.75, 1.05))
           for a in [2 * math.pi * k / 8 for k in range(8)]]
    add_prism(bm, pts, lambda a, b: Vector((a, b, PIL_TOP + 0.1)), 0.1, Vector((0, 0, -1)))
    return [finish(bm, f"P1_Mousse_Pilier_{suffix}", M_MOUSSE, KIT)]

pieces = {
    "Travee": build_travee(),
    "Pilier": build_pilier(),
    "Mousse_Travee_A": build_mousse_travee(11, "A"),
    "Mousse_Travee_B": build_mousse_travee(23, "B"),
    "Mousse_Travee_C": build_mousse_travee(37, "C"),
    "Mousse_Pilier_A": build_mousse_pilier(5, "A"),
    "Mousse_Pilier_B": build_mousse_pilier(9, "B"),
}

# ---------------------------------------------------------------- bilan
print("\n=== TRIANGLES PAR MESH (limite Roblox : 20 000) ===")
for name, objs in pieces.items():
    for ob in objs:
        ob.data.calc_loop_triangles()
        d = ob.dimensions
        print(f"{ob.name:26s} {len(ob.data.loop_triangles):6d} tris   {d.x:5.1f} x {d.y:4.1f} x {d.z:4.1f} studs")
print("\n=== BOITES ENGLOBANTES (repère Blender) ===")
for name, objs in pieces.items():
    pts = [ob.matrix_world @ Vector(c) for ob in objs for c in ob.bound_box]
    mn = [round(min(p[i] for p in pts), 3) for i in range(3)]
    mx = [round(max(p[i] for p in pts), 3) for i in range(3)]
    print("BBOX", name, mn, mx)

# ---------------------------------------------------------------- export FBX par pièce
for name, objs in pieces.items():
    for ob in bpy.data.objects:
        ob.select_set(False)
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, f"Rempart_P1_{name}.fbx"),
                             use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- assemblages d'aperçu
def place(objs, coll, loc, rot_z):
    for ob in objs:
        c = ob.copy()
        c.location = loc
        c.rotation_euler = (0, 0, rot_z)
        coll.objects.link(c)

rnd = random.Random(3)
MT = ["Mousse_Travee_A", "Mousse_Travee_B", "Mousse_Travee_C"]
MP = ["Mousse_Pilier_A", "Mousse_Pilier_B"]

ARC = collection("APERCU_ARC")
R = 90.0
D = 2 * math.asin((MODULE / 2) / R)
NB = 8
for k in range(NB + 1):
    th = (k - NB / 2) * D
    place(pieces["Pilier"] + pieces[rnd.choice(MP)], ARC, (R * math.sin(th), R * math.cos(th), 0), -th)
for k in range(NB):
    th = (k + 0.5 - NB / 2) * D
    rm = R * math.cos(D / 2)
    place(pieces["Travee"] + pieces[rnd.choice(MT)], ARC, (rm * math.sin(th), rm * math.cos(th), 0), -th)

PLANCHE = collection("PLANCHE_FACE")
OFF = Vector((0, -600, 0))
for i in range(3):
    place(pieces["Pilier"] + pieces[MP[i % 2]], PLANCHE, OFF + Vector((MODULE * (i - 1), 0, 0)), 0)
for i in range(2):
    place(pieces["Travee"] + pieces[MT[i]], PLANCHE, OFF + Vector((MODULE * (i - 0.5), 0, 0)), 0)

bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=140)
finish(bm, "Sol", M_SOL, ARC)
bm = bmesh.new()
add_box(bm, -60, 60, -30, 10, -0.5, 0, bevel=0)
finish(bm, "Sol_Planche", M_SOL, PLANCHE).location = OFF

# ---------------------------------------------------------------- lumière, caméra, rendu
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Punchy'

world = bpy.data.worlds.new("Ciel")
scene.world = world
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.62, 0.68, 0.76, 1)
bg.inputs[1].default_value = 0.7

sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 3.2
sun_data.color = (0.95, 0.97, 1.0)
sun_data.angle = math.radians(8)
sun = bpy.data.objects.new("Soleil", sun_data)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(sun)

cam_data = bpy.data.cameras.new("Camera")
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

def aim(loc, target):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

def render(path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

cam_data.type = 'PERSP'
cam_data.lens = 26
aim((-34, 30, 9), (6, 84, 19))
PLANCHE.hide_render = True
render(os.path.join(APERCUS, "rempart_p1_34.png"))

ARC.hide_render = True
PLANCHE.hide_render = False
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 80
aim(OFF + Vector((0, -80, 19)), OFF + Vector((0, 0, 19)))
render(os.path.join(APERCUS, "rempart_p1_face.png"))
PLANCHE.hide_render = True
ARC.hide_render = False

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rempart_p1.blend"))
print("OK")
