# Squelette humanoïde pour un mob nettoyé (export/<Nom>_propre.glb), sans Avatar Setup.
# Les repères sont lus sur le maillage (pose A, face vers +Y, pieds à z = 0, centré en x) :
#   cou      : tranche horizontale la plus étroite entre 55 % et 88 % de la hauteur
#   mains    : points les plus écartés à gauche et à droite (pose A)
#   entrejambe : plus haut niveau où un vide sépare les deux jambes au centre
# Le reste (épaules, coudes, hanches, genoux, chevilles) en découle. Noms d'os façon R15.
# Skinning : poids calculés par distance aux os avec garde-fous (voir plus bas) ; le personnage regarde vers +Y,
# sa gauche est en -X.
# Sorties : export/<Nom>_rig.blend et des aperçus du maillage plié (apercus/rig_*.png) pour vérifier les poids.
# Usage : blender -b --factory-startup --python mobs/rig_humanoide.py -- <dossier du mob> <Nom>
import bpy, math, os, sys
from mathutils import Vector, Matrix, Euler

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM = args[0], args[1]
ICI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), DOSSIER)
EXPORT, APERCUS = os.path.join(ICI, "export"), os.path.join(ICI, "apercus")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(EXPORT, NOM + "_propre.glb"))
corps = next(o for o in bpy.data.objects if o.type == 'MESH')
corps.name = NOM
bpy.ops.object.select_all(action='DESELECT')
corps.select_set(True)
bpy.context.view_layer.objects.active = corps
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
for o in list(bpy.data.objects):
    if o.type == 'EMPTY':
        bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [corps.matrix_world @ v.co for v in corps.data.vertices]
H = max(p.z for p in pts)

def tranche(z0, z1):
    return [p for p in pts if z0 <= p.z < z1]

# ---------------------------------------------------------------- repères
pas = H / 80
# cou : largeur de la tranche (en x) restreinte au voisinage du centre pour ignorer les épaules
meilleur, cou_z = 1e9, H * 0.75
z = H * 0.55
while z < H * 0.88:
    t = [p for p in tranche(z, z + pas) if abs(p.x) < H * 0.18]
    if t:
        largeur = max(p.x for p in t) - min(p.x for p in t)
        if largeur < meilleur:
            meilleur, cou_z = largeur, z
    z += pas
# mains : extrêmes en x, au-dessous du cou
gauche = min((p for p in pts if p.z < cou_z), key=lambda p: p.x)
droite = max((p for p in pts if p.z < cou_z), key=lambda p: p.x)
# entrejambe : plus haute tranche (sous 55 % de la hauteur) sans aucun point près de l'axe
entre_z = H * 0.3
z = H * 0.55
while z > H * 0.1:
    t = tranche(z, z + pas)
    centraux = [p for p in t if abs(p.x) < H * 0.02 and abs(p.y) < H * 0.12]
    if t and not centraux:
        entre_z = z
        break
    z -= pas
# hanches : écart moyen des jambes un peu sous l'entrejambe
jambes = [p for p in tranche(entre_z - H * 0.08, entre_z - H * 0.02) if abs(p.x) < H * 0.25]
hanche_x = (sum(abs(p.x) for p in jambes) / max(1, len(jambes))) if jambes else H * 0.08
# épaules : largeur du buste juste sous le cou
buste = [p for p in tranche(cou_z - H * 0.1, cou_z - H * 0.05) if abs(p.x) < H * 0.3]
epaule_x = max(abs(p.x) for p in buste) * 0.82 if buste else H * 0.15
epaule_z = cou_z - H * 0.05
# profondeur du centre du corps (y moyen du bassin) pour placer la colonne au milieu
bassin = tranche(entre_z, entre_z + H * 0.08)
centre_y = sum(p.y for p in bassin) / max(1, len(bassin))
print("REPERES H=%.2f cou=%.2f entrejambe=%.2f hanche_x=%.2f epaule=(%.2f, %.2f) mains=%s %s" % (
    H, cou_z, entre_z, hanche_x, epaule_x, epaule_z, tuple(round(c, 2) for c in gauche), tuple(round(c, 2) for c in droite)))

