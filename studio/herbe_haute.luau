-- Sème les touffes d'herbe haute du kit Blender (blender/export_p1/Herbe_Haute_P1.fbx) par plaques :
-- la hauteur des brins du Terrain étant globale, ce sont elles qui font varier la hauteur de l'herbe.
-- Les maillages importés (HerbeHaute_A/B/C) sont rangés dans ServerStorage.Kit_Herbe_Haute.
-- Construit Workspace.Vegetation.HerbeHaute, posée sur le relief (relançable, annulable d'un Ctrl+Z).
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ECHELLE = 1.5
local R_MAX = 200
local PAS = 4.5               -- espacement de la grille de semis (studs) : ~1 500 touffes, ~0,5 M triangles
local COULEURS = {
	A = Color3.fromRGB(90, 144, 62),
	B = Color3.fromRGB(106, 156, 70),
	C = Color3.fromRGB(82, 132, 56),
}

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

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.Terrain}
local function sol(x, z)
	local r = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
	return r and r.Position.Y or 0
end

local rec = CHS:TryBeginRecording("Herbe haute")
local ok, err = pcall(function()
	-- ranger l'import (une seule fois) : une touffe = un maillage, pivot au sol au centre
	local kit = SS:FindFirstChild("Kit_Herbe_Haute")
	local import = workspace:FindFirstChild("Herbe_Haute_P1")
	if import then
		if kit then kit:Destroy() end
		kit = Instance.new("Folder")
		kit.Name = "Kit_Herbe_Haute"
		for _, p in import:GetDescendants() do
			if p:IsA("BasePart") then
				local lettre = p.Name:match("^HerbeHaute_(%a)$")
				assert(lettre and COULEURS[lettre], "Maillage inattendu : " .. p.Name)
				local t = Instance.new("Model")
				t.Name = "Touffe_" .. lettre
				p.Color, p.Material = COULEURS[lettre], Enum.Material.SmoothPlastic
				p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
				p.Parent = t
				local cf, size = t:GetBoundingBox()
				t.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
				t.Parent = kit
			end
		end
		kit.Parent = SS
		import:Destroy()
	end
	assert(kit, "Importe d'abord blender/export_p1/Herbe_Haute_P1.fbx (modèle Herbe_Haute_P1 dans Workspace).")
	local modeles = kit:GetChildren()

	local veg = workspace:FindFirstChild("Vegetation") or Instance.new("Model")
	veg.Name, veg.Parent = "Vegetation", workspace
	local ancien = veg:FindFirstChild("HerbeHaute")
	if ancien then ancien:Destroy() end
	local dossier = Instance.new("Folder")
	dossier.Name = "HerbeHaute"

	-- grille légèrement désordonnée ; densité par plaques (bruit), plus haute au cœur des plaques
	local rng = Random.new(808)
	for gx = -R_MAX, R_MAX, PAS do
		for gz = -R_MAX, R_MAX, PAS do
			local x, z = gx + rng:NextNumber(-1.2, 1.2), gz + rng:NextNumber(-1.2, 1.2)
			if x * x + z * z < R_MAX * R_MAX and distancePave(x, z) > 2.5 then
				local plaque = math.noise(x / 40, z / 40, 9.3) + 0.15
				if plaque > 0 and rng:NextNumber() < math.min(plaque * 2.2, 0.75) then
					local y = sol(x, z)
					local t = modeles[rng:NextInteger(1, #modeles)]:Clone()
					t:PivotTo(CFrame.new(x, y - 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
					t:ScaleTo(0.8 + math.min(plaque, 0.6) * 1.2 + rng:NextNumber(-0.15, 0.15))
					t:SetAttribute("SolY", y)
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
return "Herbe haute : " .. #workspace.Vegetation.HerbeHaute:GetChildren() .. " touffes semées"
