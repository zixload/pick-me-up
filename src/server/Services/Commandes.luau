-- Commandes de chat pour tester sans missions. Autorisées dans Studio pour tout le monde,
-- et en jeu publié seulement pour les comptes de DEVELOPPEURS.
-- Les commandes sont en anglais, comme tout ce que voit le joueur :
--   /gold 1000         ajoute de l'or
--   /level 10          fixe le niveau du joueur (combat : points de vie et force des coups)
--   /xp 250            ajoute de l'expérience (avec les montées de niveau)
--   /floor 10          fixe l'étage le plus haut franchi dans la Tour (le rempart, le sol et la faille suivent)
--   /give 100          ajoute 100 de chaque matériau
--   /give silver 50    ajoute 50 d'un matériau (début de son nom, sans espace : bluestone, night, silver…)
--   /reset             remet la progression à zéro (base de départ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Base = require(script.Parent.Base)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Materiaux = require(ReplicatedStorage.Shared.Config.Materiaux)

local DEVELOPPEURS = {
	[11576618213] = true,   -- compte qui développe le jeu dans Studio
	[2347643521] = true,    -- Daichisback, troisième membre du projet (02/10/2026)
	[11576651022] = true,   -- camé (t1mts), membre du projet (02/10/2026)
}

local Commandes = {}

local function autorise(joueur: Player): boolean
	return RunService:IsStudio() or DEVELOPPEURS[joueur.UserId] == true
end
Commandes.autorise = autorise   -- utilisé par les autres commandes de test (/goblins dans Mobs)

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
	Etage = {"/floor", function(joueur, texte)
		local n = nombre(texte)
		if n then
			Donnees.modifier(joueur, function(d) d.Etage = math.max(0, n) end)
			if joueur == Base.proprietaire() then
				local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
				Base.rafraichir(racine and racine.Position or Vector3.zero)
			end
		end
	end},
	Materiaux = {"/give", function(joueur, texte)
		local n = nombre(texte)
		if not n then return end
		local nom = string.match(texte, "^%S+%s+(%a+)")
		local cibles = {}
		for _, id in Materiaux.ORDRE do
			local sansEspace = Materiaux.NOMS[id]:gsub("%s", ""):lower()
			if not nom or sansEspace:sub(1, #nom) == nom:lower() then table.insert(cibles, id) end
		end
		Donnees.modifier(joueur, function(d)
			for _, id in cibles do d.Materiaux[id] = math.max(0, (d.Materiaux[id] or 0) + n) end
		end)
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
