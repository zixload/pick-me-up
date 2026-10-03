-- Mobs (PvE). Modèles dans ServerStorage.Mobs.<Nom> (montés par studio/monter_mob.luau à partir du FBX importé),
-- animations Mixamo converties (blender/mobs/mixamo_vers_roblox.py → export_anims_roblox.py →
-- studio/construire_anims_mob.luau) puis publiées depuis ServerStorage.RBX_ANIMSAVES (clic droit → Save to Roblox).
-- Comportement : se tourne vers là où il va (pas de marche arrière ni de pas de côté), vers sa cible pour frapper ;
-- marche près de sa cible, court quand elle est loin ; cadence des animations calée sur la vitesse réelle.
local Mobs = {}

Mobs.MODELES = {
	Gobelin_Guerrier = {
		nom = "Goblin Warrior",   -- affiché au joueur (anglais)
		-- taille : 1 = modèle tel qu'importé (8,4 studs de haut). La portée et les vitesses ci-dessous sont données
		-- pour la taille 1 et suivent l'échelle (sinon il frapperait de trop loin et ses pas glisseraient).
		echelle = 0.65,           -- ~5,5 studs de haut
		niveau = 3,
		pv = 140,
		degats = 5,
		portee = 6,               -- studs : distance de frappe (modèle de 8,4 studs de haut)
		cadence = 3.4,            -- s entre deux attaques (au moins)
		cadenceHasard = 1.2,      -- s ajoutées au hasard, pour qu'ils ne frappent pas tous ensemble
		moment = 0.95,            -- s après le début de l'attaque où le coup porte
		detection = 70,           -- studs : repère un joueur dans ce rayon
		aggroGroupe = 30,         -- studs : un voisin qui a une cible la transmet à ceux qui sont à cette distance
		vitesseMarche = 9,
		vitesseCourse = 17,
		distanceCourse = 18,      -- au-delà, il court vers sa cible
		espace = 7,               -- studs gardés entre deux mobs (et entre les rangs de la troupe)
		animations = {            -- republiées le 03/10/2026 (bras retransférés, repos Orc Idle)
			Attaque = "rbxassetid://74185717401487",
			Course = "rbxassetid://131891974320320",
			Marche = "rbxassetid://113810250347304",
			Mort = "rbxassetid://132952590478539",
			Relever = "rbxassetid://86250175446197",
			Repos = "rbxassetid://139249373417812",
			Touche = "rbxassetid://84642480322422",
		},
		-- vitesse de lecture des animations d'action (1 = celle de Mixamo) ; le moment du coup suit l'Attaque
		vitesseAnimations = {Touche = 2.0, Attaque = 1.35, Relever = 2.4, Mort = 1.3},
		-- vitesse de déplacement pour laquelle Marche et Course ont été faites (pas qui ne glissent pas)
		cadenceMarche = 9,
		cadenceCourse = 17,
	},
}

return Mobs
