# Sol du palier P1 pour Pick Me Up (Roblox), d'après le concept validé (concept/sol_p1) :
# dalles gris-bleu irrégulières aux arêtes chanfreinées, joints de terre sableuse, mousse aux
# croisements, touffes d'herbe, longues bordures arrondies, place à anneaux avec filets d'argent.
# Reprend les cotes du plan (studio/sol_quartz.luau) : chaque allée, la place et chaque socle
# deviennent une pièce (pierre / terre / mousse / argent), placée à sa position réelle.
# Repère : les cotes sont écrites en coordonnées Roblox (X, Z au sol). L'import FBX fait
# Blender (x, y, z) -> Roblox (-x, z, y), donc ici x_blender = -X et y_blender = Z.
# Ce miroir inverse le sens des faces : chaque solide est remis à l'endroit par son volume signé.
# Usage : blender -b --factory-startup --python build_sol_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(2026)

# ---------------------------------------------------------------- matériaux
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, metallic=0.0, rough=0.7):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[srgb(c) for c in rgb255], 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return m

M_PIERRE = material("SolP1_Pierre", (78, 94, 116), rough=0.8)
M_TERRE = material("SolP1_Terre", (190, 164, 120), rough=0.95)
M_MOUSSE = material("SolP1_Mousse", (92, 132, 58), rough=0.9)
M_ARGENT = material("SolP1_Argent", (205, 212, 222), metallic=1.0, rough=0.3)
M_HERBE = material("Herbe_Apercu", (98, 150, 72), rough=0.9)

# ---------------------------------------------------------------- cotes (Roblox), reprises du plan
TOP_DALLE = 0.45     # dessus des dalles
TOP_TERRE = 0.36     # dessus de la terre des joints : presque à ras des dalles, comme sur le concept
TOP_BORDURE = 1.15
ALLEES = [
    ("Avenue_Sud", -8, 8, 30, 130), ("Allee_Nord", -8, 8, -62, -14),
    ("Allee_Ouest", -76, -22, 2, 14), ("Allee_Est", 22, 66, 2, 14),
    ("Allee_Logements", -64, -52, -69, 2), ("Allee_Artisans", -64, -52, 14, 40),
    ("Allee_Invocation_Admin", 12, 86, -63, -51), ("Allee_Faille_Nord", 61, 73, 18, 92),
    ("Raccord_Infirmerie", 47, 67, 86, 96), ("Raccord_Salle_Magie", 49, 61, -13, 2),
    ("Raccord_Synthese", 44, 56, -76, -63), ("Raccord_Transfert", -20, -8, -60, -52),
    ("Raccord_Logements", -74, -64, -56, -48), ("Raccord_Cantine", -98, -86, 14, 21),
]
LOTS = [
    ("Socle_Logements", -100, -74, -66, -38), ("Socle_Logements_Annexe", -101, -75, -25, 3),
    ("Socle_Cantine", -107, -79, 21, 49), ("Socle_Infirmerie", 21, 47, 78, 106),
    ("Socle_Administration", 81, 111, -58, -32), ("Socle_Entrainement", -78.5, -33.5, -99.5, -68.5),
    ("Socle_Quartier_Artisanal", -70, -20, 40, 106), ("Socle_Salle_Magie", 40, 70, -41, -13),
    ("Socle_Terrain_Magique", -33, -11, -112, -90), ("Socle_Station_Transfert", -40, -20, -65, -47),
    ("Socle_Chambre_Synthese", 36, 64, -104, -76),
]
PLACE = ("Place_Centrale", 0, 8, 25)
DISQUES = [("Socle_Faille", 78, 29, 24), ("Socle_Invocation", 12, -82, 22)]

