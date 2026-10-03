# Matériaux en 3D (03/10/2026) : cinq modèles low-poly minimaux, qui serviront aussi de gisements à récolter dans le
# monde, et leurs icônes d'inventaire rendues avec l'éclairage de l'icône du quartz (icone_quartz.py).
#   Bluestone   : tas de trois pierres taillées gris-bleu
#   Timber      : pile de trois bûches (écorce, cernes clairs aux bouts)
#   NightBasalt : orgues de basalte, prismes hexagonaux bleu nuit
#   SilverOre   : roche grise avec pépites d'argent
#   GoldOre     : roche brune avec pépites d'or
# Facettes nettes (ombrage plat + fin biseau qui accroche la lumière). Le modèle est posé au sol (z = 0), centré.
# Sorties : materiaux_3d/<Nom>.fbx, materiaux_3d/materiaux_3d.blend, objet_<nom>_3d.png (512 px, recadrées),
# apercus/materiaux_3d_planche.png. Usage : blender -b --factory-startup --python materiaux_3d.py
import bpy, bmesh, math, os, random
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, "materiaux_3d")
os.makedirs(SORTIE, exist_ok=True)
os.makedirs(os.path.join(ICI, "apercus"), exist_ok=True)
scene = bpy.context.scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

def lin(c):
    return tuple((v / 255) ** 2.2 for v in c) + (1,)

# ---------------------------------------------------------------- matières
def matiere(nom, couleur, rugosite=0.6, metal=0.0, fuite=0.55, emission=0.0):
    """couleur sRGB ; fuite : assombrit les faces qui fuient le regard (relief des facettes)"""
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    b = n["Principled BSDF"]
    b.inputs["Roughness"].default_value = rugosite
    b.inputs["Metallic"].default_value = metal
    poids = n.new("ShaderNodeLayerWeight"); poids.inputs["Blend"].default_value = 0.55
    melange = n.new("ShaderNodeMix"); melange.data_type = 'RGBA'
    melange.inputs[6].default_value = lin(couleur)
    melange.inputs[7].default_value = tuple(v * fuite for v in lin(couleur)[:3]) + (1,)
    l.new(poids.outputs["Facing"], melange.inputs[0])
    l.new(melange.outputs[2], b.inputs["Base Color"])
    if emission > 0:
        l.new(melange.outputs[2], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emission
    return m

M = {
    "Bluestone": matiere("Bluestone", (92, 112, 142), 0.7, fuite=0.5, emission=0.02),
    "Mousse": matiere("Mousse", (96, 136, 62), 0.9, fuite=0.6),
    "Ecorce": matiere("Ecorce", (110, 74, 44), 0.85, fuite=0.55),
    "Bois": matiere("Bois", (214, 174, 116), 0.7, fuite=0.7),
    "Cerne": matiere("Cerne", (170, 122, 70), 0.75, fuite=0.7),
    "Basalte": matiere("Basalte", (52, 62, 88), 0.4, fuite=0.5, emission=0.04),
    "Reflet": matiere("Reflet", (110, 160, 230), 0.3, emission=0.6),
    "RocheGrise": matiere("RocheGrise", (78, 82, 96), 0.85, fuite=0.55),
    "Argent": matiere("Argent", (226, 232, 242), 0.22, metal=0.85, fuite=0.6, emission=0.05),
    "RocheBrune": matiere("RocheBrune", (96, 76, 62), 0.85, fuite=0.55),
    "Or": matiere("Or", (250, 196, 72), 0.25, metal=0.85, fuite=0.6, emission=0.08),
}

# ---------------------------------------------------------------- géométrie
def objet(nom, bm, matieres, biseau=0.04):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(o)
    for m in matieres:
        o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = False
    if biseau > 0:
        b = o.modifiers.new("Biseau", 'BEVEL')
        b.width, b.segments, b.limit_method = biseau, 1, 'ANGLE'
    return o

def caillou(nom, taille, position, rotation, matiere_, subdiv=1, irregulier=0.18, graine=1):
    random.seed(graine)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        v.co += v.co.normalized() * random.uniform(-irregulier, irregulier)
        v.co = Vector((v.co.x * taille[0], v.co.y * taille[1], v.co.z * taille[2]))
    o = objet(nom, bm, [matiere_], biseau=min(taille) * 0.05)
    o.location, o.rotation_euler = position, rotation
    return o

def pierre_taillee(nom, taille, position, rotation, graine):
    random.seed(graine)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * taille[0], v.co.y * taille[1], v.co.z * taille[2]))
        v.co += Vector((random.uniform(-0.04, 0.04), random.uniform(-0.04, 0.04), random.uniform(-0.04, 0.04)))
    o = objet(nom, bm, [M["Bluestone"]], biseau=0.07)
    o.location, o.rotation_euler = position, rotation
    return o

