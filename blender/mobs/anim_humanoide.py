# Animations d'un mob humanoïde rigué par rig_humanoide.py (export/<Nom>_rig.blend), faites à la main par clés.
# Les rotations sont données dans les axes du personnage au repos : X = sa droite, Y = devant, Z = haut
# (règle de la main droite : X positif sur un os qui pend fait partir le membre vers l'avant ; sur le buste, X
# négatif le penche en avant). Elles sont converties en quaternions locaux de chaque os, quel que soit son roulis.
# Toutes les poses partent de la posture de gobelin (voûté, genoux pliés) : POSTURE, à laquelle s'ajoutent les clés.
# Sorties : export/<Nom>_anime.blend, export/<Nom>.fbx (maillage + squelette, pose de repos) et un FBX par animation
# (export/anims/<Nom>_<Anim>.fbx, squelette seul), plus des planches d'aperçu (apercus/anim_<Anim>.png).
# Usage : blender -b --factory-startup --python mobs/anim_humanoide.py -- <dossier du mob> <Nom> <attaque|tir>
import bpy, math, os, sys
from mathutils import Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM, ATTAQUE = args[0], args[1], args[2]
ICI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), DOSSIER)
EXPORT, APERCUS = os.path.join(ICI, "export"), os.path.join(ICI, "apercus")
ANIMS = os.path.join(EXPORT, "anims")
os.makedirs(ANIMS, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=os.path.join(EXPORT, NOM + "_rig.blend"))
scene = bpy.context.scene
scene.render.fps = 30
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
corps = next(o for o in bpy.data.objects if o.type == 'MESH')
H = max((corps.matrix_world @ v.co).z for v in corps.data.vertices)
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'QUATERNION'

AXES = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
# les côtés gauche et droit sont symétriques : une rotation autour de Y ou Z change de signe à gauche
def miroir(rot):
    return {k: (-v if k in "yz" else v) for k, v in rot.items()}

def quaternion_local(nom, rot):
    q = Quaternion()
    for axe in "zyx":
        if axe in rot:
            q = Quaternion(AXES[axe], math.radians(rot[axe])) @ q
    repos = arm.data.bones[nom].matrix_local.to_quaternion()
    return repos.inverted() @ q @ repos

# posture de base du gobelin
# Les bras de la pose A partent à ~35° du corps : autour de Y, positif rabat le bras droit (miroir à gauche) ;
# 30° les fait pendre le long du corps avec un léger jour. Dos bien voûté, tête relevée pour regarder devant.
POSTURE = {
    "LowerTorso": {"x": -10}, "UpperTorso": {"x": -20}, "Head": {"x": 24},
    "RightUpperArm": {"x": 12, "y": 30}, "RightLowerArm": {"x": 30}, "RightHand": {"x": 8},
    "RightUpperLeg": {"x": 18}, "RightLowerLeg": {"x": -32}, "RightFoot": {"x": 14},
}
for d in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"):
    if "Right" + d in POSTURE:
        POSTURE["Left" + d] = miroir(POSTURE["Right" + d])

def poser(cle: dict, hauteur: float = 0.0):
    """Applique POSTURE + la clé (rotations ajoutées axe par axe) et la hauteur du bassin (fraction de H)."""
    for b in pb:
        rot = dict(POSTURE.get(b.name, {}))
        for axe, v in cle.get(b.name, {}).items():
            rot[axe] = rot.get(axe, 0) + v
        b.rotation_quaternion = quaternion_local(b.name, rot)
        b.location = (0, 0, 0)
    # la racine monte ou descend le long de son propre axe (vertical au repos)
    pb["HumanoidRootPart"].location = (0, hauteur * H, 0)

def symetrique(cle: dict) -> dict:
    """Complète une clé donnée pour le côté droit avec le côté gauche en miroir, si absent."""
    c = dict(cle)
    for nom, rot in cle.items():
        if nom.startswith("Right") and ("Left" + nom[5:]) not in c:
            c["Left" + nom[5:]] = miroir(rot)
    return c

