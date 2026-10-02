# Invocation 1 étoile « tank » pour Pick Me Up (Roblox) : jeune palefrenier enrôlé comme porte-bouclier,
# d'après le concept validé le 02/10/2026 (un peu enrobé, sans excès). Gambison matelassé trop grand,
# rapiécé et cousu, col montant fermé par des brandebourgs de corde, ceinture de corde nouée, insigne
# de bronze à une étoile, bonnet de cuir à rabats, botte de cuir à droite, pied bandé et sandale à gauche,
# gourdin dans la main droite, bouclier de planches clouées et fendu dans la main gauche.
#
# Le personnage est modélisé sur le squelette R15 par défaut de Roblox (cotes relevées dans Studio,
# racine à l'origine, sol en y = -3,192) et découpé selon ses quinze parties : chaque maillage s'appelle
# <Partie>_<Matière> et sera soudé à la partie du même nom. Aux articulations, chaque pièce déborde sous
# sa voisine pour qu'aucun vide n'apparaisse quand les membres bougent ; un rendu en pose le vérifie.
# Tout est construit en coordonnées Roblox (X, Y haut, Z ; face vers -Z), converti à la fin.
# Usage : blender -b --factory-startup --python build_tank_p1.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export_p1")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(7)

# ---------------------------------------------------------------- squelette R15 (relevé dans Studio)
SOL = -3.192
EPAULE_Y, COUDE_Y, POIGNET_Y, MAIN_Y = 0.847, 0.073, -0.734, -0.866
BRAS_X, EPAULE_X = 1.472, 0.972
HANCHE_Y, GENOU_Y, CHEVILLE_Y, JAMBE_X = -1.0, -1.921, -2.93, 0.5
TAILLE_Y, COU_Y = -0.6, 1.098
ARTICULATIONS = {   # partie : (parent, point de rotation)
    "LowerTorso": (None, (0, -1.0, 0)), "UpperTorso": ("LowerTorso", (0, TAILLE_Y, 0)),
    "Head": ("UpperTorso", (0, COU_Y, 0)),
    "RightUpperArm": ("UpperTorso", (EPAULE_X, EPAULE_Y, 0)), "RightLowerArm": ("RightUpperArm", (BRAS_X, COUDE_Y, 0)),
    "RightHand": ("RightLowerArm", (BRAS_X, POIGNET_Y, 0)),
    "LeftUpperArm": ("UpperTorso", (-EPAULE_X, EPAULE_Y, 0)), "LeftLowerArm": ("LeftUpperArm", (-BRAS_X, COUDE_Y, 0)),
    "LeftHand": ("LeftLowerArm", (-BRAS_X, POIGNET_Y, 0)),
    "RightUpperLeg": ("LowerTorso", (JAMBE_X, HANCHE_Y, 0)), "RightLowerLeg": ("RightUpperLeg", (JAMBE_X, GENOU_Y, 0)),
    "RightFoot": ("RightLowerLeg", (JAMBE_X, CHEVILLE_Y, 0)),
    "LeftUpperLeg": ("LowerTorso", (-JAMBE_X, HANCHE_Y, 0)), "LeftLowerLeg": ("LeftUpperLeg", (-JAMBE_X, GENOU_Y, 0)),
    "LeftFoot": ("LeftLowerLeg", (-JAMBE_X, CHEVILLE_Y, 0)),
}

# ---------------------------------------------------------------- matières
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

COULEURS = {   # matière : (couleur, métal, rugosité) ; les mêmes couleurs sont reprises dans Studio
    "Peau": ((232, 188, 160), 0, 0.6), "Cheveux": ((96, 64, 42), 0, 0.8), "Yeux": ((240, 240, 234), 0, 0.3),
    "Iris": ((112, 100, 82), 0, 0.3), "Pupille": ((24, 20, 18), 0, 0.3), "Bouche": ((122, 62, 58), 0, 0.5),
    "Cuir": ((118, 82, 56), 0, 0.7), "Gambison": ((150, 128, 100), 0, 0.9), "Rapiece": ((188, 172, 140), 0, 0.9),
    "Couture": ((66, 52, 40), 0, 0.9), "Corde": ((176, 150, 108), 0, 0.9), "Pantalon": ((84, 68, 56), 0, 0.9),
    "Bandage": ((206, 196, 172), 0, 0.9), "Bois": ((124, 88, 58), 0, 0.8), "Fer": ((96, 98, 104), 1, 0.5),
    "Bronze": ((178, 130, 62), 1, 0.45), "Semelle": ((64, 50, 40), 0, 0.8),
}
MAT = {}
for nom, (c, metal, rugo) in COULEURS.items():
    m = bpy.data.materials.new("Tank_" + nom)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[srgb(x) for x in c], 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rugo
    m.use_backface_culling = True
    MAT[nom] = m

# ---------------------------------------------------------------- outils de géométrie (coordonnées Roblox)
def V(*p):
    return Vector(p[0]) if len(p) == 1 else Vector(p)

def ellipsoide(bm, c, r, rot=(0, 0, 0), seg=24, anneaux=16):
    m = (Matrix.Translation(V(c)) @ Euler([math.radians(a) for a in rot], 'XYZ').to_matrix().to_4x4()
         @ Matrix.Diagonal((r[0], r[1], r[2], 1.0)))
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=anneaux, radius=1.0, matrix=m)

def repere(t):
    """Deux vecteurs perpendiculaires à t."""
    a = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
    u = t.cross(a).normalized()
    return u, t.cross(u).normalized()

