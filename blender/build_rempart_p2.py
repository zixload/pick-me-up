# Kit « Rempart P2 » (palier 2) pour Pick Me Up (Roblox), d'après le concept validé le 02/10/2026 :
# roche noir nuit bleutée appareillée (palette blender/textures_archive_P2), piliers anguleux évasés
# à bagues d'argent, lanternes d'argent et flèches argentées, niches en arc brisé cerclées d'argent avec
# emblème sculpté, frise de filigrane d'argent, parapet crénelé à merlons fendus. Mousse très rare.
# Même grille que le P1 et le P4 : 1 unité = 1 stud, entraxe des piliers 20, face avant = -Y,
# origine en bas au centre. Deux variantes de travée (A, B) pour casser la répétition.
# Usage : blender -b --factory-startup --python build_rempart_p2.py
import bpy, bmesh, math, os, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p2")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- matériaux (palette textures_archive_P2)
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def material(name, rgb255, metallic=0.0, rough=0.7, emission=0.0):
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

COULEURS = {
    "PierreA": (30, 40, 58), "PierreB": (37, 50, 72), "PierreC": (25, 33, 48),
    "Joint": (13, 18, 27), "Gravure": (52, 66, 92), "Argent": (205, 212, 222),
    "Mousse": (26, 52, 13), "Lumiere": (196, 232, 255),
}
M = {k: material(f"P2_{k}", c, metallic=1.0 if k == "Argent" else 0.0, rough=0.3 if k == "Argent" else 0.75,
                 emission=5.0 if k == "Lumiere" else 0.0) for k, c in COULEURS.items()}
M_SOL = material("Sol_Apercu", (98, 150, 72), rough=0.9)
TONS = ("PierreA", "PierreB", "PierreC")

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
    vb = [bm.verts.new(p) for p in bas]
    vh = [bm.verts.new(p) for p in haut]
    faces = [bm.faces.new(list(reversed(vb))), bm.faces.new(vh)]
    n = len(vb)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((vb[i], vb[j], vh[j], vh[i])))
    oriente(bm, faces)

def pyramide(bm, base, sommet):
    vb = [bm.verts.new(p) for p in base]
    s = bm.verts.new(sommet)
    faces = [bm.faces.new(list(reversed(vb)))]
    for i in range(len(vb)):
        faces.append(bm.faces.new((vb[i], vb[(i + 1) % len(vb)], s)))
    oriente(bm, faces)

def boite(bm, x0, x1, y0, y1, z0, z1):
    pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    solide(bm, [Vector((x, y, z0)) for x, y in pts], [Vector((x, y, z1)) for x, y in pts])

def plat_xz(bm, pts, y_avant, ep):
    """Polygone dans le plan de la façade (x, z), en relief de ep vers -Y depuis y_avant."""
    solide(bm, [Vector((x, y_avant, z)) for x, z in pts], [Vector((x, y_avant - ep, z)) for x, z in pts])

def ruban(bm, pts, y_avant, largeur, ep):
    """Polyligne (x, z) en relief : un petit prisme par segment."""
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        d = Vector((x1 - x0, z1 - z0))
        if d.length < 1e-4:
            continue
        n = Vector((-d.y, d.x)).normalized() * largeur / 2
        e = d.normalized() * largeur / 2
        quad = [(x0 - n.x - e.x, z0 - n.y - e.y), (x1 - n.x + e.x, z1 - n.y + e.y),
                (x1 + n.x + e.x, z1 + n.y + e.y), (x0 + n.x - e.x, z0 + n.y - e.y)]
        plat_xz(bm, quad, y_avant, ep)

class Kit:
    def __init__(self):
        self.bm = {k: bmesh.new() for k in M}
    def ton(self, rnd):
        return self.bm[rnd.choice(TONS)]

COLL = bpy.data.collections.new("KIT_P2")
scene.collection.children.link(COLL)
COLL.hide_render = True

