# Rassemble les téléchargements Mixamo d'un mob (blender/<dossier>/mixamo/*.fbx) en un modèle pour Roblox.
#   * le fichier « *_avec_skin.fbx » donne le maillage rigué ; les autres (« Without Skin ») n'ont que le squelette
#     animé. Chaque animation prend le nom de son fichier (Marche.fbx -> action « Marche »).
#   * préfixe « mixamorig: » retiré des os (et des courbes d'animation) ;
#   * déplacements horizontaux du bassin supprimés (animations jouées sur place, le jeu déplace le mob) ;
#   * texture du nettoyage (export/<Nom>_couleur.png) remise si Mixamo ne l'a pas renvoyée.
# Sorties : export/<Nom>_mixamo_rig.fbx (maillage + squelette au repos, à importer dans Studio) et
#           export/<Nom>_anime.blend (actions avec « fake user », lues par export_anims_roblox.py).
# Usage : blender -b --factory-startup --python mobs/mixamo_vers_roblox.py -- <dossier du mob> <Nom> [écart des bras en degrés]
import bpy, math, os, sys
from mathutils import Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM = args[0], args[1]
ICI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), DOSSIER)
MIXAMO, EXPORT = os.path.join(ICI, "mixamo"), os.path.join(ICI, "export")
PREFIXE = "mixamorig:"

def renommer_chemins(action):
    for c in action.fcurves:
        if PREFIXE in c.data_path:
            c.data_path = c.data_path.replace(PREFIXE, "")

# Mixamo pense ses gestes pour un corps humain : sur un gobelin aux longs bras, les mains se rejoignent devant lui
# (mesuré : 0,56 stud entre les mains au repos). On écarte chaque bras vers l'extérieur d'un angle fixe, autour de
# l'axe avant-arrière du squelette, sur toute l'animation ; le mouvement lui-même ne change pas.
ECART_BRAS = float(args[2]) if len(args) > 2 else 0.0   # degrés ; inutile depuis le retransfert (03/10/2026)

def ecarter_bras(arm, action):
    for cote in ("LeftArm", "RightArm"):
        os_ = arm.data.bones.get(cote)
        if not os_:
            continue
        repos = os_.matrix_local.to_3x3()
        # axe avant-arrière (Y du squelette) exprimé dans le repère de l'os ; sens : la main part vers son côté
        signe = 1 if (arm.matrix_world @ os_.head_local).x > 0 else -1
        delta = Quaternion(repos.inverted() @ Vector((0, 1, 0)), math.radians(signe * ECART_BRAS))   # sens vérifié : positif = écarte
        chemin = 'pose.bones["%s"].rotation_quaternion' % cote
        courbes = sorted((c for c in action.fcurves if c.data_path == chemin), key=lambda c: c.array_index)
        if len(courbes) != 4:
            continue
        cles = sorted({k.co[0] for c in courbes for k in c.keyframe_points})
        valeurs = [Quaternion([c.evaluate(f) for c in courbes]) for f in cles]
        for c in courbes:
            c.keyframe_points.clear()
        for f, q in zip(cles, valeurs):
            n = delta @ q
            for i, c in enumerate(courbes):
                c.keyframe_points.insert(f, n[i], options={'FAST'})

def sur_place(action):
    # le bassin garde sa hauteur (rebond), plus d'avance ni de dérive : x et z du bassin ramenés à la 1re clé
    for c in action.fcurves:
        if c.data_path == 'pose.bones["Hips"].location' and c.array_index in (0, 2):
            v0 = c.keyframe_points[0].co[1] if c.keyframe_points else 0
            for k in c.keyframe_points:
                k.co[1] = v0
                k.handle_left[1] = v0
                k.handle_right[1] = v0

bpy.ops.wm.read_factory_settings(use_empty=True)
fichiers = sorted(f for f in os.listdir(MIXAMO) if f.lower().endswith(".fbx"))
base = next(f for f in fichiers if "avec_skin" in f)
bpy.ops.import_scene.fbx(filepath=os.path.join(MIXAMO, base))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
corps = next(o for o in bpy.data.objects if o.type == 'MESH')
arm.name, corps.name = NOM + "_Squelette", NOM
for b in arm.data.bones:
    b.name = b.name.replace(PREFIXE, "")
for g in corps.vertex_groups:
    g.name = g.name.replace(PREFIXE, "")