def tube(bm, pts, rayons, seg=14, ferme=False, bouts="plat", torsade=None):
    """Tube le long d'une polyligne, rayon variable ; bouts plats, ronds ou aucun (boucle fermée).
    torsade = (amplitude, pas) : creux en hélice, pour une corde."""
    pts = [V(p) for p in pts]
    n = len(pts)
    if isinstance(rayons, (int, float)):
        rayons = [rayons] * n
    tang = []
    for i in range(n):
        if ferme:
            a, b = pts[i - 1], pts[(i + 1) % n]
        else:
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tang.append((b - a).normalized())
    u, _ = repere(tang[0])
    anneaux, s = [], 0.0
    for i in range(n):
        if i > 0:
            u = (u - tang[i] * u.dot(tang[i])).normalized()
            s += (pts[i] - pts[i - 1]).length
        w = tang[i].cross(u)
        anneau = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            r = rayons[i]
            if torsade:
                r *= 1 + torsade[0] * math.cos(3 * a - 2 * math.pi * s / torsade[1])
            anneau.append(bm.verts.new(pts[i] + (u * math.cos(a) + w * math.sin(a)) * r))
        anneaux.append(anneau)
    paires = list(zip(anneaux, anneaux[1:])) + ([(anneaux[-1], anneaux[0])] if ferme else [])
    for a, b in paires:
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if not ferme:
        if bouts == "plat":
            bm.faces.new(list(reversed(anneaux[0])))
            bm.faces.new(anneaux[-1])
        else:
            bm.faces.new(list(reversed(anneaux[0])))
            bm.faces.new(anneaux[-1])
            ellipsoide(bm, pts[0], (rayons[0],) * 3, seg=seg, anneaux=8)
            ellipsoide(bm, pts[-1], (rayons[-1],) * 3, seg=seg, anneaux=8)

def anneaux_ellipse(bm, anneaux, seg=40):
    """Volume fermé par des ellipses horizontales : (cx, y, cz, rx, rz)."""
    rings = []
    for cx, y, cz, rx, rz in anneaux:
        rings.append([bm.verts.new((cx + rx * math.cos(2 * math.pi * k / seg), y, cz + rz * math.sin(2 * math.pi * k / seg)))
                      for k in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))