# Base agrandie de 1,5 le 01/10/2026 : les cotes du plan sont multipliées, les dalles et les
# bordures gardent leur taille (il y en a davantage).
ECHELLE = 1.5
ALLEES = [(n, x0 * ECHELLE, x1 * ECHELLE, z0 * ECHELLE, z1 * ECHELLE) for n, x0, x1, z0, z1 in ALLEES]
LOTS = [(n, x0 * ECHELLE, x1 * ECHELLE, z0 * ECHELLE, z1 * ECHELLE) for n, x0, x1, z0, z1 in LOTS]
PLACE = (PLACE[0], PLACE[1] * ECHELLE, PLACE[2] * ECHELLE, PLACE[3] * ECHELLE)
DISQUES = [(n, x * ECHELLE, z * ECHELLE, r * ECHELLE) for n, x, z, r in DISQUES]

def B(X, Z, y=0.0):
    return Vector((-X, Z, y))

# formes pavées, pour ouvrir les bordures là où deux surfaces se touchent
RECTS = [(a[1], a[2], a[3], a[4]) for a in ALLEES + LOTS]
CERCLES = [(PLACE[1], PLACE[2], PLACE[3])] + [(d[1], d[2], d[3]) for d in DISQUES]

def pave_ailleurs(X, Z, sauf, marge=0.3):
    for r in RECTS:
        if r is sauf:
            continue
        if r[0] - marge <= X <= r[1] + marge and r[2] - marge <= Z <= r[3] + marge:
            return True
    for c in CERCLES:
        if c is sauf:
            continue
        if (X - c[0]) ** 2 + (Z - c[1]) ** 2 <= (c[2] + marge) ** 2:
            return True
    return False

# ---------------------------------------------------------------- outils bmesh
def oriente(bm, faces):
    """Remet un solide fermé à l'endroit si son volume signé est négatif."""
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

def brin(bm, X, Z, h, base=0.07):
    """Brin d'herbe : petite pyramide inclinée."""
    a0 = rnd.uniform(0, 2 * math.pi)
    pts = [(X + base * math.cos(a0 + 2 * math.pi * k / 3), Z + base * math.sin(a0 + 2 * math.pi * k / 3)) for k in range(3)]
    b = [bm.verts.new(B(x, z, TOP_TERRE)) for x, z in pts]
    pente = rnd.uniform(0, 2 * math.pi)
    top = bm.verts.new(B(X + 0.25 * h * math.cos(pente), Z + 0.25 * h * math.sin(pente), TOP_TERRE + h))
    faces = [bm.faces.new(list(reversed(b)))]
    for i in range(3):
        faces.append(bm.faces.new((b[i], b[(i + 1) % 3], top)))
    oriente(bm, faces)

def touffe(bm, X, Z):
    for _ in range(rnd.randint(4, 7)):
        brin(bm, X + rnd.uniform(-0.3, 0.3), Z + rnd.uniform(-0.3, 0.3), rnd.uniform(0.45, 0.95))

def contour_bloc(X, Z, w, d, ang, coupe, jitter):
    """Rectangle aux coins coupés, légèrement déformé : une dalle ou un bloc de bordure."""
    hw, hd = w / 2, d / 2
    cw, cd = min(coupe, hw * 0.45), min(coupe, hd * 0.45)
    loc = [(-hw + cw, -hd), (hw - cw, -hd), (hw, -hd + cd), (hw, hd - cd),
           (hw - cw, hd), (-hw + cw, hd), (-hw, hd - cd), (-hw, -hd + cd)]
    ca, sa = math.cos(ang), math.sin(ang)
    pts = []
    for lx, lz in loc:
        lx += rnd.uniform(-jitter, jitter)
        lz += rnd.uniform(-jitter, jitter)
        pts.append((X + lx * ca - lz * sa, Z + lx * sa + lz * ca))
    return pts

def secteur(X, Z, r0, r1, a0, a1, res):
    """Contour d'une dalle courbe (secteur d'anneau, ou part de disque si r0 = 0)."""
    ext = [(X + r1 * math.cos(a0 + (a1 - a0) * i / res), Z + r1 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res + 1)]
    if r0 <= 0.01:
        return [(X, Z)] + ext
    inte = [(X + r0 * math.cos(a0 + (a1 - a0) * i / res), Z + r0 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res, -1, -1)]
    return ext + inte

def blob(X, Z, r, k=9):
    return [(X + r * math.cos(2 * math.pi * i / k) * rnd.uniform(0.6, 1.1),
             Z + r * math.sin(2 * math.pi * i / k) * rnd.uniform(0.6, 1.1)) for i in range(k)]

