-- Invocations : statistiques par modèle (ServerStorage.Invocations.<Nom>). Premier jet du 02/10/2026,
-- pour tester le combat sur les mannequins ; des invocations 1 étoile, donc faibles.
local Invocations = {}

Invocations.MODELES = {
	Archere_P1 = {
		classe = "Archer",
		pv = 80,
		degats = 7,
		portee = 38,          -- studs : distance de tir
		cadence = 1.6,        -- s entre deux flèches
		vitesseFleche = 75,   -- studs/s
		vitesse = 15,
	},
	Tank_P1 = {
		classe = "Tank",
		pv = 160,
		degats = 6,
		portee = 6,
		cadence = 1.4,
		vitesse = 13,
	},
}

Invocations.DISTANCE_SUIVI = 6      -- reste à cette distance de son maître
Invocations.DETECTION = 45          -- cherche des cibles dans ce rayon autour de lui

-- animations Roblox par défaut (R15), jouées par le serveur
Invocations.ANIMATIONS = {
	repos = "rbxassetid://507766388",
	marche = "rbxassetid://507777826",
}

-- Animation d'attaque par classe. Tant que l'identifiant est vide, Studio joue la séquence du même nom
-- rangée dans ReplicatedStorage.Animations ; en jeu publié, il faut la publier.
--   moment : s après le début du geste où le coup porte (flèche lâchée, gourdin qui touche)
Invocations.ATTAQUES = {
	Archer = {animation = "rbxassetid://76466347457041", sequence = "ArcTir", moment = 0.88},   -- studio/animations_archere.luau
	Tank = {animation = "rbxassetid://77702278343134", sequence = "GourdinFrappe", moment = 0.55},                        -- studio/tank_trellis_p1.luau
}

return Invocations