def boite(bm, c, taille, rot=(0, 0, 0)):
    m = (Matrix.Translation(V(c)) @ Euler([math.radians(a) for a in rot], 'XYZ').to_matrix().to_4x4()
         @ Matrix.Diagonal((taille[0], taille[1], taille[2], 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)

def prisme(bm, contour, centre, n, ep, haut=None):
    """Plaque d'épaisseur ep : contour (liste de points 3D dans un plan), extrudé le long de n."""
    n = V(n).normalized()
    bas = [bm.verts.new(V(p) - n * ep / 2) for p in contour]
    hau = [bm.verts.new(V(p) + n * ep / 2) for p in contour]
    k = len(contour)
    bm.faces.new(list(reversed(bas)))
    bm.faces.new(hau)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new((bas[i], bas[j], hau[j], hau[i]))

def normales(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

def vers_objet(bm, nom="tmp"):
    normales(bm)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    return ob

def evaluer(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(me)
    bpy.data.meshes.remove(me)
    for m in ob.modifiers:
        if m.type == 'BOOLEAN' and m.object:
            bpy.data.objects.remove(m.object)
    bpy.data.objects.remove(ob)
    return out

def organique(bm, voxel=0.025, lissage=8, force=0.35):
    """Union lissée de volumes qui se chevauchent (remaillage en voxels puis lissage laplacien)."""
    ob = vers_objet(bm)
    bm.free()
    r = ob.modifiers.new("remesh", 'REMESH')
    r.mode, r.voxel_size, r.use_smooth_shade = 'VOXEL', voxel, True
    if lissage:
        s = ob.modifiers.new("lisse", 'LAPLACIANSMOOTH')
        s.iterations, s.lambda_factor, s.use_volume_preserve = lissage, force, True
    out = evaluer(ob)
    normales(out)
    return out

def booleen(bm, autre, operation='DIFFERENCE'):
    ob = vers_objet(bm)
    bm.free()
    ob2 = vers_objet(autre, "outil")
    autre.free()
    m = ob.modifiers.new("bool", 'BOOLEAN')
    m.operation, m.solver, m.object = operation, 'EXACT', ob2
    m.use_self = True   # l'outil est fait de volumes qui se chevauchent
    ob2.hide_render = True
    out = evaluer(ob)
    normales(out)
    return out

def couper(bm, y, garder_dessus, normale=(0, 1, 0), point=None):
    """Coupe par un plan et referme le trou."""
    point = V(point) if point else Vector((0, y, 0))
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=point, plane_no=V(normale),
                           clear_inner=garder_dessus, clear_outer=not garder_dessus)
    bords = [e for e in bm.edges if e.is_boundary]
    if bords:
        bmesh.ops.holes_fill(bm, edges=bords, sides=0)
    normales(bm)
    return bm

def decimer(bm, cible):
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    n = len(bm.faces)
    if n <= cible:
        return bm
    ob = vers_objet(bm)
    bm.free()
    d = ob.modifiers.new("dec", 'DECIMATE')
    d.ratio = cible / n
    out = evaluer(ob)
    normales(out)
    return out

def projeter(bvh, origine, direction):
    loc, nor, _, _ = bvh.ray_cast(V(origine), V(direction).normalized())
    return loc, nor

# ---------------------------------------------------------------- collecte des pièces
PIECES = {}   # (partie, matière) -> bmesh
LISSE = {"Peau", "Cheveux", "Yeux", "Iris", "Pupille", "Bouche", "Cuir", "Gambison", "Rapiece", "Corde",
         "Pantalon", "Bandage", "Bois", "Semelle", "Couture"}

def ajouter(partie, matiere, bm):
    cle = (partie, matiere)
    if cle not in PIECES:
        PIECES[cle] = bmesh.new()
    me = bpy.data.meshes.new("tmp")
    normales(bm)
    bm.to_mesh(me)
    bm.free()
    PIECES[cle].from_mesh(me)
    bpy.data.meshes.remove(me)

def nouveau():
    return bmesh.new()

# ---------------------------------------------------------------- matelassage du gambison
def matelasser(bm, axe_x=0.0, echelle=1.0, pas=0.38, creux=0.024, gonfle=0.014, sauf=None):
    """Losanges matelassés : coutures en creux le long de deux familles de diagonales, carreaux bombés.
    Paramétrage cylindrique autour d'un axe vertical (x = axe_x, z = 0)."""
    bm.normal_update()
    for v in bm.verts:
        p = v.co
        if sauf and sauf(p):
            continue
        u = math.atan2(p.x - axe_x, -p.z) * echelle
        w = p.y
        d1 = abs(((u + w) / pas) % 1.0 - 0.5)
        d2 = abs(((u - w) / pas) % 1.0 - 0.5)
        d = (0.5 - max(d1, d2)) * pas / math.sqrt(2)      # distance à la couture la plus proche
        couture = math.exp(-(d / 0.024) ** 2)
        bombe = min(d / (pas * 0.3), 1.0)
        v.co = p + v.normal * (gonfle * math.sin(bombe * math.pi / 2) - creux * couture)

# ================================================================ GAMBISON (buste, ventre, jupe)
gb = nouveau()
ellipsoide(gb, (0, 0.38, 0.0), (1.0, 0.74, 0.6))                 # poitrine
ellipsoide(gb, (0, -0.32, -0.1), (1.02, 0.7, 0.66))              # ventre, un peu en avant
for s in (1, -1):
    ellipsoide(gb, (s * 0.9, 0.74, 0.0), (0.38, 0.36, 0.4))      # épaules
anneaux_ellipse(gb, [(0, 0.86, 0.02, 0.47, 0.44), (0, 1.0, 0.02, 0.43, 0.41), (0, 1.2, 0.02, 0.39, 0.37)])   # col montant
anneaux_ellipse(gb, [(0, -0.75, -0.06, 1.05, 0.72), (0, -1.2, -0.05, 1.1, 0.78), (0, -1.6, -0.04, 1.14, 0.82),
                     (0, -1.78, -0.04, 1.15, 0.83)], seg=48)      # hanches et jupe jusqu'au-dessus du genou
gb = organique(gb, voxel=0.03, lissage=10, force=0.4)
gambison_base = gb.copy()
BVH_GB = BVHTree.FromBMesh(gambison_base)

def sauf_col(p):
    return p.y > 0.98
matelasser(gb, sauf=sauf_col)
gb.normal_update()
for v in gb.verts:   # couture de fermeture sur le devant, en creux
    p = v.co
    if p.z < 0 and -1.78 < p.y < 0.9:
        v.co = p + v.normal * (-0.04 * math.exp(-(p.x / 0.035) ** 2))
haut = couper(gb.copy(), -0.74, True)
bas = couper(gb, -0.46, False)
ajouter("UpperTorso", "Gambison", decimer(haut, 6000))
ajouter("LowerTorso", "Gambison", decimer(bas, 5500))

# ---------------------------------------------------------------- pièces rapiécées et coutures
def piece_cousue(partie, coins, decalage=0.045):
    """Pièce de tissu posée sur le devant (coins en x, y), épousant le gambison, bordée de points."""
    nu, nv = 10, 10
    a, b, c, d = [V(x, y, 0) for x, y in coins]
    grille = []
    for j in range(nv + 1):
        ligne = []
        for i in range(nu + 1):
            s, t = i / nu, j / nv
            q = a.lerp(b, s).lerp(d.lerp(c, s), t)
            loc, nor = projeter(BVH_GB, (q.x, q.y, -4), (0, 0, 1))
            ligne.append((loc, nor))
        grille.append(ligne)
    bm = nouveau()
    dessus = [[bm.verts.new(l + n * decalage) for l, n in ligne] for ligne in grille]
    dessous = [[bm.verts.new(l - n * 0.02) for l, n in ligne] for ligne in grille]
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((dessus[j][i], dessus[j][i + 1], dessus[j + 1][i + 1], dessus[j + 1][i]))
            bm.faces.new((dessous[j][i], dessous[j + 1][i], dessous[j + 1][i + 1], dessous[j][i + 1]))
    bord = ([(0, i) for i in range(nu)] + [(j, nu) for j in range(nv)] + [(nv, i) for i in range(nu, 0, -1)]
            + [(j, 0) for j in range(nv, 0, -1)])
    for k in range(len(bord)):
        j0, i0 = bord[k]
        j1, i1 = bord[(k + 1) % len(bord)]
        bm.faces.new((dessus[j0][i0], dessous[j0][i0], dessous[j1][i1], dessus[j1][i1]))
    ajouter(partie, "Rapiece", bm)
    # points de couture : petits traits qui chevauchent le bord, tous les ~0,08 stud
    pts = []
    for k in range(len(bord)):
        j, i = bord[k]
        pts.append(grille[j][i])
    st = nouveau()
    for k in range(0, len(pts)):
        (l0, n0), (l1, n1) = pts[k], pts[(k + 1) % len(pts)]
        m = (l0 + l1) / 2
        n = (n0 + n1).normalized()
        dirb = (l1 - l0).normalized()
        perp = n.cross(dirb).normalized()
        centre_patch = (grille[nv // 2][nu // 2][0])
        if perp.dot(centre_patch - m) < 0:
            perp = -perp
        q = l0.lerp(l1, 0.5)
        tube(st, [q - perp * 0.03 + n * (decalage + 0.004), q + perp * 0.025 + n * (decalage + 0.004)], 0.009, seg=5)
    ajouter(partie, "Couture", st)

piece_cousue("UpperTorso", [(0.18, 0.3), (0.7, 0.34), (0.66, 0.78), (0.22, 0.74)])        # poitrine, côté droit
piece_cousue("LowerTorso", [(0.12, -1.38), (0.78, -1.32), (0.72, -0.86), (0.16, -0.9)])   # ventre bas, côté droit
piece_cousue("LowerTorso", [(-0.82, -1.7), (-0.36, -1.72), (-0.38, -1.36), (-0.8, -1.32)])  # jupe, côté gauche

# ---------------------------------------------------------------- brandebourgs de corde et chevilles de bois
for y in (0.78, 0.44, 0.1, -0.26):
    cr, bo = nouveau(), nouveau()
    for s in (1, -1):
        pts = []
        for k in range(6):
            x = s * (0.04 + 0.18 * k / 5)
            loc, nor = projeter(BVH_GB, (x, y + 0.03 * math.sin(math.pi * k / 5), -4), (0, 0, 1))
            pts.append(loc + nor * 0.06)
        tube(cr, pts, 0.032, seg=8, bouts="rond", torsade=(0.18, 0.09))
    loc, nor = projeter(BVH_GB, (0.02, y, -4), (0, 0, 1))
    tube(bo, [loc + nor * 0.085 + V(-0.08, 0.01, 0), loc + nor * 0.085 + V(0.1, -0.01, 0)], 0.03, seg=10, bouts="rond")
    partie = "UpperTorso" if y > -0.5 else "LowerTorso"
    ajouter(partie, "Corde", cr)
    ajouter(partie, "Bois", bo)

# ---------------------------------------------------------------- insigne de bronze, poitrine gauche
loc, nor = projeter(BVH_GB, (-0.44, 0.56, -4), (0, 0, 1))
u = Vector((0, 1, 0)).cross(nor).normalized()
w = nor.cross(u).normalized()
inc = math.radians(-12)
u, w = u * math.cos(inc) + w * math.sin(inc), w * math.cos(inc) - u * math.sin(inc)
etoile = []
for k in range(10):
    a = math.pi / 2 + math.pi * k / 5
    r = 0.15 if k % 2 == 0 else 0.065
    etoile.append(loc + nor * 0.075 + (u * math.cos(a) + w * math.sin(a)) * r)
bz = nouveau()
prisme(bz, etoile, loc, nor, 0.045)
ellipsoide(bz, loc + nor * 0.1, (0.035, 0.035, 0.035), seg=10, anneaux=6)
ajouter("UpperTorso", "Bronze", bz)

# ---------------------------------------------------------------- ceinture de corde nouée
def autour(y_devant, y_dos, ecart, n=56):
    pts = []
    for k in range(n):
        th = 2 * math.pi * k / n
        d = V(math.sin(th), 0, -math.cos(th))
        y = (y_devant + y_dos) / 2 + (y_devant - y_dos) / 2 * math.cos(th)
        loc, nor = projeter(BVH_GB, V(0, y, 0) + d * 3, -d)
        pts.append(loc + nor * ecart)
    return pts

cr = nouveau()
tube(cr, autour(-0.66, -0.56, 0.085), 0.06, seg=10, ferme=True, torsade=(0.2, 0.11))
# nœud sur le devant, côté droit, et deux brins qui pendent
loc, nor = projeter(BVH_GB, (0.3, -0.66, -4), (0, 0, 1))
noeud = loc + nor * 0.12
ellipsoide(cr, noeud, (0.11, 0.09, 0.08))
ellipsoide(cr, noeud + V(0.07, -0.03, -0.02), (0.07, 0.07, 0.06))
for x0, x1, y1 in ((0.27, 0.22, -1.32), (0.34, 0.42, -1.18)):
    pts = []
    for k in range(9):
        t = k / 8
        x, y = x0 + (x1 - x0) * t, -0.7 + (y1 + 0.7) * t
        l, n = projeter(BVH_GB, (x, y, -4), (0, 0, 1))
        pts.append(l + n * (0.075 + 0.02 * math.sin(t * math.pi)))
    tube(cr, pts, 0.045, seg=8, torsade=(0.2, 0.1))
    ellipsoide(cr, pts[-1] + V(0, -0.02, 0), (0.06, 0.05, 0.055), seg=10, anneaux=6)    # bout effiloché, noué
ajouter("LowerTorso", "Corde", cr)

# ================================================================ MANCHES matelassées
for s, cote in ((1, "Right"), (-1, "Left")):
    bx = s * BRAS_X
    hautm = nouveau()
    ellipsoide(hautm, (s * 1.2, 0.8, 0.0), (0.37, 0.34, 0.37))
    tube(hautm, [(s * 1.3, 0.84, 0), (bx, 0.42, 0), (bx, 0.04, 0)], [0.37, 0.36, 0.355], seg=20, bouts="rond")
    hautm = organique(hautm, voxel=0.03, lissage=6)
    matelasser(hautm, axe_x=bx, echelle=0.37, pas=0.36)
    ajouter(cote + "UpperArm", "Gambison", decimer(hautm, 2000))
    basm = nouveau()
    tube(basm, [(bx, 0.3, 0), (bx, -0.2, -0.01), (bx, -0.5, -0.02)], [0.31, 0.32, 0.32], seg=20, bouts="rond")
    anneaux_ellipse(basm, [(bx, -0.72, -0.02, 0.33, 0.33), (bx, -0.62, -0.02, 0.35, 0.35), (bx, -0.48, -0.02, 0.33, 0.33)])
    basm = organique(basm, voxel=0.03, lissage=5)
    matelasser(basm, axe_x=bx, echelle=0.32, pas=0.36, sauf=lambda p: p.y < -0.46)
    ajouter(cote + "LowerArm", "Gambison", decimer(basm, 1600))
# ================================================================ TÊTE
pe = nouveau()
ellipsoide(pe, (0, 1.8, 0.02), (0.64, 0.68, 0.62))                       # crâne
ellipsoide(pe, (0, 1.55, -0.08), (0.6, 0.42, 0.55))                      # joues et mâchoire, rondes
for s in (1, -1):
    ellipsoide(pe, (s * 0.3, 1.58, -0.38), (0.2, 0.17, 0.16))           # pommettes
    ellipsoide(pe, (s * 0.21, 1.935, -0.47), (0.155, 0.065, 0.11))      # paupières supérieures, haut relevées
    ellipsoide(pe, (s * 0.21, 1.695, -0.52), (0.13, 0.04, 0.07))        # poches sous les yeux
    ellipsoide(pe, (s * 0.6, 1.72, 0.02), (0.1, 0.17, 0.13))            # oreilles (sous les rabats)
ellipsoide(pe, (0, 1.33, -0.31), (0.22, 0.14, 0.18))                      # menton
ellipsoide(pe, (0, 1.7, -0.6), (0.085, 0.11, 0.09))                       # nez
ellipsoide(pe, (0, 1.655, -0.655), (0.075, 0.07, 0.065))                  # bout du nez
ellipsoide(pe, (0, 1.505, -0.58), (0.12, 0.035, 0.05))                    # lèvre supérieure
ellipsoide(pe, (0, 1.425, -0.57), (0.1, 0.04, 0.05))                      # lèvre inférieure
tube(pe, [(0, 0.98, 0.0), (0, 1.42, 0.02)], [0.3, 0.32], seg=20)       # cou (descend dans le col)
pe = organique(pe, voxel=0.018, lissage=8, force=0.3)
# bouche : creux sombre, entrouverte d'inquiétude
bo_ = nouveau()
ellipsoide(bo_, (0, 1.463, -0.585), (0.085, 0.03, 0.04))
ajouter("Head", "Bouche", bo_)
ajouter("Head", "Peau", decimer(pe, 3200))
# yeux grands ouverts, iris et pupilles, petit reflet
ye, ir, pu = nouveau(), nouveau(), nouveau()
for s in (1, -1):
    ellipsoide(ye, (s * 0.21, 1.83, -0.5), (0.135, 0.15, 0.1), seg=20, anneaux=12)
    ellipsoide(ir, (s * 0.205, 1.815, -0.585), (0.075, 0.08, 0.026), seg=18, anneaux=8)
    ellipsoide(pu, (s * 0.205, 1.815, -0.604), (0.038, 0.04, 0.012), seg=14, anneaux=6)
    ellipsoide(ye, (s * 0.18, 1.845, -0.612), (0.016, 0.016, 0.008), seg=8, anneaux=4)
ajouter("Head", "Yeux", ye)
ajouter("Head", "Iris", ir)
ajouter("Head", "Pupille", pu)
# sourcils relevés au milieu (inquiétude), au-dessus des paupières
ch = nouveau()
for sg in (1, -1):
    tube(ch, [(sg * 0.065, 2.055, -0.57), (sg * 0.2, 2.035, -0.56), (sg * 0.33, 1.985, -0.49)], [0.026, 0.03, 0.022],
         seg=8, bouts="rond")
ch = organique(ch, voxel=0.01, lissage=3)
ajouter("Head", "Cheveux", decimer(ch, 500))
# frange courte : mèches effilées qui dépassent du bord du bonnet
fr = nouveau()
# mèches de largeurs et longueurs inégales qui se chevauchent, légèrement couchées sur le côté
for x, lg, ang, larg in ((-0.42, 0.06, -28, 0.06), (-0.33, 0.1, -20, 0.075), (-0.2, 0.08, -12, 0.08),
                         (-0.1, 0.12, -8, 0.085), (0.03, 0.07, 4, 0.075), (0.12, 0.11, 12, 0.085),
                         (0.25, 0.09, 18, 0.08), (0.36, 0.1, 26, 0.07), (0.44, 0.05, 32, 0.055)):
    zf = -0.62 * math.sqrt(max(1 - (x / 0.64) ** 2 - (0.3 / 0.68) ** 2, 0.05)) + 0.02
    haut_m = V(x, 2.11, zf + 0.07)   # racine cachée sous le bonnet
    a = math.radians(ang)
    bout = haut_m + V(math.sin(a) * (lg + 0.06), -lg - 0.06, -0.015)
    tube(fr, [haut_m, haut_m.lerp(bout, 0.45) + V(math.sin(a) * 0.015, 0, -0.016), bout], [larg, larg * 0.62, 0.01], seg=8)
fr = organique(fr, voxel=0.009, lissage=4)
ajouter("Head", "Cheveux", decimer(fr, 900))

# ---------------------------------------------------------------- bonnet de cuir à rabats
CB, RB = V(0, 1.83, 0.03), (0.695, 0.74, 0.675)
cu = nouveau()
ellipsoide(cu, CB, RB, seg=40, anneaux=28)
for s in (1, -1):
    ellipsoide(cu, (s * 0.61, 1.5, 0.0), (0.13, 0.36, 0.33), seg=24, anneaux=16)    # rabats sur les oreilles
cu = organique(cu, voxel=0.02, lissage=3)
face = nouveau()
boite(face, (0, 1.4, -0.85), (0.98, 1.36, 1.3))        # ouverture du visage : bord à y = 2,08, x = ±0,49
ellipsoide(face, (0, 2.04, -0.6), (0.5, 0.1, 0.4))      # bord légèrement cintré au-dessus des sourcils
cu = booleen(cu, face)
cu = couper(cu, 1.18, True)
cu = organique(cu, voxel=0.016, lissage=4, force=0.3)
# coutures en relief : trois méridiens et le tour du bonnet
def point_bonnet(dir_h, t, ecart=0.012):
    a = dir_h * math.cos(t) + Vector((0, 1, 0)) * math.sin(t)
    p = CB + V(a.x * RB[0], a.y * RB[1], a.z * RB[2])
    n = V(a.x / RB[0], a.y / RB[1], a.z / RB[2]).normalized()
    return p + n * ecart
BVH_CU = BVHTree.FromBMesh(cu)
for phi in (0, 0.6, -0.6):
    h = V(math.sin(phi), 0, -math.cos(phi))
    t0 = math.asin((2.09 - CB.y) / RB[1]) + 0.12
    t1 = math.pi + math.asin((CB.y - 1.32) / RB[1])
    pts = []
    for k in range(25):
        q = point_bonnet(h, t0 + (t1 - t0) * k / 24, 0.3)
        loc, nor = projeter(BVH_CU, q, CB - q)
        if loc:
            pts.append(loc + nor * 0.004)
    tube(cu, pts, 0.017, seg=8, bouts="rond")
# lacets qui pendent sous les rabats
for s in (1, -1):
    tube(cu, [(s * 0.62, 1.2, -0.1), (s * 0.6, 1.02, -0.18), (s * 0.57, 0.88, -0.22)], 0.022, seg=6, bouts="rond")
ajouter("Head", "Cuir", decimer(cu, 2400))

# ================================================================ MAINS (poings serrés sur le manche)
def poing(cote, s, axe, rayon_manche):
    """Poing refermé sur un manche d'axe donné passant par le centre de la main."""
    hc = V(s * BRAS_X, MAIN_Y - 0.1, -0.02)
    axe = V(axe).normalized()
    haut_ = Vector((1, 0, 0)).cross(axe).normalized()
    out_ = axe.cross(haut_).normalized() * (1 if s > 0 else -1)
    if out_.x * s < 0:
        out_ = -out_
    pm = nouveau()
    tube(pm, [(s * BRAS_X, -0.5, -0.02), (s * BRAS_X, MAIN_Y + 0.05, -0.02)], [0.18, 0.2], seg=16)   # poignet
    ellipsoide(pm, hc + out_ * 0.06 + haut_ * 0.08, (0.22, 0.2, 0.22))                               # dos de la main
    rf = rayon_manche + 0.075
    for k, (dz, r) in enumerate(((-0.17, 0.08), (-0.06, 0.082), (0.05, 0.078), (0.15, 0.068))):   # 4 doigts
        pts = []
        for a in range(0, 9):
            ang = math.radians(80 - 190 * a / 8)
            pts.append(hc + axe * dz + (out_ * math.cos(ang) + haut_ * math.sin(ang)) * rf)
        tube(pm, pts, r, seg=10, bouts="rond")
    pts = []                                                                                         # pouce
    for a in range(0, 7):
        ang = math.radians(200 - 90 * a / 6)
        pts.append(hc + axe * -0.24 + (out_ * math.cos(ang) + haut_ * math.sin(ang)) * (rf + 0.01))
    tube(pm, pts, 0.085, seg=10, bouts="rond")
    pm = organique(pm, voxel=0.015, lissage=6, force=0.3)
    ajouter(cote + "Hand", "Peau", decimer(pm, 1400))
    return hc, axe

# ---------------------------------------------------------------- gourdin, main droite
ALPHA = math.radians(38)
DIR_GOURDIN = V(0, -math.sin(ALPHA), -math.cos(ALPHA))
hc, axe = poing("Right", 1, DIR_GOURDIN, 0.11)
go = nouveau()
profil = [(-0.42, 0.13), (-0.36, 0.14), (-0.3, 0.115), (0.0, 0.11), (0.3, 0.115), (0.6, 0.13), (0.9, 0.16),
          (1.2, 0.2), (1.45, 0.235), (1.65, 0.25), (1.8, 0.24), (1.88, 0.2)]
tube(go, [hc + axe * t for t, _ in profil], [r for _, r in profil], seg=18, bouts="rond")
for t, ang, r in ((0.95, 30, 0.07), (1.3, 160, 0.08), (1.55, 260, 0.075), (1.7, 70, 0.06), (0.55, 220, 0.05)):
    u_, w_ = repere(axe)
    rr = dict(profil)
    base_r = 0.11 + (t / 1.88) * 0.13
    d = u_ * math.cos(math.radians(ang)) + w_ * math.sin(math.radians(ang))
    ellipsoide(go, hc + axe * t + d * base_r * 0.9, (r, r, r * 0.8))    # nœuds du bois
go = organique(go, voxel=0.018, lissage=4)
ajouter("RightHand", "Bois", decimer(go, 1500))

# ---------------------------------------------------------------- bouclier de fortune, main gauche
THETA = math.radians(35)
N_B = V(-math.cos(THETA), 0, -math.sin(THETA))          # face du bouclier : vers l'avant-gauche
T_B = V(math.sin(THETA), 0, -math.cos(THETA))           # horizontale dans le plan du bouclier
Y_B = Vector((0, 1, 0))
hc, axe = poing("Left", -1, T_B, 0.1)
CENTRE_B = hc + N_B * 0.46
RAYON_B = 0.95
def point_b(uu, ww, dn=0.0):
    return CENTRE_B + T_B * uu + Y_B * ww + N_B * dn
# quatre planches verticales, légèrement décalées ; la dernière est cassée en bas
bo = nouveau()
largeurs = [(-0.95, -0.47), (-0.45, 0.02), (0.04, 0.5), (0.52, 0.95)]
for idx, (u0, u1) in enumerate(largeurs):
    bas_arc = [(u0 + (u1 - u0) * k / 8, -math.sqrt(max(RAYON_B ** 2 - (u0 + (u1 - u0) * k / 8) ** 2, 0.0))) for k in range(9)]
    haut_arc = [(u0 + (u1 - u0) * k / 8, math.sqrt(max(RAYON_B ** 2 - (u0 + (u1 - u0) * k / 8) ** 2, 0.0)))
                for k in range(8, -1, -1)]
    if idx == 3:
        cassure = [(0.52, -0.22), (0.6, -0.33), (0.57, -0.45), (0.68, -0.52), (0.66, -0.63), (0.78, -0.5),
                   (0.86, -0.36), (math.sqrt(RAYON_B ** 2 - 0.2 ** 2), -0.2)]
        contour = cassure + haut_arc
    else:
        contour = bas_arc + haut_arc
    dec = rnd.uniform(-0.02, 0.02)
    prisme(bo, [point_b(uu, ww, dec) for uu, ww in contour], CENTRE_B, N_B, 0.1)
# traverses clouées au dos, poignée et ses deux tenons
for ww in (-0.45, 0.42):
    larg = math.sqrt(RAYON_B ** 2 - ww ** 2) - 0.1
    if ww < 0:
        larg_d = 0.45   # la traverse du bas s'arrête avant la cassure
    else:
        larg_d = larg
    c = point_b(0, ww, -0.075)
    pts = [c - T_B * larg - Y_B * 0.08, c + T_B * larg_d - Y_B * 0.08, c + T_B * larg_d + Y_B * 0.08, c - T_B * larg + Y_B * 0.08]
    prisme(bo, pts, c, N_B, 0.11)
tube(bo, [hc - T_B * 0.32, hc + T_B * 0.32], 0.1, seg=12)
for sgn in (-1, 1):
    a_ = hc + T_B * sgn * 0.3
    tube(bo, [a_, a_ + N_B * 0.36], 0.07, seg=8)
ajouter("LeftHand", "Bois", bo)
# têtes de clous sur le devant, au droit des traverses
fe = nouveau()
for ww in (-0.45, 0.42):
    for uu in (-0.71, -0.22, 0.27, 0.72):
        if abs(uu) < math.sqrt(RAYON_B ** 2 - ww ** 2) - 0.1 and not (uu > 0.5 and ww < -0.2):
            ellipsoide(fe, point_b(uu, ww, 0.07), (0.035, 0.035, 0.035), seg=8, anneaux=5)
ajouter("LeftHand", "Fer", fe)
# corde qui ceinture le haut du bouclier, et deux ligatures qui tiennent la planche fendue
cr = nouveau()
pts = [point_b(math.cos(math.radians(15 + 150 * k / 23)) * (RAYON_B + 0.02),
               math.sin(math.radians(15 + 150 * k / 23)) * (RAYON_B + 0.02), 0.0) for k in range(24)]
tube(cr, pts, 0.045, seg=8, bouts="rond", torsade=(0.2, 0.1))
ajouter("LeftHand", "Corde", cr)

# ================================================================ JAMBES
for s, cote in ((1, "Right"), (-1, "Left")):
    jx = s * JAMBE_X
    pa = nouveau()
    tube(pa, [(jx, -0.8, 0), (jx, -1.5, -0.01), (jx, -1.98, 0)], [0.44, 0.42, 0.37], seg=20, bouts="rond")
    ajouter(cote + "UpperLeg", "Pantalon", decimer(organique(pa, voxel=0.03, lissage=4), 1600))
    pb = nouveau()
    tube(pb, [(jx, -1.78, 0), (jx, -2.2, 0), (jx, -2.4, 0.01)], [0.36, 0.35, 0.34], seg=20, bouts="rond")
    ajouter(cote + "LowerLeg", "Pantalon", decimer(organique(pb, voxel=0.03, lissage=4), 1200))

# jambe droite : botte de cuir à revers, plis
bt = nouveau()
anneaux_ellipse(bt, [(0.5, -3.0, 0.0, 0.36, 0.38), (0.5, -2.7, 0.0, 0.37, 0.37), (0.5, -2.36, 0.0, 0.39, 0.39),
                     (0.5, -2.34, 0.0, 0.44, 0.44), (0.5, -2.12, -0.01, 0.46, 0.45), (0.5, -2.08, -0.01, 0.43, 0.42)])
bt = organique(bt, voxel=0.025, lissage=3)
bt.normal_update()
for v in bt.verts:   # plis en accordéon sur la tige
    if -2.95 < v.co.y < -2.4:
        v.co = v.co + v.normal * 0.018 * math.sin((v.co.y + 0.3 * math.atan2(v.co.x - 0.5, v.co.z)) * 2 * math.pi / 0.17)
ajouter("RightLowerLeg", "Cuir", decimer(bt, 1300))
pied = nouveau()
ellipsoide(pied, (0.5, -3.0, 0.16), (0.33, 0.22, 0.32))                 # talon
ellipsoide(pied, (0.5, -3.02, -0.42), (0.34, 0.2, 0.42))                # avant-pied, bout rond
tube(pied, [(0.5, -2.86, 0.0), (0.5, -3.02, -0.1)], 0.34, seg=18)
pied = organique(pied, voxel=0.022, lissage=4)
pied = couper(pied, SOL + 0.07, True)
ajouter("RightFoot", "Cuir", decimer(pied, 1100))
se = nouveau()
contour = [V(0.5 + 0.34 * math.cos(a) * (0.95 if math.sin(a) > 0 else 1.0), SOL + 0.04,
             -0.16 + 0.68 * math.sin(a) * (1.0 if math.sin(a) < 0 else 0.78)) for a in [2 * math.pi * k / 32 for k in range(32)]]
prisme(se, contour, None, (0, 1, 0), 0.08)
ajouter("RightFoot", "Semelle", se)

# jambe gauche : bandes de tissu enroulées en spirale jusqu'au mollet
bd = nouveau()
anneaux_ellipse(bd, [(-0.5, -3.0, 0.0, 0.34, 0.35), (-0.5, -2.6, 0.0, 0.365, 0.365), (-0.5, -2.2, 0.0, 0.38, 0.38),
                     (-0.5, -2.12, 0.0, 0.37, 0.37)])
bd = organique(bd, voxel=0.02, lissage=3)
bd.normal_update()
for v in bd.verts:
    ang = math.atan2(v.co.x + 0.5, -v.co.z)
    phase = ((v.co.y + ang / (2 * math.pi) * 0.16) / 0.16) % 1.0
    v.co = v.co + v.normal * (0.028 * math.sin(math.pi * phase) ** 0.6 - 0.012)
ajouter("LeftLowerLeg", "Bandage", decimer(bd, 1300))
pg = nouveau()
ellipsoide(pg, (-0.5, -3.02, 0.12), (0.3, 0.2, 0.3))
ellipsoide(pg, (-0.5, -3.05, -0.36), (0.31, 0.16, 0.34))
tube(pg, [(-0.5, -2.86, 0.0), (-0.5, -3.02, -0.1)], 0.31, seg=18)
pg = organique(pg, voxel=0.02, lissage=4)
pg = couper(pg, SOL + 0.07, True)
pg.normal_update()
for v in pg.verts:   # le bandage continue sur le pied
    phase = ((v.co.z * 0.8 + v.co.y * 0.4) / 0.15) % 1.0
    v.co = v.co + v.normal * 0.02 * math.sin(math.pi * phase) ** 0.6
ajouter("LeftFoot", "Bandage", decimer(pg, 1000))
orteils = nouveau()
for k, (dx, r) in enumerate(((-0.2, 0.075), (-0.1, 0.065), (0.0, 0.062), (0.09, 0.058), (0.17, 0.052))):
    ellipsoide(orteils, (-0.5 - dx * -1, SOL + 0.13, -0.66 + abs(dx) * 0.25), (r, r * 0.85, r * 1.1), seg=12, anneaux=8)
orteils = organique(orteils, voxel=0.012, lissage=2)
ajouter("LeftFoot", "Peau", decimer(orteils, 700))
se = nouveau()
contour = [V(-0.5 + 0.34 * math.cos(a), SOL + 0.035, -0.17 + 0.62 * math.sin(a) * (1.0 if math.sin(a) < 0 else 0.75))
           for a in [2 * math.pi * k / 32 for k in range(32)]]
prisme(se, contour, None, (0, 1, 0), 0.07)
ajouter("LeftFoot", "Semelle", se)
la = nouveau()   # lanières de la sandale
for z0 in (-0.42, -0.12):
    pts = [V(-0.5 + 0.33 * math.cos(a), SOL + 0.07 + 0.2 * math.sin(a), z0) for a in [math.pi * k / 10 for k in range(11)]]
    tube(la, pts, 0.03, seg=8, bouts="rond")
pts = [V(-0.5 + 0.37 * math.cos(a), -2.9, 0.37 * math.sin(a)) for a in [2 * math.pi * k / 24 for k in range(24)]]
tube(la, pts, 0.028, seg=8, ferme=True)
ajouter("LeftFoot", "Cuir", la)

# ================================================================ finition, contrôle, export
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
PIVOT_TETE, TETE = Vector((0, 1.1, 0)), 1.12
for (partie, matiere), bm in sorted(PIECES.items()):
    if partie == "Head":
        for v in bm.verts:
            v.co = PIVOT_TETE + (v.co - PIVOT_TETE) * TETE
    normales(bm)
    for v in bm.verts:
        v.co = B(v.co)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    box_uv(bm)
    nom = f"{partie}_{matiere}"
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = matiere in LISSE
    me.materials.append(MAT[matiere])
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    OBJETS.append(ob)

print("\n=== MAILLAGES ===")
total, envers = 0, []
for ob in OBJETS:
    me = ob.data
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    total += n
    vol = sum(me.vertices[t.vertices[0]].co.dot(me.vertices[t.vertices[1]].co.cross(me.vertices[t.vertices[2]].co))
              for t in me.loop_triangles)
    if vol < 0:
        envers.append(ob.name)
    if n > 20000:
        print("TROP LOURD", ob.name, n)
    print(f"  {ob.name}: {n}")
print(f"{len(OBJETS)} maillages, {total} triangles")
print("Maillages à l'envers :", envers if envers else "aucun")
ref = bpy.data.objects.get("Head_Peau")
pts = [ref.matrix_world @ Vector(c) for c in ref.bound_box]
cb = Vector([sum(p[i] for p in pts) / 8 for i in range(3)])
print("REF Head_Peau centre Roblox", (round(-cb.x, 3), round(cb.z, 3), round(cb.y, 3)))

for ob in bpy.data.objects:
    ob.select_set(ob in OBJETS)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "Tank_P1.fbx"), use_selection=True, object_types={'MESH'},
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                         apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True)

# ---------------------------------------------------------------- aperçus : repos, puis en mouvement
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1000, 1200
scene.eevee.taa_render_samples = 48
scene.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new("Ciel")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.45, 0.5, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam

def vue(loc_r, cible_r, chemin, lens=50):
    loc, cible = B(V(loc_r)), B(V(cible_r))
    cam.location = loc
    cam.rotation_euler = (cible - loc).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

vue((0, 0.0, -11), (0, -0.6, 0), os.path.join(APERCUS, "tank_p1_face.png"))
vue((-6.5, 0.6, -8.5), (0, -0.6, 0), os.path.join(APERCUS, "tank_p1_34.png"))
vue((5, 0.4, 9), (0, -0.6, 0), os.path.join(APERCUS, "tank_p1_dos.png"))
vue((0.6, 1.9, -3.2), (0, 1.72, 0), os.path.join(APERCUS, "tank_p1_visage.png"), lens=55)

# pose de contrôle : bras levés, jambe en avant, buste tourné ; aucune fente ne doit apparaître
POSE = {"UpperTorso": (0, 25, 0), "Head": (0, -20, 0), "RightUpperArm": (60, 0, 15), "RightLowerArm": (70, 0, 0),
        "LeftUpperArm": (40, 0, -20), "LeftLowerArm": (60, 0, 0), "RightUpperLeg": (35, 0, 0), "RightLowerLeg": (-45, 0, 0),
        "LeftUpperLeg": (-20, 0, 0), "LeftLowerLeg": (-20, 0, 0)}
Mb = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Roblox -> Blender
monde = {}
def pose_monde(partie):
    if partie in monde:
        return monde[partie]
    parent, pivot = ARTICULATIONS[partie]
    a = POSE.get(partie, (0, 0, 0))
    local = (Matrix.Translation(V(pivot)) @ Euler([math.radians(x) for x in a], 'XYZ').to_matrix().to_4x4()
             @ Matrix.Translation(-V(pivot)))
    m = (pose_monde(parent) if parent else Matrix.Identity(4)) @ local
    monde[partie] = m
    return m
for ob in OBJETS:
    partie = ob.name.split("_")[0]
    ob.matrix_world = Mb @ pose_monde(partie) @ Mb.inverted()
vue((-6.5, 0.6, -8.5), (0, -0.6, 0), os.path.join(APERCUS, "tank_p1_pose.png"))
vue((5.5, 0.8, -6), (0, -0.4, 0), os.path.join(APERCUS, "tank_p1_pose2.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "tank_p1.blend"))
print("OK")
