# Kit de murailles — Pick me up — V01

Modèles originaux réalisés dans Blender 4.5 à partir des références fournies.
Style : pierre ivoire, panneaux encadrés, corniches, balustres et frises dorées.
Les deux autres références servent au caractère monumental et au principe
d'une enceinte assemblée autour du lobby. Les portes et le sanctuaire ne font
pas partie de ce premier kit.

## Fichiers

- `PMU_Murailles_V01.blend` : projet natif avec modèles, textures intégrées,
  pièces sources éditables, assemblage d'angle et exemple d'enceinte circulaire.
- `exports/` : chaque asset séparé en FBX et en GLB.
- `textures/` : atlas commun 1024×1024 : Color, Roughness, Metalness.
- `previews/` : rendus Blender d'assemblage, de détail et des modules séparés.
- `manifest.json` : dimensions, triangles et noms des exports.
- `verification.json` : résultats de réimport des FBX dans Blender.
- `build_wall_kit.py` : script qui permet de reconstruire le kit.

## Modules

| Nom | Fonction | Triangles |
| --- | --- | ---: |
| PMU_Mur_Panneau_16 | Mur de 16 unités, panneau et frise | 3204 |
| PMU_Pilier_Orne | Jonction de deux travées, chapiteau | 1720 |
| PMU_Corniche_16 | Corniche indépendante de 16 unités | 264 |
| PMU_Balustrade_16 | Balustrade supérieure à 12 balustres | 2724 |
| PMU_Pilier_Angle_90 | Pilier avec deux faces ornées | 2868 |
| PMU_Lierre_Grimpant | Lierre et petites fleurs optionnels | 4784 |
| PMU_Haie_8 | Petit module végétal optionnel | 640 |

## Utilisation dans Blender

La collection `02_ASSEMBLAGE_DEMO` est visible à l'ouverture. La caméra
`Camera_Assemblage` cadre l'ensemble. Passer en vue caméra avec le pavé
numérique 0 ; F12 produit un rendu.

Les collections suivantes sont masquées au départ ; activer leur icône de
moniteur dans l'Outliner pour les afficher :

- `00_SOURCE_EDITABLE` : géométrie séparée et modificateurs avant fusion.
- `01_EXPORT_MODULES` : les sept meshes canoniques à leurs pivots d'origine.
- `04_PLANCHE_MODULES` : disposition séparée des pièces.
- `05_ENCEINTE_CIRCULAIRE_48` : exemple fermé à 48 travées, sans végétation.

Afficher une démonstration à la fois pour éviter leur superposition.
Les textures sont intégrées au `.blend`. La frise et les chapiteaux ont du
relief géométrique ; aucun modèle généré par une IA 3D n'est utilisé ici.

## Grille et assemblage

Convention : une unité Blender est destinée à correspondre à un stud Roblox.
La largeur nominale d'une travée est 16 ; la hauteur maximale est 28,525.
L'axe vertical dans Blender est Z. Le côté décoré fait face à -Y.

Le mur, la corniche et la balustrade partagent un pivot au sol, au bord gauche
de la travée. Leur hauteur est déjà inscrite dans leur géométrie : les placer
au même pivot pour les assembler. Les piliers ont un pivot au sol au centre.

Pour un alignement droit, dupliquer les trois modules horizontaux avec un
décalage de 16 unités et placer un pilier à chaque jonction. Le lierre est
indépendant et se place devant le pilier. La haie a un pas conseillé de 8,
avec un léger recouvrement du feuillage.

L'enceinte circulaire d'exemple utilise les mêmes panneaux droits : ce sont
48 cordes de longueur 16, avec un pilier à chaque jonction. Son rayon est
`16 / (2 * sin(pi / 48))`, soit environ 122,32 unités. Le kit permet donc une
enceinte polygonale proche d'un cercle ; les panneaux eux-mêmes sont droits.

## Importation dans Roblox Studio

1. Utiliser le 3D Importer pour importer un FBX ou un GLB depuis `exports/`.
2. Vérifier sur le premier mur que la largeur importée est de 16 studs.
   L'import Studio n'a pas encore été validé avec ces fichiers.
3. Vérifier le pivot importé ; le replacer si l'importeur l'a recentré.
4. Activer `Anchored` sur les MeshParts.
5. Garder une collision simple `Box` pour le mur et les piliers. Utiliser
   `CanCollide = false` pour le lierre et la haie. La balustrade peut être
   purement décorative si les joueurs ne doivent pas accéder à son sommet.
6. Vérifier les textures. Au besoin, importer les trois images dans l'Asset
   Manager et les attribuer à un `SurfaceAppearance` : `ColorMap`,
   `RoughnessMap`, `MetalnessMap`.
7. Créer un Model de travée, puis un Package pour réutiliser et mettre à jour
   les exemplaires dans la base.

Un atlas et un matériau sont partagés par les meshes. Aucun shader procédural
Blender n'est requis pour les couleurs des exports. L'apparence des métaux
et l'éclairage dans Studio peuvent différer du rendu Blender.

## Vérification

Les contrôles automatiques réimportent les sept FBX dans Blender et vérifient
les dimensions, le nombre de triangles, le canal UV unique et les images
embarquées. Les aperçus sont ensuite contrôlés visuellement.
Cela ne remplace pas un test d'import et de performances dans Roblox Studio.