actions = {}
premiere = arm.animation_data.action
renommer_chemins(premiere)
premiere.name = base.replace("_avec_skin.fbx", "")
actions[premiere.name] = premiere

# Les fichiers « Without Skin » portent un squelette de référence dont la pose de repos n'est pas celle du gobelin
# (pose T contre pose A) : recopier leurs rotations telles quelles décalait tous les bras (mains rabattues devant
# le ventre). On retransfère image par image : rotation de l'os par rapport à son parent dans la source
# (repos_src @ q_src), réexprimée dans le repos du gobelin (q = repos_cible⁻¹ @ repos_src @ q_src).
def repos_relatifs(armature):
    r = {}
    for b in armature.data.bones:
        nom = b.name.replace(PREFIXE, "")
        m = b.matrix_local.to_3x3()
        if b.parent:
            m = b.parent.matrix_local.to_3x3().inverted() @ m
        r[nom] = (m.to_quaternion(), b)
    return r

cible_repos = repos_relatifs(arm)
for f in fichiers:
    if f == base:
        continue
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MIXAMO, f))
    nouveaux = [o for o in bpy.data.objects if o not in avant]
    autre = next(o for o in nouveaux if o.type == 'ARMATURE')
    source = autre.animation_data.action
    source_repos = repos_relatifs(autre)
    debut, fin = (int(round(x)) for x in source.frame_range)
    action = bpy.data.actions.new(f[:-4])
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    arm.animation_data.action = action
    for image in range(debut, fin + 1):
        bpy.context.scene.frame_set(image)
        for pb_src in autre.pose.bones:
            nom = pb_src.name.replace(PREFIXE, "")
            if nom not in cible_repos or nom not in arm.pose.bones:
                continue
            q_src = pb_src.rotation_quaternion if pb_src.rotation_mode == 'QUATERNION' else pb_src.rotation_euler.to_quaternion()
            rs, rc = source_repos[nom][0], cible_repos[nom][0]
            pb = arm.pose.bones[nom]
            pb.rotation_quaternion = rc.inverted() @ rs @ q_src
            pb.keyframe_insert("rotation_quaternion", frame=image)
            if pb_src.parent is None:
                # bassin : même déplacement dans le repère du parent, réexprimé dans le repos du gobelin
                pb.location = rc.inverted() @ (rs @ pb_src.location)
                pb.keyframe_insert("location", frame=image)
    actions[action.name] = action
    arm.animation_data.action = None
    for o in nouveaux:
        bpy.data.objects.remove(o)
    bpy.data.actions.remove(source)

for nom, action in actions.items():
    action.use_fake_user = True
    if ECART_BRAS:
        ecarter_bras(arm, action)
    if nom not in ("Relever", "Mort", "Touche", "Attaque"):
        sur_place(action)

# texture : celle du nettoyage si le maillage n'en a pas
texture = os.path.join(EXPORT, NOM + "_couleur.png")
mat = corps.active_material
a_texture = mat and mat.use_nodes and any(n.type == 'TEX_IMAGE' and n.image for n in mat.node_tree.nodes)
if not a_texture and os.path.exists(texture):
    mat = bpy.data.materials.new(NOM)
    mat.use_nodes = True
    noeud = mat.node_tree.nodes.new("ShaderNodeTexImage")
    noeud.image = bpy.data.images.load(texture)
    mat.node_tree.links.new(noeud.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    corps.data.materials.clear()
    corps.data.materials.append(mat)
print("TEXTURE", "mixamo" if a_texture else "remise")

# modèle au repos pour Studio
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
corps.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, NOM + "_mixamo_rig.fbx"), use_selection=True,
                         apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y', add_leaf_bones=False,
                         bake_anim=False, path_mode='COPY', embed_textures=True, mesh_smooth_type='FACE')
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXPORT, NOM + "_anime.blend"))
hanches = [c for c in actions.get("Marche", premiere).fcurves if c.data_path == 'pose.bones["Hips"].location']
print("ARMATURE rot", tuple(round(x, 3) for x in arm.rotation_euler), "echelle", tuple(round(x, 3) for x in arm.scale))
print("OK", NOM, "os", len(arm.data.bones), "animations", ", ".join(f"{n} ({int(a.frame_range[1] - a.frame_range[0])} i)" for n, a in actions.items()))