def prisme_hex(nom, rayon, hauteur, position, inclinaison, graine):
    random.seed(graine)
    bm = bmesh.new()
    bas, haut = [], []
    for i in range(6):
        a = math.pi / 3 * i
        x, y = rayon * math.cos(a), rayon * math.sin(a)
        bas.append(bm.verts.new((x, y, 0)))
        # sommet un peu biseauté au hasard : les orgues ne sont jamais coupées droit
        haut.append(bm.verts.new((x, y, hauteur + 0.12 * (x * 0.8 + y * random.uniform(-0.6, 0.6)))))
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((bas[i], bas[j], haut[j], haut[i]))
    bm.faces.new(haut)
    bm.faces.new(list(reversed(bas)))
    o = objet(nom, bm, [M["Basalte"]], biseau=0.035)
    o.location = position
    o.rotation_euler = (math.radians(inclinaison[0]), math.radians(inclinaison[1]), math.radians(random.uniform(0, 60)))
    return o

def buche(nom, rayon, longueur, position, rotation_z):
    bm = bmesh.new()
    cotes = 9
    gauche, droite = [], []
    for i in range(cotes):
        a = 2 * math.pi * i / cotes
        y, z = rayon * math.cos(a), rayon * math.sin(a)
        gauche.append(bm.verts.new((-longueur / 2, y, z)))
        droite.append(bm.verts.new((longueur / 2, y, z)))
    for i in range(cotes):
        j = (i + 1) % cotes
        f = bm.faces.new((gauche[i], gauche[j], droite[j], droite[i]))
        f.material_index = 0
    for bout in (list(reversed(gauche)), droite):
        f = bm.faces.new(bout)
        f.material_index = 1
        # cerne : un anneau intérieur sur chaque bout
        r = bmesh.ops.inset_individual(bm, faces=[f], thickness=rayon * 0.28)
        f.material_index = 2
    o = objet(nom, bm, [M["Ecorce"], M["Bois"], M["Cerne"]], biseau=0.03)
    o.location = position
    o.rotation_euler = (0, 0, math.radians(rotation_z))
    return o

def pepites(prefixe, roche, matiere_, nb, graine, taille=(0.16, 0.26)):
    """pépites posées sur la surface supérieure de la roche"""
    random.seed(graine)
    bpy.context.view_layer.update()
    me = roche.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    faces = [p for p in me.polygons if p.normal.z > 0.15]
    resultat = []
    for i in range(nb):
        p = random.choice(faces)
        centre = roche.matrix_world @ p.center
        normale = (roche.matrix_world.to_3x3() @ p.normal).normalized()
        t = random.uniform(*taille)
        o = caillou(f"{prefixe}_{i}", (t, t * 0.8, t * 0.7), centre + normale * t * 0.25,
                    normale.to_track_quat('Z', 'Y').to_euler(), matiere_, subdiv=1, irregulier=0.25, graine=graine * 10 + i)
        resultat.append(o)
    return resultat

# ---------------------------------------------------------------- les cinq modèles
MODELES = {}

# Bluestone : trois pierres taillées, un peu de mousse
p = [pierre_taillee("Bluestone_A", (1.5, 1.0, 0.75), (0, 0, 0.375), (0, 0, math.radians(10)), 1),
     pierre_taillee("Bluestone_B", (1.1, 0.8, 0.6), (0.15, 0.1, 1.05), (0, 0, math.radians(-14)), 2),
     pierre_taillee("Bluestone_C", (0.8, 0.7, 0.55), (-0.95, -0.55, 0.275), (0, 0, math.radians(32)), 3)]
