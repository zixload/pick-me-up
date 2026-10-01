# Lobby Pick Me Up — détails P1

Direction proposée le 1 octobre 2026. Ce document définit les pièces à modéliser ; il ne constitue pas un kit 3D déjà réalisé.

Direction validée par l'utilisateur. Méthode demandée : produire un seul asset à la fois, présenter ses aperçus et attendre son retour avant de commencer le suivant. Premier asset : lanterne sur pied, dossier `lanterne_p1/`.

Lanterne sur pied, lanterne murale et premier groupe de cailloux `P1_Cailloux_A` validés par l'utilisateur. Les cailloux sont dans `cailloux_p1/`, avec exports vérifiés. Les variantes B/C et les roches moyennes restent à produire, une pièce à la fois.

Roche plate `P1_Roche_Plate`, dossier `roche_plate_p1/`, validée par l'utilisateur (« validé »). Petite mousse facultative séparée. Ne produire une autre pièce que lors de la suite demandée, une pièce à la fois.

## Référence de production

Référence principale : `rempart_p1.blend`, son script `build_rempart_p1.py` et l'aperçu `apercus/rempart_p1_34.png`.

Le P1 existant utilise une pierre gris-bleu (84, 100, 122), un argent clair (205, 212, 222) et une mousse verte (88, 128, 56). Ses travées ont un entraxe nominal de 20 unités et ses piliers culminent à 35,8. Les dimensions proposées ci-dessous sont destinées à cette échelle ; elles devront être contrôlées à côté d'un avatar dans Studio.

Les images fournies de Pick Me Up apportent l'enceinte monumentale, les jardins par petites zones, les allées lisibles et les bâtiments rituels avec accents cyan. Les props ci-dessous sont des propositions originales inspirées de cette ambiance, pas une liste d'objets confirmés dans le récit.

## Style

- Pierre : volumes épais, chanfreins visibles, grandes faces lisibles, quelques arêtes ébréchées. Reprendre la pierre des murs, avec une variante légèrement plus claire pour le mobilier.
- Métal : fer sombre pour les structures et petites bagues argentées pour rappeler les piliers. Les détails doivent rester visibles depuis la caméra du joueur.
- Végétation : mousse en plaques irrégulières, dans les creux et au pied des objets ; quelques herbes autour des roches. Mousse séparée pour varier sa présence.
- Lumière : ambre doux dans les lanternes des allées et près des bâtiments habités. Le cyan reste concentré sur la faille, l'invocation et les repères magiques.
- Formes : lanternes à quatre ou six faces, toit pyramidal bas, socles carrés à ressauts qui reprennent ceux des remparts. Roches irrégulières à pans adoucis, avec trois silhouettes différentes plutôt qu'une sphère déformée répétée.
- Usure : lobby entretenu mais ancien ; petites marques locales, surfaces propres sur les axes de passage.

## Pièces proposées

Les dimensions sont des objectifs en unités Blender/studs, pas des mesures déjà réalisées. Largeur × profondeur × hauteur.

