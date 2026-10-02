# Emplacements des bâtiments — à lire avant de modéliser un bâtiment

Référence commune pour tous ceux qui produisent les bâtiments du lobby (Claude, ChatGPT, l'équipe).
Base agrandie de 1,5 le 1er octobre 2026 : **toutes les cotes ci-dessous sont déjà à l'échelle finale**.
Le plan illustré est dans `docs/plan_base.html`.

## Repère du lobby

- 1 stud = 1 unité Blender. Sol à **y = 0** (Roblox) / **z = 0** (Blender).
- Vu de dessus dans Studio : **+X vers l'est**, **+Z vers le sud**. Place centrale en **(0, 12)**, rayon 37,5.
- Rempart : cercle de rayon **210**, 66 travées de 20 studs. Rien ne doit dépasser un rayon de **192**.
- Point d'apparition : (0, 138), sur l'avenue sud.

## Les lots

L'identifiant (`LotId`) est celui du code (`src/shared/Config/Batiments.luau`) et le nom du dossier
`ServerStorage.Batiments.<LotId>`. Le nom affiché au joueur est en anglais.

- **Centre** : centre de l'emprise, en coordonnées Studio (X, Z).
- **Façade** : direction vers laquelle regarde l'entrée (la direction cardinale qui pointe le plus vers la place).
- **Façade × profondeur** : taille maximale du bâtiment, largeur de la façade puis profondeur, en studs.
- **H max** : hauteur maximale (studs), à ne pas dépasser, tous paliers confondus.
- **Départ** : niveau au départ (0 = emplacement réservé, à construire).
- **Construction** : pour un emplacement réservé, le bâtiment parent et le niveau qu'il doit atteindre.

| LotId | Nom (anglais) | Centre (X, Z) | Emprise | Façade | Façade × profondeur | H max | Départ | Construction |
|---|---|---|---|---|---|---|---|---|
| `Logements` | Lodging | (-130.5, -78) | X -150 → -111, Z -99 → -57 | +X | 42 × 39 | 50 | 1 | — |
| `Logements_Annexe` | Lodging Annex | (-132, -16.5) | X -151.5 → -112.5, Z -37.5 → 4.5 | +X | 42 × 39 | 50 | 1 | — |
| `Cantine` | Restaurant | (-139.5, 52.5) | X -160.5 → -118.5, Z 31.5 → 73.5 | +X | 42 × 42 | 35 | 1 | — |
| `Infirmerie` | Infirmary | (51, 138) | X 31.5 → 70.5, Z 117 → 159 | -Z | 39 × 42 | 35 | 1 | — |
| `Administration` | Administration | (144, -67.5) | X 121.5 → 166.5, Z -87 → -48 | -X | 39 × 45 | 40 | 1 | — |
| `Entrainement` | Training Center | (-84, -126) | X -117.75 → -50.25, Z -149.25 → -102.75 | +Z | 67.5 × 46.5 | 20 | 1 | — |
| `Forge` | Smithy | (-52.5, 82.5) | X -73.5 → -31.5, Z 61.5 → 103.5 | -Z | 42 × 42 | 35 | 1 | — |
| `Traitement_Metaux` | Metal Processing | (-54, 138) | X -73.5 → -34.5, Z 120 → 156 | -Z | 39 × 36 | 35 | 1 | — |
| `Menuiserie` | Woodworking Shop | (-91.5, 132) | X -105 → -78, Z 111 → 153 | -Z | 27 × 42 | 30 | 0 | Smithy 5 |
| `Chambre_Synthese` | Synthesis Chamber | (75, -135) | X 54 → 96, Z -156 → -114 | +Z | 42 × 42 | 40 | 0 | Summoning Hall 5 |
| `Academie_Magie` | Magic Academy | (82.5, -40.5) | X 60 → 105, Z -61.5 → -19.5 | -X | 42 × 45 | 55 | 0 | Training Center 10 |
| `Terrain_Magique` | Magic Training Grounds | (-33, -151.5) | X -49.5 → -16.5, Z -168 → -135 | +Z | 33 × 33 | 20 | 0 | Training Center 10 |
| `Station_Transfert` | Transfer Station | (-45, -84) | X -60 → -30, Z -97.5 → -70.5 | +Z | 30 × 27 | 35 | 0 | Training Center 15 |
| `Faille` | Space-Time Rift | (117, 43.5) | disque, rayon 36 | vers la place (-0.97, -0.26) | Ø 72 | 40 | 1 | suit la Tour |
| `Invocation` | Summoning Hall | (18, -123) | disque, rayon 33 | vers la place (-0.13, 0.99) | Ø 66 | 45 | 1 | — |

Cas particuliers :

- **Quartier artisanal** (X -105 → -30, Z 60 → 159) : `Forge`, `Traitement_Metaux` et `Menuiserie` y
  sont regroupés. Plus tard, ils fusionneront en un seul « Equipment Workshop » qui occupera tout le
  quartier (75 × 99) : garder ces trois bâtiments dans leur emprise.
- **Enceinte** (`Enceinte`) : ce n'est pas un bâtiment mais le rempart (`Rempart`) et le dallage (`Sol`,
  place comprise), faits par Claude (P1, P2, P3). Comme la `Faille`, elle ne s'achète pas : son palier
  suit l'étage atteint dans la Tour.