# ---------------------------------------------------------------- os
arm_data = bpy.data.armatures.new(NOM + "_Squelette")
arm = bpy.data.objects.new(NOM + "_Squelette", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones

def os_(nom, tete, queue, parent=None, relie=False):
    b = eb.new(nom)
    b.head, b.tail = Vector(tete), Vector(queue)
    if parent:
        b.parent = eb[parent]
        b.use_connect = relie
    return b

y = centre_y
taille_z = entre_z + (epaule_z - entre_z) * 0.35
os_("HumanoidRootPart", (0, y, entre_z), (0, y, entre_z + H * 0.05))
os_("LowerTorso", (0, y, entre_z + H * 0.02), (0, y, taille_z), "HumanoidRootPart")
os_("UpperTorso", (0, y, taille_z), (0, y, cou_z), "LowerTorso", True)
os_("Head", (0, y, cou_z), (0, y, H), "UpperTorso", True)
for cote, main, s in (("Left", gauche, -1), ("Right", droite, 1)):
    epaule = Vector((s * epaule_x, y, epaule_z))
    poignet = Vector(main) + (epaule - Vector(main)).normalized() * H * 0.06
    coude = (epaule + poignet) / 2 + Vector((0, -H * 0.015, 0))   # léger pli vers l'arrière
    os_(cote + "UpperArm", epaule, coude, "UpperTorso")
    os_(cote + "LowerArm", coude, poignet, cote + "UpperArm", True)
    os_(cote + "Hand", poignet, Vector(main), cote + "LowerArm", True)
    hanche = Vector((s * hanche_x, y, entre_z + H * 0.02))
    cheville = Vector((s * hanche_x * 1.05, y, H * 0.06))
    genou = (hanche + cheville) / 2 + Vector((0, H * 0.015, 0))     # léger pli vers l'avant
    os_(cote + "UpperLeg", hanche, genou, "LowerTorso")
    os_(cote + "LowerLeg", genou, cheville, cote + "UpperLeg", True)
    os_(cote + "Foot", cheville, cheville + Vector((0, H * 0.09, -H * 0.05)), cote + "LowerLeg", True)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- poids
# La « chaleur des os » de Blender échoue sur ces maillages remaillés puis réduits (sommets sans poids) :
# poids calculés ici. Chaque sommet suit ses trois os les plus proches (distance au segment, 1/d^4),
# avec des garde-fous : pas de jambe au-dessus du bassin, pas de bras sous le bassin ni du côté opposé,
# le haut du corps ne descend pas dans les jambes. Puis lissage aux jointures, 4 influences au plus.
bpy.ops.object.select_all(action='DESELECT')
corps.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_NAME')   # parenté + groupes vides au nom des os
segments = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones
            if b.name != "HumanoidRootPart"}

def distance_segment(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length

def permis(nom, p):
    jambe = "Leg" in nom or "Foot" in nom
    bras = "Arm" in nom or "Hand" in nom
    if jambe and p.z > entre_z + H * 0.06:
        return False
    if (bras or nom in ("UpperTorso", "Head")) and p.z < entre_z:
        return False
    if nom.startswith("Left") and p.x > H * 0.02:
        return False
    if nom.startswith("Right") and p.x < -H * 0.02:
        return False
    if bras and abs(p.x) < epaule_x * 0.75:
        return False
    return True

groupes = {nom: corps.vertex_groups.get(nom) or corps.vertex_groups.new(name=nom) for nom in segments}
for v in corps.data.vertices:
    p = corps.matrix_world @ v.co
    candidats = []
    for nom, (a, b) in segments.items():
        if permis(nom, p):
            candidats.append((distance_segment(p, a, b), nom))
    if not candidats:
        candidats = [(distance_segment(p, a, b), nom) for nom, (a, b) in segments.items()]
    candidats.sort()
    choisis = candidats[:3]
    poids = [1.0 / max(d, H * 0.01) ** 4 for d, _ in choisis]
    total = sum(poids)
    for (d, nom), w in zip(choisis, poids):
        if w / total > 0.02:
            groupes[nom].add([v.index], w / total, 'REPLACE')
bpy.context.view_layer.objects.active = corps
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=3)
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')
sans_poids = sum(1 for v in corps.data.vertices if not v.groups)
print("POIDS groupes=%d sommets=%d sans_poids=%d" % (len(corps.vertex_groups), len(corps.data.vertices), sans_poids))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXPORT, NOM + "_rig.blend"))

# ---------------------------------------------------------------- aperçus : poses de test pour juger les poids
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 700, 700
scene.view_settings.view_transform = 'Standard'
monde = bpy.data.worlds.new("Ciel")
monde.use_nodes = True
scene.world = monde
monde.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.47, 0.5, 1)
monde.node_tree.nodes["Background"].inputs[1].default_value = 1.3
soleil = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
soleil.data.energy = 3
soleil.rotation_euler = (math.radians(50), 0, math.radians(20))
scene.collection.objects.link(soleil)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
def vue(nom, loc):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector((0, 0, H * 0.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(APERCUS, nom)
    bpy.ops.render.render(write_still=True)

pb = arm.pose.bones
def pose(rotations):
    for b in pb:
        b.rotation_mode = 'XYZ'
        b.rotation_euler = (0, 0, 0)
    for nom, (rx, ry, rz) in rotations.items():
        pb[nom].rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bpy.context.view_layer.update()

D = H * 2.6
pose({})
vue("rig_repos.png", (D * 0.55, D * 0.8, H * 0.6))
# bras levés, coude plié, jambe en avant, genou plié, tête tournée : les zones à risque
pose({"LeftUpperArm": (0, 0, -70), "RightUpperArm": (0, 0, 70), "LeftLowerArm": (60, 0, 0), "RightLowerArm": (60, 0, 0),
      "LeftUpperLeg": (-50, 0, 0), "LeftLowerLeg": (70, 0, 0), "RightUpperLeg": (25, 0, 0), "Head": (0, 0, 35),
      "UpperTorso": (10, 0, 15)})
vue("rig_pose.png", (D * 0.55, D * 0.8, H * 0.6))
vue("rig_pose_dos.png", (-D * 0.55, -D * 0.8, H * 0.6))
print("OK")
