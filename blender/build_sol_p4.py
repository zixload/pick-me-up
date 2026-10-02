# Sol du palier P4 (quartz) pour Pick Me Up (Roblox) : la version Studio plaisait, en plus clair
# et plus détaillé (02/10/2026). Dalles de quartz clair aux angles coupés, joints en filets d'or,
# losanges d'or aux croisements, liserés de quartz plus soutenu, place à anneaux avec trois cercles
# et huit rayons d'or et une étoile au centre, socles surélevés à rebord, lots réservés ornés d'or.
# Mêmes cotes que le sol P1 (plan ×1,5) : chaque allée, la place et chaque socle sont une pièce
# (QuartzA / QuartzB / Bord / Or), à sa position réelle.
# Repère : cotes en coordonnées Roblox (X, Z au sol) ; l'import FBX fait Blender (x, y, z) -> Roblox
# (-x, z, y), donc x_blender = -X et y_blender = Z. Ce miroir inverse les faces : chaque solide est
# remis à l'endroit par son volume signé. Usage : blender -b --factory-startup --python build_sol_p4.py
import bpy, bmesh, math, os, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p4")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(404)

# ---------------------------------------------------------------- matériaux
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

COULEURS = {"QuartzA": (250, 242, 238), "QuartzB": (244, 233, 229), "Bord": (234, 219, 213), "Or": (232, 182, 82)}
M = {k: material(f"SolP4_{k}", c, metallic=1.0 if k == "Or" else 0.0, rough=0.28 if k == "Or" else 0.35)
     for k, c in COULEURS.items()}
M_HERBE = material("Herbe_Apercu", (98, 150, 72), rough=0.9)

# ---------------------------------------------------------------- cotes (Roblox), reprises du plan ×1,5
ECHELLE = 1.5
TOP_BASE_A, TOP_DALLE_A, TOP_LISERE = 0.3, 0.45, 0.52      # allées
TOP_BASE_S, TOP_DALLE_S, TOP_REBORD = 0.72, 0.86, 0.94     # socles et disques
TOP_PLACE, TOP_MARCHE = 0.55, 0.36
ALLEES = [
    ("Avenue_Sud", -8, 8, 30, 130), ("Allee_Nord", -8, 8, -62, -14),
    ("Allee_Ouest", -76, -22, 2, 14), ("Allee_Est", 22, 66, 2, 14),
    ("Allee_Logements", -64, -52, -69, 2), ("Allee_Artisans", -64, -52, 14, 40),
    ("Allee_Invocation_Admin", 12, 86, -63, -51), ("Allee_Faille_Nord", 61, 73, 18, 92),
    ("Raccord_Infirmerie", 47, 67, 86, 96), ("Raccord_Salle_Magie", 49, 61, -13, 2),
    ("Raccord_Synthese", 44, 56, -76, -63), ("Raccord_Transfert", -20, -8, -60, -52),
    ("Raccord_Logements", -74, -64, -56, -48), ("Raccord_Cantine", -98, -86, 14, 21),
]
LOTS = [  # nom, réservé, x0, x1, z0, z1
    ("Socle_Logements", False, -100, -74, -66, -38), ("Socle_Logements_Annexe", False, -101, -75, -25, 3),
    ("Socle_Cantine", False, -107, -79, 21, 49), ("Socle_Infirmerie", False, 21, 47, 78, 106),
    ("Socle_Administration", False, 81, 111, -58, -32), ("Socle_Entrainement", False, -78.5, -33.5, -99.5, -68.5),
    ("Socle_Quartier_Artisanal", False, -70, -20, 40, 106), ("Socle_Salle_Magie", True, 40, 70, -41, -13),
    ("Socle_Terrain_Magique", True, -33, -11, -112, -90), ("Socle_Station_Transfert", True, -40, -20, -65, -47),
    ("Socle_Chambre_Synthese", True, 36, 64, -104, -76),
]
PLACE = ("Place_Centrale", 0, 8, 25)
DISQUES = [("Socle_Faille", 78, 29, 24), ("Socle_Invocation", 12, -82, 22)]
E = ECHELLE
ALLEES = [(n, a * E, b * E, c * E, d * E) for n, a, b, c, d in ALLEES]
LOTS = [(n, r, a * E, b * E, c * E, d * E) for n, r, a, b, c, d in LOTS]
PLACE = (PLACE[0], PLACE[1] * E, PLACE[2] * E, PLACE[3] * E)
DISQUES = [(n, x * E, z * E, r * E) for n, x, z, r in DISQUES]

