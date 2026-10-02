-- Démarrage du serveur : profils, base, combat, arène classée, commandes de développement.
local Services = script.Parent.Services

require(Services.Donnees).demarrer()
require(Services.Base).demarrer()
require(Services.Combat).demarrer()
require(Services.Arene).demarrer()
require(Services.Invocations).demarrer()
require(Services.Commandes).demarrer()
