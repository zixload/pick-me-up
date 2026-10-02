-- Démarrage du serveur : profils, base, commandes de développement.
local Services = script.Parent.Services

require(Services.Donnees).demarrer()
require(Services.Base).demarrer()
require(Services.Commandes).demarrer()
