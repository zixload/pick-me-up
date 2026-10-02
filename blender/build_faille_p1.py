# Faille spatio-temporelle, palier P1, pour Pick Me Up (Roblox), d'après le concept validé :
# rotonde de pierre gris-bleu à colonnade, dôme bas en gradins, porte cintrée cerclée d'argent
# entrouverte sur une déchirure cyan lumineuse, coulures de mousse.
# v2 (retours du 02/10/2026) : colonnes massives à cannelures creusées et tambours, tambour appareillé
# en blocs, claveaux, médaillon et frise en méandre, mousse qui épouse les surfaces, tons légers.
# 1 unité = 1 stud, origine au sol au centre, porte tournée vers -Y (comme les autres kits).
# Lot du plan : disque de rayon 36 (24 × 1,5). Usage : blender -b --factory-startup --python build_faille_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(1111)

# ---------------------------------------------------------------- matériaux
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, metallic=0.0, rough=0.75, emission=0.0):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgb = (*[srgb(c) for c in rgb255], 1)
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = rgb
        bsdf.inputs["Emission Strength"].default_value = emission
    m.use_backface_culling = True
    return m

# trois tons de pierre proches (variation légère), joints plus sombres, gravures un peu plus claires
COULEURS = {
    "PierreA": (84, 100, 122), "PierreB": (93, 109, 130), "PierreC": (76, 91, 112),
    "Joint": (52, 62, 78), "Gravure": (104, 120, 142), "Sombre": (40, 48, 60),
    "Porte": (62, 74, 92), "Argent": (205, 212, 222), "Mousse": (88, 128, 56), "Lumiere": (140, 235, 245),
}
M = {}
for k, c in COULEURS.items():
    M[k] = material(f"Faille_{k}", c, metallic=1.0 if k == "Argent" else 0.0, rough=0.3 if k == "Argent" else 0.8,
                    emission=6.0 if k == "Lumiere" else 0.0)
BM = {k: bmesh.new() for k in M}
TONS = ["PierreA", "PierreB", "PierreC"]
def ton():
    return BM[rnd.choice(TONS)]

# ---------------------------------------------------------------- cotes
Z_PLAT1, Z_PLAT2 = 1.0, 2.0            # plateforme à deux marches
R_PLAT1, R_PLAT2 = 32.0, 29.0
Z_POD, R_POD = 5.0, 22.0               # podium qui porte colonnes et tambour
R_TAMB, EP_TAMB = 15.0, 2.0            # tambour (cella)
Z_ENTA0, Z_ARCHI, Z_ENTA1 = 25.0, 26.2, 27.6   # architrave, frise, haut de l'entablement
Z_CORN = 28.7                          # corniche
Z_ATTI = 30.2                          # attique
R_ENTA = 21.4                          # face de l'entablement
R_COL, N_COL, RAY_COL = 19.0, 10, 1.6  # colonnade
PORTE_DEMI, PORTE_IMPOSTE = 4.2, 12.0  # porte : demi-largeur, naissance de l'arc
A_PORTE = -math.pi / 2                 # direction -Y

# ---------------------------------------------------------------- outils
def oriente(bm, faces):
    vol = 0.0
    for f in faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1]))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=faces)

def solide(bm, bas, haut):
    """Solide fermé entre deux contours 3D de même nombre de points."""
    vb = [bm.verts.new(p) for p in bas]
    vh = [bm.verts.new(p) for p in haut]
    faces = [bm.faces.new(list(reversed(vb))), bm.faces.new(vh)]
    n = len(vb)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((vb[i], vb[j], vh[j], vh[i])))
    oriente(bm, faces)

def prisme(bm, pts3_bas, decalage):
    solide(bm, pts3_bas, [p + decalage for p in pts3_bas])

def prisme_z(bm, pts2, z0, z1):
    solide(bm, [Vector((x, y, z0)) for x, y in pts2], [Vector((x, y, z1)) for x, y in pts2])

