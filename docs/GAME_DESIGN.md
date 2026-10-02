# Pick Me Up (Roblox) — design du jeu

Référence commune pour l'équipe (et pour ChatGPT). Ce document consigne les décisions prises ;
ce qui reste à trancher est regroupé à la fin. Les emplacements et la fabrication des bâtiments
sont dans `docs/LOTS_BATIMENTS.md`, le plan illustré dans `docs/plan_base.html`.

Dernière mise à jour : 2 octobre 2026.

## Principe

Chaque joueur incarne un **héros** et possède sa **base** (le lobby). Il part de la base en
mission par la Faille, revient avec des matériaux et améliore ses bâtiments. Il recrute des
**invocations** qui combattent à ses côtés en escouades.

## Progression de la base

- **Niveau du joueur** : uniquement le combat (points de vie, force des coups, compétences).
  Il ne joue aucun rôle dans les améliorations de bâtiments.
- **Tour** : l'étage le plus haut franchi déverrouille les styles de la base.
- **Trois paliers visuels** pour l'instant :

  | Palier | Style | Niveau de bâtiment | Étage de Tour requis | Matériaux |
  |---|---|---|---|---|
  | P1 | pierre gris-bleu, mousse, argent | 1 | — | Bluestone, Timber |
  | P2 | roche noir nuit, argent | 5 | 10 | Night Basalt, Silver Ore |
  | P3 | quartz clair, or | 20 | 50 | Quartz, Gold Ore |

- **Améliorer un bâtiment** coûte de l'or et les matériaux du style visé : ceux du style actuel
  tant qu'on reste dans le même palier, ceux du nouveau style pour le niveau qui en change.
  Ce niveau-là attend en plus l'étage de Tour du palier. Le style change quand l'amélioration
  est payée, pas au moment où l'étage est franchi.
- **Enceinte (rempart et sol), place et Faille** ne s'achètent pas : leur style suit directement
  l'étage de Tour atteint.
- **Lots réservés** : construits quand leur bâtiment parent atteint un niveau donné.

  | Bâtiment parent | Annexes |
  |---|---|
  | Invocation | Chambre de synthèse (niveau 5) |
  | Entraînement | Terrain magique et Académie de magie (niveau 10), Station de transfert (niveau 15) |
  | Forge | Menuiserie (niveau 5) ; à haut niveau, Forge, Traitement des métaux et Menuiserie fusionnent en Atelier d'équipement |

- Les matériaux se minent et se récoltent en **expédition**, hors de la Tour (voir Wilderness).

## Combat du héros

- Épée de départ : combo de trois coups, esquive avec une courte invulnérabilité.
- Le serveur valide chaque coup et cherche lui-même les cibles (base du PvP sans triche).
- Gestes « cinéma » : anticipation, frappe en fente, pose figée, arrêt sur image à l'impact.

## Invocations et escouades

- **Une équipe = 5 invocations.** Au départ, le joueur emmène une équipe ; les **Logements**
  débloquent les suivantes : 2e équipe au niveau 5, 3e au niveau 10, 4e au niveau 20 (premier jet,
  à vérifier en jeu).
- **Avant de partir en mission**, le joueur décide du placement de son équipe : tanks devant,
  archers derrière, etc.
- **En combat**, trois ordres : **suivre**, **maintenir** (tenir la position), **attaquer**.
- **En mode attaque, chaque classe a son propre comportement** : l'archer s'éloigne quand un ennemi
  l'engage au corps à corps (kiting), le tank se place entre l'ennemi et le reste de l'équipe, etc.

### Classes

Les classiques du MMO (validés, sans classe de support), chacune avec une place dans la formation
et un comportement en mode attaque.

| Classe | Rôle | Place | Comportement en attaque |
|---|---|---|---|
| Tank | encaisser, protéger | devant | se place entre les ennemis et les alliés fragiles, provoque l'ennemi le plus menaçant, ne recule pas |
| Guerrier | dégâts au corps à corps, solide | devant, derrière le tank | engage la cible du tank, reste au contact |
| Assassin | dégâts rapides, cible prioritaire | sur les flancs | contourne la mêlée pour frapper les soigneurs et tireurs adverses, se retire quand il est blessé |
| Archer | dégâts à distance, une cible | derrière | garde ses distances, kite dès qu'un ennemi l'engage au corps à corps |
| Mage | dégâts de zone, contrôle | derrière | vise les groupes d'ennemis, ralentit ou immobilise ceux qui foncent sur l'équipe |
| Soigneur | soins | au centre arrière | reste hors de portée, soigne l'allié le plus en danger, fuit les assassins |

## Zones

### Arène classée (PvP ranked)

- Duels en **1v1, 2v2 et 3v3** (joueurs), avec un classement. Chaque joueur combat **avec ses
  invocations** : le placement de l'escouade et ses ordres font partie du skill. Comme en mission,
  il emmène autant d'équipes que ses Logements le permettent.
- Combat en **manches** : on gagne une manche quand tous les ennemis sont morts.
- **Le plus important** : le PvP doit récompenser le skill — le placement, la manière de se
  déplacer et d'attaquer, le kiting, le rush sur la cible prioritaire.

### Wilderness (hors Tour)

- Accessible par la Faille. **Monde commun à tous les joueurs, PvP activé** : les ressources rares
  se disputent, les joueurs plus faibles se cachent, ce qui crée de l'interaction entre joueurs.
- Contenu :
  - **missions** et **explorations** ;
  - **événements PvE et PvP**, avec des récompenses plus ou moins fréquentes ;
  - **capture de pets** stylés et très rares pendant les explorations. Les pets sont
    **cosmétiques** et servent de **monture** ; l'un d'eux se trouve dans un endroit caché
    de la carte (easter egg).
- **Mourir dans le Wilderness ne fait rien perdre** : l'enjeu du PvP est de se disputer les
  ressources rares sur place, pas de dépouiller les autres.
- **Zones de niveaux différents** : zones à mobs de haut niveau et zones de bas niveau, chacune
  avec des ressources cohérentes avec son niveau (par exemple, les matériaux P1 dans les zones
  faciles, ceux du P3 dans les plus dangereuses).

### Tour

- Une tour dans l'idée et dans le lore : chaque étage est une **salle ou un donjon**.
  Franchir un étage fait avancer l'histoire et déverrouille les styles de la base.

### PvP de base

- Attaque de la base d'un autre joueur (prévu, règles à définir).

## À trancher

- **Équipes supplémentaires** : vérifier en jeu que les seuils des Logements (5, 10, 20) fonctionnent.
- **Tour** : nombre d'étages.
