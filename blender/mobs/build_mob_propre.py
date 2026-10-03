# Mobs (gobelins, ours) : même nettoyage que les invocations. Le modèle de TRELLIS est fait de morceaux de surface ouverts dont
# une partie est retournée (Roblox, qui n'affiche qu'un côté des faces, y fait des trous). On reconstruit
# un volume fermé, toutes normales vers l'extérieur : épaisseur sur les surfaces, remaillage en voxels,
# réduction à ~15 000 triangles, nouveau dépliage UV, puis on retransfère les couleurs du modèle d'origine
# sur une texture 1024 (cuisson Cycles « depuis la sélection »). Exporte export/Mage_P1_propre.glb.
# Le voxel du remaillage suit la taille (même finesse relative que l'archère : 0,022 pour 5,3 studs) ;
# après le remaillage (volume d'un seul tenant), les petits morceaux détachés (flotteurs de TRELLIS, fil au bout
# de la queue de l'ours) sont supprimés : on ne garde que les pièces d'au moins 2 % des faces.
# Usage : blender -b --factory-startup --python mobs/build_mob_propre.py -- <dossier du mob> <Nom> <hauteur> <triangles>
#   ex. : -- gobelin_guerrier Gobelin_Guerrier 4.2 12000
import bpy, math, os, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM, HAUTEUR, TRIANGLES = args[0], args[1], float(args[2]), int(args[3])
HERE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), DOSSIER)
SOURCE = os.path.join(HERE, "source", DOSSIER + "_meshy.glb")
EXPORT = os.path.join(HERE, "export")
APERCUS = os.path.join(HERE, "apercus")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(APERCUS, exist_ok=True)

TEXTURE = 1024
VOXEL = 0.022 * HAUTEUR / 5.3
ROTATION_Z = 180.0       # TRELLIS livre le modèle face à -Y : demi-tour pour qu'il arrive de face dans Roblox

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=SOURCE)
src = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
bpy.context.view_layer.objects.active = src
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
for o in list(bpy.data.objects):
    if o.type == 'EMPTY':
        bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# même échelle et même placement que la version simple (pieds au sol, centrée, face vers -Y)
pts = [Vector(v.co) for v in src.data.vertices]
k = HAUTEUR / (max(p.z for p in pts) - min(p.z for p in pts))
# demi-tour : vue de dos dans Avatar Setup avec l'orientation d'origine (02/10/2026)
src.data.transform(Matrix.Rotation(math.radians(ROTATION_Z), 4, 'Z') @ Matrix.Scale(k, 4))
pts = [Vector(v.co) for v in src.data.vertices]
src.data.transform(Matrix.Translation((-(min(p.x for p in pts) + max(p.x for p in pts)) / 2,
                                       -(min(p.y for p in pts) + max(p.y for p in pts)) / 2, -min(p.z for p in pts))))

# ---------------------------------------------------------------- volume fermé
cible = src.copy()
cible.data = src.data.copy()
cible.name = cible.data.name = NOM
scene.collection.objects.link(cible)
cible.data.materials.clear()
bpy.ops.object.select_all(action='DESELECT')
cible.select_set(True)
bpy.context.view_layer.objects.active = cible
ep = cible.modifiers.new("epaisseur", 'SOLIDIFY')
ep.thickness, ep.offset, ep.use_even_offset, ep.use_rim = 0.03, 0.0, False, True
bpy.ops.object.modifier_apply(modifier=ep.name)
rm = cible.modifiers.new("remaillage", 'REMESH')
rm.mode, rm.voxel_size = 'VOXEL', VOXEL
bpy.ops.object.modifier_apply(modifier=rm.name)
print("APRES REMAILLAGE", len(cible.data.polygons))
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')
pieces = [o for o in bpy.context.selected_objects if o.type == 'MESH']
total = sum(len(o.data.polygons) for o in pieces)
gardees = [o for o in pieces if len(o.data.polygons) >= 0.02 * total]
for o in pieces:
    if o not in gardees:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT')
for o in gardees:
    o.select_set(True)
gardees.sort(key=lambda o: -len(o.data.polygons))
bpy.context.view_layer.objects.active = gardees[0]
if len(gardees) > 1:
    bpy.ops.object.join()
cible = bpy.context.view_layer.objects.active
cible.name = cible.data.name = NOM
print("PIECES", len(pieces), "GARDEES", len(gardees))
dec = cible.modifiers.new("reduction", 'DECIMATE')
dec.ratio = (TRIANGLES / 2) / len(cible.data.polygons)   # le remaillage donne des quads : 2 triangles chacun
bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
for p in cible.data.polygons:
    p.use_smooth = True
cible.data.calc_loop_triangles()
print("TRIANGLES", len(cible.data.loop_triangles))

# ---------------------------------------------------------------- retransfert des couleurs
img = bpy.data.images.new(NOM + "_Couleur", TEXTURE, TEXTURE)
mat = bpy.data.materials.new(NOM)
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.8
tex = nodes.new("ShaderNodeTexImage")
tex.image = img
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nodes.active = tex
cible.data.materials.append(mat)

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = 0.2
scene.render.bake.max_ray_distance = 0.0   # sans limite : la surface la plus proche
scene.render.bake.margin = 6
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
cible.select_set(True)
bpy.context.view_layer.objects.active = cible
bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=True)
img.filepath_raw = os.path.join(EXPORT, NOM + "_couleur.png")
img.file_format = 'PNG'
img.save()
img.pack()
print("CUISSON OK")

bpy.data.objects.remove(src)
bpy.ops.object.select_all(action='DESELECT')
cible.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(EXPORT, NOM + "_propre.glb"), export_format='GLB',
                          use_selection=True, export_image_format='JPEG')

# ---------------------------------------------------------------- aperçus, une seule face affichée comme dans Roblox
mat.use_backface_culling = True
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x, scene.render.resolution_y = 800, 1000
scene.view_settings.view_transform = 'Standard'
world = bpy.data.worlds.new("Ciel")
world.use_nodes = True
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.47, 0.5, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sun = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", 'SUN'))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(20))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
def vue(loc, nom, cible_z=HAUTEUR * 0.5, lens=50):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector((0, 0, cible_z)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    scene.render.filepath = os.path.join(APERCUS, nom)
    bpy.ops.render.render(write_still=True)
D = max(HAUTEUR, max(cible.dimensions)) * 2.4
vue((0, D, HAUTEUR * 0.55), "propre_face.png")
vue((D * 0.6, D * 0.75, HAUTEUR * 0.7), "propre_34.png")
vue((D, 0, HAUTEUR * 0.55), "propre_profil.png")
print("OK")