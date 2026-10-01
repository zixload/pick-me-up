# Kit modulaire « Rempart quartz » pour Pick Me Up (Roblox).
# 1 unité Blender = 1 stud. Face avant des pièces = -Y, origine en bas au centre.
# Usage : blender -b --python build_rempart.py
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export")
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
    try:
        m.use_nodes = True
    except Exception:
        pass
    rgb = tuple(srgb(c) for c in rgb255)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        out = m.node_tree.nodes.get("Material Output") or m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        m.node_tree.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1)
    return m

M_PIERRE = material("Quartz_Pierre", (242, 206, 192), rough=0.55)
M_OR = material("Quartz_Or", (226, 170, 70), metallic=1.0, rough=0.3)
M_HAIE = material("Haie", (78, 128, 52), rough=0.85)
M_FEUILLE = material("Lierre_Feuilles", (70, 120, 50), rough=0.7)
M_FLEUR = material("Lierre_Fleurs", (250, 248, 240), rough=0.6)
M_SOL = material("Dallage", (226, 220, 210), rough=0.8)

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

def add_sphere(bm, center, scale, u=8, v=6):
    mat = Matrix.Translation(center) @ Matrix.Diagonal((*scale, 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0, matrix=mat)

def add_frustum(bm, center_bottom, half_bottom, half_top, height):
    # tronc de pyramide à base carrée (cône à 4 segments tourné de 45°)
    mat = (Matrix.Translation(Vector(center_bottom) + Vector((0, 0, height / 2)))
           @ Matrix.Rotation(math.radians(45), 4, 'Z'))
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=4,
                          radius1=half_bottom * math.sqrt(2), radius2=half_top * math.sqrt(2),
                          depth=height, matrix=mat)

