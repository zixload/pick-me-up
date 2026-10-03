-- Quêtes : avancement dans le profil du joueur, remise à zéro quotidienne et hebdomadaire (4 h, heure de Paris),
-- récompenses réclamées par le joueur. La liste vient de Config/Quetes.
-- Les événements sont détectés ici, sans toucher au code des autres services :
--   * Combat.infliger est enveloppé (comme Arene remplace Combat.surKO) : gobelins vaincus (crédités à tous les
--     joueurs qui les ont frappés), coups sur les mannequins, combo de coups (fenêtre de 3,5 s, comme le HUD) ;
--   * techniques : l'attribut Recharge_<id> du joueur avance quand une technique part ;
--   * ordres d'escouade : seconde écoute du remote OrdreEscouade ;
--   * victoires en arène et améliorations : comparaison du profil à chaque changement (Donnees.Change) ;
--   * inventaire ouvert : signalé par le client (sans enjeu, quête d'histoire).
-- La parade parfaite n'est pas détectable de l'extérieur du combat : sa quête reste désactivée (Config).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Donnees = require(script.Parent.Donnees)
local Combat = require(script.Parent.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Quetes)
local Materiaux = require(ReplicatedStorage.Shared.Config.Materiaux)
local ConfigCombat = require(ReplicatedStorage.Shared.Config.Combat)

local Quetes = {}

local function distant(classe, nom)
	local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
	reseau.Name = "Reseau"
	reseau.Parent = ReplicatedStorage
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end
local LireQuetes = distant("RemoteFunction", "LireQuetes")         -- client -> serveur : état des quêtes
local QuetesChange = distant("RemoteEvent", "QuetesChange")        -- serveur -> client : nouvel état
local ReclamerQuete = distant("RemoteFunction", "ReclamerQuete")   -- client -> serveur : (genre, id) -> ok, message
local SignalQuete = distant("RemoteEvent", "SignalQuete")          -- client -> serveur : action sans enjeu

local FENETRE_COMBO = (ConfigCombat.COMBO_HUD and ConfigCombat.COMBO_HUD.expiration) or 3.5
local hasard = Random.new()

-- ---------------------------------------------------------------- jours et semaines
local function quotidiennesActives()
	local t = {}
	for _, q in Config.QUOTIDIENNES do
		if q.active ~= false then table.insert(t, q) end
	end
	return t
end

-- nouveau jour ou nouvelle semaine : tirage des quotidiennes, remise à zéro des hebdomadaires ; renvoie true si changé
local function renouveler(q): boolean
	local cal = Config.calendrier(os.time())
	local change = false
	if q.Jour ~= cal.jour then
		q.Jour, q.BonusPris = cal.jour, false
		local pool = quotidiennesActives()
		q.Quotidiennes = {}
		for _ = 1, math.min(Config.NB_QUOTIDIENNES, #pool) do
			local quete = table.remove(pool, hasard:NextInteger(1, #pool))
			table.insert(q.Quotidiennes, {id = quete.id, progres = 0, reclamee = false})
		end
		change = true
	end
	if q.Semaine ~= cal.semaine then
		q.Semaine = cal.semaine
		q.Hebdo = {}
		for _, quete in Config.HEBDOMADAIRES do
			q.Hebdo[quete.id] = {progres = 0, reclamee = false}
		end
		change = true
	end
	return change
end

-- état envoyé au client : avancement seulement (le client a la config) et heures des remises à zéro
local function etat(joueur: Player)
	local d = Donnees.profil(joueur)
	if not d then return nil end
	renouveler(d.Quetes)
	local q = d.Quetes
	local cal = Config.calendrier(os.time())
	return {
		quotidiennes = q.Quotidiennes, bonusPris = q.BonusPris, hebdo = q.Hebdo,
		histoire = q.Histoire, histoireProgres = q.HistoireProgres,
		prochainJour = cal.prochainJour, prochaineSemaine = cal.prochaineSemaine,
	}
end

-- envois groupés : un coup sur un mannequin ou un combo font avancer très souvent
local aEnvoyer = {}
local function prevenir(joueur: Player)
	if aEnvoyer[joueur] then return end
	aEnvoyer[joueur] = true
	task.delay(0.4, function()
		aEnvoyer[joueur] = nil
		if joueur.Parent then
			local e = etat(joueur)
			if e then QuetesChange:FireClient(joueur, e) end
		end
	end)
end

-- ---------------------------------------------------------------- avancement
local function avancer(entree, quete, quantite: number, valeur: number?): boolean
	if entree.reclamee or entree.progres >= quete.cible then return false end
	local avant = entree.progres
	if quete.mode == "maximum" then
		entree.progres = math.min(quete.cible, math.max(entree.progres, valeur or quantite))
	else
		entree.progres = math.min(quete.cible, entree.progres + quantite)
	end
	return entree.progres ~= avant
end

-- Un événement s'est produit pour ce joueur. quantite : de combien il avance ; valeur : pour les quêtes
-- « maximum » (longueur d'un combo, niveau d'un bâtiment) ; lot : bâtiment concerné.
function Quetes.signaler(joueur: Player, evenement: string, quantite: number?, valeur: number?, lot: string?)
	local d = Donnees.profil(joueur)
	if not d then return end
	local q = d.Quetes
	local change = renouveler(q)
	local n = quantite or 1
	local quotidiennesFinies = 0
	for _, entree in q.Quotidiennes do
		local quete = Config.trouver(Config.QUOTIDIENNES, entree.id)
		if quete and quete.evenement == evenement then
			local etaitFinie = entree.progres >= quete.cible
			if avancer(entree, quete, n, valeur) then
				change = true
				if not etaitFinie and entree.progres >= quete.cible then quotidiennesFinies += 1 end
			end
		end
	end
	for _, quete in Config.HEBDOMADAIRES do
		local entree = q.Hebdo[quete.id]
		if entree and quete.evenement == evenement and avancer(entree, quete, n, valeur) then change = true end
	end
	local etape = Config.HISTOIRE[q.Histoire]
	if etape and etape.evenement == evenement and (etape.lot == nil or etape.lot == lot) then
		local entree = {progres = q.HistoireProgres, reclamee = false}
		if avancer(entree, etape, n, valeur) then
			q.HistoireProgres = entree.progres
			change = true
		end
	end
	if change then prevenir(joueur) end
	-- les quotidiennes terminées comptent pour l'hebdomadaire « Dedicated Master »
	if quotidiennesFinies > 0 then Quetes.signaler(joueur, "QuotidienneFinie", quotidiennesFinies) end
end

-- l'étape d'histoire en cours peut déjà être remplie (bâtiment déjà au bon niveau) : on la vérifie
local function verifierHistoire(joueur: Player)
	local d = Donnees.profil(joueur)
	local etape = d and Config.HISTOIRE[d.Quetes.Histoire]
	if etape and etape.evenement == "NiveauBatiment" then
		Quetes.signaler(joueur, "NiveauBatiment", 0, d.Batiments[etape.lot] or 0, etape.lot)
	end
end

-- ---------------------------------------------------------------- récompenses
local function donner(joueur: Player, recompense)
	Donnees.modifier(joueur, function(d)
		d.Or += recompense.Or or 0
		for id, n in recompense.Materiaux or {} do
			if Materiaux.NOMS[id] then d.Materiaux[id] = (d.Materiaux[id] or 0) + n end
		end
	end)
	if recompense.XP and recompense.XP > 0 then Donnees.ajouterXP(joueur, recompense.XP) end
end

local function reclamer(joueur: Player, genre: string, id: string)
	local d = Donnees.profil(joueur)
	if not d then return false, "Your progress hasn't loaded yet." end
	local q = d.Quetes
	renouveler(q)
	local recompense
	if genre == "Quotidienne" then
		for _, entree in q.Quotidiennes do
			if entree.id == id then
				local quete = Config.trouver(Config.QUOTIDIENNES, id)
				if not quete or entree.reclamee or entree.progres < quete.cible then return false, "This quest isn't complete." end
				entree.reclamee, recompense = true, quete.recompense
			end
		end
	elseif genre == "Bonus" then
		if q.BonusPris then return false, "Already claimed." end
		for _, entree in q.Quotidiennes do
			if not entree.reclamee then return false, "Claim all daily quests first." end
		end
		q.BonusPris, recompense = true, Config.BONUS_QUOTIDIEN
	elseif genre == "Hebdo" then
		local quete, entree = Config.trouver(Config.HEBDOMADAIRES, id), q.Hebdo[id]
		if not quete or not entree or entree.reclamee or entree.progres < quete.cible then return false, "This quest isn't complete." end
		entree.reclamee, recompense = true, quete.recompense
	elseif genre == "Histoire" then
		local etape = Config.HISTOIRE[q.Histoire]
		if not etape or etape.id ~= id or q.HistoireProgres < etape.cible then return false, "This quest isn't complete." end
		q.Histoire, q.HistoireProgres, recompense = q.Histoire + 1, 0, etape.recompense
	end
	if not recompense then return false, "Unknown quest." end
	donner(joueur, recompense)
	verifierHistoire(joueur)
	prevenir(joueur)
	return true, "Reward claimed!"
end

-- ---------------------------------------------------------------- détection des événements
local frappeurs = setmetatable({}, {__mode = "k"})   -- humanoïde de mob -> {joueur = true}
local combos = {}                                     -- joueur -> {n, dernier}

local function surMobVaincu(modele: Instance, h: Humanoid)
	local nom = modele:GetAttribute("NomAffiche")
	local liste = frappeurs[h]
	frappeurs[h] = nil
	if type(nom) ~= "string" or not liste or not nom:find("Goblin") then return end
	for joueur in liste do
		if joueur.Parent then
			Quetes.signaler(joueur, "Gobelin", 1)
			if nom:find("Blowgunner") then Quetes.signaler(joueur, "Sarbacanier", 1) end
		end
	end
end

local function envelopperCombat()
	local original = Combat.infliger
	Combat.infliger = function(h: Humanoid, degats: number, auteur: Player?, details)
		local avant = h and h.Health or 0
		local modele = h and h.Parent
		local touche = original(h, degats, auteur, details)
		if not modele then return touche end
		local mob = CollectionService:HasTag(modele, "Mob")
		if touche and auteur then
			if mob then
				frappeurs[h] = frappeurs[h] or {}
				frappeurs[h][auteur] = true
			end
			if modele:GetAttribute("P1_AssetSource") == "P1_Mannequin_Entrainement" then
				Quetes.signaler(auteur, "Mannequin", 1)
			end
			local c = combos[auteur]
			local t = os.clock()
			if not c or t - c.dernier > FENETRE_COMBO then
				c = {n = 0, dernier = t}
				combos[auteur] = c
			end
			c.n, c.dernier = c.n + 1, t
			Quetes.signaler(auteur, "Combo", 0, c.n)
		end
		-- le coup fatal peut venir d'une invocation (auteur nil) : tous ceux qui ont frappé le mob sont crédités
		if mob and avant > 0 and h.Health <= 0 then surMobVaincu(modele, h) end
		return touche
	end
end

local derniers = {}   -- joueur -> {victoires, niveaux} : pour repérer duels gagnés et améliorations
local function sommeNiveaux(d): number
	local s = 0
	for _, n in d.Batiments do s += n end
	return s
end

local function surChangement(joueur: Player)
	local d = Donnees.profil(joueur)
	if not d then return end
	local avant = derniers[joueur]
	local maintenant = {victoires = d.Victoires or 0, niveaux = sommeNiveaux(d)}
	derniers[joueur] = maintenant
	if not avant then
		verifierHistoire(joueur)
		prevenir(joueur)
		return
	end
	if maintenant.victoires > avant.victoires then Quetes.signaler(joueur, "Duel", maintenant.victoires - avant.victoires) end
	if maintenant.niveaux > avant.niveaux then
		Quetes.signaler(joueur, "Amelioration", maintenant.niveaux - avant.niveaux)
		verifierHistoire(joueur)
	end
end

local function suivreTechniques(joueur: Player)
	for _, id in ConfigCombat.ORDRE_TECHNIQUES or {} do
		local precedent = joueur:GetAttribute("Recharge_" .. id) or 0
		joueur:GetAttributeChangedSignal("Recharge_" .. id):Connect(function()
			local v = joueur:GetAttribute("Recharge_" .. id) or 0
			-- la recharge avance quand la technique part (elle est remise à 0 en début de manche : ignoré)
			if v > precedent and v > workspace:GetServerTimeNow() then Quetes.signaler(joueur, "Technique", 1) end
			precedent = v
		end)
	end
end

function Quetes.demarrer()
	envelopperCombat()
	LireQuetes.OnServerInvoke = etat
	ReclamerQuete.OnServerInvoke = function(joueur, genre, id)
		if type(genre) ~= "string" or (id ~= nil and type(id) ~= "string") then return false, "Unknown quest." end
		return reclamer(joueur, genre, id or "")
	end
	SignalQuete.OnServerEvent:Connect(function(joueur, quoi)
		if quoi == "Inventaire" then Quetes.signaler(joueur, "Inventaire", 1) end
	end)
	-- seconde écoute des ordres d'escouade (le service Invocations garde la sienne)
	task.spawn(function()
		local ordre = ReplicatedStorage:WaitForChild("Reseau"):WaitForChild("OrdreEscouade", 30)
		if ordre then
			ordre.OnServerEvent:Connect(function(joueur, id)
				if id == "Suivre" or id == "Maintenir" or id == "Attaquer" then Quetes.signaler(joueur, "Ordre", 1) end
			end)
		end
	end)
	Donnees.Change:Connect(surChangement)
	Players.PlayerAdded:Connect(suivreTechniques)
	for _, j in Players:GetPlayers() do suivreTechniques(j) end
	Players.PlayerRemoving:Connect(function(j)
		derniers[j], combos[j], aEnvoyer[j] = nil, nil, nil
	end)
end

return Quetes