def finir(kit, prefixe):
    objets = []
    for nom, bm in kit.bm.items():
        if not bm.faces:
            bm.free()
            continue
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            nrm = f.normal
            ax = max(range(3), key=lambda i: abs(nrm[i]))
            a, b = [(1, 2), (0, 2), (0, 1)][ax]
            for loop in f.loops:
                loop[uv].uv = (loop.vert.co[a] / 8, loop.vert.co[b] / 8)
        me = bpy.data.meshes.new(f"{prefixe}_{nom}")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(M[nom])
        for p in me.polygons:
            p.use_smooth = nom == "Lumiere"
        ob = bpy.data.objects.new(f"{prefixe}_{nom}", me)
        COLL.objects.link(ob)
        objets.append(ob)
    return objets

# ---------------------------------------------------------------- cotes (studs)
H = 10.0                       # demi-entraxe
INT = 7.0                      # face intérieure des piliers (largeur pilier 6)
Y_MUR = -1.6                   # face des blocs du mur
Z_SOUB0, Z_SOUB1 = 3.0, 6.0    # soubassement à deux ressauts
Z_FRISE0, Z_FRISE1 = 27.0, 29.4
Z_CORN = 30.4
Z_PARA = 33.4                  # haut du parapet plein
Z_MERLON = 36.2
NICHE_W, NICHE_BAS, NICHE_NAISS, NICHE_CLE = 4.2, 8.5, 18.6, 25.2   # clé haute : arc nettement brisé

def arc_brise(w, z_naiss, z_cle, n=10):
    """Contour (x, z) d'une niche en arc brisé, du pied gauche au pied droit en passant par la clé."""
    h = z_cle - z_naiss
    R = (w * w + h * h) / (2 * w)
    c = R - w                          # centre de l'arc gauche en (c, z_naiss)
    a_cle = math.atan2(h, -c)
    gauche = [(c + R * math.cos(math.pi - (math.pi - a_cle) * i / n), z_naiss + R * math.sin(math.pi - (math.pi - a_cle) * i / n))
              for i in range(n + 1)]
    droite = [(-x, z) for x, z in reversed(gauche[:-1])]
    return gauche + droite

def dans_niche(x, z, marge):
    if abs(x) > NICHE_W + marge or z < NICHE_BAS - marge:
        return False
    if z <= NICHE_NAISS:
        return True
    h = NICHE_CLE - NICHE_NAISS
    R = (NICHE_W ** 2 + h ** 2) / (2 * NICHE_W)
    c = R - NICHE_W
    return (abs(x) + c) ** 2 + (z - NICHE_NAISS) ** 2 <= (R + marge) ** 2   # arc du côté de x

def demi_largeur_niche(z):
    """Demi-largeur de la niche à la hauteur z (None au-dessus de la clé ou sous l'appui)."""
    if z < NICHE_BAS or z > NICHE_CLE:
        return None
    if z <= NICHE_NAISS:
        return NICHE_W
    h = NICHE_CLE - NICHE_NAISS
    R = (NICHE_W ** 2 + h ** 2) / (2 * NICHE_W)
    return math.sqrt(max(R * R - (z - NICHE_NAISS) ** 2, 0)) - (R - NICHE_W)

def appareil_mur(kit, rnd, x0, x1, z0, z1, y_av, y_ar, h_rang, l_bloc, trou=None, joint=0.1):
    """Blocs en rangs décalés ; trou(z0, z1) rend la demi-largeur à laisser libre au centre du rang
    (les blocs sont coupés au ras, le cadre de la niche recouvre la coupe)."""
    z, rang = z0, 0
    while z < z1 - 0.05:
        h = min(h_rang, z1 - z)
        libre = trou(z, z + h) if trou else None
        x = x0 - (l_bloc / 2 if rang % 2 else 0)
        while x < x1 - 0.05:
            a, b = max(x, x0), min(x + l_bloc * rnd.uniform(0.75, 1.25), x1)
            morceaux = [(a, b)]
            if libre is not None:
                morceaux = [(a, min(b, -libre)), (max(a, libre), b)]
            for ma, mb in morceaux:
                if mb - ma > 0.25:
                    boite(kit.ton(rnd), ma + joint / 2, mb - joint / 2, y_av - rnd.uniform(0, 0.06), y_ar, z + joint / 2, z + h - joint / 2)
            x = b
        z += h
        rang += 1

