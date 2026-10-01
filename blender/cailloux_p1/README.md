# P1 — Cailloux A, V01

Troisième asset du lobby : un groupe décoratif de six petites pierres, réalisé seul pour validation. Palette gris-bleu reprise du rempart P1, avec des variations discrètes de teinte.

## Fichiers

- `P1_Cailloux_A.blend` : six pierres éditables, groupe assemblé, présentation et rempart de référence.
- `exports/P1_Cailloux_A.fbx` et `.glb` : un seul mesh, uniquement les six pierres.
- `textures/` : atlas Color, Roughness et Metalness 512 × 512, également intégré aux livrables.
- `previews/01_cailloux_34.png` : vue de trois quarts.
- `previews/02_cailloux_dessus.png` : disposition vue du dessus.
- `previews/03_au_pied_du_rempart.png` : contrôle des proportions et des matériaux avec le vrai rempart P1.
- `manifest.json` et `verification.json` : mesures et contrôles des exports.

## Design et dimensions

Une pierre plate dominante, une pierre trapue, une pierre allongée et trois fragments. Chaque pierre a un contour différent, un dessous plat et de petites arêtes adoucies. Les espaces entre les pierres sont conservés. Pas de végétation attachée ; les futures plaques de mousse pourront être placées indépendamment.

Encombrement : environ **2,24 × 1,36 × 0,48 unités**. Convention de travail : une unité destinée à correspondre à un stud Roblox. **1812 triangles** au total. Pivot commun à Z=0 au centre de placement du groupe ; Z est l'axe vertical Blender.

## Collections Blender

- `00_SOURCE_EDITABLE` : les six pierres séparées, masquées au départ.
- `01_ASSET_EXPORT` : groupe assemblé, visible à l'ouverture.
- `02_CONTEXTE_REMPART_P1` : rempart existant, masqué au départ et exclu des exports.
- `03_PRESENTATION` : caméra, sol et éclairages, exclus des exports.

Le script dépend du rempart dans le dossier voisin. Les fichiers livrés sont autonomes : textures utiles intégrées au Blender et aux exports.

## Roblox après import

Importer le FBX ou le GLB avec le 3D Importer, contrôler les dimensions et poser le pivot sur le sol. Pour ces pierres décoratives, prévoir `Anchored=true` et `CanCollide=false` afin de garder les déplacements fluides. Désactiver également `CanTouch` si aucune interaction n'est prévue. Ces réglages sont à appliquer dans Studio et ne sont pas déjà installés dans le projet.

Placer quelques groupes au pied des murs ou à la limite des jardins, en variant rotation et échelle modérément. Garder le milieu des allées libre. Un contrôle visuel après import dans Studio reste nécessaire.

## Validation

Validé par l'utilisateur le 1 octobre 2026. Les variantes B/C et les roches moyennes ne sont pas produites à ce stade.