| Nom de travail | Pièce / style | Dimensions indicatives | Emplacement | Lot |
|---|---|---|---|---|
| P1_Lanterne_Pied | Pied en fer sombre, bagues argentées, socle de pierre à deux ressauts, cage à lumière ambre | 2 × 2 × 9 | Jonctions d'allées, entrée des bâtiments | 1 |
| P1_Lanterne_Murale | Même cage, petite console arquée et platine argentée | 1,5 × 2 × 3 | Façades et quelques piliers près d'une entrée | 1 |
| P1_Lanterne_Basse | Version courte sur socle de pierre | 1,5 × 1,5 × 3 | Bord des jardins et petits escaliers | 2 |
| P1_Cailloux_A_B_C | Trois groupes de petits galets anguleux, espacements différents | 1,5 à 3 × 1 à 2 × 0,2 à 0,6 | Pied des murs, pieds de plantes | 1 |
| P1_Roche_A_B_C | Trois roches : plate, trapue et inclinée ; mousse facultative | 1,5 à 3,5 × 1 à 3 × 0,8 à 2 | Jardins, bords extérieurs des chemins | 1 |
| P1_Rocher_Accent | Un rocher plus imposant, à silhouette marquée | 4 à 6 × 3 à 5 × 2 à 4 | Une ou deux zones végétales périphériques | 3, option |
| P1_Mousse_Sol_A_B_C | Plaques basses séparées, contours irréguliers | 1 à 3 × 1 à 2 × 0,03 | Autour des roches et des socles | 1 |
| P1_Bordure_Droite_4 | Bordure en pierre, léger chanfrein et joint visible | 4 × 0,6 × 0,6 | Limites des jardins | 1 |
| P1_Bordure_Angle | Coin assorti pour fermer les parterres | 1 × 1 × 0,6 | Angles de jardin | 1 |
| P1_Banc_Pierre | Pieds en pierre à ressauts, assise épaisse, bande argentée discrète | 6 × 2 × 2,5 | Périphérie de la place centrale | 2 |
| P1_Jardiniere | Cuve de pierre encadrée, mousse au pied ; végétation indépendante | 3 × 3 × 2,5 | Entrées et angles de bâtiments | 2 |
| P1_Dalle_Ancienne_A_B | Dalles irrégulières et légèrement usées | 2 à 4 × 2 à 4 × 0,15 | Petits raccords, chemins secondaires | 2 |
| P1_Marche_4 | Marche de pierre modulaire | 4 × 1,5 × 0,5 | Seuils et petits dénivelés | 2 |
| P1_Plaque_Direction | Plaque encadrée sur socle bas ; surface de texte séparée | 3 × 1 × 3 | Intersection menant aux dortoirs, forge et invocation | 2 |
| P1_Banniere | Support en fer sombre, étoffe bleu désaturé, emblème clair | 2,5 × 0,6 × 5 | Entrées majeures | 3 |
| P1_Brasero_Rituel | Coupelle sombre sur petit piédestal de pierre | 2,5 × 2,5 × 4 | Approche de la zone rituelle | 3 |
| P1_Socle_Embleme | Petit socle reprenant les cadres des murailles, insert argenté | 3 × 3 × 2 | Repère devant un sanctuaire | 3 |
| P1_Fontaine_Petite | Bassin de pierre octogonal et jet central sobre | 6 × 6 × 4 | Zone de repos, si la place reste assez dégagée | 3, option |

## Premier lot conseillé

Commencer par les deux lanternes principales, les cailloux, les trois roches moyennes, les plaques de mousse et les deux bordures. Cela permet de valider les matériaux, les proportions et le niveau de détail avant de produire le mobilier complet.

Réaliser d'abord une petite scène témoin : une travée et un pilier P1, une lanterne sur pied, une applique, une bordure de jardin, un groupe de cailloux et une roche avec mousse. Un rendu de jour contrôle l'accord des matériaux ; un rendu de fin de journée contrôle la lumière ambre.

## Placement

- Lanternes aux endroits où le joueur décide d'une direction, et près des entrées ; commencer avec un pas de 20 à 40 studs sur les grandes allées, puis ajuster visuellement.
- Cailloux et roches en groupes de tailles variées, surtout aux interfaces pierre/végétation. Garder le centre des allées libre.
- Bancs et jardinières autour de la place et près des bâtiments, avec une orientation qui conserve la vue vers les repères principaux.
- Les gros rochers et la petite fontaine sont optionnels : les ajouter seulement si une zone paraît vide après le premier assemblage.

## Préparation Blender et Roblox

Chaque prop sera séparé, nommé, avec son pivot au contact du sol. Pour une applique, pivot au centre de la platine de fixation ; façade de référence orientée vers -Y, axe vertical Blender Z. Les modules droits de 4 unités s'alignent sur la travée de 20.

Séparer pour les lanternes la structure, les vitres et le cœur lumineux. La géométrie sera produite dans Blender ; la lumière qui éclaire réellement la scène, l'éventuel scintillement, le feu et l'eau seront réglés dans Roblox. Éviter les matières qui dépendent uniquement de shaders procéduraux Blender pour les exports.

Prévoir trois silhouettes de roches et des variantes de mousse indépendantes. Les budgets de triangles seront fixés après le prototype, selon la taille et le nombre d'exemplaires à afficher. Collisions simples sur les volumes importants ; les petits cailloux décoratifs ne doivent pas accrocher les déplacements.

Livrables visés après modélisation : fichier Blender, exports séparés FBX/GLB, textures utiles, noms/pivots documentés et aperçu d'assemblage avec le rempart P1.
