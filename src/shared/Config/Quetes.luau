-- Quêtes (liste validée le 03/10/2026) : quotidiennes tirées au hasard, hebdomadaires, histoire (tutoriel).
-- Les quêtes sont pour l'instant la seule vraie source d'or, d'XP et de matériaux : les montants fixent le rythme
-- des améliorations (Smithy niveau 2 : 250 or). Tout texte affiché est en anglais.
-- Champs d'une quête :
--   evenement : ce qui la fait avancer (signalé par Services/Quetes) ; cible : nombre à atteindre
--   mode      : "cumul" (par défaut, on additionne) ou "maximum" (meilleure valeur atteinte, ex. combo)
--   recompense: {Or, XP, Materiaux = {id = n}}
--   active    : false tant que l'événement n'est pas détectable (exclue du tirage)
local Quetes = {}

Quetes.HEURE_REMISE = 4          -- heure de Paris de la remise à zéro quotidienne (et du lundi pour l'hebdo)
Quetes.NB_QUOTIDIENNES = 4
Quetes.BONUS_QUOTIDIEN = {Or = 200, Materiaux = {Bluestone = 10}}

Quetes.QUOTIDIENNES = {
	{id = "ChasseGobelins", nom = "Goblin Hunt", objectif = "Defeat goblins", evenement = "Gobelin", cible = 15,
		lieu = "Outside the rampart", recompense = {Or = 150, XP = 40},
		description = "Goblin troops keep probing the walls of the base. Thin their ranks before they grow bold."},
	{id = "Sarbacanes", nom = "Silence the Blowguns", objectif = "Defeat Goblin Blowgunners", evenement = "Sarbacanier", cible = 5,
		lieu = "Outside the rampart", recompense = {Or = 120, Materiaux = {Timber = 5}},
		description = "The blowgunners stay behind their friends and pick off anyone who comes close. Reach them first."},
	{id = "GardeParfaite", nom = "Perfect Guard", objectif = "Land perfect parries", evenement = "Parade", cible = 3,
		lieu = "Any fight", recompense = {Or = 100, XP = 30}, active = false,
		description = "Raise your shield at the very last moment and leave your attacker reeling."},
	{id = "RythmeLame", nom = "Blade Rhythm", objectif = "Reach a hit combo", evenement = "Combo", mode = "maximum", cible = 20,
		lieu = "Any fight", recompense = {Or = 100, XP = 30},
		description = "Keep the pressure on: chain your strikes without letting the count drop."},
	{id = "Techniques", nom = "Master's Techniques", objectif = "Use Sky Cleave or Blade Storm", evenement = "Technique", cible = 10,
		lieu = "Any fight", recompense = {Or = 80, Materiaux = {Bluestone = 4}},
		description = "A master who never draws on their techniques is wasting half their training."},
	{id = "Exercice", nom = "Drill Practice", objectif = "Strike the training dummies", evenement = "Mannequin", cible = 30,
		lieu = "Training Center", recompense = {Or = 80, XP = 20},
		description = "The dummies at the Training Center never complain. Work your combos on them."},
	{id = "Arene", nom = "Arena Challenger", objectif = "Win an arena duel", evenement = "Duel", cible = 1,
		lieu = "Arena", recompense = {Or = 200, XP = 50},
		description = "Step into the ranked arena and prove your blade against another master."},
	{id = "Batisseur", nom = "Builder's Duty", objectif = "Upgrade any building", evenement = "Amelioration", cible = 1,
		lieu = "Your base", recompense = {Materiaux = {Bluestone = 5, Timber = 5}},
		description = "A base that stops growing starts falling apart. Raise one of your buildings."},
	{id = "Escouade", nom = "Squad Leader", objectif = "Give orders to your squad", evenement = "Ordre", cible = 5,
		lieu = "Anywhere", recompense = {Or = 60, XP = 20},
		description = "Follow, hold, attack: a squad is only as good as the orders it receives."},
}

Quetes.HEBDOMADAIRES = {
	{id = "PurgeGobelins", nom = "Goblin Purge", objectif = "Defeat goblins", evenement = "Gobelin", cible = 100,
		lieu = "Outside the rampart", recompense = {Or = 800, Materiaux = {Bluestone = 20, Timber = 20}},
		description = "Clear the lands around the base for good. At least for this week."},
	{id = "HabitueArene", nom = "Arena Regular", objectif = "Win arena duels", evenement = "Duel", cible = 5,
		lieu = "Arena", recompense = {Or = 1000, XP = 100},
		description = "One win is luck. Five is a reputation."},
	{id = "MaitreBatisseur", nom = "Master Builder", objectif = "Upgrade buildings", evenement = "Amelioration", cible = 3,
		lieu = "Your base", recompense = {Materiaux = {Timber = 30, Bluestone = 30}},
		description = "Keep the craftsmen busy: three upgrades in a single week."},
	{id = "MaitreAssidu", nom = "Dedicated Master", objectif = "Complete daily quests", evenement = "QuotidienneFinie", cible = 20,
		lieu = "Anywhere", recompense = {Or = 500, Materiaux = {NightBasalt = 5}},
		description = "Show up every day. The Tower rewards those who do."},
}

-- histoire, chapitre 1 : une étape à la fois, chacune débloque la suivante
Quetes.CHAPITRE = "A New Master"
Quetes.HISTOIRE = {
	{id = "H1", nom = "A Bag of One's Own", objectif = "Open your inventory", evenement = "Inventaire", cible = 1,
		lieu = "Your base", recompense = {Or = 50},
		description = "Every master keeps track of what they own. Open your inventory (B) and take stock."},
	{id = "H2", nom = "Sparks at the Forge", objectif = "Upgrade the Smithy to Lv. 2", evenement = "NiveauBatiment", lot = "Forge",
		cible = 2, mode = "maximum", lieu = "Smithy", recompense = {Or = 100, Materiaux = {Timber = 5}},
		description = "The Smithy is the heart of the crafting quarter. Visit its plot and raise it to level 2."},
	{id = "H3", nom = "Fall In!", objectif = "Give an order to your squad", evenement = "Ordre", cible = 1,
		lieu = "Anywhere", recompense = {Or = 100, XP = 30},
		description = "Gather your summons and give them their first order. They are waiting for your voice."},
	{id = "H4", nom = "The First Troop", objectif = "Defeat goblins", evenement = "Gobelin", cible = 10,
		lieu = "Outside the rampart", recompense = {Or = 200, Materiaux = {Bluestone = 10}},
		description = "A goblin troop has been seen near the walls. Show them whose base this is."},
	{id = "H5", nom = "Into the Arena", objectif = "Win an arena duel", evenement = "Duel", cible = 1,
		lieu = "Arena", recompense = {Or = 300, XP = 100},
		description = "Other masters are watching. Win your first duel and make your name known."},
}

-- ---------------------------------------------------------------- jours et semaines de jeu (heure de Paris)
-- dernier dimanche d'un mois, à 1 h UTC (passage à l'heure d'été en mars, retour en octobre)
local function dernierDimanche(annee: number, mois: number): number
	for jour = 31, 22, -1 do
		local ok, dt = pcall(DateTime.fromUniversalTime, annee, mois, jour, 1)
		if ok and dt then
			local t = dt.UnixTimestamp
			local d = os.date("!*t", t)
			if d.month == mois and d.wday == 1 then return t end
		end
	end
	return 0
end

-- décalage de Paris sur UTC (secondes) à l'instant t
function Quetes.decalageParis(t: number): number
	local annee = os.date("!*t", t).year
	if t >= dernierDimanche(annee, 3) and t < dernierDimanche(annee, 10) then return 7200 end
	return 3600
end

-- clé du jour de jeu, clé de la semaine (son lundi) et heures (unix) des prochaines remises à zéro
function Quetes.calendrier(t: number)
	local decalage = Quetes.decalageParis(t)
	local s = t + decalage - Quetes.HEURE_REMISE * 3600     -- temps « de jeu » : la journée commence à 4 h
	local debutJour = s - s % 86400
	local d = os.date("!*t", s)
	local depuisLundi = (d.wday + 5) % 7
	local lundi = debutJour - depuisLundi * 86400
	local retour = Quetes.HEURE_REMISE * 3600 - decalage
	return {
		jour = os.date("!%Y-%m-%d", s),
		semaine = os.date("!%Y-%m-%d", lundi),
		prochainJour = debutJour + 86400 + retour,
		prochaineSemaine = lundi + 7 * 86400 + retour,
	}
end

-- recherche d'une quête par son id, dans une liste
function Quetes.trouver(liste, id: string)
	for _, q in liste do
		if q.id == id then return q end
	end
	return nil
end

return Quetes
