-- Éclairage de la base : jour de début d'après-midi, légèrement chaud, un seul ciel.
-- L'ancien éclairage (effets de Codex, 12 ciels et 2 atmosphères empilés) est rangé dans
-- ServerStorage.Eclairage_Ancien avec ses réglages en attributs, pas supprimé.
-- Relançable, annulable d'un Ctrl+Z. Lighting.Technology n'est pas modifiable par script :
-- le régler à la main sur Future (Properties de Lighting).
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local L = game:GetService("Lighting")

local REGLAGES = {
	ClockTime = 14.5,
	GeographicLatitude = 35,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(96, 99, 106),
	OutdoorAmbient = Color3.fromRGB(128, 130, 136),
	ExposureCompensation = 0,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	GlobalShadows = true,
	ShadowSoftness = 0.25,
}

local rec = CHS:TryBeginRecording("Éclairage de la base")
local ok, err = pcall(function()
	-- ranger l'ancien éclairage (une seule fois)
	if not SS:FindFirstChild("Eclairage_Ancien") then
		local ancien = Instance.new("Folder")
		ancien.Name = "Eclairage_Ancien"
		for k in REGLAGES do ancien:SetAttribute(k, L[k]) end
		for _, c in L:GetChildren() do c.Parent = ancien end
		ancien.Parent = SS
	else
		for _, c in L:GetChildren() do c:Destroy() end
	end

	for k, v in REGLAGES do L[k] = v end

	local ciel = Instance.new("Sky")        -- ciel de Roblox par défaut
	ciel.Name = "Ciel_Jour"
	ciel.SunAngularSize = 11
	ciel.CelestialBodiesShown = true
	ciel.Parent = L

	local atmo = Instance.new("Atmosphere")
	atmo.Name = "Atmosphere_Jour"
	atmo.Density = 0.28
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(199, 210, 220)
	atmo.Decay = Color3.fromRGB(106, 120, 140)
	atmo.Glare = 0.15
	atmo.Haze = 1
	atmo.Parent = L

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Etalonnage_Jour"
	cc.Saturation = 0.08
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 242)
	cc.Parent = L

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bloom_Jour"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = L

	local rayons = Instance.new("SunRaysEffect")
	rayons.Name = "Rayons_Jour"
	rayons.Intensity = 0.05
	rayons.Spread = 0.6
	rayons.Parent = L
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local t = {}
for _, c in L:GetChildren() do table.insert(t, c.Name) end
return "Lighting : " .. table.concat(t, ", ") .. " | ancien éclairage : " .. #SS.Eclairage_Ancien:GetChildren() .. " objets rangés"