def trou_niche(z0, z1):
    largeurs = [w for w in (demi_largeur_niche(z0), demi_largeur_niche(z1), demi_largeur_niche((z0 + z1) / 2)) if w is not None]
    return (max(largeurs) + 0.55) if largeurs else None

def spirale(cx, cz, r0, tours, a0, sens, n=18):
    pts = []
    for i in range(n + 1):
        t = tours * 2 * math.pi * i / n
        r = r0 * math.exp(-0.28 * t)
        pts.append((cx + r * math.cos(a0 + sens * t), cz + r * math.sin(a0 + sens * t)))
    return pts

# ---------------------------------------------------------------- travée
def travee(variante, graine):
    rnd = random.Random(graine)
    k = Kit()
    boite(k.bm["Joint"], -H, H, Y_MUR + 0.4, 2.2, 0, Z_FRISE0 + 0.1)                 # cœur du mur
    # soubassement : deux ressauts appareillés
    appareil_mur(k, rnd, -H, H, 0, Z_SOUB0, -3.4, -1.0, 1.5, 4.4)
    appareil_mur(k, rnd, -H, H, Z_SOUB0, Z_SOUB1, -2.6, -1.0, 1.5, 4.0)
    boite(k.bm["PierreB"], -H, H, -2.9, -1.0, Z_SOUB1 - 0.05, Z_SOUB1 + 0.35)          # larmier
    # parement de blocs, sauf la niche et son cadre
    appareil_mur(k, rnd, -H, H, Z_SOUB1 + 0.35, Z_FRISE0, Y_MUR, Y_MUR + 0.45, 1.6, 3.2,
                 trou=trou_niche)
    # fond de la niche et emblème sculpté
    contour = arc_brise(NICHE_W, NICHE_NAISS, NICHE_CLE)
    niche = [(-NICHE_W, NICHE_BAS)] + contour + [(NICHE_W, NICHE_BAS)]
    plat_xz(k.bm["PierreC"], niche, Y_MUR + 0.6, 0.15)
    ye = Y_MUR + 0.45
    zc = (NICHE_BAS + NICHE_CLE) / 2
    plat_xz(k.bm["Gravure"], [(-0.22, NICHE_BAS + 1.4), (0.22, NICHE_BAS + 1.4), (0.22, NICHE_CLE - 2.2), (-0.22, NICHE_CLE - 2.2)], ye, 0.18)
    plat_xz(k.bm["Gravure"], [(0, NICHE_CLE - 1.0), (0.85, NICHE_CLE - 2.4), (0, NICHE_CLE - 3.8), (-0.85, NICHE_CLE - 2.4)], ye, 0.22)
    for s in (-1, 1):   # deux paires de feuilles et des crosses, symétriques
        for zf, l in ((zc + 1.6, 2.2), (zc - 1.4, 2.8)):
            feuille = [(0, zf), (s * l * 0.55, zf + 0.9), (s * l, zf + 0.2), (s * l * 0.6, zf - 0.45)]
            plat_xz(k.bm["Gravure"], feuille, ye, 0.16)
        ruban(k.bm["Gravure"], spirale(s * 1.6, NICHE_BAS + 2.6, 0.9, 1.1, math.pi / 2, -s), ye, 0.18, 0.14)
        if variante == "B":   # variante : un ornement de plus en haut de la niche
            plat_xz(k.bm["Gravure"], [(s * 0.5, NICHE_CLE - 4.6), (s * 1.6, NICHE_CLE - 3.9), (s * 1.2, NICHE_CLE - 5.2)], ye, 0.14)
    plat_xz(k.bm["Gravure"], [(0.55 * math.cos(t), NICHE_BAS + 1.1 + 0.55 * math.sin(t)) for t in [2 * math.pi * i / 10 for i in range(10)]], ye, 0.2)
    # cadre de pierre et filet d'argent autour de la niche
    bord = [(-NICHE_W, NICHE_BAS)] + contour + [(NICHE_W, NICHE_BAS)]
    ruban(k.bm["PierreB"], [(-NICHE_W - 0.45, NICHE_BAS - 0.2)] + arc_brise(NICHE_W + 0.45, NICHE_NAISS, NICHE_CLE + 0.55) + [(NICHE_W + 0.45, NICHE_BAS - 0.2)],
          Y_MUR + 0.05, 0.9, 0.35)
    ruban(k.bm["Argent"], bord, Y_MUR - 0.28, 0.2, 0.12)
    boite(k.bm["PierreB"], -NICHE_W - 0.9, NICHE_W + 0.9, Y_MUR - 0.35, Y_MUR + 0.3, NICHE_BAS - 0.8, NICHE_BAS)   # appui
    # frise à filigrane d'argent, corniche
    boite(k.bm["PierreA"], -H, H, -1.85, 1.8, Z_FRISE0, Z_FRISE1)
    zf = (Z_FRISE0 + Z_FRISE1) / 2
    for s in (-1, 1):
        tige = [(s * (0.4 + 5.8 * i / 30), zf - 0.32 * math.cos(math.pi * (0.4 + 5.8 * i / 30) / 1.45)) for i in range(31)]
        ruban(k.bm["Argent"], tige, -1.86, 0.11, 0.1)
        for j in range(4):
            cx = s * (1.0 + 1.45 * j)
            haut = j % 2 == 0
            ruban(k.bm["Argent"], spirale(cx, zf + (0.32 if haut else -0.32), 0.48, 1.2, -math.pi / 2 if haut else math.pi / 2, s * (1 if haut else -1)), -1.86, 0.1, 0.1)
    plat_xz(k.bm["Argent"], [(0.3 * math.cos(t), zf + 0.3 * math.sin(t)) for t in [2 * math.pi * i / 10 for i in range(10)]], -1.86, 0.12)
    boite(k.bm["Argent"], -H, H, -1.95, -1.83, Z_FRISE0 + 0.08, Z_FRISE0 + 0.2)
    boite(k.bm["Argent"], -H, H, -1.95, -1.83, Z_FRISE1 - 0.2, Z_FRISE1 - 0.08)
    boite(k.bm["PierreB"], -H, H, -2.5, 2.2, Z_FRISE1, Z_FRISE1 + 0.5)
    boite(k.bm["PierreA"], -H, H, -2.25, 2.0, Z_FRISE1 + 0.5, Z_CORN)
    # parapet plein puis merlons fendus à chapeau d'argent
    appareil_mur(k, rnd, -H, H, Z_CORN, Z_PARA, -1.9, 0.0, 1.5, 3.0)
    for i in range(4):
        x0 = -INT + 0.4 + i * 3.5
        x1 = x0 + 2.4
        boite(k.ton(rnd), x0, x1, -1.95, 0.0, Z_PARA, Z_PARA + 1.3)
        boite(k.ton(rnd), x0, (x0 + x1) / 2 - 0.18, -1.95, 0.0, Z_PARA + 1.3, Z_MERLON)
        boite(k.ton(rnd), (x0 + x1) / 2 + 0.18, x1, -1.95, 0.0, Z_PARA + 1.3, Z_MERLON)
        boite(k.bm["Argent"], x0 - 0.12, x1 + 0.12, -2.08, 0.12, Z_MERLON, Z_MERLON + 0.28)
    # très peu de mousse, dans les joints du pied
    for _ in range(rnd.randint(2, 3)):
        x = rnd.uniform(-8, 8)
        plat_xz(k.bm["Mousse"], [(x - 0.9, 0.05), (x + 0.9, 0.05), (x + 0.6, rnd.uniform(0.6, 1.2)), (x - 0.5, rnd.uniform(0.5, 1.0))], -3.42, 0.04)
    return finir(k, f"P2_Travee_{variante}")

