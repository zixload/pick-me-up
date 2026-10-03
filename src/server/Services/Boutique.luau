-- Boutique : remise des achats en Robux (MarketplaceService.ProcessReceipt). Le client affiche la boutique et ouvre
-- la fenêtre d'achat de Roblox ; c'est ici, une fois le paiement confirmé par Roblox, que le contenu est donné.
-- Chaque reçu n'est traité qu'une fois (ses identifiants sont gardés dans le profil). Catalogue : Config/Boutique.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Donnees = require(script.Parent.Donnees)
local Config = require(ReplicatedStorage.Shared.Config.Boutique)
local Materiaux = require(ReplicatedStorage.Shared.Config.Materiaux)

local Boutique = {}
local RECUS_GARDES = 50

local function distant(classe, nom)
	local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
	reseau.Name = "Reseau"
	reseau.Parent = ReplicatedStorage
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end

local function traiterRecu(recu)
	local joueur = Players:GetPlayerByUserId(recu.PlayerId)
	local d = joueur and Donnees.profil(joueur)
	if not d then
		-- joueur parti ou profil pas encore chargé : Roblox représentera le reçu plus tard
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(d.Recus, recu.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local article = Config.parProduit(recu.ProductId)
	if not article then
		warn("[Boutique] produit inconnu : " .. tostring(recu.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = Donnees.modifier(joueur, function(x)
		x.Or += article.contenu.Or or 0
		for id, n in article.contenu.Materiaux or {} do
			if Materiaux.NOMS[id] then x.Materiaux[id] = (x.Materiaux[id] or 0) + n end
		end
		if article.unique then x.Achats[article.id] = true end
		table.insert(x.Recus, recu.PurchaseId)
		while #x.Recus > RECUS_GARDES do table.remove(x.Recus, 1) end
	end)
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Boutique.demarrer()
	local LireAchats = distant("RemoteFunction", "LireAchats")   -- client -> serveur : articles uniques déjà achetés
	LireAchats.OnServerInvoke = function(joueur)
		local d = Donnees.profil(joueur)
		return d and d.Achats or {}
	end
	MarketplaceService.ProcessReceipt = traiterRecu
end

return Boutique
