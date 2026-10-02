-- Insigne de rang de l'arène classée : losange au dégradé de la couleur du rang, cœur sombre,
-- étoiles du rang (clin d'œil aux étoiles des héros) et ruban de division (III, II, I).
-- Les rangs Gold et au-dessus ont un reflet qui tourne ; Seven Star est irisé.
-- Construit en interface Roblox, sans image : à remplacer plus tard par de vrais logos si besoin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arene = require(ReplicatedStorage:WaitForChild("Shared").Config.Arene)

local Insigne = {}

local SOMBRE = Color3.fromRGB(18, 24, 36)

local function coin(parent, rayon)
	local c = Instance.new("UICorner")
	c.CornerRadius = rayon
	c.Parent = parent
end

-- Crée un insigne carré de côté `taille` (pixels). Renvoie {cadre, maj(cote) -> rang}.
function Insigne.creer(parent: Instance, taille: number)
	local cadre = Instance.new("Frame")
	cadre.Name = "Insigne"
	cadre.BackgroundTransparency = 1
	cadre.Size = UDim2.fromOffset(taille, taille)
	cadre.Parent = parent

	local exterieur = Instance.new("Frame")
	exterieur.AnchorPoint, exterieur.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.46)
	exterieur.Size = UDim2.fromScale(0.68, 0.68)
	exterieur.Rotation = 45
	exterieur.BackgroundColor3 = Color3.new(1, 1, 1)
	exterieur.Parent = cadre
	coin(exterieur, UDim.new(0.14, 0))
	local degrade = Instance.new("UIGradient")
	degrade.Parent = exterieur
	local trait = Instance.new("UIStroke")
	trait.Thickness = math.max(1.5, taille / 28)
	trait.Parent = exterieur

	local coeur = Instance.new("Frame")
	coeur.AnchorPoint, coeur.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	coeur.Size = UDim2.fromScale(0.66, 0.66)
	coeur.BackgroundColor3 = SOMBRE
	coeur.Parent = exterieur
	coin(coeur, UDim.new(0.12, 0))
	local traitCoeur = Instance.new("UIStroke")
	traitCoeur.Thickness = math.max(1, taille / 44)
	traitCoeur.Parent = coeur

	local etoiles = Instance.new("TextLabel")
	etoiles.AnchorPoint, etoiles.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45)
	etoiles.Size = UDim2.fromScale(0.42, 0.42)
	etoiles.BackgroundTransparency = 1
	etoiles.Font, etoiles.TextScaled, etoiles.RichText = Enum.Font.GothamBlack, true, true
	etoiles.Parent = cadre

	local ruban = Instance.new("Frame")
	ruban.AnchorPoint, ruban.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.86)
	ruban.Size = UDim2.fromScale(0.5, 0.2)
	ruban.Parent = cadre
	coin(ruban, UDim.new(0.3, 0))
	local traitRuban = Instance.new("UIStroke")
	traitRuban.Thickness = math.max(1, taille / 50)
	traitRuban.Parent = ruban
	local division = Instance.new("TextLabel")
	division.BackgroundTransparency, division.Size = 1, UDim2.fromScale(1, 1)
	division.Font, division.TextScaled = Enum.Font.GothamBlack, true
	division.TextColor3 = Color3.new(1, 1, 1)
	division.Parent = ruban
	local marge = Instance.new("UIPadding")
	marge.PaddingTop, marge.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	marge.Parent = division

	-- reflet tournant pour les hauts rangs
	local tourne = false
	local lien = RunService.RenderStepped:Connect(function(dt)
		if tourne and cadre.Parent then degrade.Rotation = (degrade.Rotation + dt * 60) % 360 end
	end)
	cadre.Destroying:Connect(function() lien:Disconnect() end)

	local function maj(cote: number)
		local r = Arene.rang(cote)
		if r.indice == #Arene.RANGS then
			degrade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, r.clair), ColorSequenceKeypoint.new(0.5, r.sombre),
				ColorSequenceKeypoint.new(1, r.clair)})
		else
			degrade.Color = ColorSequence.new(r.clair, r.sombre)
		end
		tourne = r.indice >= 4
		if not tourne then degrade.Rotation = 90 end
		trait.Color, traitCoeur.Color = r.clair, r.sombre
		-- étoiles : une grande, et le nombre d'étoiles du rang en petit dessous
		local petites = string.rep("★", math.min(r.etoiles, 7))
		local hex = "#" .. r.clair:ToHex()
		etoiles.Text = `<font color="{hex}">★</font>`
			.. `\n<font size="{math.floor(taille / 9)}" color="{hex}">{petites}</font>`
		etoiles.TextScaled = false
		etoiles.TextSize = math.floor(taille / 3.2)
		ruban.Visible = r.division ~= ""
		ruban.BackgroundColor3, traitRuban.Color = r.sombre, r.clair
		division.Text = r.division
		return r
	end

	return {cadre = cadre, maj = maj}
end

return Insigne