# ---------------------------------------------------------------- pilier
Y_PIL0, Y_PIL1 = -5.4, 2.6     # devant, derrière
def section(z, echelle, marge=0.0):
    """Section octogonale du pilier (coins avant largement coupés), évasée vers le bas."""
    w = 3.0 * echelle + marge
    y0 = -0.7 + (Y_PIL0 + 0.7) * echelle - marge
    y1 = -0.7 + (Y_PIL1 + 0.7) * echelle + marge
    c, cb = 1.3 * echelle, 0.5 * echelle
    pts = [(-w + c, y0), (w - c, y0), (w, y0 + c), (w, y1 - cb), (w - cb, y1), (-w + cb, y1), (-w, y1 - cb), (-w, y0 + c)]
    return [Vector((x, y, z)) for x, y in pts]

def echelle_fut(z):
    return 1.0 - 0.16 * (z - 3.6) / (34.0 - 3.6)

def pilier():
    rnd = random.Random(77)
    k = Kit()
    solide(k.bm["PierreC"], section(0, 1.28), section(1.6, 1.28))                 # socle
    solide(k.bm["PierreB"], section(1.6, 1.2), section(3.0, 1.16))
    solide(k.bm["PierreA"], section(3.0, 1.1), section(3.6, 1.04))
    solide(k.bm["Joint"], section(3.5, 0.94), section(34.1, 0.78))                # cœur (joints)
    z = 3.6
    while z < 34.0 - 0.1:                                                          # tambours de pierre
        z1 = min(z + 2.6, 34.0)
        solide(k.ton(rnd), section(z + 0.05, echelle_fut(z)), section(z1 - 0.05, echelle_fut(z1)))
        z = z1
    for zb in (10.5, 18.5, 26.5):                                                  # bagues d'argent
        solide(k.bm["Argent"], section(zb, echelle_fut(zb), 0.14), section(zb + 0.5, echelle_fut(zb + 0.5), 0.14))
    solide(k.bm["PierreB"], section(34.0, 0.9, 0.2), section(34.7, 0.9, 0.2))     # épaulement
    solide(k.bm["PierreA"], section(34.7, 0.86), section(36.4, 0.82))
    solide(k.bm["Argent"], section(36.4, 0.84, 0.1), section(36.8, 0.8, 0.1))
    solide(k.bm["PierreB"], section(36.8, 0.7), section(37.8, 0.62))              # gradins de la flèche
    solide(k.bm["PierreA"], section(37.8, 0.52), section(38.6, 0.46))
    pyramide(k.bm["Argent"], section(38.6, 0.44), Vector((0, -1.3, 43.0)))         # flèche d'argent
    # lanterne d'argent suspendue à une potence, sur la face avant
    yf = -0.7 + (Y_PIL0 + 0.7) * echelle_fut(23.5)
    boite(k.bm["Argent"], -0.15, 0.15, yf - 1.6, yf + 0.1, 23.6, 23.9)               # potence
    boite(k.bm["Argent"], -0.12, 0.12, yf - 1.5, yf - 1.3, 22.9, 23.6)               # crochet
    cy = yf - 1.4
    hexa = lambda r, zz: [Vector((r * math.cos(math.pi / 3 * i), cy + r * math.sin(math.pi / 3 * i), zz)) for i in range(6)]
    solide(k.bm["Argent"], hexa(0.55, 22.65), hexa(0.55, 22.9))                    # chapeau
    pyramide(k.bm["Argent"], hexa(0.6, 22.9), Vector((0, cy, 23.0)))
    solide(k.bm["Lumiere"], hexa(0.36, 21.3), hexa(0.4, 22.65))                    # verre lumineux
    for i in range(6):                                                             # montants
        a = math.pi / 3 * i
        x, y = 0.45 * math.cos(a), cy + 0.45 * math.sin(a)
        boite(k.bm["Argent"], x - 0.05, x + 0.05, y - 0.05, y + 0.05, 21.25, 22.7)
    solide(k.bm["Argent"], hexa(0.5, 21.0), hexa(0.42, 21.3))                      # fond
    pyramide(k.bm["Argent"], hexa(0.3, 21.0), Vector((0, cy, 20.5)))
    # un soupçon de mousse au pied
    plat_xz(k.bm["Mousse"], [(-1.2, 0.05), (0.8, 0.05), (0.4, 1.1), (-0.8, 0.8)], -0.7 + (Y_PIL0 + 0.7) * 1.28 - 0.02, 0.04)
    return finir(k, "P2_Pilier")

