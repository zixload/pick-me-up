-- Terrain d'herbe de la base et point d'apparition, à l'échelle du plan (agrandi de 1,5 le 01/10/2026).
-- Sous les surfaces dallées, l'herbe devient de l'herbe rase : les brins du Terrain traversent les dalles.
-- Relançable, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local ECHELLE = 1.5
local R_HERBE = 310          -- l'enceinte (rayon 210) et ses abords, quai du dirigeable compris
local MARGE = 3              -- les bordures du dallage P1 débordent d'environ 2,5 studs
local SPAWN_Z = 92           -- échelle 1, sur l'avenue sud

-- surfaces dallées du plan (échelle 1) : rectangles {x0, x1, z0, z1} et disques {x, z, r}
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

local function pave(x, z)
	for _, r in RECTS do
		if x >= r[1] * ECHELLE - MARGE and x <= r[2] * ECHELLE + MARGE
			and z >= r[3] * ECHELLE - MARGE and z <= r[4] * ECHELLE + MARGE then
			return true
		end
	end
	for _, d in DISQUES do
		if (x - d[1] * ECHELLE) ^ 2 + (z - d[2] * ECHELLE) ^ 2 <= (d[3] * ECHELLE + MARGE) ^ 2 then return true end
	end
	return false
end

local rec = CHS:TryBeginRecording("Terrain d'herbe")
local ok, err = pcall(function()
	-- Le Terrain lisse dessine sa surface entre deux centres de voxels : avec des cellules pleines
	-- jusqu'à y = 0, l'herbe affleure à y = 2. La couche -4..0 remplie à moitié place la surface
	-- exactement à y = 0 (vérifié au rayon).
	local T = workspace.Terrain
	local DEMI = math.ceil(R_HERBE / 4) * 4 + 4
	local NC = DEMI / 2
	T:Clear()
	T:FillCylinder(CFrame.new(0, -10, 0), 12, R_HERBE, Enum.Material.Grass)
	local m, c = {}, {}
	for xi = 1, NC do
		m[xi], c[xi] = {{}}, {{}}
		local x = -DEMI + (xi - 0.5) * 4
		for zi = 1, NC do
			local z = -DEMI + (zi - 0.5) * 4
			local inside = x * x + z * z <= R_HERBE * R_HERBE
			m[xi][1][zi] = inside and (pave(x, z) and Enum.Material.LeafyGrass or Enum.Material.Grass) or Enum.Material.Air
			c[xi][1][zi] = inside and 0.5 or 0
		end
	end
	T:WriteVoxels(Region3.new(Vector3.new(-DEMI, -4, -DEMI), Vector3.new(DEMI, 0, DEMI)), 4, m, c)
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(98, 150, 72))
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(98, 150, 72))

	local spawn = workspace:FindFirstChild("Spawn_Heros") or Instance.new("SpawnLocation")
	spawn.Name = "Spawn_Heros"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.6, SPAWN_Z * ECHELLE)
	spawn.Anchored, spawn.Neutral, spawn.Transparency = true, true, 1
	spawn.CanCollide, spawn.CanTouch, spawn.Duration = false, false, 0
	spawn.Parent = workspace
	CS:AddTag(spawn, "PMU_HeroSpawn")
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return "Terrain d'herbe : rayon " .. R_HERBE .. ", point d'apparition en z = " .. SPAWN_Z * ECHELLE