def cercle(r, n, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]

def secteur(r0, r1, a0, a1, res):
    ext = [(r1 * math.cos(a0 + (a1 - a0) * i / res), r1 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res + 1)]
    inn = [(r0 * math.cos(a0 + (a1 - a0) * i / res), r0 * math.sin(a0 + (a1 - a0) * i / res)) for i in range(res, -1, -1)]
    return ext + inn

def anneau(bm, r0, r1, z0, z1, n=64, a0=0.0, a1=2 * math.pi):
    pas = (a1 - a0) / n
    for i in range(n):
        prisme_z(bm, secteur(r0, r1, a0 + pas * i - 0.002, a0 + pas * (i + 1) + 0.002, 1), z0, z1)

def disque(bm, r, z0, z1, n=64):
    prisme_z(bm, cercle(r, n), z0, z1)

def tronc(bm, cx, cy, r0, r1, z0, z1, n=24):
    solide(bm, [Vector((x, y, z0)) for x, y in cercle(r0, n, cx, cy)], [Vector((x, y, z1)) for x, y in cercle(r1, n, cx, cy)])

def carre(bm, cx, cy, demi, z0, z1):
    prisme_z(bm, [(cx - demi, cy - demi), (cx + demi, cy - demi), (cx + demi, cy + demi), (cx - demi, cy + demi)], z0, z1)

def appareil(r0, r1, z0, z1, hauteur_rang, longueur_bloc, a0, a1, joint=0.12):
    """Blocs d'un mur courbe, rangs décalés d'un demi-bloc ; chacun prend un ton au hasard."""
    z, rang = z0, 0
    while z < z1 - 0.05:
        h = min(hauteur_rang, z1 - z)
        pas = longueur_bloc / ((r0 + r1) / 2)
        a = a0 - (pas / 2 if rang % 2 else 0)
        while a < a1 - 0.01:
            b0, b1 = max(a, a0), min(a + pas * rnd.uniform(0.8, 1.2), a1)
            if b1 - b0 > 0.02:
                g = joint / 2 / r1
                prisme_z(ton(), secteur(r0, r1 + rnd.uniform(-0.03, 0.05), b0 + g, b1 - g, 3), z + joint / 2, z + h - joint / 2)
            a = b1
        z += h
        rang += 1

# coulures de mousse plaquées sur un cylindre : le contour s'enroule autour de la surface
def coulure_contour(longueur, largeur, pas=6):
    gauche, droite = [], []
    for i in range(pas + 1):
        t = i / pas
        w = largeur * (1 - 0.85 * t ** 1.4) * rnd.uniform(0.85, 1.1)
        dx = rnd.uniform(-0.1, 0.1) * largeur
        gauche.append((-w / 2 + dx, -longueur * t))
        droite.append((w / 2 + dx, -longueur * t))
    return gauche + [(rnd.uniform(-0.05, 0.05), -longueur - rnd.uniform(0.15, 0.4))] + list(reversed(droite))

def coulure(bm, cx, cy, r, a, z_haut, longueur, largeur):
    pts = coulure_contour(longueur, largeur)
    def p(u, v, dr):
        b = a + u / r
        return Vector((cx + (r + dr) * math.cos(b), cy + (r + dr) * math.sin(b), z_haut + v))
    solide(bm, [p(u, v, -0.02) for u, v in pts], [p(u, v, 0.05) for u, v in pts])

def plaque_mousse(bm, cx, cy, rayon, z):
    pts = [(cx + rayon * math.cos(t) * rnd.uniform(0.6, 1.1), cy + rayon * math.sin(t) * rnd.uniform(0.6, 1.1))
           for t in [2 * math.pi * i / 8 for i in range(8)]]
    prisme_z(bm, pts, z - 0.03, z + 0.07)

