# Squelette quadrupède pour un mob nettoyé (export/<Nom>_propre.glb), face vers +Y, pattes au sol (z = 0).
# Repères lus sur le maillage :
#   pattes   : points sous 12 % de la hauteur, rangés en quatre groupes (avant/arrière selon y, gauche/droite selon x)
#   museau   : point le plus en avant (y max) ; queue : point le plus en arrière (y min)
#   colonne  : bassin au-dessus des pattes arrière, torse au-dessus des pattes avant, à 62 % de la hauteur
# Os : Racine, Bassin, Dos, Torse, Cou, Tete, Machoire, Queue1-2, et pour chaque patte <Patte>Haut/Bas/Pied
# (Patte = AvantGauche, AvantDroite, ArriereGauche, ArriereDroite ; la gauche de l'animal est en -X).
# Skinning automatique, 4 influences au plus. Sorties : export/<Nom>_rig.blend, apercus/rig_*.png.
# Usage : blender -b --factory-startup --python mobs/rig_quadrupede.py -- <dossier du mob> <Nom>
import bpy, math, os, sys
from mathutils import Vector

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
ymin, ymax = min(p.y for p in pts), max(p.y for p in pts)
L = ymax - ymin

# ---------------------------------------------------------------- repères
bas = [p for p in pts if p.z < H * 0.12]
ymilieu = (min(p.y for p in bas) + max(p.y for p in bas)) / 2
pattes = {}
for nom, avant, gauche in (("AvantGauche", True, True), ("AvantDroite", True, False),
                           ("ArriereGauche", False, True), ("ArriereDroite", False, False)):
    groupe = [p for p in bas if (p.y > ymilieu) == avant and (p.x < 0) == gauche]
    pattes[nom] = sum(groupe, Vector()) / max(1, len(groupe))
dos_z = H * 0.62
y_avant = (pattes["AvantGauche"].y + pattes["AvantDroite"].y) / 2
y_arriere = (pattes["ArriereGauche"].y + pattes["ArriereDroite"].y) / 2
museau = max(pts, key=lambda p: p.y)
tete_pts = [p for p in pts if p.y > ymax - L * 0.12]
tete_z = sum(p.z for p in tete_pts) / max(1, len(tete_pts))
queue_pts = [p for p in pts if p.y < ymin + L * 0.06]
queue_z = sum(p.z for p in queue_pts) / max(1, len(queue_pts)) if queue_pts else H * 0.5
print("REPERES H=%.2f L=%.2f avant_y=%.2f arriere_y=%.2f museau=%s tete_z=%.2f" % (
    H, L, y_avant, y_arriere, tuple(round(c, 2) for c in museau), tete_z))

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

bassin = Vector((0, y_arriere, dos_z))
torse = Vector((0, y_avant, dos_z * 1.03))
milieu = (bassin + torse) / 2 + Vector((0, 0, H * 0.03))
cou_base = torse + Vector((0, L * 0.06, H * 0.04))
tete_base = Vector((0, ymax - L * 0.16, tete_z + H * 0.04))
os_("Racine", (0, (y_avant + y_arriere) / 2, 0), (0, (y_avant + y_arriere) / 2, H * 0.15))
os_("Bassin", bassin, milieu, "Racine")
os_("Dos", milieu, torse, "Bassin", True)
os_("Torse", torse, cou_base, "Dos", True)
os_("Cou", cou_base, tete_base, "Torse", True)
os_("Tete", tete_base, Vector((0, museau.y, museau.z + H * 0.05)), "Cou", True)
os_("Machoire", tete_base + Vector((0, L * 0.02, -H * 0.06)), Vector((0, museau.y - L * 0.02, museau.z - H * 0.06)), "Tete")
queue_debut = Vector((0, ymin + L * 0.08, queue_z))
os_("Queue1", bassin, queue_debut, "Bassin")
os_("Queue2", queue_debut, Vector((0, ymin, queue_z - H * 0.03)), "Queue1", True)
for nom, patte in pattes.items():
    avant = nom.startswith("Avant")
    parent = "Torse" if avant else "Bassin"
    epaule = Vector((patte.x * 0.85, patte.y - (L * 0.03 if avant else -L * 0.02), dos_z * 0.92))
    coude = Vector((patte.x * 0.95, patte.y + (L * 0.02 if avant else -L * 0.05), H * 0.36))   # genou arrière plié vers l'arrière
    poignet = Vector((patte.x, patte.y, H * 0.08))
    os_(nom + "Haut", epaule, coude, parent)
    os_(nom + "Bas", coude, poignet, nom + "Haut", True)
    os_(nom + "Pied", poignet, Vector((patte.x, patte.y + L * 0.06, 0.01)), nom + "Bas", True)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- poids automatiques
bpy.ops.object.select_all(action='DESELECT')
corps.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
sans_poids = sum(1 for v in corps.data.vertices if not v.groups)
print("POIDS groupes=%d sommets_sans_poids=%d" % (len(corps.vertex_groups), sans_poids))
bpy.context.view_layer.objects.active = corps
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXPORT, NOM + "_rig.blend"))

# ---------------------------------------------------------------- aperçus de poses de test
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 800, 600
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
    cam.rotation_euler = (Vector((0, (ymin + ymax) / 2, H * 0.45)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
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
D = max(H, L) * 2.2
pose({})
vue("rig_repos.png", (D * 0.8, (ymin + ymax) / 2 + D * 0.5, H * 0.8))
pose({"AvantGaucheHaut": (40, 0, 0), "AvantGaucheBas": (-50, 0, 0), "ArriereDroiteHaut": (-35, 0, 0),
      "Cou": (-25, 0, 20), "Machoire": (25, 0, 0), "Queue1": (0, 0, 30), "Dos": (0, 0, 10)})
vue("rig_pose.png", (D * 0.8, (ymin + ymax) / 2 + D * 0.5, H * 0.8))
print("OK")