def B(X, Z, y=0.0):
    return Vector((-X, Z, y))

RECTS = [(a[1], a[2], a[3], a[4]) for a in ALLEES] + [(l[2], l[3], l[4], l[5]) for l in LOTS]
CERCLES = [(PLACE[1], PLACE[2], PLACE[3])] + [(d[1], d[2], d[3]) for d in DISQUES]

def pave_ailleurs(X, Z, sauf, marge=0.3):
    for r in RECTS:
        if r is not sauf and r[0] - marge <= X <= r[1] + marge and r[2] - marge <= Z <= r[3] + marge:
            return True
    for c in CERCLES:
        if c is not sauf and (X - c[0]) ** 2 + (Z - c[1]) ** 2 <= (c[2] + marge) ** 2:
            return True
    return False

# ---------------------------------------------------------------- outils bmesh
def oriente(bm, faces):
    vol = 0.0
    for f in faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1]))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=faces)

def prisme(bm, pts, z0, z1, chanfrein=0.0):
    """Prisme vertical sur un contour (X, Z) ; le chanfrein adoucit les arêtes du dessus."""
    n = len(pts)
    cx, cz = sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n
    bas = [bm.verts.new(B(x, z, z0)) for x, z in pts]
    if chanfrein > 0:
        mil = [bm.verts.new(B(x, z, z1 - chanfrein)) for x, z in pts]
        haut = []
        for x, z in pts:
            dx, dz = cx - x, cz - z
            k = min(chanfrein / (math.hypot(dx, dz) or 1), 0.45)
            haut.append(bm.verts.new(B(x + dx * k, z + dz * k, z1)))
        anneaux = [bas, mil, haut]
    else:
        haut = [bm.verts.new(B(x, z, z1)) for x, z in pts]
        anneaux = [bas, haut]
    faces = [bm.faces.new(list(reversed(bas))), bm.faces.new(haut)]
    for a, b in zip(anneaux, anneaux[1:]):
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    oriente(bm, faces)

def rect(x0, x1, z0, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]

def dalle_coins_coupes(x0, x1, z0, z1, c):
    return [(x0 + c, z0), (x1 - c, z0), (x1, z0 + c), (x1, z1 - c), (x1 - c, z1), (x0 + c, z1), (x0, z1 - c), (x0, z0 + c)]

def losange(X, Z, r):
    return [(X + r, Z), (X, Z + r), (X - r, Z), (X, Z - r)]

def secteur(X, Z, r0, r1, a0, a1, res):
    ext = [(X + r1 * math.cos(a0 + (a1 - a0) * i / res), Z + r1 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res + 1)]
    if r0 <= 0.01:
        return [(X, Z)] + ext
    inn = [(X + r0 * math.cos(a0 + (a1 - a0) * i / res), Z + r0 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res, -1, -1)]
    return ext + inn

def disque_contour(X, Z, r, n=64):
    return [(X + r * math.cos(2 * math.pi * i / n), Z + r * math.sin(2 * math.pi * i / n)) for i in range(n)]

def anneau(bm, X, Z, r0, r1, z0, z1, n=96, chanfrein=0.0):
    for i in range(n):
        prisme(bm, secteur(X, Z, r0, r1, 2 * math.pi * i / n - 0.003, 2 * math.pi * (i + 1) / n + 0.003, 1), z0, z1, chanfrein)

def box_uv(bm, tile=8.0):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / tile, loop.vert.co[b] / tile)

COLL = bpy.data.collections.new("SOL_P4")
scene.collection.children.link(COLL)
OBJETS = []

