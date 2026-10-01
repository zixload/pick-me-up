# Pick me up — sélection des effets sonores V01

Sélection validée par l'utilisateur le 1 octobre 2026 (« ok tout me va »). Les sons principaux sont retenus ; les variantes restent disponibles pour les variations et le mixage. Intégration au gameplay à réaliser.

**52 usages, 51 sons principaux distincts, 61 fichiers avec les variantes. 22 usages prioritaires pour le prototype.** La charge magique sert à la fois aux sorts et à l'invocation.

Les candidats ont été trouvés dans le Creator Store avec le filtre Audio et sont indiqués gratuits par le Store. Les 61 fichiers ont été préchargés avec succès dans le Studio de Pick me up (place 107076511400081, univers 10768886580) ; IsLoaded était vrai et les durées ont été mesurées. Test en mode Édition, sans jouer les sons. Cela vérifie leur chargement actuel, pas leur qualité artistique ni leur comportement dans une partie publiée. Les objets temporaires ont été supprimés ; aucun son n'a été branché au gameplay.

## Écoute et ajustements ultérieurs

1. Ouvrir le lien du son dans le Creator Store et utiliser son aperçu audio.
2. Écouter d'abord les lignes marquées **Prototype**.
3. Noter « garder », « remplacer » ou « variante », avec le code SFX et le nom choisi.
4. Pour les ambiances, vérifier le raccord de boucle. Pour les combats, vérifier que les effets restent lisibles lorsqu'ils se superposent.

Les associations et descriptions ci-dessous sont des propositions à partir des titres et des descriptions des assets ; aucune écoute artistique n'a été effectuée par l'assistant. Un titre générique ne suffit pas à confirmer l'origine d'un enregistrement. Les reprises explicitement identifiées comme venant d'autres jeux dans les résultats de recherche ont été écartées.

Les budgets de durée sont à ajuster au gameplay : la défaite dure environ 10,8 secondes et convient à un écran de fin, pas à chaque coup reçu ; les explosions de sorts sont longues et peuvent nécessiter une autre sélection ou un réglage. Une parade parfaite devrait rester distincte du blocage après écoute et mixage.

