# Icônes de l'inventaire (03/10/2026) : catégories et petits pictos en blanc sur fond transparent (teintés dans le jeu),
# pièce d'or, et icônes provisoires des objets en couleurs à plat, en attendant de vraies icônes.
# Dessinées 4x plus grandes puis réduites (anticrénelage). Usage : python icones.py (Pillow requis).
import math, os
from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
T, F = 256, 4          # taille finale, facteur de suréchantillonnage
S = T * F

def nouvelle():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)

def p(*pts):
    return [(x * F, y * F) for x, y in pts]

def sauver(im, nom):
    im.resize((T, T), Image.LANCZOS).save(os.path.join(ICI, nom + ".png"))

BLANC = (255, 255, 255, 255)

def cube(d, cx, cy, r, haut, gauche, droite, trait=None):
    h = r * 0.58
    sommet = p((cx, cy - r), (cx + r * 0.87, cy - r + h), (cx, cy - r + 2 * h), (cx - r * 0.87, cy - r + h))
    g = p((cx - r * 0.87, cy - r + h), (cx, cy - r + 2 * h), (cx, cy + r), (cx - r * 0.87, cy + r - h))
    dr = p((cx + r * 0.87, cy - r + h), (cx, cy - r + 2 * h), (cx, cy + r), (cx + r * 0.87, cy + r - h))
    d.polygon(g, fill=gauche)
    d.polygon(dr, fill=droite)
    d.polygon(sommet, fill=haut)
    if trait:
        for poly in (sommet, g, dr):
            d.line(poly + [poly[0]], fill=trait, width=3 * F, joint="curve")

# ---------------------------------------------------------------- catégories (blanc, teintées en jeu)
im, d = nouvelle()
cube(d, 128, 128, 96, BLANC, (255, 255, 255, 170), (255, 255, 255, 110))
sauver(im, "cat_materiaux")

im, d = nouvelle()
d.polygon(p((200, 30), (226, 56), (100, 182), (74, 156)), fill=BLANC)                   # lame
d.polygon(p((54, 136), (120, 202), (106, 216), (40, 150)), fill=BLANC)                  # garde
d.polygon(p((72, 178), (84, 190), (52, 222), (40, 210)), fill=BLANC)                    # poignée
d.ellipse(p((22, 216), (46, 240)), fill=BLANC)                                          # pommeau
sauver(im, "cat_equipement")

im, d = nouvelle()
d.rectangle(p((104, 24), (152, 44)), fill=BLANC)                                        # bouchon
d.rectangle(p((110, 44), (146, 92)), fill=(255, 255, 255, 200))                         # col
d.ellipse(p((52, 76), (204, 232)), fill=BLANC)                                          # panse
d.ellipse(p((76, 140), (180, 216)), fill=(255, 255, 255, 140))                          # liquide
sauver(im, "cat_consommables")

# ---------------------------------------------------------------- pictos
im, d = nouvelle()
d.ellipse(p((64, 24), (192, 152)), fill=BLANC)
d.polygon(p((72, 120), (184, 120), (128, 236)), fill=BLANC)
d.ellipse(p((104, 64), (152, 112)), fill=(0, 0, 0, 0))
sauver(im, "epingle")

im, d = nouvelle()   # étoile de rareté
pts = []
for i in range(10):
    a = -math.pi / 2 + i * math.pi / 5
    r = 118 if i % 2 == 0 else 50
    pts.append((128 + r * math.cos(a), 132 + r * math.sin(a)))
d.polygon(p(*pts), fill=(255, 205, 60, 255))
d.line(p(*pts) + [p(*pts)[0]], fill=(196, 128, 24, 255), width=8 * F, joint="curve")
sauver(im, "etoile")

im, d = nouvelle()   # pièce d'or
d.ellipse(p((14, 14), (242, 242)), fill=(176, 118, 34, 255))
d.ellipse(p((28, 28), (228, 228)), fill=(250, 205, 104, 255))
d.ellipse(p((70, 70), (186, 186)), outline=(196, 138, 44, 255), width=12 * F)
d.polygon(p((128, 92), (164, 128), (128, 164), (92, 128)), fill=(214, 156, 52, 255))
sauver(im, "piece_or")

# ---------------------------------------------------------------- objets (provisoires, couleurs à plat)
def contour(c, k=0.55):
    return tuple(int(v * k) for v in c[:3]) + (255,)

def ton(c, k):
    return tuple(min(255, int(v * k)) for v in c[:3]) + (255,)

for nom, base in (("bluestone", (92, 114, 144)), ("nightbasalt", (44, 50, 66))):
    im, d = nouvelle()
    cube(d, 128, 134, 100, ton(base, 1.45), ton(base, 1.0), ton(base, 0.75), contour(base, 0.45))
    d.line(p((60, 120), (118, 152)), fill=ton(base, 0.6), width=4 * F)
    d.line(p((150, 150), (200, 128)), fill=ton(base, 0.55), width=4 * F)
    if nom == "nightbasalt":
        d.line(p((90, 70), (150, 60)), fill=(130, 170, 230, 255), width=4 * F)
    sauver(im, "objet_" + nom)

im, d = nouvelle()   # bois : deux bûches
for y, c in ((86, (154, 107, 63)), (150, (176, 124, 74))):
    d.rounded_rectangle(p((34, y), (206, y + 56)), radius=28 * F, fill=c + (255,), outline=(94, 63, 34, 255), width=5 * F)
    d.ellipse(p((180, y), (236, y + 56)), fill=(222, 182, 128, 255), outline=(94, 63, 34, 255), width=5 * F)
    d.ellipse(p((198, y + 18), (218, y + 38)), outline=(160, 112, 66, 255), width=3 * F)