def creer(nom: str, cles: list, boucle: bool):
    """cles : liste de (image, clé, hauteur). Une boucle reprend sa première clé à la fin."""
    action = bpy.data.actions.new(nom)
    arm.animation_data_create()
    arm.animation_data.action = action
    for image, cle, hauteur in cles:
        poser(cle, hauteur)
        for b in pb:
            b.keyframe_insert("rotation_quaternion", frame=image)
            b.keyframe_insert("location", frame=image)
    if boucle:
        derniere = cles[-1][0] + (cles[1][0] - cles[0][0])
        image, cle, hauteur = cles[0]
        poser(cle, hauteur)
        for b in pb:
            b.keyframe_insert("rotation_quaternion", frame=derniere)
            b.keyframe_insert("location", frame=derniere)
    for courbe in action.fcurves:
        for k in courbe.keyframe_points:
            k.interpolation = 'BEZIER'
            k.easing = 'AUTO'
    action.use_fake_user = True
    return action

def pas(phase):
    """Clé de marche : phase 0 = jambe droite devant, 1 = jambe gauche devant."""
    s = 1 if phase == 0 else -1
    return {
        "RightUpperLeg": {"x": 26 * s}, "LeftUpperLeg": {"x": -26 * s},
        "RightLowerLeg": {"x": -8}, "LeftLowerLeg": {"x": -8},
        "RightUpperArm": {"x": -28 * s}, "LeftUpperArm": {"x": 28 * s},
        "RightLowerArm": {"x": 10 if s > 0 else -5}, "LeftLowerArm": {"x": -5 if s > 0 else 10},
        "UpperTorso": {"z": -7 * s}, "LowerTorso": {"z": 5 * s}, "Head": {"z": 5 * s},
    }
def passage(cote):
    """Clé de marche : la jambe arrière passe sous le corps, genou plié."""
    autre = "Left" if cote == "Right" else "Right"
    return {cote + "UpperLeg": {"x": 18}, cote + "LowerLeg": {"x": -48}, cote + "Foot": {"x": 18},
            autre + "UpperLeg": {"x": -6}, autre + "LowerLeg": {"x": -4}}

actions = {}
# repos : respiration, petit balancement, regard qui balaie
actions["Repos"] = creer("Repos", [
    (1, {"UpperTorso": {"x": 0}, "Head": {"z": 0}}, 0),
    (20, {"UpperTorso": {"x": 3}, "Head": {"z": 10, "x": -3}, **symetrique({"RightUpperArm": {"z": 3}})}, -0.008),
    (40, {"UpperTorso": {"x": -1}, "Head": {"z": -8}, **symetrique({"RightUpperArm": {"z": -2}})}, 0.004),
], True)
# marche : 1 s pour deux pas
actions["Marche"] = creer("Marche", [
    (1, pas(0), -0.01), (8, passage("Left"), 0.015), (16, pas(1), -0.01), (23, passage("Right"), 0.015),
], True)
# marche arrière : le cycle de marche joué à l'envers, buste un peu redressé
recul = {"UpperTorso": {"x": 5}}
actions["MarcheArriere"] = creer("MarcheArriere", [
    (1, {**pas(0), **recul}, -0.01), (8, {**passage("Right"), **recul}, 0.015),
    (16, {**pas(1), **recul}, -0.01), (23, {**passage("Left"), **recul}, 0.015),
], True)
# pas chassés : la jambe du côté où l'on va s'écarte, l'autre la rejoint ; buste qui penche à peine.
# Autour de Y, positif écarte la jambe gauche (vers -X) et rapproche la droite.
def chasse(sens):   # sens = 1 vers la droite, -1 vers la gauche
    devant, suit = ("Right", "Left") if sens > 0 else ("Left", "Right")
    s = sens
    # bras qui s'écartent un peu pour l'équilibre, bassin qui balance, buste qui suit à contretemps
    ecart = {devant + "UpperLeg": {"y": -30 * s, "x": 6}, suit + "UpperLeg": {"y": -12 * s},
             devant + "LowerLeg": {"x": -22}, devant + "Foot": {"y": 8 * s},
             "LowerTorso": {"y": -6 * s}, "UpperTorso": {"y": 9 * s}, "Head": {"y": -4 * s},
             devant + "UpperArm": {"y": -12}, suit + "UpperArm": {"y": -6}}
    rejoint = {devant + "UpperLeg": {"y": -6 * s}, suit + "UpperLeg": {"y": 10 * s, "x": 6},
               suit + "LowerLeg": {"x": -26}, "LowerTorso": {"y": 4 * s}, "UpperTorso": {"y": -5 * s},
               devant + "UpperArm": {"y": -4}, suit + "UpperArm": {"y": -10}}
    return ecart, rejoint
