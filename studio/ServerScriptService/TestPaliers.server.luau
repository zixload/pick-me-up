-- Outil de test, pas une mécanique du jeu : un bouton sur l'avenue, près du point d'apparition,
-- fait alterner le rempart et le sol entre le palier 1 et le palier 4 avec l'animation de Paliers.
-- Un lot qui n'a pas encore de modèle pour le palier visé reste tel quel.
-- À retirer quand le vrai système d'amélioration (back end) existera.
local SS = game:GetService("ServerStorage")
local Paliers = require(script.Parent.Paliers)
local LOTS = {"Rempart", "Sol"}

local function existe(lot, palier)
	local d = SS.Batiments:FindFirstChild(lot)
	return d and d:FindFirstChild("P" .. palier) ~= nil
end

-- chaque partie de test commence au palier 1, pour voir l'amélioration
for _, lot in LOTS do
	if existe(lot, 1) and Paliers.actuel(lot) ~= 1 then
		Paliers.changer(lot, 1)
	end
end

local borne = Instance.new("Part")
borne.Name = "Borne_Test_Paliers"
borne.Anchored, borne.CanCollide, borne.CanTouch = true, false, false
borne.Transparency = 1
borne.Size = Vector3.new(2, 4, 2)
borne.CFrame = CFrame.new(0, 3, 120)   -- devant le point d'apparition (0, 138)
borne.Parent = workspace

local prompt = Instance.new("ProximityPrompt")
prompt.ObjectText = "Base"
prompt.HoldDuration = 0.4
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = borne

local function maj()
	prompt.ActionText = Paliers.actuel(LOTS[1]) == 4 and "Revenir au palier 1" or "Améliorer (palier 4)"
end
maj()

prompt.Triggered:Connect(function(joueur)
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	local origine = racine and racine.Position or Vector3.zero
	local cible = Paliers.actuel(LOTS[1]) == 4 and 1 or 4
	local son = true
	for _, lot in LOTS do
		if existe(lot, cible) then
			Paliers.changer(lot, cible, origine, {silencieux = not son})
			son = false
		end
	end
	maj()
end)