# ---------------------------------------------------------------- plateforme, podium, escalier
def dallage_anneau(r0, r1, z0, z1, n):
    off = rnd.uniform(0, 2 * math.pi / n)
    for i in range(n):
        a0, a1 = off + 2 * math.pi * i / n + 0.06 / r1, off + 2 * math.pi * (i + 1) / n - 0.06 / r1
        prisme_z(ton(), secteur(r0, r1, a0, a1, 3), z0, z1 + rnd.uniform(-0.03, 0.03))
disque(BM["Joint"], R_PLAT1 - 0.1, -0.4, Z_PLAT1 - 0.06, 72)              # lit de joints
disque(BM["Joint"], R_PLAT2 - 0.1, Z_PLAT1 - 0.1, Z_PLAT2 - 0.06, 72)
dallage_anneau(R_PLAT2 + 0.1, R_PLAT1, -0.4, Z_PLAT1, 40)
dallage_anneau(R_POD + 0.2, R_PLAT2, Z_PLAT1 - 0.1, Z_PLAT2, 34)
# podium : noyau, blocs de parement, larmier
disque(BM["Joint"], R_POD - 0.15, Z_PLAT2 - 0.1, Z_POD, 64)
appareil(R_POD - 1.2, R_POD, Z_PLAT2, Z_POD, 1.5, 4.5, A_PORTE + 0.28, A_PORTE + 2 * math.pi - 0.28)
anneau(BM["PierreB"], R_POD - 0.8, R_POD + 0.4, Z_POD - 0.5, Z_POD + 0.06, 64)
# escalier : six marches de la plateforme au podium, avec deux joues
for i in range(6):
    y_avant = -(R_POD + (6 - i) * 0.95)
    prisme_z(ton(), [(-5.0, y_avant), (5.0, y_avant), (5.0, -R_POD + 2.5), (-5.0, -R_POD + 2.5)],
             Z_PLAT2 - 0.1, Z_PLAT2 + 0.5 * (i + 1))
for sx in (-1, 1):
    x0, x1 = (5.0, 6.6) if sx > 0 else (-6.6, -5.0)
    pts = [Vector((x0, -(R_POD + 6.2), Z_PLAT2 - 0.1)), Vector((x0, -R_POD + 2.5, Z_PLAT2 - 0.1)),
           Vector((x0, -R_POD + 2.5, Z_POD + 0.7)), Vector((x0, -(R_POD + 6.2), Z_PLAT2 + 0.8))]
    prisme(BM["PierreB"], pts, Vector((x1 - x0, 0, 0)))

# ---------------------------------------------------------------- tambour appareillé, porte
L = PORTE_DEMI + 1.6                                     # demi-largeur du trumeau autour de la porte
demi_angle = math.asin(L / R_TAMB)                       # l'appareil s'arrête au trumeau
anneau(BM["Joint"], R_TAMB - EP_TAMB, R_TAMB - 0.15, Z_POD - 0.1, Z_ENTA0 + 0.1, 46,
       A_PORTE + demi_angle, A_PORTE + 2 * math.pi - demi_angle)
appareil(R_TAMB - 0.4, R_TAMB, Z_POD, Z_ENTA0, 2.5, 4.2, A_PORTE + demi_angle, A_PORTE + 2 * math.pi - demi_angle)
# trumeau plat (piédroits et tympan) qui entoure la porte, puis claveaux, médaillon et encadrement
y_avant = -R_TAMB * math.cos(demi_angle) - 0.05
contour = [(-L, Z_POD), (-PORTE_DEMI, Z_POD)]
contour += [(PORTE_DEMI * math.cos(t), PORTE_IMPOSTE + PORTE_DEMI * math.sin(t)) for t in [math.pi - math.pi * k / 16 for k in range(17)]]
contour += [(PORTE_DEMI, Z_POD), (L, Z_POD), (L, Z_ENTA0 + 0.1), (-L, Z_ENTA0 + 0.1)]
prisme(BM["PierreA"], [Vector((u, y_avant, v)) for u, v in contour], Vector((0, EP_TAMB + 0.05, 0)))
for k in range(9):   # claveaux en éventail, la clé au centre plus haute
    t0, t1 = math.pi - math.pi * k / 9 - 0.015, math.pi - math.pi * (k + 1) / 9 + 0.015
    r1 = PORTE_DEMI + (2.1 if k == 4 else 1.5)
    pts = [(PORTE_DEMI * math.cos(t0), PORTE_IMPOSTE + PORTE_DEMI * math.sin(t0)), (r1 * math.cos(t0), PORTE_IMPOSTE + r1 * math.sin(t0)),
           (r1 * math.cos(t1), PORTE_IMPOSTE + r1 * math.sin(t1)), (PORTE_DEMI * math.cos(t1), PORTE_IMPOSTE + PORTE_DEMI * math.sin(t1))]
    prisme(ton(), [Vector((u, y_avant - 0.3, v)) for u, v in pts], Vector((0, 0.35, 0)))
