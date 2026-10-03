-- Inventaire : chaque joueur lit le sien (or, matériaux, équipement) et reçoit les changements.
-- L'état de la base (Base.luau) ne contient que le profil du propriétaire : l'inventaire passe à part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Objets = require(ReplicatedStorage.Shared.Config.Objets)

local Inventaire = {}

local function distant(classe, nom)
	local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
	reseau.Name = "Reseau"
	reseau.Parent = ReplicatedStorage
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end

local function contenu(joueur: Player)
	local d = Donnees.profil(joueur)
	if not d then return nil end
	local objets = {}
	for id, n in d.Materiaux do
		if n > 0 then objets[id] = n end
	end
	for id, n in Objets.EQUIPEMENT_DE_DEPART do
		objets[id] = n
	end
	return {Or = d.Or, Objets = objets}
end

function Inventaire.demarrer()
	local Lire = distant("RemoteFunction", "LireInventaire")      -- client -> serveur : son inventaire
	local Change = distant("RemoteEvent", "InventaireChange")    -- serveur -> client : nouvel inventaire
	Lire.OnServerInvoke = contenu
	Donnees.Change:Connect(function(joueur)
		local c = contenu(joueur)
		if c and joueur.Parent then Change:FireClient(joueur, c) end
	end)
end

return Inventaire
