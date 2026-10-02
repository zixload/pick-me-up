-- Végétation de la base : arbres et buissons du pack « Yasu's Stylized Tree Pack »
-- (ServerStorage.PMU_AssetLibrary, sans script). Exception à la règle « tout dans Blender » :
-- l'utilisateur a demandé des arbres issus des assets Roblox (02/10/2026).
-- Placement en bosquets (bruit), hors des surfaces dallées du plan (×1,5) et loin du rempart.
-- Construit Workspace.Vegetation (relançable, annulable d'un Ctrl+Z).
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ECHELLE = 1.5
local R_ARBRES = 186          -- le rempart est à 210 ; les couronnes ne doivent pas le traverser
local MARGE_ARBRE, MARGE_BUISSON = 10, 4.5
local DIST_ARBRES, DIST_BUISSONS = 17, 7
local NB_ARBRES, NB_BUISSONS = 55, 110

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

-- distance (au sol) à la surface dallée la plus proche ; négative à l'intérieur
local function distancePave(x, z)
	local d = math.huge
	for _, r in RECTS do
		local x0, x1, z0, z1 = r[1] * ECHELLE, r[2] * ECHELLE, r[3] * ECHELLE, r[4] * ECHELLE
		local dx = math.max(x0 - x, 0, x - x1)
		local dz = math.max(z0 - z, 0, z - z1)
		local dr = (dx == 0 and dz == 0) and -1 or math.sqrt(dx * dx + dz * dz)
		d = math.min(d, dr)
	end
	for _, c in DISQUES do
		d = math.min(d, math.sqrt((x - c[1] * ECHELLE) ^ 2 + (z - c[2] * ECHELLE) ^ 2) - c[3] * ECHELLE)
	end
	return d
end

local rec = CHS:TryBeginRecording("Végétation")
local ok, err = pcall(function()
	local pack = SS.PMU_AssetLibrary["Yasu's Stylized Tree Pack"]
	local arbres, buissons = pack.Models_Trees.Models:GetChildren(), pack.Models_Bushes.Models:GetChildren()
	-- les très grands arbres (Tree_20 fait 189 studs) dépasseraient le rempart
	local choix = {}
	for _, a in arbres do
		local _, size = a:GetBoundingBox()
		if size.Y <= 85 then table.insert(choix, a) end
	end

	local ancien = workspace:FindFirstChild("Vegetation")
	if ancien then ancien:Destroy() end
	local veg = Instance.new("Model")
	veg.Name = "Vegetation"
	local fArbres, fBuissons = Instance.new("Folder"), Instance.new("Folder")
	fArbres.Name, fBuissons.Name = "Arbres", "Buissons"
	fArbres.Parent, fBuissons.Parent = veg, veg

	local rng = Random.new(1404)
	local poses = {}
	local function libre(x, z, dmin)
		for _, p in poses do
			-- arbre-arbre 17, arbre-buisson 12, buisson-buisson 7
			if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < ((dmin + p[3]) / 2) ^ 2 then return false end
		end
		return true
	end
	local function planter(source, x, z, echelle, parent)
		local m = source:Clone()
		m:ScaleTo(m:GetScale() * echelle)
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, -(cf.Position.Y - size.Y / 2) - 0.3, 0))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanTouch = true, false, false end
		end
		m.Parent = parent
	end

	-- arbres : en bosquets (bruit basse fréquence), jamais sur les dalles ni contre le rempart
	local n, essais = 0, 0
	while n < NB_ARBRES and essais < 20000 do
		essais += 1
		local a, r = rng:NextNumber(0, 2 * math.pi), R_ARBRES * math.sqrt(rng:NextNumber())
		local x, z = r * math.cos(a), r * math.sin(a)
		local bosquet = math.noise(x / 70, z / 70, 3.1) + 0.5
		if rng:NextNumber() < bosquet and distancePave(x, z) > MARGE_ARBRE and libre(x, z, DIST_ARBRES) then
			planter(choix[rng:NextInteger(1, #choix)], x, z, rng:NextNumber(0.38, 0.55), fArbres)
			table.insert(poses, {x, z, DIST_ARBRES})
			n += 1
		end
	end

	-- buissons : surtout au bord des allées et au pied des bosquets
	local nb, essaisB = 0, 0
	while nb < NB_BUISSONS and essaisB < 20000 do
		essaisB += 1
		local a, r = rng:NextNumber(0, 2 * math.pi), (R_ARBRES + 10) * math.sqrt(rng:NextNumber())
		local x, z = r * math.cos(a), r * math.sin(a)
		local d = distancePave(x, z)
		local bordure = d > MARGE_BUISSON and d < 12
		if (bordure or rng:NextNumber() < 0.25) and d > MARGE_BUISSON and libre(x, z, DIST_BUISSONS) then
			planter(buissons[rng:NextInteger(1, #buissons)], x, z, rng:NextNumber(0.3, 0.5), fBuissons)
			table.insert(poses, {x, z, DIST_BUISSONS})
			nb += 1
		end
	end
	veg.Parent = workspace
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local v = workspace.Vegetation
return string.format("Végétation : %d arbres, %d buissons", #v.Arbres:GetChildren(), #v.Buissons:GetChildren())