# médaillon gravé au-dessus de la porte : disque, anneau, huit rayons, cœur
zm = PORTE_IMPOSTE + PORTE_DEMI + 4.6
def plat(pts, y0, ep, bm):
    prisme(bm, [Vector((u, y0, v)) for u, v in pts], Vector((0, ep, 0)))
plat([(1.9 * math.cos(t), zm + 1.9 * math.sin(t)) for t in [2 * math.pi * i / 24 for i in range(24)]], y_avant - 0.15, 0.2, BM["PierreB"])
for i in range(24):
    t0, t1 = 2 * math.pi * i / 24, 2 * math.pi * (i + 1) / 24 + 0.01
    plat([(1.55 * math.cos(t0), zm + 1.55 * math.sin(t0)), (1.75 * math.cos(t0), zm + 1.75 * math.sin(t0)),
          (1.75 * math.cos(t1), zm + 1.75 * math.sin(t1)), (1.55 * math.cos(t1), zm + 1.55 * math.sin(t1))], y_avant - 0.22, 0.1, BM["Gravure"])
for i in range(8):
    t = 2 * math.pi * i / 8
    c, s = math.cos(t), math.sin(t)
    plat([(0.35 * c - 0.07 * s, zm + 0.35 * s + 0.07 * c), (1.4 * c - 0.07 * s, zm + 1.4 * s + 0.07 * c),
          (1.4 * c + 0.07 * s, zm + 1.4 * s - 0.07 * c), (0.35 * c + 0.07 * s, zm + 0.35 * s - 0.07 * c)], y_avant - 0.22, 0.1, BM["Gravure"])
plat([(0.3 * math.cos(t), zm + 0.3 * math.sin(t)) for t in [2 * math.pi * i / 12 for i in range(12)]], y_avant - 0.22, 0.1, BM["Gravure"])
# encadrement d'argent de la porte
cadre = [(-PORTE_DEMI - 0.15, Z_POD), (-PORTE_DEMI - 0.15, PORTE_IMPOSTE)]
cadre += [((PORTE_DEMI + 0.15) * math.cos(t), PORTE_IMPOSTE + (PORTE_DEMI + 0.15) * math.sin(t)) for t in [math.pi - math.pi * k / 20 for k in range(21)]]
cadre += [(PORTE_DEMI + 0.15, Z_POD)]
for (u0, v0), (u1, v1) in zip(cadre, cadre[1:]):
    d = Vector((u1 - u0, 0, v1 - v0))
    n = Vector((-d.z, 0, d.x)).normalized() * 0.22
    a, b = Vector((u0, y_avant - 0.35, v0)), Vector((u1, y_avant - 0.35, v1))
    prisme(BM["Argent"], [a - n, b - n, b + n, a + n], Vector((0, 0.5, 0)))
