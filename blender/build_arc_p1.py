# Arc de l'archère 1 étoile (Pick Me Up, Roblox) : arc court taillé à la main, branches qui s'affinent,
# pointes légèrement recourbées vers la corde, poignée de cuir enroulé, encoches, corde un peu effilochée.
# 1 unité = 1 stud. Arc vertical (+Z Blender = +Y Roblox), dos de l'arc vers -Y (devant dans Roblox),
# corde du côté +Y, centre de la poignée à l'origine. Exporte export_p1/Arc_P1.fbx.
# Usage : blender -b --factory-startup --python build_arc_p1.py
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

def material(nom, rgb, rugo):
    m = bpy.data.materials.new(nom)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*[srgb(c) for c in rgb], 1)
    b.inputs["Roughness"].default_value = rugo
    m.use_backface_culling = True
    return m

M = {"Bois": material("Arc_Bois", (140, 100, 64), 0.75), "Cuir": material("Arc_Cuir", (90, 62, 42), 0.85),
     "Corde": material("Arc_Corde", (212, 202, 172), 0.9)}

DEMI = 1.3          # demi-hauteur de l'arc

def courbe(t):
    """Point de l'arc pour t dans [-1, 1] : ventre en arc vers -Y, pointes ramenées vers la corde."""
    a = abs(t)
    recourbe = 0.0 if a < 0.78 else ((a - 0.78) / 0.22) ** 2 * 0.13
    return Vector((0.0, -0.24 * (1 - t * t) + recourbe, DEMI * t))

def section(t):
    """Demi-largeur (X) et demi-épaisseur de la branche ; la poignée est plus forte."""
    a = abs(t)
    if a < 0.14:
        return 0.06, 0.055
    k = (a - 0.14) / 0.86
    return 0.055 - 0.03 * k, 0.045 - 0.022 * k

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
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(M[cle])
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    return ob

def ruban(bm, ts, rayon, seg=10, gonfle=0.0, spirale=None):
    """Volume le long de la courbe de l'arc entre les paramètres ts, section elliptique."""
    anneaux = []
    for i, t in enumerate(ts):
        p = courbe(t)
        q = courbe(min(t + 0.01, 1.0)) - courbe(max(t - 0.01, -1.0))
        tan = q.normalized()
        nor = Vector((1, 0, 0)).cross(tan).normalized()
        lx, ly = rayon(t)
        anneau = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            r = 1.0 + gonfle
            if spirale:
                r += spirale[0] * max(0.0, math.cos(a + t * spirale[1]))
            anneau.append(bm.verts.new(p + Vector((1, 0, 0)) * math.cos(a) * lx * r + nor * math.sin(a) * ly * r))
        anneaux.append(anneau)
    for a, b in zip(anneaux, anneaux[1:]):
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(list(reversed(anneaux[0])))
    bm.faces.new(anneaux[-1])

objets = []
# bois : branches et poignée d'une seule pièce, encoches aux pointes
bm = bmesh.new()
ruban(bm, [-1 + 2 * i / 60 for i in range(61)], section, seg=12)
for s in (1, -1):
    p = courbe(s * 1.0)
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.032,
                              matrix=__import__("mathutils").Matrix.Translation(p + Vector((0, 0.015, -s * 0.03))))
objets.append(piece("Arc_P1_Bois", "Bois", bm))
# cuir enroulé sur la poignée, en spirale
bm = bmesh.new()
ruban(bm, [-0.15 + 0.3 * i / 30 for i in range(31)], lambda t: (0.068, 0.063), seg=14, spirale=(0.12, 90))
objets.append(piece("Arc_P1_Cuir", "Cuir", bm))
# corde tendue entre les encoches, et une fibre effilochée près du haut
bm = bmesh.new()
haut, bas = courbe(1.0) + Vector((0, 0.02, -0.04)), courbe(-1.0) + Vector((0, 0.02, 0.04))
d = (haut - bas).normalized()
cyl = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.012, radius2=0.012, depth=(haut - bas).length)
rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
bmesh.ops.transform(bm, matrix=__import__("mathutils").Matrix.Translation((haut + bas) / 2) @ rot, verts=cyl["verts"])
fibre = [haut - d * 0.25, haut - d * 0.32 + Vector((0.03, 0.02, 0)), haut - d * 0.4 + Vector((0.05, 0.01, -0.02))]
for a, b in zip(fibre, fibre[1:]):
    c = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.006, radius2=0.005, depth=(b - a).length)
    r2 = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=__import__("mathutils").Matrix.Translation((a + b) / 2) @ r2, verts=c["verts"])
objets.append(piece("Arc_P1_Corde", "Corde", bm))

for ob in objets:
    ob.data.calc_loop_triangles()
    print(ob.name, len(ob.data.loop_triangles), "triangles")
for ob in bpy.data.objects:
    ob.select_set(ob in objets)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Arc_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 700, 1000
scene.view_settings.view_transform = 'AgX'
w = bpy.data.worlds.new("Ciel")
scene.world = w
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.36, 0.42, 1)
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(40))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = Vector((4.5, -1.5, 0.4))
cam.rotation_euler = (Vector((0, -0.1, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(APERCUS, "arc_p1.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "arc_p1.blend"))
print("OK")