## Interface

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_01 | Survol de bouton | Prototype | [ui-simple-button-hover](https://create.roblox.com/store/asset/139800881181209) · ID `139800881181209` | AmbientSorcery | 0,13 s |
| SFX_02 | Clic de bouton | Prototype | [ui-simple-button-click](https://create.roblox.com/store/asset/88442833509532) · ID `88442833509532` | AmbientSorcery | 0,03 s |
| SFX_03 | Confirmation / achat | Prototype | [UI - Confirm 1](https://create.roblox.com/store/asset/116995696565929) · ID `116995696565929` | lluma3D | 1,9 s |
| SFX_04 | Erreur / ressources insuffisantes | Prototype | [ui-simple-negative-error](https://create.roblox.com/store/asset/87519554692663) · ID `87519554692663` | AmbientSorcery | 0,31 s |
| SFX_05 | Notification | Plus tard | [UI Notification](https://create.roblox.com/store/asset/106553517979212) · ID `106553517979212` | CoreCraft Studio | 0,97 s |
| SFX_06 | Ouverture inventaire | Prototype | [ui-simple-inventory-open](https://create.roblox.com/store/asset/127877437691780) · ID `127877437691780` | AmbientSorcery | 0,05 s |
| SFX_07 | Fermeture inventaire | Prototype | [ui-simple-inventory-close](https://create.roblox.com/store/asset/74657965144290) · ID `74657965144290` | AmbientSorcery | 0,04 s |
| SFX_08 | Équipement d'un objet | Plus tard | [ui-simple-equip](https://create.roblox.com/store/asset/138323438407619) · ID `138323438407619` | AmbientSorcery | 0,12 s |

- **SFX_01 — Survol de bouton :** Petit tic discret.
- **SFX_02 — Clic de bouton :** Confirmation immédiate du clic.
- **SFX_03 — Confirmation / achat :** Valider une action importante.
- **SFX_04 — Erreur / ressources insuffisantes :** Action impossible ou compétence indisponible.
- **SFX_05 — Notification :** Quête, message ou invitation.
- **SFX_06 — Ouverture inventaire :** Entrée dans l'inventaire ou le menu du héros.
- **SFX_07 — Fermeture inventaire :** Retour au jeu.
- **SFX_08 — Équipement d'un objet :** Arme ou équipement sélectionné.

## Combat

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_09 | Coup d'épée léger | Prototype | [Sword Swing Sound](https://create.roblox.com/store/asset/134671877618939) · ID `134671877618939` | 0FFZ3TI | 0,56 s |
| SFX_10 | Coup d'épée lourd | Plus tard | [Sword Swing Metal Heavy](https://create.roblox.com/store/asset/6241709963) · ID `6241709963` | Aurarus | 0,59 s |
| SFX_11 | Impact d'épée | Prototype | [Sword Hit (Impact)](https://create.roblox.com/store/asset/7171761940) · ID `7171761940` | BushSeed | 1,4 s |
| SFX_12 | Dégâts reçus / coup au corps | Prototype | [Body Hit Impact](https://create.roblox.com/store/asset/127495971181378) · ID `127495971181378` | NickySergal | 0,89 s |
| SFX_13 | Blocage au bouclier | Prototype | [Shield Clang As Hit Metal Sword Hubcap 1 (SFX)](https://create.roblox.com/store/asset/9119072660) · ID `9119072660` | ProSoundEffects | 0,74 s |
| SFX_14 | Parade parfaite | Plus tard | [Shield Clang As Hit Metal Sword Hubcap 2 (SFX)](https://create.roblox.com/store/asset/9119072674) · ID `9119072674` | ProSoundEffects | 1,3 s |
| SFX_15 | Esquive / dash | Prototype | [Swift/Whooshes Potential Dash/Fast Hits SFX](https://create.roblox.com/store/asset/124044443087502) · ID `124044443087502` | DragonndineWhite2 | 0,41 s |

- **SFX_09 — Coup d'épée léger :** Souffle de la lame, même si le coup manque.
- **SFX_10 — Coup d'épée lourd :** Attaque chargée, plus ample.
- **SFX_11 — Impact d'épée :** Uniquement quand une cible est touchée.
- **SFX_12 — Dégâts reçus / coup au corps :** Retour sonore quand le héros prend un coup.
- **SFX_13 — Blocage au bouclier :** Impact métallique amorti.
- **SFX_14 — Parade parfaite :** Impact net ; sera à distinguer du blocage au mixage.
- **SFX_15 — Esquive / dash :** Souffle bref pendant le déplacement.

## Déplacements

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_16 | Saut | Plus tard | [Jump Sound](https://create.roblox.com/store/asset/135162567109750) · ID `135162567109750` | EightyKoii | 0,63 s |
| SFX_17 | Réception / chute | Prototype | [Body Fall Thud 2 (SFX)](https://create.roblox.com/store/asset/9113480915) · ID `9113480915` | ProSoundEffects | 1,1 s |
| SFX_18 | Pas sur pierre | Prototype | [Stone Footstep 1 (SFX)](https://create.roblox.com/store/asset/133325104274958) · ID `133325104274958` | ChamoyBaconXD | 0,50 s |
| SFX_19 | Pas sur herbe | Plus tard | [footstep grass 4](https://create.roblox.com/store/asset/135037154891351) · ID `135037154891351` | Robloxmastermanyay | 0,38 s |

- **SFX_16 — Saut :** Départ d'un saut ; comparer avec le son Roblox par défaut.
- **SFX_17 — Réception / chute :** Réception forte ou corps qui tombe.
- **SFX_18 — Pas sur pierre :** Dalles de la base et de la tour. Variantes : [Stone Footstep 5 (SFX)](https://create.roblox.com/store/asset/140594308250996) (0,49 s),[Stone Footstep 6 (SFX)](https://create.roblox.com/store/asset/82615619091463) (0,45 s).
- **SFX_19 — Pas sur herbe :** Jardins et zones d'exploration. Variantes : [footstep grass 3](https://create.roblox.com/store/asset/110522236020035) (0,39 s),[footstep grass 1](https://create.roblox.com/store/asset/129956418693357) (0,35 s).

## Magie / classes

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_20 | Lancement d'un sort | Prototype | [Magic Spell Cast](https://create.roblox.com/store/asset/93989620006639) · ID `93989620006639` | GleonoffG | 1,5 s |
| SFX_21 | Charge magique | Prototype | [Magic Charge](https://create.roblox.com/store/asset/5696557721) · ID `5696557721` | Ekyuklia | 2,0 s |
| SFX_22 | Impact magique | Plus tard | [[SFX] Magic Explosion 2](https://create.roblox.com/store/asset/75300135616235) · ID `75300135616235` | Just_Sear | 4,5 s |
| SFX_23 | Soin | Plus tard | [Fast healing magic sound](https://create.roblox.com/store/asset/139481162475902) · ID `139481162475902` | Kaoriox | 2,1 s |
| SFX_24 | Arc : tension de corde | Plus tard | [[SFX] Bow Draw](https://create.roblox.com/store/asset/82271313074659) · ID `82271313074659` | Just_Sear | 1,9 s |
| SFX_25 | Arc : tir | Plus tard | [Arrow Shoot](https://create.roblox.com/store/asset/89390229858498) · ID `89390229858498` | thefuture1687 | 1,0 s |
| SFX_26 | Arc : impact | Plus tard | [[SFX] Arrow Impact 2](https://create.roblox.com/store/asset/106118762903032) · ID `106118762903032` | Just_Sear | 2,3 s |

- **SFX_20 — Lancement d'un sort :** Sort générique de départ.
- **SFX_21 — Charge magique :** Préparation avant libération de l'énergie.
- **SFX_22 — Impact magique :** Explosion d'un projectile ou d'une zone. Variantes : [[SFX] Magic Explosion 3](https://create.roblox.com/store/asset/83680922290300) (6,2 s).
- **SFX_23 — Soin :** Gain de vie / soutien.
- **SFX_24 — Arc : tension de corde :** Préparation d'un tir.
- **SFX_25 — Arc : tir :** Départ de la flèche.
- **SFX_26 — Arc : impact :** Flèche qui touche.

## Tour / PvP

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_27 | Rugissement de boss | Plus tard | [Creature Mix Giant Crab Monster Roar Growl 1 (SFX)](https://create.roblox.com/store/asset/9113980319) · ID `9113980319` | ProSoundEffects | 3,1 s |
| SFX_28 | Vie critique | Plus tard | [Heartbeat](https://create.roblox.com/store/asset/139481207162657) · ID `139481207162657` | Marksmansz | 3,9 s |
| SFX_29 | Compte à rebours | Plus tard | [Countdown beep](https://create.roblox.com/store/asset/117751546358455) · ID `117751546358455` | santt2848 | 1,0 s |
| SFX_30 | Victoire / étage terminé | Prototype | [Success Correct Sound](https://create.roblox.com/store/asset/135165335432475) · ID `135165335432475` | 0FFZ3TI | 0,69 s |
| SFX_31 | Défaite | Plus tard | [Without Emotion (sting)](https://create.roblox.com/store/asset/9042163336) · ID `9042163336` | APMOfficial | 10,8 s |

- **SFX_27 — Rugissement de boss :** Apparition du boss ou avertissement d'attaque. Variantes : [Creature Roar Mix Of Animals Gate Creaks 1 (SFX)](https://create.roblox.com/store/asset/9113985604) (3,3 s).
- **SFX_28 — Vie critique :** Battements doux et intermittents à faible vie.
- **SFX_29 — Compte à rebours :** Départ d'une mission ou d'un duel.
- **SFX_30 — Victoire / étage terminé :** Signal bref de réussite ; fanfare à choisir séparément.
- **SFX_31 — Défaite :** Sting sombre de fin de mission, à écouter pour le ton.

## Invocation / progression

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_32 | Invocation : charge du cercle | Prototype | [Magic Charge](https://create.roblox.com/store/asset/5696557721) · ID `5696557721` | Ekyuklia | 2,0 s |
| SFX_33 | Invocation : apparition | Prototype | [Magic Glows Soft Clusters Of Chiming Hits 1 (SFX)](https://create.roblox.com/store/asset/9116394545) · ID `9116394545` | ProSoundEffects | 1,4 s |
| SFX_34 | Invocation : rare | Plus tard | [Magic crystal sparkle sound effect 3](https://create.roblox.com/store/asset/132381858621446) · ID `132381858621446` | roblox_user_1996596200 | 4,1 s |
| SFX_35 | Invocation : légendaire | Plus tard | [Magic Burst 1 (SFX)](https://create.roblox.com/store/asset/9116384485) · ID `9116384485` | ProSoundEffects | 3,2 s |
| SFX_36 | Synthèse / absorption | Plus tard | [Magic Tone Falling Shimmer Flanged 3 (SFX)](https://create.roblox.com/store/asset/9116418035) · ID `9116418035` | ProSoundEffects | 3,3 s |
| SFX_37 | Promotion / évolution | Prototype | [Magic Transformation Oscillating Flutter 2 (SFX)](https://create.roblox.com/store/asset/9116426727) · ID `9116426727` | ProSoundEffects | 3,2 s |
| SFX_38 | Nouvelle étoile | Prototype | [Magic Glows Soft Clusters Of Chiming Hits 4 (SFX)](https://create.roblox.com/store/asset/9116395089) · ID `9116395089` | ProSoundEffects | 2,5 s |
| SFX_39 | Niveau gagné | Prototype | [UI - Level Up](https://create.roblox.com/store/asset/112485797063762) · ID `112485797063762` | SodaBreadle | 1,5 s |

- **SFX_32 — Invocation : charge du cercle :** Réutilise la charge magique pendant la montée.
- **SFX_33 — Invocation : apparition :** Carillon lors de l'apparition du héros. Variantes : [Magic Glows Soft Clusters Of Chiming Hits 2 (SFX)](https://create.roblox.com/store/asset/9116394876) (2,0 s).
- **SFX_34 — Invocation : rare :** Cristal et scintillement en couche supplémentaire. Variantes : [Magic crystal sparkle sound effect 2](https://create.roblox.com/store/asset/131722051883127) (5,8 s).
- **SFX_35 — Invocation : légendaire :** Impact magique plus ample, accompagné du carillon.
- **SFX_36 — Synthèse / absorption :** Shimmer descendant pour le transfert d'énergie.
- **SFX_37 — Promotion / évolution :** Libération d'énergie lors du changement de rang. Variantes : [Magic Transformation 6 (SFX)](https://create.roblox.com/store/asset/9116421550) (1,4 s).
- **SFX_38 — Nouvelle étoile :** Carillon au moment où l'étoile s'affiche.
- **SFX_39 — Niveau gagné :** Montée de niveau ordinaire.

## Récompenses / objets

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_40 | Quête terminée | Plus tard | [Quest-Complete!](https://create.roblox.com/store/asset/95148743653937) · ID `95148743653937` | ValtAoi947 | 5,0 s |
| SFX_41 | Or ramassé | Plus tard | [Coin Pickup](https://create.roblox.com/store/asset/113730061669739) · ID `113730061669739` | Narplox | 1,5 s |
| SFX_42 | Ouverture de coffre | Plus tard | [chest open](https://create.roblox.com/store/asset/119461042040425) · ID `119461042040425` | RoyaI_Squire | 0,94 s |
| SFX_43 | Cristal brisé | Plus tard | [Crystal Break](https://create.roblox.com/store/asset/111044884172919) · ID `111044884172919` | jmlopes08 | 1,7 s |

- **SFX_40 — Quête terminée :** Validation d'un objectif.
- **SFX_41 — Or ramassé :** Petite récompense monétaire.
- **SFX_42 — Ouverture de coffre :** Ouverture physique ; ajouter le carillon pour le butin.
- **SFX_43 — Cristal brisé :** Ressource, pierre de synthèse ou objet destructible.

## Base / exploration

| Code | Usage | Priorité | Son proposé et écoute | Créateur | Durée |
|---|---|---|---|---|---|
| SFX_44 | Faille : ambiance | Plus tard | [Portal ambience sound effect](https://create.roblox.com/store/asset/9063726568) · ID `9063726568` | 1nnter | 5,2 s |
| SFX_45 | Téléportation | Prototype | [Portal Teleport](https://create.roblox.com/store/asset/86284095824874) · ID `86284095824874` | Minish1910 | 2,2 s |
| SFX_46 | Vent de l'île | Plus tard | [Desert Wind Whistley Light Gusts 1 (SFX)](https://create.roblox.com/store/asset/9114057104) · ID `9114057104` | ProSoundEffects | 37,4 s |
| SFX_47 | Oiseaux des jardins | Plus tard | [Background Birds Ambience](https://create.roblox.com/store/asset/72220890067268) · ID `72220890067268` | CBE_Simon | 8,5 s |
| SFX_48 | Porte : ouverture | Plus tard | [door-double-wood-open-start](https://create.roblox.com/store/asset/82104982606471) · ID `82104982606471` | Forezzk | 0,86 s |
| SFX_49 | Porte : fermeture | Plus tard | [door-close-wood](https://create.roblox.com/store/asset/111763202035471) · ID `111763202035471` | Forezzk | 1,1 s |
| SFX_50 | Forge : marteau | Plus tard | [Blacksmith Anvil Hammer Hits 16 (SFX)](https://create.roblox.com/store/asset/9113447467) · ID `9113447467` | ProSoundEffects | 1,3 s |
| SFX_51 | Feu / brasero | Plus tard | [Fireplace Constant Burning Flame 1 (SFX)](https://create.roblox.com/store/asset/9112780193) · ID `9112780193` | ProSoundEffects | 36,0 s |
| SFX_52 | Fontaine / eau | Plus tard | [Water Fountain 2 (SFX)](https://create.roblox.com/store/asset/9120557577) · ID `9120557577` | ProSoundEffects | 37,0 s |

- **SFX_44 — Faille : ambiance :** Bourdonnement près du portail ; raccord de boucle à vérifier.
- **SFX_45 — Téléportation :** Passage vers une mission / retour à la base.
- **SFX_46 — Vent de l'île :** Fond léger ; raccord de boucle à vérifier.
- **SFX_47 — Oiseaux des jardins :** Touches naturelles espacées.
- **SFX_48 — Porte : ouverture :** Porte en bois de dortoir ou cantine.
- **SFX_49 — Porte : fermeture :** Fermeture d'une porte.
- **SFX_50 — Forge : marteau :** Coups localisés près de l'enclume. Variantes : [Blacksmith Anvil Hammer Hits 11 (SFX)](https://create.roblox.com/store/asset/9113447116) (1,6 s).
- **SFX_51 — Feu / brasero :** Crépitement local ; boucle annoncée par l'éditeur.
- **SFX_52 — Fontaine / eau :** Ambiance proche d'une fontaine ; raccord à vérifier.

## Séquences proposées

- **Invocation :** SFX_32 charge → SFX_33 apparition → SFX_34 scintillement si rare, ou SFX_35 impact ample si légendaire. Ajuster les couches pour ne pas couvrir le carillon.
- **Promotion :** charge SFX_21 → libération SFX_37 → nouvelle étoile SFX_38. SFX_39 reste réservé au niveau ordinaire.
- **Synthèse :** SFX_36 transfert → confirmation SFX_03. On peut ajouter une touche de carillon si le transfert réussit.
- **Combat :** SFX_09 souffle → SFX_11 uniquement si l'attaque touche, ou SFX_13 si elle est bloquée. Pas de confirmation d'impact sur un coup manqué.
- **Quête / étage :** une confirmation de réussite, puis le ramassage d'or si une récompense est effectivement récupérée ; ne pas empiler tous les jingles.
- **PvP :** SFX_29 compte à rebours → mêmes sons de combat que la tour → victoire ou défaite. Une bibliothèque PvP séparée n'est pas nécessaire au départ.
- **Forge / fabrication :** SFX_50 marteau pour l'action, puis SFX_03 confirmation de réussite. Ajouter ensuite un son spécifique si la fabrication devient une activité importante.

Les sons de coup critique, élimination, changement de phase et récupération de cooldown pourront être choisis après écoute du noyau de combat. L'identité musicale de la base, des combats et des boss est un travail séparé : ce document concerne les effets et ambiances, avec un sting candidat pour la défaite.

## Retour à envoyer

Exemple : « SFX_09 garder ; SFX_11 remplacer, plus sec ; SFX_33 variante 2 ; SFX_37 garder ; SFX_31 trop long. »

