-- Commandes de chat pour tester sans missions. Autorisées dans Studio pour tout le monde,
-- et en jeu publié seulement pour les comptes de DEVELOPPEURS.
-- Les commandes sont en anglais, comme tout ce que voit le joueur :
--   /gold 1000    ajoute de l'or
--   /level 10     fixe le niveau global
--   /xp 250       ajoute de l'expérience (avec les montées de niveau)
--   /reset        remet la progression à zéro (base de départ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Base = require(script.Parent.Base)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)

local DEVELOPPEURS = {
	[11576618213] = true,   -- compte qui développe le jeu dans Studio
}

local Commandes = {}

local function autorise(joueur: Player): boolean
	return RunService:IsStudio() or DEVELOPPEURS[joueur.UserId] == true
end

local function nombre(texte: string): number?
	local n = tonumber(string.match(texte, "%s(-?%d+)"))
	return n
end

local ACTIONS = {
	Or = {"/gold", function(joueur, texte)
		local n = nombre(texte)
		if n then Donnees.modifier(joueur, function(d) d.Or = math.max(0, d.Or + n) end) end
	end},
	Niveau = {"/level", function(joueur, texte)
		local n = nombre(texte)
		if n then
			Donnees.modifier(joueur, function(d)
				d.Niveau = math.clamp(n, 1, Progression.NIVEAU_MAX)
				d.XP = 0
			end)
		end
	end},
	XP = {"/xp", function(joueur, texte)
		local n = nombre(texte)
		if n and n > 0 then Donnees.ajouterXP(joueur, n) end
	end},
	Reset = {"/reset", function(joueur)
		Donnees.reinitialiser(joueur)
		if joueur == Base.proprietaire() then Base.rafraichir() end
	end},
}

function Commandes.demarrer()
	local dossier = TextChatService:FindFirstChild("CommandesPMU") or Instance.new("Folder")
	dossier.Name = "CommandesPMU"
	dossier.Parent = TextChatService
	for nom, action in ACTIONS do
		local c = dossier:FindFirstChild(nom) or Instance.new("TextChatCommand")
		c.Name = nom
		c.PrimaryAlias = action[1]
		c.Parent = dossier
		c.Triggered:Connect(function(source, texte)
			local joueur = Players:GetPlayerByUserId(source.UserId)
			if joueur and autorise(joueur) then
				action[2](joueur, texte)
			end
		end)
	end
end

return Commandes
