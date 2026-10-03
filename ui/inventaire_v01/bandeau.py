# Bandeau de gauche de l'inventaire, façon bannière (03/10/2026) : fond translucide en dégradé, double filet clair
# sur les bords, fil central et motifs discrets (losanges, chevrons, points), pointe en bas ; fanion doré du haut.
# Dessin 4x plus grand puis réduit. Usage : python bandeau.py (Pillow requis).
import os
from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
F = 4
L, H = 100, 1080

def p(*pts):
    return [(x * F, y * F) for x, y in pts]

# ---------------------------------------------------------------- bandeau
im = Image.new("RGBA", (L * F, H * F), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
POINTE = 44   # hauteur de la pointe en bas
for y in range(H * F):
    t = y / (H * F)
    a = int(150 - 70 * (1 - abs(t - 0.5) * 2))   # plus dense en haut et en bas, plus léger au milieu
    d.line([(0, y), (L * F, y)], fill=(38, 46, 64, a))
# pointe : on efface les deux coins du bas
d.polygon(p((0, H - POINTE), (L / 2, H), (0, H)), fill=(0, 0, 0, 0))
d.polygon(p((L, H - POINTE), (L / 2, H), (L, H)), fill=(0, 0, 0, 0))

CLAIR = (196, 204, 224)
def trait(pts, a, w=1.5):
    d.line(p(*pts), fill=CLAIR + (a,), width=int(w * F), joint="curve")

# double filet sur les bords, qui suit la pointe
for marge, a in ((1.5, 110), (8, 55)):
    trait([(marge, 0), (marge, H - POINTE - 2 + marge * 0.6), (L / 2, H - 2 - (marge - 1.5) * 1.2),
           (L - marge, H - POINTE - 2 + marge * 0.6), (L - marge, 0)], a)

# fil central
trait([(L / 2, 150), (L / 2, H - 70)], 26, 1)

def losange(cx, cy, r, a, plein=False):
    pts = p((cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy))
    if plein:
        d.polygon(pts, fill=CLAIR + (a,))
    else:
        d.line(pts + [pts[0]], fill=CLAIR + (a,), width=int(1.5 * F), joint="curve")

def chevron(cx, cy, r, a, bas=True):
    s = 1 if bas else -1
    trait([(cx - r, cy - s * r * 0.6), (cx, cy + s * r * 0.4), (cx + r, cy - s * r * 0.6)], a)

def motif(cy, grand=True):
    r = 26 if grand else 16
    losange(L / 2, cy, r, 40)
    losange(L / 2, cy, r * 0.55, 30, plein=True)
    losange(L / 2, cy, r * 0.22, 60, plein=True)
    for s in (-1, 1):
        chevron(L / 2, cy + s * (r + 14), 14, 34, bas=s > 0)
        d.ellipse(p((L / 2 - 2.5, cy + s * (r + 30) - 2.5), (L / 2 + 2.5, cy + s * (r + 30) + 2.5)), fill=CLAIR + (60,))
    if grand:
        for s in (-1, 1):   # petits losanges sur les côtés
            losange(L / 2 + s * 30, cy, 5, 45, plein=True)

for cy, grand in ((620, True), (760, False), (880, True)):
    motif(cy, grand)
# au-dessus de la pointe, un dernier losange
losange(L / 2, H - 70, 9, 70, plein=True)

im.resize((L, H), Image.LANCZOS).save(os.path.join(ICI, "bandeau.png"))

# ---------------------------------------------------------------- fanion doré (porte l'icône du sac)
FL, FH = 84, 112
im = Image.new("RGBA", (FL * F, FH * F), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
corps = p((10, 12), (FL - 10, 12), (FL - 10, FH - 8), (FL / 2, FH - 26), (10, FH - 8))
d.polygon(corps, fill=(206, 178, 122, 255))
d.line(corps + [corps[0]], fill=(150, 118, 66, 255), width=3 * F, joint="curve")
interieur = p((16, 18), (FL - 16, 18), (FL - 16, FH - 18), (FL / 2, FH - 33), (16, FH - 18))
d.line(interieur + [interieur[0]], fill=(236, 214, 162, 255), width=2 * F, joint="curve")
d.rounded_rectangle(p((4, 4), (FL - 4, 16)), radius=6 * F, fill=(170, 138, 84, 255), outline=(120, 92, 50, 255), width=2 * F)
im.resize((FL, FH), Image.LANCZOS).save(os.path.join(ICI, "fanion.png"))
print("ok")
