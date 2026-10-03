# Exporte les animations d'un mob (export/<Nom>_anime.blend) vers un module Luau lu par Studio, sans passer par
# l'import d'animation FBX de Roblox (qui ne compense pas l'orientation des os et tord le modèle).
# Conversion vérifiée le 03/10/2026 sur le gobelin guerrier importé en FBX : chaque os Roblox = l'os Blender
# tourné d'un demi-tour autour de son axe Y (erreur 1e-4 sur tous les os). Une rotation locale Blender q
# (w, x, y, z) devient (w, -x, y, -z) ; un déplacement local (x, y, z) devient (-x, y, -z) × échelle d'import.
# Chaque image est relevée (30 i/s, interpolation linéaire côté Roblox).
# Sortie : src/shared/AnimationsMobs/<Nom>.txt (JSON ; Rojo en fait une StringValue, lisible sans require)
# Usage : blender -b --factory-startup --python mobs/export_anims_roblox.py -- <dossier du mob> <Nom> <échelle d'import>
import bpy, os, sys

args = sys.argv[sys.argv.index("--") + 1:]
DOSSIER, NOM, ECHELLE = args[0], args[1], float(args[2])
RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICI = os.path.join(RACINE, "blender", DOSSIER)
SORTIE = os.path.join(RACINE, "src", "shared", "AnimationsMobs")
os.makedirs(SORTIE, exist_ok=True)
BOUCLES = {"Repos", "Marche", "MarcheArriere", "PasDroite", "PasGauche", "Course"}
PRIORITES = {"Attaque": "Action", "Tir": "Action", "Relever": "Action", "Touche": "Action2", "Mort": "Action3"}

bpy.ops.wm.open_mainfile(filepath=os.path.join(ICI, "export", NOM + "_anime.blend"))
scene = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
os_ = [b.name for b in arm.data.bones]
parents = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
RACINE_OS = next(b for b in os_ if parents[b] is None)   # HumanoidRootPart (nos rigs) ou Hips (Mixamo)

def n(v):
    return round(v, 4) + 0.0   # + 0.0 : pas de « -0.0 »

# Format JSON compact (lu par HttpService:JSONDecode, sans require) : os dans un ordre fixe, chaque image =
# [temps, racine x, y, z, puis w, x, y, z de chaque os dans l'ordre de « os »].
donnees = {"piece": NOM, "racine": RACINE_OS, "os": os_, "parents": [parents[b] or "" for b in os_], "animations": {}}
actions = [a for a in bpy.data.actions if a.use_fake_user]
for action in actions:
    arm.animation_data.action = action
    debut, fin = (int(round(x)) for x in action.frame_range)
    images = []
    for f in range(debut, fin + 1):
        scene.frame_set(f)
        l = arm.pose.bones[RACINE_OS].location
        image = [n((f - debut) / scene.render.fps), n(-l.x * ECHELLE), n(l.y * ECHELLE), n(-l.z * ECHELLE)]
        for nom in os_:
            pb = arm.pose.bones[nom]
            q = pb.rotation_quaternion if pb.rotation_mode == 'QUATERNION' else pb.rotation_euler.to_quaternion()
            image += [n(q.w), n(-q.x), n(q.y), n(-q.z)]
        images.append(image)
    donnees["animations"][action.name] = {"boucle": action.name in BOUCLES,
                                          "priorite": PRIORITES.get(action.name, "Core"), "images": images}
import json
chemin = os.path.join(SORTIE, NOM + ".txt")   # Rojo : un .txt devient une StringValue
with open(chemin, "w", encoding="utf-8") as fichier:
    json.dump(donnees, fichier, separators=(",", ":"))
ancien = os.path.join(SORTIE, NOM + ".luau")
if os.path.exists(ancien):
    os.remove(ancien)
print("OK", chemin, ", ".join(a.name for a in actions))
