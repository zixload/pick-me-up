-- Démarrage du serveur : profils, base, inventaire, boutique, offres du jour, combat, quêtes, arène classée, invocations, mobs, commandes de développement.
local Services = script.Parent.Services

require(Services.Donnees).demarrer()
require(Services.Base).demarrer()
require(Services.Inventaire).demarrer()
require(Services.Boutique).demarrer()
require(Services.Offres).demarrer()
require(Services.Combat).demarrer()
require(Services.Quetes).demarrer()
require(Services.Arene).demarrer()
require(Services.Invocations).demarrer()
require(Services.Mobs).demarrer()
require(Services.Commandes).demarrer()
