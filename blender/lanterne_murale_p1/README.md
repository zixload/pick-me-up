# P1 — Lanterne murale, V01

Deuxième asset du lobby, réalisé seul pour validation. La cage, le toit, les vitres et le cristal sont repris directement des pièces sources de la lanterne sur pied validée. La platine murale et la console sont nouvelles.

## Fichiers

- `P1_Lanterne_Murale.blend` : sources éditables, asset assemblé, présentation et rempart P1 de référence.
- `exports/P1_Lanterne_Murale.fbx` et `.glb` : la lanterne seule, en trois meshes séparés.
- `textures/` : même atlas Color, Roughness et Metalness 512 × 512 que la lanterne sur pied, intégré aux livrables.
- `previews/01_lanterne_murale.png` : vue de trois quarts de l'asset.
- `previews/02_profil_fixation.png` : vue de profil pour examiner la console et la fixation.
- `previews/03_sur_rempart_P1.png` : installation à hauteur de 7,5 unités sur un pilier du vrai rempart P1.
- `manifest.json` et `verification.json` : mesures et résultats du contrôle des exports.

## Design

Platine en pierre gris-bleu, bordure argentée, quatre rivets, petit losange argenté et console courbe en fer sombre. Même cage à quatre faces, toit pyramidal, entretoises et cœur ivoire/ambre que l'asset précédent.

L'asset mesure environ **1,63 de large × 2,56 de profondeur × 3,64 de haut**. Convention de travail : une unité destinée à correspondre à un stud Roblox. Le pivot est au centre de la platine, contre le mur. Le dos touche le plan Y=0 ; l'asset se projette vers -Y. Z est l'axe vertical dans Blender.

La hauteur d'installation proposée de 7,5 studs se mesure au pivot, pas au sommet de la lanterne. Elle place le cristal près de cette hauteur et le sommet à environ 9,54 studs.

| Mesh | Rôle | Triangles |
|---|---|---:|
| P1_Lanterne_Murale_Structure | Platine, console, cage, toit et métal | 5344 |
| P1_Lanterne_Murale_Vitres | Quatre vitres | 8 |
| P1_Lanterne_Murale_Coeur | Cristal | 76 |

Total : **5428 triangles**. Les trois meshes partagent le même pivot de fixation.

## Blender

- `00_SOURCE_EDITABLE` : pièces séparées, masquées au départ.
- `01_ASSET_EXPORT` : lanterne assemblée, visible à l'ouverture.
- `02_CONTEXTE_REMPART_P1` : pilier et travée existants, masqués au départ.
- `03_PRESENTATION` : caméra, sol et éclairages, exclus des exports.

Le script de construction dépend du fichier de la lanterne sur pied validée et du rempart P1 dans les dossiers voisins. Les fichiers livrés `.blend`, `.fbx` et `.glb` sont autonomes pour leur utilisation : géométrie et atlas utiles y sont intégrés.

## Roblox après import

Importer un des exports avec le 3D Importer, vérifier les dimensions et le pivot, puis créer un Model ancré. Aligner le pivot sur la surface de fixation. Le verre et le cœur sont séparés pour régler leur transparence et leur apparence dans Studio.

Configurer la lumière réelle dans Roblox : le cristal est centré approximativement à X=0, Y=-1,75, Z=0 dans le repère Blender de l'asset. Tenir compte de la conversion d'axes à l'import. La lumière ambre et l'émission visibles dans les rendus sont des réglages de présentation Blender, pas un éclairage Roblox déjà installé.

Prévoir des collisions simples ou désactivées pour cette applique décorative, selon sa position. Le verre peut nécessiter DoubleSided. Le rendu exact dans Studio doit encore être vérifié.

## Validation

Contrôles attendus : lanterne reconnaissable comme faisant partie de la même famille que la version sur pied, console suffisamment solide, platine lisible et projection acceptable depuis le mur. Attendre le retour de l'utilisateur avant de créer une autre pièce.

Statut : validé par l'utilisateur le 1 octobre 2026 (« validé; suite »).
