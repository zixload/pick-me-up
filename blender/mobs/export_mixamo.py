# Prépare un mob nettoyé (export/<Nom>_propre.glb) pour l'auto-rig de Mixamo : un seul maillage sans squelette,
# texture intégrée au FBX, pose A d'origine, face tournée vers la caméra de Mixamo. Nos modèles regardent vers +Y
# dans Blender (pour Roblox) ; l'export FBX par défaut (avant -Z, haut Y) attend un personnage tourné vers -Y :
# on le retourne d'un demi-tour avant l'export.
# Sortie : export/<Nom>_mixamo.fbx. Usage : blender -b --factory-startup --python mobs/export_mixamo.py -- <dossier> <Nom>
import bpy, math, os, sys
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM = args[0], args[1]
EXPORT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), DOSSIER, "export")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(EXPORT, NOM + "_propre.glb"))
corps = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.ops.object.select_all(action='DESELECT')
corps.select_set(True)
bpy.context.view_layer.objects.active = corps
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
for o in list(bpy.data.objects):
    if o.type == 'EMPTY':
        bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
corps.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
corps.name = corps.data.name = NOM
# la texture doit être un fichier pour être intégrée au FBX
for img in bpy.data.images:
    if img.packed_file or not img.filepath:
        img.filepath_raw = os.path.join(EXPORT, NOM + "_couleur.png")
        img.file_format = 'PNG'
        img.save()
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, NOM + "_mixamo.fbx"), use_selection=True,
                         axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_UNITS',
                         path_mode='COPY', embed_textures=True, mesh_smooth_type='FACE')
print("OK", NOM)