def finish(bm, name, mat):
    if not bm.faces:
        bm.free()
        return
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    box_uv(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    OBJETS.append(ob)

class Piece:
    """Maillages d'une pièce, coupés en morceaux sous 18 000 triangles (~44 par dalle)."""
    def __init__(self, name):
        self.name = name
        self.bms = {k: [bmesh.new()] for k in M}
        self.n = {k: 0 for k in M}
    def bm(self, sorte, poids=1):
        if self.n[sorte] + poids > 400:
            self.bms[sorte].append(bmesh.new())
            self.n[sorte] = 0
        self.n[sorte] += poids
        return self.bms[sorte][-1]
    def ton(self):
        return self.bm(rnd.choice(("QuartzA", "QuartzB")))
    def close(self):
        for sorte, liste in self.bms.items():
            for i, bm in enumerate(liste):
                finish(bm, f"{self.name}_{sorte}" + (f"_{i + 1}" if len(liste) > 1 else ""), M[sorte])

# ---------------------------------------------------------------- générateurs
def grille(p, x0, x1, z0, z1, taille, z_base, z_dalle, coin):
    """Dalles aux angles coupés sur une grille ajustée au rectangle, joints en filets d'or,
    losange d'or un croisement sur deux."""
    nx, nz = max(1, round((x1 - x0) / taille)), max(1, round((z1 - z0) / taille))
    tx, tz = (x1 - x0) / nx, (z1 - z0) / nz
    g = 0.16
    for i in range(nx):
        for j in range(nz):
            a0, a1, b0, b1 = x0 + i * tx + g, x0 + (i + 1) * tx - g, z0 + j * tz + g, z0 + (j + 1) * tz - g
            prisme(p.ton(), dalle_coins_coupes(a0, a1, b0, b1, coin), z_base, z_dalle + rnd.uniform(-0.01, 0.01), chanfrein=0.07)
    zf = z_dalle - 0.04
    for i in range(nx + 1):
        x = x0 + i * tx
        prisme(p.bm("Or"), rect(x - 0.1, x + 0.1, z0, z1), z_base, zf)
    for j in range(nz + 1):
        z = z0 + j * tz
        prisme(p.bm("Or"), rect(x0, x1, z - 0.1, z + 0.1), z_base, zf)
    for i in range(nx + 1):
        for j in range(nz + 1):
            if (i + j) % 2 == 0:
                prisme(p.bm("Or"), losange(x0 + i * tx, z0 + j * tz, coin * 0.95), z_base, z_dalle - 0.015)

def liseres(p, forme, x0, x1, z0, z1, largeur, z0b, z1b, filet_or=False):
    """Bandes de bordure sur les quatre côtés, ouvertes là où une autre surface prolonge la pièce."""
    for (ax, az, bx, bz, ox, oz) in ((x0, z0, x1, z0, 0, -1), (x0, z1, x1, z1, 0, 1),
                                     (x0, z0, x0, z1, -1, 0), (x1, z0, x1, z1, 1, 0)):
        longueur = math.hypot(bx - ax, bz - az)
        n = max(1, round(longueur / 4))
        for k in range(n):
            m0, m1 = k / n, (k + 1) / n
            mx, mz = ax + (bx - ax) * (m0 + m1) / 2, az + (bz - az) * (m0 + m1) / 2
            if pave_ailleurs(mx + ox * 0.6, mz + oz * 0.6, forme):   # une surface touche ce bord, côté extérieur
                continue
            px0, pz0 = ax + (bx - ax) * m0, az + (bz - az) * m0
            px1, pz1 = ax + (bx - ax) * m1, az + (bz - az) * m1
            if oz != 0:
                pts = rect(px0, px1, min(pz0, pz0 + oz * largeur), max(pz0, pz0 + oz * largeur))
            else:
                pts = rect(min(px0, px0 + ox * largeur), max(px0, px0 + ox * largeur), pz0, pz1)
            prisme(p.bm("Bord"), pts, z0b, z1b, chanfrein=0.1)
            if filet_or:
                cx, cz = mx + ox * largeur * 0.5, mz + oz * largeur * 0.5
                if oz != 0:
                    prisme(p.bm("Or"), rect(px0, px1, cz - 0.08, cz + 0.08), z1b - 0.1, z1b + 0.015)
                else:
                    prisme(p.bm("Or"), rect(cx - 0.08, cx + 0.08, pz0, pz1), z1b - 0.1, z1b + 0.015)

def allee(nom, x0, x1, z0, z1, forme):
    p = Piece(nom)
    prisme(p.bm("Bord"), rect(x0 - 1.0, x1 + 1.0, z0 - 1.0, z1 + 1.0), -0.3, TOP_BASE_A)
    grille(p, x0, x1, z0, z1, 4.0, TOP_BASE_A - 0.05, TOP_DALLE_A, 0.42)
    liseres(p, forme, x0, x1, z0, z1, 1.0, -0.3, TOP_LISERE)
    p.close()

def socle(nom, reserve, x0, x1, z0, z1, forme):
    p = Piece(nom)
    prisme(p.bm("Bord"), rect(x0, x1, z0, z1), -0.3, TOP_BASE_S, chanfrein=0.1)
    grille(p, x0 + 1.3, x1 - 1.3, z0 + 1.3, z1 - 1.3, 6.0, TOP_BASE_S - 0.05, TOP_DALLE_S, 0.6)
    # rebord mouluré à l'intérieur du socle, ouvert vers les allées
    liseres(p, forme, x0, x1, z0, z1, -1.3, TOP_BASE_S - 0.05, TOP_REBORD, filet_or=reserve)
    if reserve:   # losanges d'or aux angles : emplacement à construire
        for cx, cz in ((x0 + 0.65, z0 + 0.65), (x1 - 0.65, z0 + 0.65), (x1 - 0.65, z1 - 0.65), (x0 + 0.65, z1 - 0.65)):
            prisme(p.bm("Or"), losange(cx, cz, 0.55), TOP_REBORD - 0.05, TOP_REBORD + 0.04)
    p.close()

def etoile(X, Z, r_ext, r_int, branches=8, rot=0.0):
    return [(X + (r_ext if k % 2 == 0 else r_int) * math.cos(rot + math.pi * k / branches),
             Z + (r_ext if k % 2 == 0 else r_int) * math.sin(rot + math.pi * k / branches)) for k in range(2 * branches)]

def place(nom, X, Z, R):
    p = Piece(nom)
    prisme(p.bm("Bord"), disque_contour(X, Z, R + 2.4, 96), -0.3, TOP_MARCHE, chanfrein=0.12)   # marche
    prisme(p.bm("Bord"), disque_contour(X, Z, R, 96), TOP_MARCHE - 0.1, TOP_PLACE - 0.12)      # lit de pose
    bandes = [(R * 0.81, R - 0.4, 32), (R * 0.49, R * 0.79, 24), (R * 0.21, R * 0.47, 16)]
    for r0, r1, n in bandes:
        for i in range(n):
            pad = 0.14 / ((r0 + r1) / 2)
            a0, a1 = 2 * math.pi * i / n + pad, 2 * math.pi * (i + 1) / n - pad
            prisme(p.ton(), secteur(X, Z, r0, r1, a0, a1, max(3, int(6 * (a1 - a0) * r1 / 4))), TOP_PLACE - 0.17, TOP_PLACE, chanfrein=0.07)
    prisme(p.ton(), disque_contour(X, Z, R * 0.19, 48), TOP_PLACE - 0.17, TOP_PLACE, chanfrein=0.07)
    # trois cercles d'or, huit rayons d'or dans les joints, étoile au centre
    for r in (R * 0.80, R * 0.48, R * 0.20):
        anneau(p.bm("Or", 4), X, Z, r - 0.22, r + 0.22, TOP_PLACE - 0.2, TOP_PLACE - 0.02, 96)
    anneau(p.bm("Or", 4), X, Z, R - 0.3, R - 0.05, TOP_PLACE - 0.2, TOP_PLACE + 0.02, 96)
    for k in range(8):
        a = math.pi * k / 4
        c, s = math.cos(a), math.sin(a)
        w = 0.16
        pts = [(X + R * 0.21 * c - w * s, Z + R * 0.21 * s + w * c), (X + R * 0.80 * c - w * s, Z + R * 0.80 * s + w * c),
               (X + R * 0.80 * c + w * s, Z + R * 0.80 * s - w * c), (X + R * 0.21 * c + w * s, Z + R * 0.21 * s - w * c)]
        prisme(p.bm("Or"), pts, TOP_PLACE - 0.2, TOP_PLACE - 0.02)
    prisme(p.bm("Or"), etoile(X, Z, R * 0.17, R * 0.07, 8, math.pi / 8), TOP_PLACE - 0.05, TOP_PLACE + 0.04)
    prisme(p.bm("Or"), disque_contour(X, Z, R * 0.035, 24), TOP_PLACE, TOP_PLACE + 0.08)
    # petits losanges d'or sur la marche, un tous les 10°
    for k in range(36):
        a = 2 * math.pi * k / 36
        prisme(p.bm("Or"), losange(X + (R + 1.2) * math.cos(a), Z + (R + 1.2) * math.sin(a), 0.35), TOP_MARCHE - 0.05, TOP_MARCHE + 0.03)
    p.close()

def disque_socle(nom, X, Z, R):
    p = Piece(nom)
    prisme(p.bm("Bord"), disque_contour(X, Z, R, 96), -0.3, TOP_BASE_S, chanfrein=0.1)
    anneau(p.bm("Bord", 2), X, Z, R - 1.4, R, TOP_BASE_S - 0.05, TOP_REBORD, 64, chanfrein=0.1)
    for r0, r1, n in ((R * 0.58, R - 1.55, 32), (R * 0.27, R * 0.56, 16)):
        for i in range(n):
            pad = 0.14 / ((r0 + r1) / 2)
            a0, a1 = 2 * math.pi * i / n + pad, 2 * math.pi * (i + 1) / n - pad
            prisme(p.ton(), secteur(X, Z, r0, r1, a0, a1, max(3, int(6 * (a1 - a0) * r1 / 4))), TOP_BASE_S - 0.05, TOP_DALLE_S, chanfrein=0.07)
    prisme(p.ton(), disque_contour(X, Z, R * 0.25, 40), TOP_BASE_S - 0.05, TOP_DALLE_S, chanfrein=0.07)
    for r in (R * 0.57, R * 0.26):
        anneau(p.bm("Or", 4), X, Z, r - 0.2, r + 0.2, TOP_BASE_S - 0.05, TOP_DALLE_S - 0.03, 96)
    anneau(p.bm("Or", 4), X, Z, R - 0.75, R - 0.6, TOP_REBORD - 0.1, TOP_REBORD + 0.015, 96)
    p.close()

# ---------------------------------------------------------------- construction
for (nom, x0, x1, z0, z1), forme in zip(ALLEES, RECTS[:len(ALLEES)]):
    allee(nom, x0, x1, z0, z1, forme)
for (nom, reserve, x0, x1, z0, z1), forme in zip(LOTS, RECTS[len(ALLEES):]):
    socle(nom, reserve, x0, x1, z0, z1, forme)
place(*PLACE)
for (nom, X, Z, R) in DISQUES:
    disque_socle(nom, X, Z, R)

# ---------------------------------------------------------------- bilan
print("\n=== MAILLAGES ===")
total, pire, negatifs = 0, ("", 0), []
for ob in OBJETS:
    me = ob.data
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    total += n
    if n > pire[1]:
        pire = (ob.name, n)
    vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
              for t in me.loop_triangles)
    if vol < 0:
        negatifs.append(ob.name)