# intérieur sombre
disque(BM["Sombre"], R_TAMB - EP_TAMB + 0.05, Z_POD - 0.05, Z_POD + 0.05, 40)
disque(BM["Sombre"], R_TAMB - EP_TAMB + 0.05, Z_ENTA0 - 0.6, Z_ENTA0 - 0.5, 40)
# battants : le gauche grand ouvert vers l'intérieur, le droit entrouvert
def battant(sx, ouverture):
    contour = [(0, Z_POD), (PORTE_DEMI - 0.05, Z_POD)]
    contour += [(PORTE_DEMI * math.cos(t), PORTE_IMPOSTE + PORTE_DEMI * math.sin(t)) for t in [math.pi * k / 16 for k in range(9)]]
    pivot = Vector((sx * PORTE_DEMI, y_avant + EP_TAMB * 0.5, 0))
    rot = Matrix.Rotation(sx * ouverture, 4, 'Z')
    pts = [pivot + rot @ (Vector((sx * (PORTE_DEMI - u), 0, v)) - Vector((sx * PORTE_DEMI, 0, 0))) for u, v in contour]
    prisme(BM["Porte"], pts, rot @ Vector((0, 0.35, 0)))
battant(-1, math.radians(-75))
battant(1, math.radians(20))
# la déchirure : éclair vertical irrégulier, et quelques éclats qui flottent vers la porte
zig = [(rnd.uniform(-0.25, 0.25), Z_POD + 0.8 + i * 1.6) for i in range(9)]
pts = [(x - rnd.uniform(0.25, 0.55), z) for x, z in zig] + [(0, zig[-1][1] + 1.2)]
pts += [(x + rnd.uniform(0.25, 0.55), z) for x, z in reversed(zig)] + [(0, zig[0][1] - 1.2)]
prisme(BM["Lumiere"], [Vector((u, -4.0, v)) for u, v in pts], Vector((0, 0.15, 0)))
for _ in range(9):
    c = Vector((rnd.uniform(-2.6, 2.6), rnd.uniform(-12.5, -6), rnd.uniform(7, 15)))
    s = rnd.uniform(0.15, 0.3)
    prisme(BM["Lumiere"], [c + Vector((0, 0, s)), c + Vector((s * 0.8, 0, -s * 0.6)), c + Vector((-s * 0.8, 0, -s * 0.6))], Vector((0, 0.08, 0)))

# ---------------------------------------------------------------- colonnade
def section_cannelee(cx, cy, r, z, n_gorges=16, profondeur=0.2, pts_par_gorge=3):
    pts = []
    for i in range(n_gorges * pts_par_gorge):
        t = 2 * math.pi * i / (n_gorges * pts_par_gorge)
        rr = r - profondeur * (0.5 + 0.5 * math.cos(n_gorges * t))
        pts.append(Vector((cx + rr * math.cos(t), cy + rr * math.sin(t), z)))
    return pts

