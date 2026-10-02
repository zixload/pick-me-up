-- La base affichée sur ce serveur est celle de son propriétaire : le premier joueur chargé
-- (plus tard, un serveur privé par joueur). Les visiteurs la voient mais ne l'améliorent pas.
-- Ce service pose les bornes d'amélioration, affiche les paliers selon le profil du propriétaire,
-- valide les demandes d'amélioration et tient les clients au courant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Paliers = require(script.Parent.Parent.Paliers)
local Batiments = require(ReplicatedStorage.Shared.Config.Batiments)
local Regles = require(ReplicatedStorage.Shared.Regles)

local Base = {}
local proprietaire: Player? = nil

-- Communication avec les clients : hors de ReplicatedStorage.Shared, que Rojo synchronise.
local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
reseau.Name = "Reseau"
reseau.Parent = ReplicatedStorage
local function distant(classe, nom)
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end
local EtatBase = distant("RemoteEvent", "EtatBase")        -- serveur -> clients : état de la base
local LireEtat = distant("RemoteFunction", "LireEtat")     -- client -> serveur : état au démarrage
local Ameliorer = distant("RemoteFunction", "Ameliorer")   -- client -> serveur : (lotId) -> ok, message

-- palier de style de chaque lot affiché : selon son niveau pour les bâtiments, selon l'étage de Tour
-- pour les lots automatiques ; ceux du propriétaire, ou ceux de départ s'il n'y en a pas encore
local function paliersVoulus()
	local d = proprietaire and Donnees.profil(proprietaire)
	local t = {}
	for id, lot in Batiments.LOTS do
		t[id] = {Regles.palier(d and d.Batiments[id] or lot.depart), lot.visuels}
	end
	local tour = Regles.palierTour(d and d.Etage or 0)
	for id, lot in Batiments.AUTOMATIQUES do
		t[id] = {tour, lot.visuels}
	end
	return t
end

local function etat()
	local d = proprietaire and Donnees.profil(proprietaire)
	return {
		proprietaireId = proprietaire and proprietaire.UserId or 0,
		proprietaireNom = proprietaire and proprietaire.DisplayName or "",
		donnees = d and {Niveau = d.Niveau, XP = d.XP, Or = d.Or, Etage = d.Etage, Materiaux = d.Materiaux,
			Batiments = d.Batiments} or nil,
	}
end

local function diffuser()
	EtatBase:FireAllClients(etat())
end

-- Affiche chaque lot au palier de son niveau. Avec une origine, les changements sont animés
-- (un seul grondement pour tous les lots) ; un lot en pleine animation est repris juste après.
local function appliquer(origine: Vector3?)
	local son = true
	local aReprendre = false
	for _, voulu in paliersVoulus() do
		local cible, visuels = voulu[1], voulu[2]
		for _, visuel in visuels do
			local p = cible > 0 and Paliers.disponible(visuel, cible) or nil
			if p == nil then
				if Paliers.actuel(visuel) ~= nil and not Paliers.retirer(visuel) then aReprendre = true end
			elseif Paliers.actuel(visuel) ~= p then
				if Paliers.changer(visuel, p, origine, {silencieux = not son}) then
					son = false
				else
					aReprendre = true
				end
			end
		end
	end
	if aReprendre then
		task.delay(5, appliquer)
	end
end

-- une borne invisible avec une invite « Améliorer » au centre de chaque lot
local function poserBornes()
	local dossier = workspace:FindFirstChild("Bornes") or Instance.new("Folder")
	dossier.Name = "Bornes"
	dossier:ClearAllChildren()
	for id, lot in Batiments.LOTS do
		local borne = Instance.new("Part")
		borne.Name = "Borne_" .. id
		borne.Anchored, borne.CanCollide, borne.CanTouch, borne.CanQuery = true, false, false, false
		borne.Transparency = 1
		borne.Size = Vector3.new(2, 4, 2)
		borne.CFrame = CFrame.new(lot.position[1], 3.5, lot.position[2])
		local invite = Instance.new("ProximityPrompt")
		invite.ObjectText = lot.nom
		invite.ActionText = "View"
		invite.HoldDuration = 0.2
		invite.MaxActivationDistance = 18
		invite.RequiresLineOfSight = false
		invite:SetAttribute("LotId", id)
		invite.Parent = borne
		borne.Parent = dossier
	end
	dossier.Parent = workspace
end

local function choisirProprietaire()
	if proprietaire and Donnees.profil(proprietaire) then return end
	proprietaire = nil
	for _, j in Players:GetPlayers() do
		if Donnees.profil(j) then
			proprietaire = j
			break
		end
	end
	appliquer(nil)
	diffuser()
end

function Base.proprietaire(): Player?
	return proprietaire
end

-- réapplique les visuels (après une commande de développement, par exemple) : sans animation,
-- ou en vague à partir d'une origine
function Base.rafraichir(origine: Vector3?)
	appliquer(origine)
	diffuser()
end

function Base.demarrer()
	poserBornes()
	appliquer(nil)   -- base de départ affichée tout de suite, avant même le premier joueur

	Donnees.Change:Connect(function(joueur)
		if proprietaire == nil then
			choisirProprietaire()
		elseif joueur == proprietaire then
			diffuser()
		end
	end)
	Players.PlayerRemoving:Connect(function(joueur)
		if joueur == proprietaire then
			proprietaire = nil
			task.defer(choisirProprietaire)
		end
	end)

	LireEtat.OnServerInvoke = function()
		return etat()
	end

	Ameliorer.OnServerInvoke = function(joueur, lotId)
		if type(lotId) ~= "string" or not Batiments.LOTS[lotId] then
			return false, "Unknown building."
		end
		if joueur ~= proprietaire then
			return false, "Only the owner of this base can upgrade it."
		end
		local d = Donnees.profil(joueur)
		if not d then
			return false, "Your progress hasn't loaded yet."
		end
		local ok, raison, detail = Regles.verifier(d, lotId)
		if not ok then
			return false, raison
		end
		Donnees.modifier(joueur, function(donnees)
			donnees.Or -= detail.cout
			for _, m in detail.materiaux do
				donnees.Materiaux[m[1]] -= m[2]
			end
			donnees.Batiments[lotId] = detail.cible
		end)
		if detail.palierCible ~= detail.palierActuel then
			local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
			appliquer(racine and racine.Position or Vector3.zero)
		end
		local nom = Batiments.LOTS[lotId].nom
		return true, if detail.niveau == 0 then `{nom} built!` else `{nom} upgraded to level {detail.cible}.`
	end
end

return Base
