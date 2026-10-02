# Pick me up — jeu Roblox

Lobby de héros inspiré du webtoon *Pick Me Up*. Le code vit dans ce dépôt et se synchronise avec
Roblox Studio grâce à [Rojo](https://rojo.space) ; les modèles 3D se font dans Blender et restent
dans la place Roblox.

## Installer les outils (une fois par machine)

1. Installer [Rokit](https://github.com/rojo-rbx/rokit) (gestionnaire d'outils Roblox) : télécharger
   `rokit-…-windows-x86_64.zip` dans les releases, puis lancer `rokit.exe self-install`.
2. Dans le dossier du dépôt : `rokit install`. Cela installe la version de Rojo fixée dans `rokit.toml`.
3. `rojo plugin install` : installe le plugin Rojo dans Studio (redémarrer Studio ensuite).

## Travailler sur le code

1. Modifier et vérifier les fichiers de `src/`, puis faire un commit et un push sur GitHub.
2. Le collaborateur récupère les changements avec `git pull`, puis lance `rojo serve` dans son dépôt.
3. Sur son poste, dans Studio : **Plugins > Rojo > Connect**, serveur `localhost:34872`.
4. Arrêter puis relancer Play pour charger les nouveaux scripts.

Ne pas supposer que la place ouverte sur ce poste est synchronisée. L'autorisation HTTP
du plugin ne prouve pas une connexion Rojo active. Avant de synchroniser, conserver dans
Git les changements de scripts présents uniquement dans Studio, sinon ils risquent d'être
écrasés par les fichiers du dépôt. Les modèles 3D restent dans la place collaborative.

| Dossier | Dans Studio | Contenu |
|---|---|---|
| `src/server` | `ServerScriptService.Serveur` | services : données (ProfileStore), base, commandes ; module `Paliers` |
| `src/shared` | `ReplicatedStorage.Shared` | configuration des bâtiments et de la progression, règles d'amélioration |
| `src/client` | `StarterPlayerScripts.Client` | interface du lobby |

## Tester sans missions

Course : maintenir Shift gauche ou droit en se déplaçant (26 studs/s au lieu de 16).
Relâcher Shift revient à la marche. Les vitesses et animations R15/R6 sont définies
dans `src/shared/Config/Deplacement.luau`. La course utilise les animations Roblox
par défaut ; les attaques conservent leur ralentissement et leur priorité d'animation.
Shift est réservé à la course ; le verrouillage souris reste sur Ctrl.
Après synchronisation Rojo, relancer le test pour charger le nouveau LocalScript.

Commandes de chat (Studio, ou comptes listés dans `src/server/Services/Commandes.luau`) :
`/gold 1000`, `/level 10`, `/xp 250`, `/reset`. Tout texte visible par le joueur est en anglais ;
le code et ses commentaires restent en français.

Dans Studio, la progression n'est enregistrée que si **Game Settings > Security > Enable Studio
Access to API Services** est activé.

## Autres dossiers

- `blender/` : scripts Blender qui génèrent les kits (rempart, sol, faille…), exports FBX et aperçus.
- `studio/` : scripts d'assemblage à coller dans la barre de commande de Studio après un import FBX.
- `docs/plan_base.html` : plan directeur de la base.
- `licences/` : licences des modules tiers (ProfileStore, Apache 2.0, intégré dans `src/server/Packages`).