Z_FUT0, Z_FUT1 = Z_POD + 1.9, Z_ENTA0 - 2.2
for k in range(N_COL):
    a = A_PORTE + math.pi / N_COL + 2 * math.pi * k / N_COL   # la porte tombe entre deux colonnes
    cx, cy = R_COL * math.cos(a), R_COL * math.sin(a)
    # base : socle carré, deux tores et une scotie, bague d'argent
    carre(ton(), cx, cy, RAY_COL + 0.75, Z_POD, Z_POD + 0.7)
    tronc(ton(), cx, cy, RAY_COL + 0.55, RAY_COL + 0.45, Z_POD + 0.7, Z_POD + 1.15)
    tronc(BM["Joint"], cx, cy, RAY_COL + 0.15, RAY_COL + 0.15, Z_POD + 1.15, Z_POD + 1.4)
    tronc(ton(), cx, cy, RAY_COL + 0.35, RAY_COL + 0.25, Z_POD + 1.4, Z_POD + 1.7)
    tronc(BM["Argent"], cx, cy, RAY_COL + 0.12, RAY_COL + 0.12, Z_POD + 1.7, Z_FUT0 + 0.05)
    # fût : quatre tambours cannelés, légèrement fuselés, séparés par des joints
    n_tamb = 4
    hauteur = (Z_FUT1 - Z_FUT0) / n_tamb
    for t in range(n_tamb):
        z0, z1 = Z_FUT0 + t * hauteur, Z_FUT0 + (t + 1) * hauteur
        r0 = RAY_COL * (1 - 0.1 * t / n_tamb)
        r1 = RAY_COL * (1 - 0.1 * (t + 1) / n_tamb)
        solide(ton(), section_cannelee(cx, cy, r0, z0 + 0.06), section_cannelee(cx, cy, r1, z1 - 0.06))
        tronc(BM["Joint"], cx, cy, r1 - 0.25, r1 - 0.25, z1 - 0.1, z1 + 0.1, 16)
    # chapiteau : gorgerin d'argent, échine évasée, abaque carré épais
    rh = RAY_COL * 0.9
    tronc(BM["Argent"], cx, cy, rh + 0.1, rh + 0.1, Z_FUT1 - 0.05, Z_FUT1 + 0.35)
    tronc(ton(), cx, cy, rh, rh + 0.15, Z_FUT1 + 0.35, Z_FUT1 + 0.75)
    tronc(ton(), cx, cy, rh + 0.15, RAY_COL + 0.85, Z_FUT1 + 0.75, Z_ENTA0 - 0.75)
    carre(ton(), cx, cy, RAY_COL + 1.0, Z_ENTA0 - 0.75, Z_ENTA0 + 0.02)
    # mousse qui coule du chapiteau en épousant le fût
    for _ in range(rnd.randint(1, 2)):
        coulure(BM["Mousse"], cx, cy, RAY_COL, a + rnd.uniform(-1.0, 1.0), Z_FUT1 + 0.3, rnd.uniform(2.5, 9), rnd.uniform(0.4, 0.75))

# ---------------------------------------------------------------- entablement, frise en méandre, corniche, attique, dôme
anneau(ton(), R_TAMB - EP_TAMB, R_ENTA, Z_ENTA0, Z_ARCHI, 64)                         # architrave
anneau(BM["PierreB"], R_TAMB - EP_TAMB, R_ENTA - 0.15, Z_ARCHI - 0.05, Z_ENTA1, 64)   # fond de frise
# méandre (grecque) en relief sur la frise : motif répété, chaque trait plaqué sur la courbe
MOTIF = [(0, 0), (0, 1), (1, 1), (1, 0.33), (0.5, 0.33), (0.5, 0.66), (0.75, 0.66)]   # en unités de motif
L_MOTIF, H_MOTIF = 1.7, 0.95
n_motifs = int(2 * math.pi * R_ENTA / L_MOTIF)
pas_a = 2 * math.pi / n_motifs
z_base = Z_ARCHI + (Z_ENTA1 - Z_ARCHI - H_MOTIF) / 2
def trait(bm, a0, z0, a1, z1, r, w=0.12, saillie=0.12):
    """Trait en relief entre deux points (angle, hauteur) d'une surface cylindrique de rayon r."""
    du, dz = (a1 - a0) * r, z1 - z0
    l = math.hypot(du, dz) or 1.0
    tu, tz = du / l, dz / l             # direction du trait
    nu, nz = -tz, tu                    # perpendiculaire
    coins_uv = [(-tu * w - nu * w, -tz * w - nz * w), (du + tu * w - nu * w, dz + tz * w - nz * w),
                (du + tu * w + nu * w, dz + tz * w + nz * w), (-tu * w + nu * w, -tz * w + nz * w)]
    def p(u, v, dr):
        a = a0 + u / r
        return Vector(((r + dr) * math.cos(a), (r + dr) * math.sin(a), z0 + v))
    solide(bm, [p(u, v, -0.15) for u, v in coins_uv], [p(u, v, saillie) for u, v in coins_uv])