p.append(caillou("Bluestone_Mousse", (0.35, 0.28, 0.08), (-0.45, 0.2, 0.76), (0, 0, 0), M["Mousse"], subdiv=1, graine=4))
MODELES["Bluestone"] = p

# Timber : pile de trois bûches
MODELES["Timber"] = [buche("Timber_A", 0.36, 2.2, (0, -0.37, 0.36), 6),
                     buche("Timber_B", 0.34, 2.0, (0.05, 0.36, 0.34), -4),
                     buche("Timber_C", 0.33, 1.9, (0.02, 0.0, 0.98), 2)]

# Night Basalt : orgues de basalte avec un reflet bleu sur une arête
MODELES["NightBasalt"] = [prisme_hex("Basalte_A", 0.42, 2.0, (0, 0, 0), (0, 0), 11),
                          prisme_hex("Basalte_B", 0.38, 1.45, (0.72, 0.1, 0), (0, 6), 12),
                          prisme_hex("Basalte_C", 0.36, 1.1, (-0.66, 0.22, 0), (0, -7), 13),
                          prisme_hex("Basalte_D", 0.33, 0.75, (0.15, -0.68, 0), (-8, 0), 14)]

# Silver Ore et Gold Ore : roche cabossée et pépites
roche_argent = caillou("Argent_Roche", (1.35, 1.05, 0.85), (0, 0, 0.62), (0, 0, 0), M["RocheGrise"], subdiv=2, graine=21)
MODELES["SilverOre"] = [roche_argent] + pepites("Argent_Pepite", roche_argent, M["Argent"], 9, 22, (0.26, 0.42))
roche_or = caillou("Or_Roche", (1.3, 1.1, 0.8), (0, 0, 0.58), (0, 0, math.radians(30)), M["RocheBrune"], subdiv=2, graine=31)
MODELES["GoldOre"] = [roche_or] + pepites("Or_Pepite", roche_or, M["Or"], 9, 32, (0.26, 0.42))

# ---------------------------------------------------------------- export FBX (un fichier par gisement)
for nom, objets in MODELES.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objets:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objets[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(SORTIE, nom + ".fbx"), use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_ALL', bake_space_transform=True,
                             use_mesh_modifiers=True, mesh_smooth_type='FACE')

# ---------------------------------------------------------------- lumière, caméra, rendus (comme le quartz)
monde = bpy.data.worlds.new("Monde"); monde.use_nodes = True; scene.world = monde
monde.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.66, 1)
monde.node_tree.nodes["Background"].inputs[1].default_value = 0.35
def lampe(nom, energie, couleur, position, taille):
    d = bpy.data.lights.new(nom, 'AREA'); d.energy, d.color, d.size = energie, couleur, taille
    o = bpy.data.objects.new(nom, d); scene.collection.objects.link(o)
    o.location = position
    o.rotation_euler = (Vector((0, 0, 0.6)) - Vector(position)).to_track_quat('-Z', 'Y').to_euler()
lampe("Principale", 380, (1.0, 0.96, 0.9), (-3.5, -4.0, 5.0), 3)
lampe("ContreJour", 520, (0.7, 0.8, 1.0), (3.0, 4.0, 2.5), 2)
lampe("Debouchage", 70, (1.0, 0.9, 0.95), (4.0, -3.5, 0.5), 4)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera")); scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = 'ORTHO'
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.eevee.taa_render_samples = 64
DIRECTION = Vector((2.6, -5.6, 3.0)).normalized()

rendus = []
for nom, objets in MODELES.items():
    for autre, os_ in MODELES.items():
        for o in os_:
            o.hide_render = autre != nom
    bpy.context.view_layer.update()
    coins = [o.matrix_world @ Vector(c) for o in objets for c in o.bound_box]
    mn = Vector((min(c.x for c in coins), min(c.y for c in coins), min(c.z for c in coins)))
    mx = Vector((max(c.x for c in coins), max(c.y for c in coins), max(c.z for c in coins)))
    centre, dim = (mn + mx) / 2, max(mx - mn)
    cam.location = centre + DIRECTION * dim * 4
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = dim * 1.35
    chemin = os.path.join(ICI, "apercus", f"{nom.lower()}_brut.png")
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    rendus.append((nom, chemin))
    print("RENDU", nom)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SORTIE, "materiaux_3d.blend"))
print("OK")