sauver(im, "objet_timber")

def minerai(nom, roche, pepite):
    im, d = nouvelle()
    pierre = p((40, 176), (66, 86), (140, 52), (214, 104), (222, 182), (150, 222), (72, 218))
    d.polygon(pierre, fill=roche + (255,))
    d.line(pierre + [pierre[0]], fill=contour(roche), width=5 * F, joint="curve")
    for poly in (((96, 110), (130, 90), (150, 128), (112, 146)), ((150, 150), (184, 140), (190, 176), (160, 186)), ((78, 160), (100, 150), (108, 176), (84, 184))):
        pts = p(*poly)
        d.polygon(pts, fill=pepite + (255,))
        d.line(pts + [pts[0]], fill=contour(pepite, 0.6), width=3 * F, joint="curve")
        d.line([pts[0], pts[1]], fill=(255, 255, 255, 200), width=3 * F)
    sauver(im, "objet_" + nom)
minerai("silverore", (110, 112, 122), (226, 232, 240))
minerai("goldore", (120, 104, 90), (250, 200, 80))

im, d = nouvelle()   # quartz : grappe de cristaux
for (x, h, w, c) in ((80, 150, 44, (236, 232, 222)), (164, 130, 40, (226, 222, 214)), (124, 196, 54, (248, 246, 240))):
    pts = p((x - w / 2, 226), (x - w / 2, 226 - h), (x, 226 - h - w * 0.8), (x + w / 2, 226 - h), (x + w / 2, 226))
    d.polygon(pts, fill=c + (255,))
    d.line(pts, fill=(150, 140, 126, 255), width=4 * F, joint="curve")
    d.line(p((x, 226 - h - w * 0.8), (x, 226)), fill=(200, 192, 180, 255), width=3 * F)
sauver(im, "objet_quartz")

im, d = nouvelle()   # épée
d.polygon(p((206, 26), (230, 50), (104, 176), (80, 152)), fill=(214, 220, 230, 255), outline=(110, 118, 132, 255))
d.line(p((218, 38), (92, 164)), fill=(160, 168, 182, 255), width=3 * F)
d.polygon(p((54, 136), (120, 202), (106, 216), (40, 150)), fill=(176, 134, 70, 255), outline=(96, 70, 36, 255))
d.polygon(p((72, 178), (84, 190), (52, 222), (40, 210)), fill=(110, 74, 46, 255))
d.ellipse(p((22, 216), (46, 240)), fill=(176, 134, 70, 255))
sauver(im, "objet_epee")

im, d = nouvelle()   # bouclier rond
d.ellipse(p((24, 24), (232, 232)), fill=(120, 84, 52, 255), outline=(70, 48, 30, 255), width=6 * F)
d.ellipse(p((44, 44), (212, 212)), outline=(196, 204, 214, 255), width=12 * F)
for a in range(0, 360, 45):
    x, y = 128 + 74 * math.cos(math.radians(a)), 128 + 74 * math.sin(math.radians(a))
    d.ellipse(p((x - 7, y - 7), (x + 7, y + 7)), fill=(210, 216, 226, 255))
d.ellipse(p((96, 96), (160, 160)), fill=(206, 212, 222, 255), outline=(120, 128, 140, 255), width=4 * F)
sauver(im, "objet_bouclier")
print("ok")

# ---------------------------------------------------------------- étoile à quatre branches (onglet choisi, badge « New »)
# côtés creusés (courbe en astroïde) et pointes légèrement arrondies, blanc uni (teintée en jeu)
im, d = nouvelle()
pts = []
for i in range(360):
    t = math.radians(i)
    c, s = math.cos(t), math.sin(t)
    x = math.copysign(abs(c) ** 3.3, c)
    y = math.copysign(abs(s) ** 3.3, s)
    pts.append((128 + 116 * x, 128 + 116 * y))
d.polygon(p(*pts), fill=BLANC)
sauver(im, "etoile4")

# ---------------------------------------------------------------- pastille du bouton d'action (fond du rond)
# disque ardoise en dégradé, filet doré extérieur, filet clair intérieur ; l'icône (flèche, étoile) se pose dessus
im, d = nouvelle()
for r in range(120, 0, -1):
    t = r / 120
    c = tuple(int(a + (b - a) * t) for a, b in zip((86, 96, 124), (52, 58, 78)))
    d.ellipse(p((128 - r, 128 - r), (128 + r, 128 + r)), fill=c + (255,))
d.ellipse(p((10, 10), (246, 246)), outline=(226, 201, 138, 255), width=7 * F)
d.ellipse(p((24, 24), (232, 232)), outline=(236, 229, 216, 90), width=2 * F)
sauver(im, "pastille")

# double chevron vers le haut (amélioration), blanc uni, teinté en jeu
im, d = nouvelle()
for y0 in (70, 132):
    d.line(p((62, y0 + 52), (128, y0 - 6), (194, y0 + 52)), fill=BLANC, width=26 * F, joint="curve")
    for x, y in ((62, y0 + 52), (128, y0 - 6), (194, y0 + 52)):
        d.ellipse(p((x - 13, y - 13), (x + 13, y + 13)), fill=BLANC)
sauver(im, "fleche_haut")