for nom, sens in (("PasDroite", 1), ("PasGauche", -1)):
    ecart, rejoint = chasse(sens)
    actions[nom] = creer(nom, [(1, ecart, -0.02), (9, rejoint, 0.015)], True)
# course : buste penché, grands pas, bras pliés qui pompent
def foulee(phase):
    s = 1 if phase == 0 else -1
    return {"UpperTorso": {"x": -16, "z": -8 * s}, "Head": {"x": 10},
            "RightUpperLeg": {"x": 45 * s}, "LeftUpperLeg": {"x": -40 * s},
            "RightLowerLeg": {"x": -20 if s > 0 else -75}, "LeftLowerLeg": {"x": -75 if s > 0 else -20},
            "RightUpperArm": {"x": -32 * s}, "LeftUpperArm": {"x": 32 * s},
            "RightLowerArm": {"x": 38}, "LeftLowerArm": {"x": 38}}
actions["Course"] = creer("Course", [(1, foulee(0), -0.03), (6, {}, 0.03), (11, foulee(1), -0.03), (16, {}, 0.03)], True)
# attaque
if ATTAQUE == "attaque":
    # griffure : bras droit levé au-dessus de la tête, main en arrière, buste qui se cambre et tourne ;
    # frappe en travers vers le bas avec un pas en avant, l'autre bras part en arrière pour équilibrer
    actions["Attaque"] = creer("Attaque", [
        (1, {}, 0),
        (10, {"RightUpperArm": {"x": 150, "z": 15}, "RightLowerArm": {"x": 60}, "RightHand": {"x": -20},
              "UpperTorso": {"x": 14, "z": 22}, "LowerTorso": {"z": 8}, "Head": {"x": -8},
              "LeftUpperArm": {"x": 35}, "LeftLowerArm": {"x": 30}}, 0.02),
        (14, {"RightUpperArm": {"x": 45, "z": -30}, "RightLowerArm": {"x": 10}, "RightHand": {"x": 15},
              "UpperTorso": {"x": -22, "z": -28}, "LowerTorso": {"z": -12, "x": -6}, "Head": {"x": 6},
              "LeftUpperArm": {"x": -35}, "RightUpperLeg": {"x": 28}, "RightLowerLeg": {"x": -18},
              "LeftUpperLeg": {"x": -18}}, -0.05),
        (19, {"RightUpperArm": {"x": 30, "z": -25}, "RightLowerArm": {"x": 15},
              "UpperTorso": {"x": -18, "z": -22}, "LowerTorso": {"z": -10}, "LeftUpperArm": {"x": -25},
              "RightUpperLeg": {"x": 24}, "LeftUpperLeg": {"x": -14}}, -0.05),
        (32, {}, 0),
    ], False)
else:
    # tir à la sarbacane : les deux mains montent à la bouche, souffle, recul de la tête
    a_la_bouche = {"RightUpperArm": {"x": 75, "y": 20}, "RightLowerArm": {"x": 85}, "LeftUpperArm": {"x": 70, "y": -25},
                   "LeftLowerArm": {"x": 80}, "Head": {"x": -6}, "UpperTorso": {"x": -4}}
    actions["Tir"] = creer("Tir", [
        (1, {}, 0),
        (10, a_la_bouche, 0),
        (16, {**a_la_bouche, "UpperTorso": {"x": -10}, "Head": {"x": -12}}, -0.01),   # inspire, se penche
        (19, {**a_la_bouche, "UpperTorso": {"x": 4}, "Head": {"x": 2}}, 0.005),        # souffle : recul
        (30, {}, 0),
    ], False)
