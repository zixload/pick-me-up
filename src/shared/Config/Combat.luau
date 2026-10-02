-- Combat au corps à corps : stats tirées du niveau du joueur, épée de départ, esquive.
-- Premier jet (02/10/2026), à rééquilibrer en jouant. Le serveur fait foi ; le client s'en sert pour
-- jouer les animations au bon rythme.
local Combat = {}

-- le niveau du joueur ne sert qu'au combat : il fixe les points de vie et la force des coups
function Combat.pvMax(niveau: number): number
	return 100 + 12 * (niveau - 1)
end
function Combat.attaque(niveau: number): number
	return 10 + 2 * (niveau - 1)
end

-- Épée : combo de trois coups. Pour chaque coup :
--   multiplicateur : part de l'attaque infligée
--   impact         : délai entre le début du geste et le moment où la lame touche (s)
--   duree          : durée du geste ; le suivant ne part pas avant (s)
--   recul          : poussée sur la cible (mobs et mannequins seulement)
Combat.EPEE = {
	portee = 7.5,        -- studs, depuis le centre du personnage
	demiAngle = 75,      -- degrés de part et d'autre du regard
	fenetreCombo = 0.8,  -- temps après la fin d'un coup pour enchaîner le suivant (s)
	-- gestes « cinéma » : anticipation, frappe sèche, pose figée, retour (studio/animations_combat.luau)
	coups = {
		{animation = "Coup1", multiplicateur = 1.0, impact = 0.34, duree = 0.75, recul = 0, son = "Souffle"},
		{animation = "Coup2", multiplicateur = 1.1, impact = 0.32, duree = 0.75, recul = 0, son = "Souffle"},
		{animation = "Coup3", multiplicateur = 1.8, impact = 0.6, duree = 1.05, recul = 35, son = "SouffleLourd"},
	},
	-- position de l'épée dans la main droite : poignée sous la paume, lame dans le prolongement
	-- du bras, pointe inclinée de 25° vers l'avant
	prise = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-155), 0, 0),
}

-- Bouclier rond sanglé sur l'avant-bras gauche (LeftLowerArm), face vers l'extérieur du bras : au repos
-- il pend contre le flanc, en garde de parade il couvre le buste. Le modèle a son pivot au centre du dos
-- et regarde (LookVector) du côté de sa face. Position calculée sur un R15 avec la pose de parade.
Combat.BOUCLIER = {
	prise = CFrame.new(-0.62, -0.2, 0) * CFrame.Angles(0, math.rad(90), 0),
}

Combat.ESQUIVE = {
	vitesse = 55,         -- studs/s pendant la poussée
	duree = 0.22,         -- durée de la poussée (s)
	invulnerable = 0.3,   -- durée pendant laquelle aucun coup ne porte (s)
	recharge = 0.9,       -- délai avant la prochaine esquive (s)
}

Combat.REAPPARITION = 4   -- secondes avant de réapparaître après une mort

-- touché : on ne peut ni frapper ni esquiver pendant ce temps, et le coup en préparation est perdu.
-- C'est ce qui récompense le premier qui touche, et punit celui qui frappe dans le vide.
Combat.ETOURDISSEMENT = 0.35

-- Parade (F, L2 à la manette) : un coup reçu de face pendant la fenêtre ne fait rien, et l'attaquant
-- est longuement étourdi. Ratée, elle laisse un instant exposé ; elle a une courte recharge.
Combat.PARADE = {
	fenetre = 0.28,          -- s pendant lesquelles un coup de face est paré
	recuperation = 0.25,     -- s après la fenêtre pendant lesquelles on ne peut pas agir
	recharge = 1.0,          -- s avant la parade suivante
	etourdissement = 0.9,    -- s d'étourdissement de l'attaquant paré
	demiAngle = 80,          -- degrés : l'attaquant doit être devant
}

-- effets de frappe : arrêt sur image pour l'attaquant quand la lame touche, secousse de caméra
Combat.EFFETS = {
	arretImage = 0.07,          -- s pendant lesquelles le geste est presque figé
	secousseFrappe = 0.18,      -- amplitude (studs) quand on touche
	secousseBlessure = 0.35,    -- amplitude quand on est touché
	secousseDuree = 0.18,
}

-- Animations publiées (rbxassetid://…). Si un identifiant est vide, Studio joue la séquence du même
-- nom rangée dans ReplicatedStorage.Animations (créée par studio/animations_combat.luau), mais
-- seulement pour soi : les autres joueurs ne la voient pas, et le jeu publié ne la joue pas.
-- Publiées le 02/10/2026 depuis le compte propriétaire du jeu (séquences du 02/10, version « cinéma »).
-- Après une retouche d'une séquence, la republier et remplacer son identifiant ici.
Combat.ANIMATIONS = {
	Coup1 = "rbxassetid://110906412686539",
	Coup2 = "rbxassetid://75486995073874",
	Coup3 = "rbxassetid://120430126845776",   -- republié le 02/10 : tranchant vers le bas
	Esquive = "rbxassetid://84381095727648",
	Touche = "rbxassetid://97237406117422",   -- recul quand on est touché
	Parade = "rbxassetid://116019242952207",  -- bouclier levé devant le buste, épée armée en retrait
	KO = "rbxassetid://84467509626244",       -- à genoux, en arène, jusqu'à la manche suivante (en boucle)
}

-- sons choisis dans audio/selection_sfx_v01.md (SFX_09, 10, 11, 12, 14, 15)
Combat.SONS = {
	Souffle = "rbxassetid://134671877618939",
	SouffleLourd = "rbxassetid://6241709963",
	Impact = "rbxassetid://7171761940",
	Blessure = "rbxassetid://127495971181378",
	Esquive = "rbxassetid://124044443087502",
	Parade = "rbxassetid://9119072674",   -- SFX_14, parade parfaite
}

return Combat