print(f"{len(OBJETS)} maillages, {total} triangles au total, le plus lourd : {pire[0]} ({pire[1]})")
print("Maillages à l'envers :", negatifs if negatifs else "aucun")
ref = bpy.data.objects["Place_Centrale_Or"] if "Place_Centrale_Or" in bpy.data.objects else None
if ref:
    pts = [ref.matrix_world @ Vector(c) for c in ref.bound_box]
    print("REF Place_Centrale_Or centre blender", [round(sum(p[i] for p in pts) / 8, 3) for i in range(3)])

for ob in bpy.data.objects:
    ob.select_set(False)
for ob in OBJETS:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Sol_P4.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçus
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=128, radius=210)
me = bpy.data.meshes.new("Herbe")
bm.to_mesh(me)
bm.free()
me.materials.append(M_HERBE)
herbe = bpy.data.objects.new("Herbe", me)
herbe.location.z = -0.01
scene.collection.objects.link(herbe)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Punchy'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.66, 0.73, 0.82, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 3.4
sun_data.color = (1.0, 0.96, 0.9)
sun_data.angle = math.radians(6)
sun = bpy.data.objects.new("Soleil", sun_data)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam

def vue(loc, cible, chemin, lens=30):
    cam.location = loc
    cam.rotation_euler = (Vector(cible) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

vue(B(-45, 93, 34), B(0, 21, 0), os.path.join(APERCUS, "sol_p4_place.png"))
vue(B(16, 100, 7), B(0, 75, 0), os.path.join(APERCUS, "sol_p4_detail.png"), lens=28)
vue(B(-40, 30, 14), B(-67, 92, 0), os.path.join(APERCUS, "sol_p4_socle.png"), lens=28)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sol_p4.blend"))
print("OK")