# coup reçu : rejeté en arrière, bras écartés, puis retour
actions["Touche"] = creer("Touche", [
    (1, {}, 0),
    (4, {"UpperTorso": {"x": 18}, "LowerTorso": {"x": 6}, "Head": {"x": -22},
         **symetrique({"RightUpperArm": {"x": -25, "z": -20}, "RightLowerArm": {"x": -15}})}, 0.01),
    (14, {}, 0),
], False)
# mort : genoux qui lâchent, chute sur le dos
actions["Mort"] = creer("Mort", [
    (1, {}, 0),
    (8, {"UpperTorso": {"x": 15}, "Head": {"x": -20}, **symetrique({"RightUpperLeg": {"x": 30}, "RightLowerLeg": {"x": -60}})}, -0.12),
    (18, {"HumanoidRootPart": {"x": 75}, "UpperTorso": {"x": 10}, "Head": {"x": -15},
          **symetrique({"RightUpperArm": {"x": -60, "z": -40}, "RightUpperLeg": {"x": 40}, "RightLowerLeg": {"x": -30}})}, -0.32),
    (24, {"HumanoidRootPart": {"x": 88}, "Head": {"x": -5},
          **symetrique({"RightUpperArm": {"x": -80, "z": -50}, "RightUpperLeg": {"x": 20}, "RightLowerLeg": {"x": -10}})}, -0.36),
    (40, {"HumanoidRootPart": {"x": 88}, "Head": {"x": -5},
          **symetrique({"RightUpperArm": {"x": -80, "z": -50}, "RightUpperLeg": {"x": 20}, "RightLowerLeg": {"x": -10}})}, -0.36),
], False)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXPORT, NOM + "_anime.blend"))

# ---------------------------------------------------------------- exports FBX (1 stud = 1 unité)
def exporter(chemin, objets, avec_animation):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(filepath=chemin, use_selection=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', add_leaf_bones=False, bake_anim=avec_animation,
                             bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_simplify_factor=0.0, mesh_smooth_type='FACE', path_mode='COPY', embed_textures=True)

arm.animation_data.action = None
for b in pb:
    b.rotation_quaternion, b.location = Quaternion(), (0, 0, 0)
exporter(os.path.join(EXPORT, NOM + ".fbx"), [arm, corps], False)
for nom, action in actions.items():
    arm.animation_data.action = action
    debut, fin = action.frame_range
    scene.frame_start, scene.frame_end = int(debut), int(fin)
    exporter(os.path.join(ANIMS, NOM + "_" + nom + ".fbx"), [arm], True)

# ---------------------------------------------------------------- planches : 4 images de chaque animation
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 360, 420
scene.view_settings.view_transform = 'Standard'
# la scène du squelette a été enregistrée avant ses lumières : ciel et soleil pour les planches
monde = bpy.data.worlds.new("Ciel")
monde.use_nodes = True
scene.world = monde
monde.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.47, 0.5, 1)
monde.node_tree.nodes["Background"].inputs[1].default_value = 1.3
soleil = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
soleil.data.energy = 3
soleil.rotation_euler = (math.radians(50), 0, math.radians(20))
scene.collection.objects.link(soleil)
cam = scene.camera
if cam is None:
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
D = H * 2.6
cam.location = Vector((D * 0.75, D * 0.65, H * 0.6))
cam.rotation_euler = (Vector((0, 0, H * 0.45)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
for nom, action in actions.items():
    arm.animation_data.action = action
    debut, fin = action.frame_range
    for i in range(4):
        scene.frame_set(int(debut + (fin - debut) * i / 4))
        scene.render.filepath = os.path.join(APERCUS, f"anim_{nom}_{i}.png")
        bpy.ops.render.render(write_still=True)
print("OK", ", ".join(actions))