def add_lathe(bm, cx, cy, z0, profile, seg=8):
    # profil (rayon, hauteur) tourné autour d'un axe vertical
    rings = []
    for r, h in profile:
        ring = [bm.verts.new((cx + r * math.cos(2 * math.pi * i / seg),
                              cy + r * math.sin(2 * math.pi * i / seg), z0 + h)) for i in range(seg)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

def append_mesh(bm, mesh):
    vmap = [bm.verts.new(v.co) for v in mesh.vertices]
    for p in mesh.polygons:
        try:
            bm.faces.new([vmap[i] for i in p.vertices])
        except ValueError:
            pass

def tubes(bm, polylines, radius):
    # polylignes 3D converties en tubes via une courbe Blender
    cu = bpy.data.curves.new("tmp_tube", 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 1
    cu.use_fill_caps = True
    for pts in polylines:
        sp = cu.splines.new('POLY')
        sp.points.add(len(pts) - 1)
        for p, co in zip(sp.points, pts):
            p.co = (*co, 1.0)
    ob = bpy.data.objects.new("tmp_tube", cu)
    scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    append_mesh(bm, me)
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)

def spiral(cx, y, cz, r0, turns, a0, direction, n=36):
    pts = []
    tmax = turns * 2 * math.pi
    for i in range(n + 1):
        t = tmax * i / n
        r = r0 * math.exp(-0.26 * t)
        a = a0 + direction * t
        pts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    return pts

def finish(bm, name, mat, coll, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
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

KIT = collection("KIT", hide_render=True)

# ---------------------------------------------------------------- cotes (studs)
MODULE = 20.0          # entraxe des piliers
WALL_Y0, WALL_Y1 = -1.2, 1.5
PANEL_X = 6.5          # demi-largeur du panneau en retrait
PANEL_Z0, PANEL_Z1 = 5.0, 25.0
FRISE_Z0, FRISE_Z1 = 27.0, 30.0
CORNICHE_Z1 = 32.0
PIL_Y = -0.6           # axe des piliers (ils débordent devant le mur)

# ---------------------------------------------------------------- travée de mur
def build_travee():
    h = MODULE / 2
    bm = bmesh.new()
    add_box(bm, -h, h, WALL_Y0, WALL_Y1, 0, FRISE_Z0, bevel=0)                       # masse
    # parement autour du panneau
    add_box(bm, -h, -PANEL_X, -1.5, WALL_Y0 + 0.01, 3, FRISE_Z0, bevel=0.05)
    add_box(bm, PANEL_X, h, -1.5, WALL_Y0 + 0.01, 3, FRISE_Z0, bevel=0.05)
    add_box(bm, -PANEL_X, PANEL_X, -1.5, WALL_Y0 + 0.01, 3, PANEL_Z0, bevel=0.05)
    add_box(bm, -PANEL_X, PANEL_X, -1.5, WALL_Y0 + 0.01, PANEL_Z1, FRISE_Z0, bevel=0.05)
    # moulures du panneau : cadre extérieur + filet intérieur
    for (w, off, d) in ((0.45, 0.0, -1.42), (0.22, 0.95, -1.36)):
        x0, x1 = -PANEL_X + off, PANEL_X - off
        z0, z1 = PANEL_Z0 + off, PANEL_Z1 - off
        add_box(bm, x0, x0 + w, d, WALL_Y0, z0, z1, bevel=0.06)
        add_box(bm, x1 - w, x1, d, WALL_Y0, z0, z1, bevel=0.06)
        add_box(bm, x0, x1, d, WALL_Y0, z0, z0 + w, bevel=0.06)
        add_box(bm, x0, x1, d, WALL_Y0, z1 - w, z1, bevel=0.06)
    # soubassement à ressauts
    add_box(bm, -h, h, -2.3, 1.9, 0, 1.4, bevel=0.1)
    add_box(bm, -h, h, -2.0, 1.75, 1.4, 2.4, bevel=0.08)
    add_box(bm, -h, h, -1.75, 1.6, 2.4, 3.0, bevel=0.06)
    # frise et corniche
    add_box(bm, -h, h, -1.7, 1.6, FRISE_Z0, FRISE_Z1, bevel=0.06)
    add_box(bm, -h, h, -2.0, 1.8, 30.0, 30.5, bevel=0.06)
    add_box(bm, -h, h, -2.5, 2.0, 30.5, 31.3, bevel=0.12)
    add_box(bm, -h, h, -2.3, 1.8, 31.3, CORNICHE_Z1, bevel=0.06)
    pierre = finish(bm, "Travee_Pierre", M_PIERRE, KIT)

    # rinceaux dorés de la frise
    bm = bmesh.new()
    y, z0 = -1.78, (FRISE_Z0 + FRISE_Z1) / 2
    lines = []
    for s in (1, -1):
        stem = []
        for i in range(61):
            ax = 0.8 + 6.9 * i / 60
            stem.append((s * ax, y, z0 - 0.38 * math.cos(math.pi * (ax - 1.6) / 1.6)))
        lines.append(stem)
        for k in range(4):
            cx = s * (1.6 + 1.6 * k)
            up = k % 2 == 0
            cz = z0 + (0.4 if up else -0.4)
            a0 = -math.pi / 2 if up else math.pi / 2
            lines.append(spiral(cx, y, cz, 0.78, 1.35, a0, s * (1 if up else -1)))
        for k in range(4):  # petites feuilles entre les volutes
            ax = 2.4 + 1.6 * k
            zl = z0 - 0.38 * math.cos(math.pi * (ax - 1.6) / 1.6)
            add_sphere(bm, (s * ax, y - 0.02, zl + (0.32 if k % 2 == 0 else -0.32)),
                       (0.32, 0.09, 0.15), u=6, v=4)
    tubes(bm, lines, 0.1)
    # rosace centrale
    mat = Matrix.Translation((0, y, z0)) @ Matrix.Rotation(math.radians(90), 4, 'X')
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.55, radius2=0.45,
                          depth=0.22, matrix=mat)
    for i in range(8):
        a = 2 * math.pi * i / 8
        add_sphere(bm, (0.78 * math.cos(a), y, z0 + 0.78 * math.sin(a)), (0.24, 0.1, 0.24), u=6, v=4)
    or_ = finish(bm, "Travee_Or", M_OR, KIT, smooth=True)
    return [pierre, or_]

# ---------------------------------------------------------------- pilier
def build_pilier():
    bm = bmesh.new()
    def sq(half, z0, z1, bev=0.08, dy=0.0):
        add_box(bm, -half, half, PIL_Y - half - dy, PIL_Y + half, z0, z1, bevel=bev)
    sq(2.8, 0, 1.6, 0.12)
    sq(2.6, 1.6, 3.2, 0.1)
    sq(2.3, 3.2, 4.0, 0.06)
    # fût avec panneau vertical en retrait sur la face avant
    add_box(bm, -2.1, 2.1, PIL_Y - 1.8, PIL_Y + 2.1, 4.0, 27.0, bevel=0)
    fy0, fy1 = PIL_Y - 2.1, PIL_Y - 1.79
    add_box(bm, -2.1, -1.45, fy0, fy1, 4.0, 27.0, bevel=0.06)
    add_box(bm, 1.45, 2.1, fy0, fy1, 4.0, 27.0, bevel=0.06)
    add_box(bm, -1.45, 1.45, fy0, fy1, 4.0, 5.0, bevel=0.06)
    add_box(bm, -1.45, 1.45, fy0, fy1, 26.0, 27.0, bevel=0.06)
    # entablement, dé de balustrade, chapeau
    sq(2.8, 30.0, CORNICHE_Z1, 0.12)
    sq(2.3, CORNICHE_Z1, 37.5, 0.08)
    sq(2.7, 37.5, 38.3, 0.1)
    sq(2.4, 38.3, 38.9, 0.08)
    sq(1.8, 38.9, 39.4, 0.06)
    pierre = finish(bm, "Pilier_Pierre", M_PIERRE, KIT)

    # chapiteau doré
    bm = bmesh.new()
    sq(2.2, 27.0, 27.3, 0.04)
    add_frustum(bm, (0, PIL_Y, 27.3), 2.05, 2.5, 2.0)
    sq(2.9, 29.3, 30.0, 0.08)
    fy = PIL_Y - 2.3
    for x in (-1.3, 0.0, 1.3):                     # rang inférieur de feuilles
        add_sphere(bm, (x, fy, 28.0), (0.55, 0.3, 0.85))
    for x in (-0.65, 0.65):                        # rang supérieur
        add_sphere(bm, (x, fy - 0.15, 28.85), (0.45, 0.28, 0.6))
    for sx in (-1, 1):
        add_sphere(bm, (sx * 2.45, PIL_Y - 1.2, 28.0), (0.3, 0.55, 0.85))  # feuilles latérales
    vol = [spiral(sx * 2.2, fy - 0.35, 29.0, 0.5, 1.5, math.pi / 2, -sx) for sx in (-1, 1)]
    tubes(bm, vol, 0.12)
    or_ = finish(bm, "Pilier_Or", M_OR, KIT, smooth=True)
    return [pierre, or_]

# ---------------------------------------------------------------- balustrade
def build_balustrade():
    h = MODULE / 2
    bm = bmesh.new()
    yc = -0.9
    add_box(bm, -h, h, yc - 0.8, yc + 0.8, CORNICHE_Z1, 32.6, bevel=0.08)
    add_box(bm, -h, h, yc - 0.9, yc + 0.9, 35.3, 35.75, bevel=0.1)
    add_box(bm, -h, h, yc - 0.75, yc + 0.75, 35.75, 36.0, bevel=0.06)
    profile = [(0.36, 0), (0.36, 0.2), (0.24, 0.32), (0.21, 0.55), (0.4, 1.25), (0.4, 1.4),
               (0.2, 2.0), (0.17, 2.18), (0.3, 2.32), (0.3, 2.7)]
    n = 16
    for i in range(n):
        x = -7.5 + 15.0 * i / (n - 1)
        add_lathe(bm, x, yc, 32.6, profile)
    return [finish(bm, "Balustrade_Pierre", M_PIERRE, KIT)]

# ---------------------------------------------------------------- haie
def build_haie():
    me = bpy.data.meshes.new("tmp_haie")
    bm = bmesh.new()
    add_box(bm, -7.6, 7.6, -1.5, 1.5, 0, 3.4, bevel=0)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tmp_haie", me)
    scene.collection.objects.link(ob)
    bv = ob.modifiers.new("bev", 'BEVEL'); bv.width = 0.45; bv.segments = 2
    ss = ob.modifiers.new("sub", 'SUBSURF'); ss.levels = 2; ss.render_levels = 2
    tex = bpy.data.textures.new("haie_bruit", 'CLOUDS'); tex.noise_scale = 0.32
    dp = ob.modifiers.new("disp", 'DISPLACE'); dp.texture = tex; dp.strength = 0.4
    dg = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
    bm = bmesh.new()
    append_mesh(bm, baked)
    bpy.data.meshes.remove(baked)
    return [finish(bm, "Haie", M_HAIE, KIT, smooth=True)]

# ---------------------------------------------------------------- grimpante fleurie
def build_lierre():
    import random
    rnd = random.Random(7)
    bm_f, bm_fl = bmesh.new(), bmesh.new()
    stems = []
    for k in range(3):
        x0 = (k - 1) * 0.55
        top = rnd.uniform(9, 14)
        ph = rnd.uniform(0, 6.28)
        pts = [(x0 + 0.5 * math.sin(ph + z * 0.7), -0.1, z) for z in [i * top / 40 for i in range(41)]]
        stems.append(pts)
        for i in range(2, 41, 2):  # feuilles le long de la tige
            x, y, z = pts[i]
            sx = rnd.choice((-1, 1))
            add_sphere(bm_f, (x + sx * rnd.uniform(0.15, 0.35), -0.2, z + rnd.uniform(-0.1, 0.1)),
                       (rnd.uniform(0.22, 0.32), 0.07, rnd.uniform(0.14, 0.2)), u=6, v=4)
        for i in range(6, 41, 5):  # grappes de fleurs blanches
            x, y, z = pts[i]
            for j in range(rnd.randint(3, 5)):
                add_sphere(bm_fl, (x + rnd.uniform(-0.4, 0.4), -0.28, z + rnd.uniform(-0.35, 0.35)),
                           (0.13, 0.1, 0.13), u=6, v=4)
    tubes(bm_f, stems, 0.06)
    return [finish(bm_f, "Lierre_Feuilles", M_FEUILLE, KIT, smooth=True),
            finish(bm_fl, "Lierre_Fleurs", M_FLEUR, KIT, smooth=True)]

pieces = {
    "Travee": build_travee(),
    "Pilier": build_pilier(),
    "Balustrade": build_balustrade(),
    "Haie": build_haie(),
    "Lierre": build_lierre(),
}

# ---------------------------------------------------------------- bilan triangles
print("\n=== TRIANGLES PAR MESH (limite Roblox : 20 000) ===")
for name, objs in pieces.items():
    for ob in objs:
        ob.data.calc_loop_triangles()
        dims = ob.dimensions
        print(f"{ob.name:22s} {len(ob.data.loop_triangles):6d} tris   "
              f"{dims.x:5.1f} x {dims.y:4.1f} x {dims.z:4.1f} studs")

# ---------------------------------------------------------------- export FBX par pièce
for name, objs in pieces.items():
    for ob in bpy.data.objects:
        ob.select_set(False)
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, f"Rempart_{name}.fbx"),
                             use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- assemblages d'aperçu
