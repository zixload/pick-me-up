-- Profils des joueurs, sauvegardés avec ProfileStore (verrou de session : un profil n'est ouvert
-- que sur un serveur à la fois). Contenu : niveau du joueur (combat), expérience, or, étage le plus
-- haut franchi dans la Tour, matériaux, niveau de chaque bâtiment.
-- Dans Studio sans accès aux API, ProfileStore fonctionne mais n'enregistre rien.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Batiments = require(ReplicatedStorage.Shared.Config.Batiments)
local Materiaux = require(ReplicatedStorage.Shared.Config.Materiaux)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)

local MODELE = {
	Version = 2,
	Niveau = 1,
	XP = 0,
	Or = 0,
	Etage = 0,
	Materiaux = {},
	Batiments = {},
}
for id, lot in Batiments.LOTS do
	MODELE.Batiments[id] = lot.depart
end
for _, id in Materiaux.ORDRE do
	MODELE.Materiaux[id] = 0
end

local Store = ProfileStore.New("PMU_Profils_v1", MODELE)
local profils: {[Player]: any} = {}
local change = Instance.new("BindableEvent")

local Donnees = {}
Donnees.Change = change.Event   -- (joueur) : profil chargé ou modifié

-- copie profonde du modèle (pour une remise à zéro)
local function copie(t)
	local c = {}
	for k, v in t do c[k] = if type(v) == "table" then copie(v) else v end
	return c
end

function Donnees.profil(joueur: Player)
	local p = profils[joueur]
	return p and p.Data
end

function Donnees.joueursCharges(): {Player}
	local t = {}
	for j in profils do table.insert(t, j) end
	return t
end

-- applique une modification au profil puis prévient les autres services
function Donnees.modifier(joueur: Player, fn: (any) -> ())
	local p = profils[joueur]
	if not p or not p:IsActive() then return false end
	fn(p.Data)
	change:Fire(joueur)
	return true
end

function Donnees.ajouterXP(joueur: Player, quantite: number)
	return Donnees.modifier(joueur, function(d)
		d.XP += quantite
		while d.Niveau < Progression.NIVEAU_MAX and d.XP >= Progression.xpPourNiveau(d.Niveau) do
			d.XP -= Progression.xpPourNiveau(d.Niveau)
			d.Niveau += 1
		end
	end)
end

function Donnees.reinitialiser(joueur: Player)
	return Donnees.modifier(joueur, function(d)
		local neuf = copie(MODELE)
		for k in d do d[k] = nil end
		for k, v in neuf do d[k] = v end
	end)
end

local function charger(joueur: Player)
	local profil = Store:StartSessionAsync(`Joueur_{joueur.UserId}`, {
		Cancel = function()
			return joueur.Parent ~= Players
		end,
	})
	if not profil then
		joueur:Kick("We couldn't load your progress. Please try again in a moment.")
		return
	end
	profil:AddUserId(joueur.UserId)
	profil:Reconcile()
	-- bâtiments sortis de la liste (Enceinte et Faille suivent la Tour, Salle_Magie devenue Academie_Magie)
	for id in profil.Data.Batiments do
		if not Batiments.LOTS[id] then profil.Data.Batiments[id] = nil end
	end
	for id in profil.Data.Materiaux do
		if not Materiaux.NOMS[id] then profil.Data.Materiaux[id] = nil end
	end
	profil.Data.Version = MODELE.Version
	profil.OnSessionEnd:Connect(function()
		profils[joueur] = nil
		if joueur.Parent == Players then
			joueur:Kick("Your progress was opened on another server.")
		end
	end)
	if joueur.Parent == Players then
		profils[joueur] = profil
		change:Fire(joueur)
	else
		profil:EndSession()
	end
end

function Donnees.demarrer()
	Players.PlayerAdded:Connect(charger)
	for _, j in Players:GetPlayers() do
		task.spawn(charger, j)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		local p = profils[joueur]
		profils[joueur] = nil
		if p then p:EndSession() end
	end)
end

return Donnees