pieces = {"Travee_A": travee("A", 11), "Travee_B": travee("B", 29), "Pilier": pilier()}

# ---------------------------------------------------------------- bilan et export
print("\n=== MAILLAGES ===")
negatifs = []
for nom, objs in pieces.items():
    pts = []
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
                  for t in me.loop_triangles)
        if vol < 0:
            negatifs.append(ob.name)
        print(f"{ob.name:26s} {len(me.loop_triangles):6d} tris")
        pts += [Vector(c) for c in ob.bound_box]
    print("BBOX", nom, [round(min(p[i] for p in pts), 3) for i in range(3)], [round(max(p[i] for p in pts), 3) for i in range(3)])
print("Maillages à l'envers :", negatifs if negatifs else "aucun")

for nom, objs in pieces.items():
    for ob in bpy.data.objects:
        ob.select_set(False)
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, f"Rempart_P2_{nom}.fbx"), use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçus : arc de 8 travées et planche de face
def placer(objs, coll, loc, rot_z):
    for ob in objs:
        c = ob.copy()
        c.location = loc
        c.rotation_euler = (0, 0, rot_z)
        coll.objects.link(c)

ARC = bpy.data.collections.new("APERCU_ARC")
scene.collection.children.link(ARC)
R = 90.0
D = 2 * math.asin(10 / R)
for k in range(9):
    th = (k - 4) * D
    placer(pieces["Pilier"], ARC, (R * math.sin(th), R * math.cos(th), 0), -th)