def place(objs, coll, loc, rot_z):
    for ob in objs:
        c = ob.copy()  # copie liée : même mesh que la pièce du kit
        c.location = loc
        c.rotation_euler = (0, 0, rot_z)
        coll.objects.link(c)

ARC = collection("APERCU_ARC")
R = 90.0
D = 2 * math.asin((MODULE / 2) / R)
NB = 8
for k in range(NB + 1):
    th = (k - NB / 2) * D
    place(pieces["Pilier"], ARC, (R * math.sin(th), R * math.cos(th), 0), -th)
for k in range(NB):
    th = (k + 0.5 - NB / 2) * D
    rm = R * math.cos(D / 2)
    loc = Vector((rm * math.sin(th), rm * math.cos(th), 0))
    place(pieces["Travee"] + pieces["Balustrade"], ARC, loc, -th)
    inward = Vector((-math.sin(th), -math.cos(th), 0))
    place(pieces["Haie"], ARC, loc + inward * 4.3, -th)
    for sx in (-1, 1):
        side = Vector((math.cos(th), -math.sin(th), 0)) * (sx * 6.6)
        place(pieces["Lierre"], ARC, loc + side + inward * 1.55, -th)

PLANCHE = collection("PLANCHE_FACE")
OFF = Vector((0, -600, 0))
for i in range(3):
    place(pieces["Pilier"], PLANCHE, OFF + Vector((MODULE * (i - 1), 0, 0)), 0)
