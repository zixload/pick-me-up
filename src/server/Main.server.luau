-- Démarrage du serveur : profils, base, combat, commandes de développement.
local Services = script.Parent.Services

require(Services.Donnees).demarrer()
require(Services.Base).demarrer()
require(Services.Combat).demarrer()
require(Services.Commandes).demarrer()
