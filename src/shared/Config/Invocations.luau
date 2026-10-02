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
	Mage_P1 = {
		classe = "Mage",
		pv = 65,
		degats = 6,           -- à chaque ennemi pris dans l'éclat
		zone = 3,             -- studs : rayon de l'éclat de l'orbe (autour du point où elle éclate)
		portee = 30,
		cadence = 2.4,
		vitesseOrbe = 40,
		vitesse = 14,
	},
	Soigneuse_P1 = {
		classe = "Soigneur",
		pv = 70,
		soin = 9,             -- PV rendus à chaque soin
		portee = 20,
		cadence = 2.2,
		vitesse = 14,
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

-- noms affichés au joueur (anglais) et case par défaut dans la formation, par modèle et par classe
Invocations.NOMS = {
	Tank_P1 = "Rookie Shieldbearer", Archere_P1 = "Rookie Huntress",
	Mage_P1 = "Rookie Mage", Soigneuse_P1 = "Rookie Herbalist",
}
Invocations.DETECTION = 45          -- cherche des cibles dans ce rayon autour de lui

-- Formation : grille vue de dessus autour du héros, choisie à la borne du centre d'entraînement.
-- Colonnes de gauche (1) à droite (5), rangées de l'avant (1) vers l'arrière (4) ; le héros est en (3, 2).
Invocations.FORMATION = {
	colonnes = 5, rangees = 4, ecart = 4.5,   -- studs entre deux cases
	heros = {3, 2},
	defaut = {Tank = {3, 1}, Archer = {2, 3}, Mage = {4, 3}, Soigneur = {3, 4}, Assassin = {5, 2}, Guerrier = {1, 2}},
	borne = Vector3.new(-70, 3.5, -102),      -- borne « Formation » à l'entrée du centre d'entraînement
}

-- Ordres donnés à l'escouade (touches X, C, V) ; noms affichés en anglais
Invocations.ORDRES = {
	{id = "Suivre", nom = "Follow", touche = Enum.KeyCode.X},
	{id = "Maintenir", nom = "Hold", touche = Enum.KeyCode.C},
	{id = "Attaquer", nom = "Attack", touche = Enum.KeyCode.V},
}

-- Comportement en mode Attaquer, par classe (distances en studs)
Invocations.COMPORTEMENT = {
	Archer = {fuite = 8, ideal = 24},          -- s'éloigne si un ennemi arrive à 8, tire de 24
	Mage = {fuite = 9, ideal = 22},
	Soigneur = {fuite = 10, recul = 7},        -- reste 7 studs derrière le centre de l'équipe
}
Invocations.DEFENSE = 4                      -- s après un coup reçu pendant lesquelles on riposte en mode Suivre

-- animations Roblox par défaut (R15), jouées par le serveur
Invocations.ANIMATIONS = {
	repos = "rbxassetid://507766388",
	marche = "rbxassetid://507777826",
	course = "rbxassetid://507767714",
}
-- réactions (animations du héros, publiées, valables pour tout R15) : coup reçu, mise à terre
Invocations.REACTIONS = {
	touche = "rbxassetid://97237406117422",
	mort = "rbxassetid://84467509626244",
}
Invocations.DEPLACEMENT = {
	arrivee = 1.2,         -- studs : s'arrête à cette distance de sa destination
	depart = 2.6,          -- ne repart que si la destination s'éloigne de plus que ça (pas de piétinement)
	rattrapage = 8,        -- au-delà de cette distance de sa case, court pour la rattraper
	vitesseRattrapage = 24,
	rotation = 14,         -- réactivité du demi-tour vers une cible (plus haut = plus vif)
}

-- Animation d'attaque par classe. Tant que l'identifiant est vide, Studio joue la séquence du même nom
-- rangée dans ReplicatedStorage.Animations ; en jeu publié, il faut la publier.
--   moment : s après le début du geste où le coup porte (flèche lâchée, gourdin qui touche)
Invocations.ATTAQUES = {
	Archer = {animation = "rbxassetid://76466347457041", sequence = "ArcTir", moment = 0.88},   -- studio/animations_archere.luau
	Mage = {animation = "", sequence = "BatonSort", moment = 0.6},                               -- studio/mage_p1.luau
	Soigneur = {animation = "", sequence = "BatonSoin", moment = 0.6},                         -- studio/soigneuse_p1.luau
	Tank = {animation = "rbxassetid://77702278343134", sequence = "GourdinFrappe", moment = 0.55},                      -- studio/tank_trellis_p1.luau
}

return Invocations