for i in range(2):
    place(pieces["Travee"] + pieces["Balustrade"], PLANCHE, OFF + Vector((MODULE * (i - 0.5), 0, 0)), 0)
    place(pieces["Haie"], PLANCHE, OFF + Vector((MODULE * (i - 0.5), -4.3, 0)), 0)
    for sx in (-1, 1):
        place(pieces["Lierre"], PLANCHE, OFF + Vector((MODULE * (i - 0.5) + sx * 6.6, -1.55, 0)), 0)

# sol
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=140)
sol = finish(bm, "Sol", M_SOL, ARC)
bm = bmesh.new()
add_box(bm, -60, 60, -30, 10, -0.5, 0, bevel=0)
finish(bm, "Sol_Planche", M_SOL, PLANCHE).location = OFF

# ---------------------------------------------------------------- lumière, caméra, rendu
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
try:
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Punchy'
except Exception:
    pass
try:
    scene.eevee.taa_render_samples = 64
except Exception:
    pass

world = bpy.data.worlds.new("Ciel")
scene.world = world
try:
    world.use_nodes = True
except Exception:
    pass
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.72, 0.8, 0.93, 1)
    bg.inputs[1].default_value = 0.55
else:
    world.color = (0.72, 0.8, 0.93)

sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 4.5
sun_data.color = (1.0, 0.94, 0.84)
sun_data.angle = math.radians(3)
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

# vue de trois quarts depuis l'intérieur de l'enceinte
cam_data.type = 'PERSP'
cam_data.lens = 26
aim((-34, 30, 9), (6, 84, 19))
PLANCHE.hide_render = True
render(os.path.join(APERCUS, "rempart_34.png"))

# élévation de face, orthographique
ARC.hide_render = True
PLANCHE.hide_render = False
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 80
aim(OFF + Vector((0, -80, 20)), OFF + Vector((0, 0, 20)))
render(os.path.join(APERCUS, "rempart_face.png"))
PLANCHE.hide_render = True
ARC.hide_render = False

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rempart_quartz.blend"))
print("OK")
