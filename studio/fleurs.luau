-- Sème les touffes de fleurs du kit Blender (blender/export_p1/Fleurs_P1.fbx) en massifs :
-- surtout le long des allées, quelques-uns dans l'herbe. Les maillages importés sont regroupés
-- par touffe (préfixe Fleurs_A, Fleurs_B…) et rangés dans ServerStorage.Kit_Fleurs.
-- Construit Workspace.Vegetation.Fleurs (relançable, annulable d'un Ctrl+Z).
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ECHELLE = 1.5
local R_MAX = 195
local NB_MASSIFS = 60

local RECTS = {
	{-8, 8, 30, 130}, {-8, 8, -62, -14}, {-76, -22, 2, 14}, {22, 66, 2, 14},
	{-64, -52, -69, 2}, {-64, -52, 14, 40}, {12, 86, -63, -51}, {61, 73, 18, 92},
	{47, 67, 86, 96}, {49, 61, -13, 2}, {44, 56, -76, -63}, {-20, -8, -60, -52},
	{-74, -64, -56, -48}, {-98, -86, 14, 21},
	{-100, -74, -66, -38}, {-101, -75, -25, 3}, {-107, -79, 21, 49}, {21, 47, 78, 106},
	{81, 111, -58, -32}, {-78.5, -33.5, -99.5, -68.5}, {-70, -20, 40, 106}, {40, 70, -41, -13},
	{-33, -11, -112, -90}, {-40, -20, -65, -47}, {36, 64, -104, -76},
}
local DISQUES = {{0, 8, 25}, {78, 29, 24}, {12, -82, 22}}
local COULEURS = {  -- suffixe du maillage -> couleur
	Tige = Color3.fromRGB(72, 122, 52),
	Coeur = Color3.fromRGB(236, 184, 64),
	PetalesBlanc = Color3.fromRGB(246, 244, 236),
	PetalesLilas = Color3.fromRGB(184, 160, 226),
	PetalesJaune = Color3.fromRGB(242, 210, 92),
}

local function distancePave(x, z)
	local d = math.huge
	for _, r in RECTS do
		local dx = math.max(r[1] * ECHELLE - x, 0, x - r[2] * ECHELLE)
		local dz = math.max(r[3] * ECHELLE - z, 0, z - r[4] * ECHELLE)
		d = math.min(d, (dx == 0 and dz == 0) and -1 or math.sqrt(dx * dx + dz * dz))
	end
	for _, c in DISQUES do
		d = math.min(d, math.sqrt((x - c[1] * ECHELLE) ^ 2 + (z - c[2] * ECHELLE) ^ 2) - c[3] * ECHELLE)
	end
	return d
end

local rec = CHS:TryBeginRecording("Fleurs")
local ok, err = pcall(function()
	-- regrouper l'import (une seule fois) en touffes modèles
	local kit = SS:FindFirstChild("Kit_Fleurs")
	local import = workspace:FindFirstChild("Fleurs_P1")
	if import then
		if kit then kit:Destroy() end
		kit = Instance.new("Folder")
		kit.Name = "Kit_Fleurs"
		local touffes = {}
		for _, p in import:GetDescendants() do
			if p:IsA("BasePart") then
				local lettre, sorte = p.Name:match("^Fleurs_(%a)_(%a+)$")
				assert(lettre and COULEURS[sorte], "Maillage inattendu : " .. p.Name)
				local t = touffes[lettre]
				if not t then
					t = Instance.new("Model")
					t.Name = "Touffe_" .. lettre
					t.Parent = kit
					touffes[lettre] = t
				end
				p.Color, p.Material = COULEURS[sorte], Enum.Material.SmoothPlastic
				p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
				p.Parent = t
			end
		end
		for _, t in kit:GetChildren() do  -- pivot au sol, au centre de la touffe
			local cf, size = t:GetBoundingBox()
			t.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		end
		kit.Parent = SS
		import:Destroy()
	end
	assert(kit, "Importe d'abord blender/export_p1/Fleurs_P1.fbx (modèle Fleurs_P1 dans Workspace).")
	local modeles = kit:GetChildren()

	local veg = workspace:FindFirstChild("Vegetation") or Instance.new("Model")
	veg.Name, veg.Parent = "Vegetation", workspace
	local ancien = veg:FindFirstChild("Fleurs")
	if ancien then ancien:Destroy() end
	local dossier = Instance.new("Folder")
	dossier.Name = "Fleurs"

	-- massifs : un centre, puis 3 à 8 touffes serrées autour, d'une ou deux variantes
	local rng = Random.new(512)
	local massifs, essais = 0, 0
	while massifs < NB_MASSIFS and essais < 5000 do
		essais += 1
		local a, r = rng:NextNumber(0, 2 * math.pi), R_MAX * math.sqrt(rng:NextNumber())
		local cx, cz = r * math.cos(a), r * math.sin(a)
		local d = distancePave(cx, cz)
		local bordAllee = d > 3 and d < 9
		if bordAllee or (d > 3 and rng:NextNumber() < 0.2) then
			massifs += 1
			local v1, v2 = modeles[rng:NextInteger(1, #modeles)], modeles[rng:NextInteger(1, #modeles)]
			for _ = 1, rng:NextInteger(3, 8) do
				local x, z = cx + rng:NextNumber(-4, 4), cz + rng:NextNumber(-4, 4)
				if distancePave(x, z) > 2.5 then
					local t = (rng:NextNumber() < 0.7 and v1 or v2):Clone()
					t:PivotTo(CFrame.new(x, -0.05, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
					t:ScaleTo(rng:NextNumber(0.9, 1.4))
					t.Parent = dossier
				end
			end
		end
	end
	dossier.Parent = veg
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return "Fleurs : " .. #workspace.Vegetation.Fleurs:GetChildren() .. " touffes semées"