for m in range(n_motifs):
    a_m = m * pas_a
    pts = [(a_m + u * pas_a * 0.82, z_base + v * H_MOTIF) for u, v in MOTIF]
    for (a0, z0), (a1, z1) in zip(pts, pts[1:]):
        trait(BM["Gravure"], a0, z0, a1, z1, R_ENTA - 0.15)
    trait(BM["Gravure"], a_m, z_base - 0.15, a_m + pas_a, z_base - 0.15, R_ENTA - 0.15, w=0.07)   # filets haut et bas
    trait(BM["Gravure"], a_m, z_base + H_MOTIF + 0.15, a_m + pas_a, z_base + H_MOTIF + 0.15, R_ENTA - 0.15, w=0.07)
anneau(ton(), R_TAMB - EP_TAMB, R_COL + 2.9, Z_ENTA1 - 0.05, Z_CORN, 64)            # corniche
anneau(BM["Argent"], R_COL + 2.85, R_COL + 3.0, Z_ENTA1 + 0.3, Z_ENTA1 + 0.6, 96)
anneau(ton(), R_TAMB - EP_TAMB, R_TAMB + 2.2, Z_CORN - 0.1, Z_ATTI, 64)              # attique
disque(BM["PierreA"], R_TAMB - EP_TAMB + 0.1, Z_ENTA0 - 0.5, Z_ATTI, 40)
R_DOME, H_DOME, N_RANGS = R_TAMB + 1.2, 6.5, 9
for i in range(N_RANGS):
    r_ext = R_DOME * math.sqrt(1 - (i / N_RANGS) ** 2)
    r_int = R_DOME * math.sqrt(1 - ((i + 1) / N_RANGS) ** 2)
    z0, z1 = Z_ATTI - 0.05 + H_DOME * i / N_RANGS, Z_ATTI + H_DOME * (i + 1) / N_RANGS
    if r_int > 1.0:
        n = 40
        dec = math.pi / n if i % 2 else 0.0
        for j in range(n):   # chaque rang du dôme est fait de blocs aux tons variés
            a0, a1 = dec + 2 * math.pi * j / n, dec + 2 * math.pi * (j + 1) / n + 0.002
            prisme_z(ton(), secteur(max(r_int - 1.6, 0.5), r_ext, a0, a1, 1), z0, z1)
    else:
        disque(BM["PierreA"], r_ext, z0, z1, 32)

# ---------------------------------------------------------------- mousse qui épouse les surfaces
for _ in range(28):   # sur la face de la corniche, courtes : elles ne descendent pas dans le vide
    coulure(BM["Mousse"], 0, 0, R_COL + 2.9, rnd.uniform(0, 2 * math.pi), Z_CORN - 0.05, rnd.uniform(0.5, 0.95), rnd.uniform(0.6, 1.3))
for _ in range(16):   # sur la face de l'entablement, sans dépasser l'architrave
    coulure(BM["Mousse"], 0, 0, R_ENTA, rnd.uniform(0, 2 * math.pi), Z_ENTA1 - 0.1, rnd.uniform(0.8, 2.2), rnd.uniform(0.5, 1.1))
for _ in range(10):   # sur le tambour, loin de la porte
    a = rnd.uniform(0, 2 * math.pi)
    if abs((a - A_PORTE + math.pi) % (2 * math.pi) - math.pi) > 0.6:
        coulure(BM["Mousse"], 0, 0, R_TAMB + 0.05, a, Z_ENTA0 - 0.1, rnd.uniform(3, 12), rnd.uniform(0.6, 1.2))
for _ in range(12):   # sur le podium, hors escalier
    a = rnd.uniform(0, 2 * math.pi)
    if abs((a - A_PORTE + math.pi) % (2 * math.pi) - math.pi) > 0.4:
        coulure(BM["Mousse"], 0, 0, R_POD + 0.05, a, Z_POD - 0.6, rnd.uniform(0.8, 2.3), rnd.uniform(0.7, 1.4))
