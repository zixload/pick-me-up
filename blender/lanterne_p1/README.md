# P1 — Lanterne sur pied, V01

Premier asset du kit de détails du lobby, réalisé seul pour validation visuelle avant de passer au suivant.

Statut : validé par l'utilisateur (« Validé; passe à la suite »).

## Fichiers

- `P1_Lanterne_Pied.blend` : modèle Blender avec sources éditables, asset assemblé, caméras et rempart P1 de référence.
- `exports/P1_Lanterne_Pied.fbx` et `.glb` : la lanterne seule, sans rempart, sol, caméra ni éclairage de présentation.
- `textures/` : atlas Color, Roughness et Metalness 512 × 512, également intégrés au Blender et aux exports.
- `previews/01_lanterne_entiere.png` : vue de trois quarts.
- `previews/02_detail_cage.png` : détail des vitres, du cristal et de la cage.
- `previews/03_avec_rempart_P1.png` : comparaison avec la vraie muraille P1, dont la partie basse est cadrée.
- `previews/04_lanterne_face.png` : vue de face.
- `manifest.json` : dimensions, pivots et triangles.
- `verification.json` : contrôles de réimport FBX et de structure GLB.

## Modèle

Hauteur : **9,59 unités**, largeur du socle : **1,78**. Convention de travail : 1 unité destinée à correspondre à 1 stud Roblox. Pivot commun au centre du socle, au sol ; Z vertical dans Blender.

Un seul asset, composé de quatre meshes qui partagent ce pivot :

| Mesh | Rôle | Triangles |
|---|---|---:|
| P1_Lanterne_Pied_Structure | Socle, montant, cage, toit et argent | 4704 |
| P1_Lanterne_Pied_Vitres | Quatre vitres indépendantes | 8 |
| P1_Lanterne_Pied_Coeur | Cristal lumineux | 76 |
| P1_Lanterne_Pied_Mousse | Petites plaques optionnelles au pied | 12 |

Total : **4800 triangles**. Pierre gris-bleu et argent issus de la palette du rempart P1 existant ; fer sombre et cœur ambre ajoutés pour le mobilier.

## Blender

L'asset assemblé est dans `01_ASSET_EXPORT`, visible à l'ouverture. Les pièces d'origine sont dans `00_SOURCE_EDITABLE`, masquée. Le rempart réel de référence est dans `02_CONTEXTE_REMPART_P1`, masquée à l'ouverture ; la rendre visible pour comparer les proportions. Le sol, les lumières et la caméra se trouvent dans `03_PRESENTATION` et ne font pas partie des exports.

Les meshes d'export sont triangulés et ont chacun un canal UV. Les sources restent séparées pour permettre un ajustement du socle, de la hauteur, du toit, des montants ou de la cage. La mousse peut être cachée ou retirée indépendamment.

## Préparation Roblox

Importer l'un des exports avec le 3D Importer et vérifier la hauteur de 9,59 studs. Les réglages d'import Studio ne sont pas encore contrôlés avec cet asset. Garder les meshes ancrés et les assembler dans un Model.

Le matériau principal utilise un atlas commun. Si nécessaire, attribuer les images Color, Roughness et Metalness à une SurfaceAppearance sur la structure et la mousse.

Les shaders de présentation ne constituent pas un éclairage Roblox déjà configuré :

- Vitres : mesh séparé pour régler la transparence (point de départ proposé : 0,75 à 0,85) et la teinte ambre. Vérifier les faces ; utiliser DoubleSided si nécessaire.
- Cœur : teinte ivoire chaude et matériau Neon à tester.
- Lumière : créer un Attachment vers la hauteur de la cage (environ 7,55 studs) et y placer un PointLight ambre. Régler sa portée et son intensité dans le lobby. La lumière Blender présente dans le fichier sert aux rendus.
- Collisions : garder une collision simple sur les volumes principaux et aucune sur les vitres, le cristal et la mousse. Tester le passage du joueur près du socle.

## Vérification visuelle demandée

Examiner la silhouette, la hauteur du pied, la taille de la cage, les accents argentés, le socle et la chaleur du cœur. La prochaine pièce ne sera commencée qu'après le retour de l'utilisateur sur celle-ci.
