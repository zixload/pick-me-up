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

Combat.ESQUIVE = {
	vitesse = 55,         -- studs/s pendant la poussée
	duree = 0.22,         -- durée de la poussée (s)
	invulnerable = 0.3,   -- durée pendant laquelle aucun coup ne porte (s)
	recharge = 0.9,       -- délai avant la prochaine esquive (s)
}

Combat.REAPPARITION = 4   -- secondes avant de réapparaître après une mort

-- effets de frappe : arrêt sur image pour l'attaquant quand la lame touche, secousse de caméra
Combat.EFFETS = {
	arretImage = 0.07,          -- s pendant lesquelles le geste est presque figé
	secousseFrappe = 0.18,      -- amplitude (studs) quand on touche
	secousseBlessure = 0.35,    -- amplitude quand on est touché
	secousseDuree = 0.18,
}

-- Animations publiées (rbxassetid://…). Tant qu'un identifiant est vide, Studio joue la séquence
-- du même nom rangée dans ReplicatedStorage.Animations (créée par studio/animations_combat.luau) ;
-- en jeu publié, il faut l'identifiant.
Combat.ANIMATIONS = {
	Coup1 = "",
	Coup2 = "",
	Coup3 = "",
	Esquive = "",
}

-- sons choisis dans audio/selection_sfx_v01.md (SFX_09, 10, 11, 12, 15)
Combat.SONS = {
	Souffle = "rbxassetid://134671877618939",
	SouffleLourd = "rbxassetid://6241709963",
	Impact = "rbxassetid://7171761940",
	Blessure = "rbxassetid://127495971181378",
	Esquive = "rbxassetid://124044443087502",
}

-- mannequins de test posés sur le lot de l'Entraînement, en attendant le vrai bâtiment
Combat.MANNEQUINS_TEST = true

return Combat
