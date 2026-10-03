# Animation « Tir » du gobelin sarbacanier, faite à la main (le Throw de Mixamo a été refusé le 03/10/2026).
# Principe : le corps garde la respiration du Repos Mixamo ; une sarbacane (objet de travail, non exporté) est animée
# de la hanche à la bouche, recule à l'inspiration, part d'un coup sec au souffle, puis redescend. Les deux poignets
# y sont accrochés par cinématique inverse (IK sur l'avant-bras, coudes vers le bas et l'extérieur), la tête suit
# un peu le tube. Le tout est cuit en clés ordinaires dans l'action « Tir » (remplace celle de Mixamo).
# Le souffle (départ du dard) est à l'image SOUFFLE. Aperçus : apercus/tir_<image>.png.
# Usage : blender -b --factory-startup --python mobs/creer_tir_sarbacane.py
import bpy, math, os
from mathutils import Vector, Matrix

ICI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "gobelin_sarbacanier")
FICHIER = os.path.join(ICI, "export", "Gobelin_Sarbacanier_anime.blend")
APERCUS = os.path.join(ICI, "apercus")
bpy.ops.wm.open_mainfile(filepath=FICHIER)
scene = bpy.context.scene
scene.render.fps = 30
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
corps = next(o for o in bpy.data.objects if o.type == 'MESH')
pb = arm.pose.bones
MW = arm.matrix_world

# ---------------------------------------------------------------- repères du personnage (au repos)
arm.animation_data.action = bpy.data.actions["Repos"]
scene.frame_set(1)
def monde(nom, queue=False):
    b = pb[nom]
    return MW @ (b.tail if queue else b.head)
haut = Vector((0, 0, 1))
# le modèle Mixamo regarde -Y (exporté ainsi pour Mixamo) ; les pieds, écartés vers l'extérieur, faussaient l'avant
devant = Vector((0, -1, 0))
droite = devant.cross(haut).normalized()
tete_bas, tete_haut = monde("Head"), monde("Head", True)
hh = (tete_haut - tete_bas).length
bouche = tete_bas + haut * (0.32 * hh) + devant * (0.5 * hh)
LONGUEUR = 2.25          # 4,5 studs une fois importé à l'échelle 2
print("REPERES devant", tuple(round(x, 2) for x in devant), "tete", round(hh, 3), "bouche", tuple(round(x, 2) for x in bouche))

# ---------------------------------------------------------------- sarbacane de travail (origine = embout, Z local = vers l'avant)
bpy.ops.mesh.primitive_cylinder_add(radius=0.055, depth=LONGUEUR, location=(0, 0, 0))
tube = bpy.context.active_object
tube.name = "Sarbacane_Travail"
tube.data.transform(Matrix.Translation((0, 0, LONGUEUR / 2)))   # de l'embout (0) vers le bout (+Z local)
def orientation(axe: Vector, incline_deg: float = 0.0) -> Matrix:
    """Repère du tube : Z local selon l'axe (incliné vers le bas de incline_deg), Y local vers le haut."""
    z = (axe * math.cos(math.radians(incline_deg)) - haut * math.sin(math.radians(incline_deg))).normalized()
    x = haut.cross(z).normalized()
    y = z.cross(x).normalized()
    return Matrix((x, y, z)).transposed().to_4x4()

def placer_tube(image, position: Vector, incline: float):
    tube.matrix_world = Matrix.Translation(position) @ orientation(devant, incline)
    tube.keyframe_insert("location", frame=image)
    tube.keyframe_insert("rotation_euler", frame=image)

# poignets accrochés au tube : main droite près de l'embout, gauche plus loin, un peu sous le tube
def vide(nom, parent, local):
    e = bpy.data.objects.new(nom, None)
    scene.collection.objects.link(e)
    e.parent = tube
    e.location = local
    return e
cible_d = vide("Cible_D", tube, (0, -0.07, LONGUEUR * 0.16))
cible_g = vide("Cible_G", tube, (0, -0.07, LONGUEUR * 0.40))
pole_d = bpy.data.objects.new("Pole_D", None); scene.collection.objects.link(pole_d)
pole_g = bpy.data.objects.new("Pole_G", None); scene.collection.objects.link(pole_g)
pole_d.location = monde("RightForeArm") - haut * 1.2 + droite * 0.6
pole_g.location = monde("LeftForeArm") - haut * 1.2 - droite * 0.6
regard = bpy.data.objects.new("Regard", None); scene.collection.objects.link(regard)
regard.parent = tube
regard.location = (0, 0.3, LONGUEUR * 1.6)

# ---------------------------------------------------------------- contraintes
contraintes = []
for cote, cible, pole in (("Right", cible_d, pole_d), ("Left", cible_g, pole_g)):
    ik = pb[cote + "ForeArm"].constraints.new('IK')
    ik.target, ik.pole_target, ik.chain_count = cible, pole, 2
    ik.pole_angle = math.radians(-90)
    contraintes.append(ik)
    # la main prolonge l'avant-bras vers l'avant du tube
    dt = pb[cote + "Hand"].constraints.new('DAMPED_TRACK')
    dt.target, dt.track_axis = regard, 'TRACK_Y'
    dt.influence = 0.0
    contraintes.append(dt)
tete = pb["Head"].constraints.new('DAMPED_TRACK')
tete.target, tete.track_axis = regard, 'TRACK_Z'
contraintes.append(tete)

def influence(image, valeur):
    for c in contraintes:
        v = valeur * (0.9 if c.type == 'DAMPED_TRACK' and c.track_axis == 'TRACK_Y' else
                      0.25 if c.type == 'DAMPED_TRACK' else 1.0)
        c.influence = v
        c.keyframe_insert("influence", frame=image)