for k in range(8):
    th = (k + 0.5 - 4) * D
    rm = R * math.cos(D / 2)
    placer(pieces["Travee_A" if k % 2 == 0 else "Travee_B"], ARC, (rm * math.sin(th), rm * math.cos(th), 0), -th)
PLANCHE = bpy.data.collections.new("PLANCHE")
scene.collection.children.link(PLANCHE)
OFF = Vector((0, -600, 0))
for i in range(3):
    placer(pieces["Pilier"], PLANCHE, OFF + Vector((20 * (i - 1), 0, 0)), 0)
for i, v in enumerate(("Travee_A", "Travee_B")):
    placer(pieces[v], PLANCHE, OFF + Vector((20 * (i - 0.5), 0, 0)), 0)

sol = bpy.data.meshes.new("Sol")
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=96, radius=140)
bm.to_mesh(sol)
bm.free()
sol.materials.append(M_SOL)
o = bpy.data.objects.new("Sol", sol)
ARC.objects.link(o)
o2 = bpy.data.objects.new("Sol2", sol)
o2.location = OFF + Vector((0, 0, -0.01))
PLANCHE.objects.link(o2)

scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Punchy'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.76, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun_data = bpy.data.lights.new("Soleil", 'SUN')
sun_data.energy = 3.4
sun_data.angle = math.radians(6)
sun = bpy.data.objects.new("Soleil", sun_data)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam

def vue(loc, cible, chemin, lens=26, ortho=None):
    cam.location = loc
    cam.rotation_euler = (Vector(cible) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho:
        cam.data.ortho_scale = ortho
    cam.data.lens = lens
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

PLANCHE.hide_render = True
vue((-34, 30, 10), (6, 84, 22), os.path.join(APERCUS, "rempart_p2_34.png"))
ARC.hide_render, PLANCHE.hide_render = True, False
vue(OFF + Vector((0, -90, 22)), OFF + Vector((0, 0, 22)), os.path.join(APERCUS, "rempart_p2_face.png"), ortho=56)
vue(OFF + Vector((-14, -26, 14)), OFF + Vector((-4, 0, 22)), os.path.join(APERCUS, "rempart_p2_detail.png"), lens=30)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rempart_p2.blend"))
print("OK")
