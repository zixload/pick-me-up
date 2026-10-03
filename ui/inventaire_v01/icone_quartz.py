# Icône « Quartz » de l'inventaire, modélisée en 3D puis rendue (03/10/2026).
# Grappe de cristaux hexagonaux à pointe taillée, blanc laiteux légèrement chaud (style P3 : quartz crème),
# sur un petit socle de roche. Facettes nettes (ombrage plat + fin biseau qui accroche la lumière),
# éclairage d'icône : lumière principale en haut à gauche, contre-jour froid, débouchage doux. Fond transparent.
# Sorties : objet_quartz.png (512 px, recadré) et apercus/quartz_sur_carte.png (sur une carte violette).
# Usage : blender -b --factory-startup --python icone_quartz.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

ICI = os.path.dirname(os.path.abspath(__file__))
random.seed(7)
scene = bpy.context.scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

# ---------------------------------------------------------------- matières
def matiere(nom):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    return m, m.node_tree.nodes, m.node_tree.links

cristal, n, l = matiere("Cristal")
bsdf = n["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.16
bsdf.inputs["Coat Weight"].default_value = 0.3
bsdf.inputs["Coat Roughness"].default_value = 0.05
bsdf.inputs["Subsurface Weight"].default_value = 0.25
bsdf.inputs["Subsurface Radius"].default_value = (0.6, 0.5, 0.5)
# facettes : plus sombres et légèrement lavande quand elles fuient le regard, plus claires vers les pointes
poids = n.new("ShaderNodeLayerWeight"); poids.inputs["Blend"].default_value = 0.6
melange = n.new("ShaderNodeMix"); melange.data_type = 'RGBA'
melange.inputs[6].default_value = (0.92, 0.87, 0.84, 1)    # face au regard : crème laiteux
melange.inputs[7].default_value = (0.46, 0.42, 0.57, 1)    # en fuite : gris lavande
l.new(poids.outputs["Facing"], melange.inputs[0])
coords = n.new("ShaderNodeTexCoord")
sep = n.new("ShaderNodeSeparateXYZ")
l.new(coords.outputs["Object"], sep.inputs[0])
rampe = n.new("ShaderNodeMapRange")
rampe.inputs["From Min"].default_value, rampe.inputs["From Max"].default_value = 0.0, 1.0
l.new(sep.outputs["Z"], rampe.inputs["Value"])
pointe = n.new("ShaderNodeMix"); pointe.data_type = 'RGBA'
pointe.inputs[7].default_value = (1.0, 0.98, 0.95, 1)      # pointes presque blanches
l.new(rampe.outputs["Result"], pointe.inputs[0])
l.new(melange.outputs[2], pointe.inputs[6])
l.new(pointe.outputs[2], bsdf.inputs["Base Color"])
l.new(pointe.outputs[2], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = 0.02       # le cristal ne tombe jamais dans le noir

roche, n, l = matiere("Roche")
b = n["Principled BSDF"]
b.inputs["Roughness"].default_value = 0.85
bruit = n.new("ShaderNodeTexNoise"); bruit.inputs["Scale"].default_value = 9
cr = n.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].color = (0.17, 0.15, 0.16, 1)
cr.color_ramp.elements[1].color = (0.36, 0.32, 0.31, 1)
l.new(bruit.outputs["Fac"], cr.inputs[0])
l.new(cr.outputs[0], b.inputs["Base Color"])

# ---------------------------------------------------------------- géométrie
def cristal_obj(nom, rayon, hauteur, pointe_h, position, inclinaison, rotation_z):
    bm = bmesh.new()
    cotes = 6
    bas, haut = [], []
    for i in range(cotes):
        a = 2 * math.pi * i / cotes
        # facettes inégales : un cristal naturel n'est jamais un hexagone parfait
        r = rayon * random.uniform(0.86, 1.1)
        bas.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0)))
        haut.append(bm.verts.new((r * 0.97 * math.cos(a), r * 0.97 * math.sin(a), hauteur)))
    sommet = bm.verts.new((rayon * random.uniform(-0.15, 0.15), rayon * random.uniform(-0.15, 0.15), hauteur + pointe_h))
    for i in range(cotes):
        j = (i + 1) % cotes
        bm.faces.new((bas[i], bas[j], haut[j], haut[i]))
        bm.faces.new((haut[i], haut[j], sommet))
    bm.faces.new(list(reversed(bas)))
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(o)
    o.data.materials.append(cristal)
    o.location = position
    o.rotation_euler = (math.radians(inclinaison[0]), math.radians(inclinaison[1]), math.radians(rotation_z))
    biseau = o.modifiers.new("Biseau", 'BEVEL')
    biseau.width, biseau.segments, biseau.limit_method = rayon * 0.05, 1, 'ANGLE'
    for p in o.data.polygons:
        p.use_smooth = False
    return o

# (rayon, hauteur du fût, hauteur de la pointe, position, inclinaison x/y, rotation z)
GRAPPE = [
    (0.36, 1.55, 0.55, (0.0, 0.05, 0.1), (-4, 3), 10),       # le grand, au centre
    (0.26, 1.05, 0.42, (-0.42, 0.1, 0.05), (6, -24), 40),
    (0.24, 0.95, 0.38, (0.44, -0.05, 0.05), (-2, 26), 75),
    (0.18, 0.6, 0.3, (-0.2, -0.38, 0.0), (-28, -10), 20),
    (0.17, 0.55, 0.28, (0.3, -0.36, 0.0), (-30, 16), 55),
    (0.15, 0.5, 0.25, (-0.68, -0.1, 0.0), (10, -44), 5),
    (0.14, 0.42, 0.22, (0.72, 0.1, 0.0), (6, 46), 30),
    (0.2, 0.75, 0.32, (0.12, 0.42, 0.05), (24, 6), 65),
]
for i, (r, h, ph, pos, inc, rz) in enumerate(GRAPPE):
    cristal_obj(f"Cristal_{i}", r, h, ph, pos, inc, rz)

# socle de roche : icosphère écrasée et cabossée
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, 0, -0.18))
socle = bpy.context.active_object
socle.name = "Socle"
socle.scale = (1.05, 0.8, 0.32)
for v in socle.data.vertices:
    v.co += v.normal * random.uniform(-0.12, 0.1)
socle.data.materials.append(roche)
for p in socle.data.polygons:
    p.use_smooth = False

# ---------------------------------------------------------------- lumière et caméra
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
cam.data.ortho_scale = 3.4
cam.location = (2.6, -5.6, 3.0)
cam.rotation_euler = (Vector((0, 0, 0.75)) - cam.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.eevee.taa_render_samples = 64
brut = os.path.join(ICI, "apercus", "quartz_brut.png")
os.makedirs(os.path.dirname(brut), exist_ok=True)
scene.render.filepath = brut
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, "icone_quartz.blend"))
print("RENDU", brut)
