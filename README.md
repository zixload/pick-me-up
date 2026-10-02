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

1. Dans le dossier du dépôt : `rojo serve`.
2. Dans Studio, ouvrir la place « Pick me up! », onglet **Plugins > Rojo > Connect**.
3. Modifier les fichiers de `src/` : Studio se met à jour tout seul. Ne pas modifier ces scripts
   directement dans Studio (Rojo écraserait les changements).

| Dossier | Dans Studio | Contenu |
|---|---|---|
| `src/server` | `ServerScriptService.Serveur` | services : données (ProfileStore), base, commandes ; module `Paliers` |
| `src/shared` | `ReplicatedStorage.Shared` | configuration des bâtiments et de la progression, règles d'amélioration |
| `src/client` | `StarterPlayerScripts.Client` | interface du lobby |

## Tester sans missions

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