# ---------------------------------------------------------------- minutage (30 i/s)
hanche = monde("RightHand") + devant * 0.1
SOUFFLE = 25
placer_tube(1, hanche, 35)                                      ; influence(1, 0.0)
placer_tube(5, hanche + haut * 0.25 + devant * 0.1, 25)         ; influence(5, 0.6)
placer_tube(11, bouche, 0)                                      ; influence(11, 1.0)   # à la bouche
placer_tube(19, bouche - devant * 0.03 + haut * 0.02, -2)       ; influence(19, 1.0)   # inspire, recule
placer_tube(SOUFFLE, bouche + devant * 0.06, 1)                 ; influence(SOUFFLE, 1.0)   # souffle sec
placer_tube(28, bouche - devant * 0.02, 0)                      ; influence(28, 1.0)   # léger recul
placer_tube(36, bouche, 0)                                      ; influence(36, 1.0)
placer_tube(43, hanche + haut * 0.2, 25)                        ; influence(43, 0.5)
placer_tube(48, hanche, 35)                                     ; influence(48, 0.0)
for obj in (tube,):
    for c in obj.animation_data.action.fcurves:
        for k in c.keyframe_points:
            k.interpolation = 'BEZIER'

# ---------------------------------------------------------------- cuisson en clés ordinaires : action « Tir »
arm.animation_data.action = bpy.data.actions["Repos"]   # le corps respire pendant le geste
ancien = bpy.data.actions.get("Tir")
if ancien:
    ancien.name = "Tir_Mixamo_refuse"
    ancien.use_fake_user = False
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.select_all(action='SELECT')
bpy.ops.nla.bake(frame_start=1, frame_end=48, only_selected=False, visual_keying=True, clear_constraints=True,
                 use_current_action=False, bake_types={'POSE'})
bpy.ops.object.mode_set(mode='OBJECT')
tir = arm.animation_data.action
tir.name = "Tir"
tir.use_fake_user = True
if ancien:
    bpy.data.actions.remove(ancien)
print("CUIT", tir.name, tuple(tir.frame_range), "souffle", SOUFFLE)

# ---------------------------------------------------------------- doigts refermés sur le tube pendant le geste
# Le sens de pliage est choisi par l'essai : celui qui rapproche le plus le bout de l'index de la paume.
from mathutils import Quaternion
def poids(image):
    if image <= 1 or image >= 48:
        return 0.0
    if image < 11:
        return (image - 1) / 10
    if image > 36:
        return (48 - image) / 12
    return 1.0
DOIGTS = {"Index1": 55, "Index2": 70, "Index3": 50, "Thumb1": 15, "Thumb2": 35, "Thumb3": 30}
def bout_index(cote):
    return (MW @ pb[cote + "HandIndex3"].tail - MW @ pb[cote + "Hand"].head).length
for cote in ("Left", "Right"):
    scene.frame_set(SOUFFLE)
    meilleur, essai = None, None
    for axe in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)):
        sauves = {}
        for d, ang in DOIGTS.items():
            b = pb.get(cote + "Hand" + d)
            if b:
                sauves[b.name] = b.rotation_quaternion.copy()
                b.rotation_quaternion = b.rotation_quaternion @ Quaternion(axe, math.radians(ang))
        bpy.context.view_layer.update()
        dist = bout_index(cote)
        for nom, q in sauves.items():
            pb[nom].rotation_quaternion = q
        if meilleur is None or dist < meilleur:
            meilleur, essai = dist, axe
    print("DOIGTS", cote, "axe", essai, "bout de l'index a", round(meilleur, 3))
    for d, ang in DOIGTS.items():
        b = pb.get(cote + "Hand" + d)
        if not b:
            continue
        chemin = 'pose.bones["%s"].rotation_quaternion' % b.name
        courbes = sorted((c for c in tir.fcurves if c.data_path == chemin), key=lambda c: c.array_index)
        if len(courbes) != 4:
            continue
        for image in range(1, 49):
            q = Quaternion([c.evaluate(image) for c in courbes])
            n = q @ Quaternion(essai, math.radians(ang) * poids(image))
            for i, c in enumerate(courbes):
                c.keyframe_points.insert(image, n[i], options={'REPLACE', 'FAST'})

# ---------------------------------------------------------------- aperçus (sarbacane visible, face et profil)
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 360, 420
scene.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new("C"); w.use_nodes = True; scene.world = w
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.55, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.4
soleil = bpy.data.objects.new("S", bpy.data.lights.new("S", 'SUN')); soleil.data.energy = 3
soleil.rotation_euler = (math.radians(40), 0, math.radians(10)); scene.collection.objects.link(soleil)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam); scene.camera = cam
centre = monde("Spine1")
H = 4.0
for nom, d in (("trois_quarts", devant * 0.8 + droite * 0.9), ("profil", droite)):
    cam.location = centre + d.normalized() * H * 2.2 + haut * 0.4
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler()
    for image in (1, 11, SOUFFLE, 40):
        scene.frame_set(image)
        scene.render.filepath = os.path.join(APERCUS, f"tir_{nom}_{image:02d}.png")
        bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(tube)   # objet de travail : pas dans le fichier final
for e in (cible_d, cible_g, pole_d, pole_g, regard):
    if e.name in bpy.data.objects:
        bpy.data.objects.remove(e)
bpy.ops.wm.save_as_mainfile(filepath=FICHIER)
print("OK")
