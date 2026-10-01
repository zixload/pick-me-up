# P1 — Roche plate, V01

Un seul nouvel asset, pour validation visuelle : une roche basse et large destinée aux jardins et aux abords des remparts. Pierre gris-bleu assortie aux cailloux P1 approuvés ; petite mousse facultative, séparée.

## Fichiers

- `P1_Roche_Plate.blend` : roche source, îlots de mousse éditables, asset assemblé et scène de présentation.
- `exports/P1_Roche_Plate.fbx` et `.glb` : uniquement la roche et sa mousse, en deux meshes.
- `textures/` : atlas Color, Roughness et Metalness 512 × 512, intégré aux livrables.
- `previews/01_roche_plate_34.png` : vue de trois quarts avec la mousse.
- `previews/02_roche_sans_mousse.png` : même vue sans mousse.
- `previews/03_roche_dessus.png` : contour et dessus incliné.
- `previews/04_avec_rempart_et_cailloux.png` : roche au pied du vrai rempart P1, à côté des cailloux approuvés. Ces références sont exclues des exports.
- `manifest.json` et `verification.json` : mesures et contrôles.

## Design

Contour asymétrique, angles coupés, encoche latérale, dessus large légèrement incliné et dessous plat. De petits chanfreins adoucissent les arêtes tout en gardant les grandes faces lisibles. Les îlots de mousse suivent la surface de la roche ; ils peuvent être masqués ou supprimés indépendamment.

Dimensions de la pierre : **3,24 × 2,18 × 1,06 unités**. Convention de travail : une unité destinée à correspondre à un stud Roblox. Pivot au sol à l'origine commune des deux meshes, axe vertical Blender Z.

| Mesh | Triangles | Rôle |
|---|---:|---|
| P1_Roche_Plate_Pierre | 880 | Roche principale fermée |
| P1_Roche_Plate_Mousse | 816 | Trois petites plaques facultatives, suivant les reliefs |

Total avec mousse : **1696 triangles** ; pierre seule : **880 triangles**.

## Collections Blender

- `00_SOURCE_EDITABLE` : roche et îlots de mousse séparés, masqués au départ.
- `01_ASSET_EXPORT` : deux meshes assemblés, visibles à l'ouverture.
- `02_CONTEXTE_REMPART_P1` : rempart et cailloux approuvés, masqués au départ.
- `03_PRESENTATION` : caméra, éclairages et sol, exclus des exports.

Le script de construction dépend de `../rempart_p1.blend` et de `../cailloux_p1/P1_Cailloux_A.blend` pour les références de présentation. Les fichiers livrés sont autonomes pour leur utilisation : géométrie et textures utiles intégrées.

## Préparation pour Roblox

Importer un export avec le 3D Importer et vérifier dimensions, axes et pivot. Grouper la pierre et la mousse dans un Model ancré. Pour une version nue, supprimer ou masquer uniquement le mesh `P1_Roche_Plate_Mousse`.

La mousse est une surface fine : prévoir `CanCollide=false` et, si nécessaire, `DoubleSided=true`. Pour la roche, utiliser une collision simple si elle doit bloquer le joueur ; sinon désactiver la collision. Garder ces éléments en bordure des jardins, hors des principaux axes de circulation.

Les réglages Roblox restent à appliquer dans Studio. L'asset n'est pas encore importé dans le projet.

## Validation

Contrôle de construction : pierre fermée, volume positif, dessous à Z=0. Le résultat des contrôles d'export est consigné dans `verification.json` : meshes attendus, dimensions, pivots, UV et textures intégrées. Validé visuellement par l'utilisateur le 1 octobre 2026 (« validé »). Aucune autre roche n'est produite dans ce lot.