for _ in range(14):   # plaques sur la corniche et sur la plateforme
    a, rr = rnd.uniform(0, 2 * math.pi), rnd.uniform(R_ENTA - 2.5, R_COL + 2.4)
    plaque_mousse(BM["Mousse"], rr * math.cos(a), rr * math.sin(a), rnd.uniform(0.8, 1.4), Z_CORN + 0.02)
for _ in range(10):
    a, rr = rnd.uniform(0, 2 * math.pi), rnd.uniform(R_POD + 1, R_PLAT1 - 1)
    if abs((a - A_PORTE + math.pi) % (2 * math.pi) - math.pi) > 0.3:
        plaque_mousse(BM["Mousse"], rr * math.cos(a), rr * math.sin(a), rnd.uniform(0.8, 1.8), Z_PLAT1 + 0.02 if rr > R_PLAT2 else Z_PLAT2 + 0.02)

# ---------------------------------------------------------------- maillages (coupés sous 18 000 triangles)
COLL = bpy.data.collections.new("FAILLE_P1")
scene.collection.children.link(COLL)
objets = []
def maillage(nom, bm, mat):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] / 8, loop.vert.co[b] / 8)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = nom.endswith("Lumiere")
    ob = bpy.data.objects.new(nom, me)
    COLL.objects.link(ob)
    objets.append(ob)

for nom, bm in BM.items():
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    if len(bm.faces) <= 18000:
        maillage(f"Faille_{nom}", bm, M[nom])
    else:   # coupe par îlots (pièces séparées) en paquets sous la limite de Roblox
        bm.faces.ensure_lookup_table()
        bm.verts.index_update()
        vus, paquets, courant = set(), [], []
        for f in bm.faces:
            if f.index in vus:
                continue
            ilot, pile = [], [f]
            vus.add(f.index)
            while pile:
                g = pile.pop()
                ilot.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in vus:
                            vus.add(h.index)
                            pile.append(h)
            if len(courant) + len(ilot) > 18000:
                paquets.append(courant)
                courant = []
            courant += ilot
        paquets.append(courant)
        for i, faces in enumerate(paquets):
            sous = bmesh.new()
            vmap = {}
            for f in faces:
                vs = []
                for v in f.verts:
                    if v.index not in vmap:
                        vmap[v.index] = sous.verts.new(v.co)
                    vs.append(vmap[v.index])
                sous.faces.new(vs)
            maillage(f"Faille_{nom}_{i + 1}", sous, M[nom])
            sous.free()
    bm.free()

print("\n=== MAILLAGES ===")
negatifs = []
for ob in objets:
    me = ob.data
    me.calc_loop_triangles()
    vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
              for t in me.loop_triangles)
    if vol < 0:
        negatifs.append(ob.name)
    print(f"{ob.name:20s} {len(me.loop_triangles):6d} tris")
print("Maillages à l'envers :", negatifs if negatifs else "aucun")

for ob in bpy.data.objects:
    ob.select_set(False)
for ob in objets:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Faille_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçus
sol = bpy.data.meshes.new("Sol")
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=60)
bm.to_mesh(sol)
bm.free()
sol.materials.append(material("Herbe", (98, 150, 72), rough=0.9))
o = bpy.data.objects.new("Sol", sol)
o.location.z = -0.05
scene.collection.objects.link(o)
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
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam

def vue(loc, cible, chemin, lens=30, ortho=None):
    cam.location = loc
    cam.rotation_euler = (Vector(cible) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho:
        cam.data.ortho_scale = ortho
    cam.data.lens = lens
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

vue((-42, -62, 20), (0, 0, 14), os.path.join(APERCUS, "faille_p1_34.png"))
vue((0, -120, 18), (0, 0, 18), os.path.join(APERCUS, "faille_p1_face.png"), ortho=72)
vue((-4, -36, 8), (-9, -16, 15), os.path.join(APERCUS, "faille_p1_colonne.png"), lens=32)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "faille_p1.blend"))
print("OK")