- **Académie de magie** (`Academie_Magie`) : anciennement « Salle de magie » (`Salle_Magie`), même bâtiment.
  Les pièces de dallage gardent l'ancien nom (`Socle_Salle_Magie`, `Raccord_Salle_Magie`).
- **Logements** : prévoir de la hauteur pour les paliers suivants (ils gagnent des étages).

## Paliers

Chaque bâtiment a 20 niveaux et, pour l'instant, 3 paliers visuels : **P1** (niveau 1), **P2** (5), **P3** (20).
Le niveau qui fait changer de style est verrouillé tant que le joueur n'a pas franchi l'étage de Tour
du palier (P2 : étage 10, P3 : 50) ; chaque amélioration coûte de l'or et les matériaux du
palier visé (`src/shared/Config/Materiaux.luau`). La Faille et l'Enceinte prennent directement le palier
ouvert par la Tour.
Un bâtiment n'a besoin que du P1 pour exister ; tant qu'un palier manque, le jeu affiche le dernier
palier disponible. Les quatre versions d'un bâtiment tiennent dans la **même emprise**, avec le **même
pivot** et la **même façade** : le jeu les remplace l'une par l'autre avec une animation.

| Palier | Direction artistique |
|---|---|
| P1 | pierre gris-bleu (84, 100, 122), mousse verte, accents d'argent brossé |
| P2 | roche noir nuit bleutée (palette `blender/textures_archive_P2/`), argent, mousse très sombre et rare |
| P3 | quartz crème très clair, filets et ornements d'or (anciennement P4) |

## Conventions de modélisation (Blender)

- 1 unité = 1 stud, Z en haut. **Façade (entrée) tournée vers -Y**. **Origine au sol, au centre de l'emprise.**
- Prévoir un **socle d'au moins 1 stud** sous le bâtiment : le dallage du lot est à y ≈ 0,45 au P1 et
  y ≈ 0,86 au P3, le socle masque cette différence.
- Moins de **20 000 triangles par maillage** (couper si besoin). Normales vérifiées vers l'extérieur
  (Roblox n'affiche qu'un côté des faces).
- Un maillage par matière, nommé `<LotId>_P<n>_<Matiere>` (ex. `Forge_P1_Pierre`, `Forge_P1_Argent`).
- Export FBX : `axis_forward='-Z'`, `axis_up='Y'`, échelle 1. Garder le script de génération dans le dépôt.
- Ajouter un objet (vide ou petit cube) nommé **`<LotId>_Entree`** devant la porte, au sol, à environ
  3 studs de la façade : la borne d'amélioration y sera déplacée (aujourd'hui elle est au centre du lot).
- Le feuillage existant (`PMU_Lierre_Grimpant`, `PMU_Haie_8`) peut habiller les murs et les abords.

## Intégration dans Studio

1. Importer le FBX dans Studio.
2. Le ranger dans `ServerStorage.Batiments.<LotId>.P<n>` (un `Model`, attributs `LotId` = l'identifiant,
   `Palier` = n), posé au centre du lot, façade tournée vers la direction du tableau.
   Exemple de script d'assemblage : `studio/faille_p1.luau` (rotation automatique vers la place).
3. Le système de paliers (`src/server/Paliers.luau`) et le service de base l'affichent automatiquement
   selon le niveau du bâtiment (ou l'étage de Tour) dans la sauvegarde du joueur. Rien à coder.

## Qui fait quoi

| Bâtiment | Qui | État |
|---|---|---|
| Rempart, Sol | Claude | P1, P2 et P3 faits |
| Entrainement (Training Center) | ChatGPT pour P1, Claude pour P2 et P3 selon plan antérieur | Un seul mannequin réalisé et validé : `blender/mannequin_entrainement_p1/`. Import Roblox à faire par l’utilisateur. Bâtiment complet en attente ; prompt initial dans `PROMPTS_BATIMENTS_MESHY.md` à adapter aux références du webtoon. |
| Faille | Claude | P1 en pause (à retravailler) |
| Détails du lobby P1 (lanternes, roches, banc…) | ChatGPT | en cours |
| Autres bâtiments | à attribuer | — |