def box_uv(bm, tile=8.0):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / tile, loop.vert.co[b] / tile)

COLL = bpy.data.collections.new("SOL_P1")
scene.collection.children.link(COLL)
OBJETS = []

def finish(bm, name, mat, smooth=False):
    if not bm.faces:
        bm.free()
        return None
    bmesh.ops.triangulate(bm, faces=bm.faces[:])   # garde le sens des faces fixé par oriente()
    box_uv(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    OBJETS.append(ob)
    return ob

class Piece:
    """Accumule les maillages d'une pièce ; coupe la pierre en morceaux sous 18 000 triangles."""
    def __init__(self, name):
        self.name = name
        self.terre, self.mousse, self.argent = bmesh.new(), bmesh.new(), bmesh.new()
        self.pierres, self.n = [bmesh.new()], 0
    def pierre(self):
        if self.n >= 380:   # ~44 triangles par dalle chanfreinée
            self.pierres.append(bmesh.new())
            self.n = 0
        self.n += 1
        return self.pierres[-1]
    def close(self):
        for i, bm in enumerate(self.pierres):
            finish(bm, f"{self.name}_Pierre" + (f"_{i + 1}" if len(self.pierres) > 1 else ""), M_PIERRE)
        finish(self.terre, f"{self.name}_Terre", M_TERRE)
        finish(self.mousse, f"{self.name}_Mousse", M_MOUSSE)
        finish(self.argent, f"{self.name}_Argent", M_ARGENT, smooth=True)

# ---------------------------------------------------------------- générateurs
def decor_joint(p, pts):
    """Mousse au croisement des joints et touffes d'herbe, autour d'une dalle."""
    if rnd.random() < 0.35:
        x, z = rnd.choice(pts)
        prisme(p.mousse, blob(x, z, rnd.uniform(0.35, 0.8), 7), TOP_TERRE - 0.03, TOP_TERRE + 0.06)
    if rnd.random() < 0.07:
        x, z = rnd.choice(pts)
        touffe(p.mousse, x, z)

def dallage_rect(p, x0, x1, z0, z1, taille=(1.8, 3.6), manque=0.12):
    """Dalles irrégulières en rangées alignées sur le grand côté, joints de terre."""
    long_x = (x1 - x0) >= (z1 - z0)
    (a0, a1), (b0, b1) = ((x0, x1), (z0, z1)) if long_x else ((z0, z1), (x0, x1))
    b = b0
    while b < b1 - 0.5:
        rw = min(rnd.uniform(*taille), b1 - b)
        if b1 - (b + rw) < 1.0:
            rw = b1 - b
        a = a0 + (rnd.uniform(0, 1.5) if rnd.random() < 0.5 else 0)
        while a < a1 - 0.5:
            rl = min(rnd.uniform(taille[0], taille[1] * 1.25), a1 - a)
            if a1 - (a + rl) < 1.0:
                rl = a1 - a
            ca, cb = a + rl / 2, b + rw / 2
            X, Z = (ca, cb) if long_x else (cb, ca)
            if rnd.random() > manque:
                g = rnd.uniform(0.18, 0.32)   # demi-joint : la terre se voit entre les dalles
                w, d = (rl - 2 * g, rw - 2 * g) if long_x else (rw - 2 * g, rl - 2 * g)
                top = TOP_DALLE + rnd.uniform(-0.06, 0.04)
                pts = contour_bloc(X, Z, w, d, rnd.uniform(-0.04, 0.04), min(w, d) * rnd.uniform(0.1, 0.22), 0.07)
                prisme(p.pierre(), pts, TOP_TERRE - 0.1, top, chanfrein=0.12)
                if rnd.random() < 0.1:
                    prisme(p.mousse, blob(X, Z, min(w, d) * 0.28, 7), top - 0.03, top + 0.03)
                decor_joint(p, pts)
            elif rnd.random() < 0.5:   # dalle manquante : terre nue, parfois une touffe
                touffe(p.mousse, X, Z)
            a += rl
        b += rw

def bordure_rect(p, rect, x0, x1, z0, z1):
    """Longs blocs de bordure autour d'un rectangle, sauf là où une autre surface pavée le prolonge."""
    for (ax, az, bx, bz, ox, oz) in ((x0, z0, x1, z0, 0, -1), (x0, z1, x1, z1, 0, 1),
                                     (x0, z0, x0, z1, -1, 0), (x1, z0, x1, z1, 1, 0)):
        longueur = math.hypot(bx - ax, bz - az)
        t = 0.0
        while t < longueur - 0.3:
            l = min(rnd.uniform(3.2, 5.2), longueur - t)
            m = (t + l / 2) / longueur
            X = ax + (bx - ax) * m + ox * 0.85
            Z = az + (bz - az) * m + oz * 0.85
            if not pave_ailleurs(X - ox * 0.6, Z - oz * 0.6, rect) and not pave_ailleurs(X, Z, rect):
                w, d = (l - 0.2, 1.6) if oz != 0 else (1.6, l - 0.2)
                pts = contour_bloc(X, Z, w, d, rnd.uniform(-0.025, 0.025), 0.35, 0.05)
                prisme(p.pierre(), pts, 0.0, TOP_BORDURE + rnd.uniform(-0.1, 0.05), chanfrein=0.24)
                if rnd.random() < 0.3:
                    prisme(p.mousse, blob(X, Z, 0.8, 7), TOP_BORDURE - 0.08, TOP_BORDURE + 0.04)
                if rnd.random() < 0.25:   # herbe au pied, côté allée
                    touffe(p.mousse, X - ox * 1.1, Z - oz * 1.1)
            t += l

def bordure_cercle(p, cercle, X, Z, r):
    n = max(12, int(2 * math.pi * r / 4.2))
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n + 0.015, 2 * math.pi * (i + 1) / n - 0.015
        am = (a0 + a1) / 2
        cx, cz = X + (r + 0.85) * math.cos(am), Z + (r + 0.85) * math.sin(am)
        ix, iz = X + (r - 0.3) * math.cos(am), Z + (r - 0.3) * math.sin(am)
        if pave_ailleurs(cx, cz, cercle) or pave_ailleurs(ix, iz, cercle):
            continue
        prisme(p.pierre(), secteur(X, Z, r + 0.1, r + 1.7, a0, a1, 3), 0.0,
               TOP_BORDURE + rnd.uniform(-0.1, 0.05), chanfrein=0.24)
        if rnd.random() < 0.3:
            prisme(p.mousse, blob(cx, cz, 0.8, 7), TOP_BORDURE - 0.08, TOP_BORDURE + 0.04)

def anneaux(p, X, Z, bandes, filets, centre_r):
    """Bandes de dalles courbes séparées par des rainures, filets d'argent entre les bandes."""
    for (r0, r1, n) in bandes:
        off = rnd.uniform(0, 2 * math.pi / n)
        for i in range(n):
            pad = 0.2 / ((r0 + r1) / 2)
            a0, a1 = off + 2 * math.pi * i / n + pad, off + 2 * math.pi * (i + 1) / n - pad
            res = max(3, int(8 * (a1 - a0) * r1 / 6))
            top = TOP_DALLE + rnd.uniform(-0.04, 0.02)
            prisme(p.pierre(), secteur(X, Z, r0, r1, a0, a1, res), TOP_TERRE - 0.1, top, chanfrein=0.1)
            am, rm = (a0 + a1) / 2, (r0 + r1) / 2
            if rnd.random() < 0.18:
                prisme(p.mousse, blob(X + rm * math.cos(am), Z + rm * math.sin(am), (r1 - r0) * 0.25, 7),
                       top - 0.03, top + 0.03)
            if rnd.random() < 0.3:   # mousse dans la rainure
                prisme(p.mousse, blob(X + r1 * math.cos(a1 + pad), Z + r1 * math.sin(a1 + pad), 0.5, 7),
                       TOP_TERRE - 0.03, TOP_TERRE + 0.06)
    if centre_r:
        prisme(p.pierre(), secteur(X, Z, 0, centre_r, 0, 2 * math.pi - 0.001, 24)[1:], TOP_TERRE - 0.1, TOP_DALLE, chanfrein=0.1)
    for r in filets:   # filet d'argent en 64 segments (un anneau n'a pas de contour simple)
        for i in range(64):
            a0, a1 = 2 * math.pi * i / 64 - 0.01, 2 * math.pi * (i + 1) / 64 + 0.01
            prisme(p.argent, secteur(X, Z, r - 0.18, r + 0.18, a0, a1, 1), TOP_DALLE - 0.2, TOP_DALLE + 0.03)

def terre_rect(p, x0, x1, z0, z1):
    prisme(p.terre, [(x0 - 0.4, z0 - 0.4), (x1 + 0.4, z0 - 0.4), (x1 + 0.4, z1 + 0.4), (x0 - 0.4, z1 + 0.4)],
           -0.3, TOP_TERRE)
    for _ in range(int((x1 - x0) * (z1 - z0) / 70) + 1):  # plaques de mousse sur la terre
        prisme(p.mousse, blob(rnd.uniform(x0 + 1, x1 - 1), rnd.uniform(z0 + 1, z1 - 1), rnd.uniform(0.6, 1.4)),
               TOP_TERRE - 0.03, TOP_TERRE + 0.05)

def terre_cercle(p, X, Z, r):
    prisme(p.terre, [(X + (r + 0.4) * math.cos(2 * math.pi * i / 48), Z + (r + 0.4) * math.sin(2 * math.pi * i / 48))
                     for i in range(48)], -0.3, TOP_TERRE)

# ---------------------------------------------------------------- construction
for (name, x0, x1, z0, z1), rect in zip(ALLEES, RECTS[:len(ALLEES)]):
    p = Piece(name)
    terre_rect(p, x0, x1, z0, z1)
    dallage_rect(p, x0, x1, z0, z1, taille=(1.8, 3.4), manque=0.12)
    bordure_rect(p, rect, x0, x1, z0, z1)
    p.close()

for (name, x0, x1, z0, z1), rect in zip(LOTS, RECTS[len(ALLEES):]):
    p = Piece(name)
    terre_rect(p, x0, x1, z0, z1)
    dallage_rect(p, x0, x1, z0, z1, taille=(2.6, 4.6), manque=0.08)
    bordure_rect(p, rect, x0, x1, z0, z1)
    p.close()

name, X, Z, R = PLACE
p = Piece(name)
terre_cercle(p, X, Z, R)
E = ECHELLE
anneaux(p, X, Z, bandes=[(19.6 * E, 24.6 * E, round(22 * E)), (12.4 * E, 19.2 * E, round(12 * E)), (5.4 * E, 12.0 * E, round(8 * E))],
        filets=[19.4 * E, 12.2 * E, 5.2 * E], centre_r=5.0 * E)
bordure_cercle(p, CERCLES[0], X, Z, R)
p.close()

for (name, X, Z, R), cercle in zip(DISQUES, CERCLES[1:]):
    p = Piece(name)
    terre_cercle(p, X, Z, R)
    anneaux(p, X, Z, bandes=[(R * 0.55, R - 0.2, round(16 * ECHELLE))], filets=[R * 0.53], centre_r=R * 0.51)
    bordure_cercle(p, cercle, X, Z, R)
    p.close()

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

for ob in bpy.data.objects:
    ob.select_set(False)
for ob in OBJETS:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Sol_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçu
# rendu en faces simples (comme Roblox) : une face retournée apparaîtrait comme un trou
for m in (M_PIERRE, M_TERRE, M_MOUSSE, M_ARGENT):
    m.use_backface_culling = True
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
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.76, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 3.2
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

cam_data.lens = 30
aim(B(-45, 93, 34), B(0, 21, 0))
render(os.path.join(APERCUS, "sol_p1_place.png"))
aim(B(21, 105, 8), B(0, 75, 0))
render(os.path.join(APERCUS, "sol_p1_detail.png"))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sol_p1.blend"))
print("OK")
