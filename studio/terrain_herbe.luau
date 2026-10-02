-- Terrain d'herbe de la base et point d'apparition, à l'échelle du plan (agrandi de 1,5 le 01/10/2026).
-- Herbe haute partout ; herbe rase seulement sous les dalles (les brins du Terrain les traversent).
-- Relief très léger dans les zones d'herbe : bosses douces de 2 studs au plus, sans creux,
-- qui retombent à plat près des dalles et au pied du rempart.
-- Relançable, annulable d'un Ctrl+Z. Après coup, relancer studio/reposer_vegetation.luau.
local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local ECHELLE = 1.5
local R_HERBE = 310           -- l'enceinte (rayon 210) et ses abords, quai du dirigeable compris
local MARGE = 3               -- les bordures du dallage P1 débordent d'environ 2,5 studs
local SPAWN_Z = 92            -- échelle 1, sur l'avenue sud
local RELIEF_MAX = 2.2        -- studs
local RELIEF_ONDE = 55        -- largeur des bosses (studs)
local R_PLAT = 196            -- au-delà, le relief s'éteint (rempart à 210)

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
		local dx = math.max(r[1] * ECHELLE - x, 0, x - r[2] * ECHELLE)
		local dz = math.max(r[3] * ECHELLE - z, 0, z - r[4] * ECHELLE)
		d = math.min(d, (dx == 0 and dz == 0) and -1 or math.sqrt(dx * dx + dz * dz))
	end
	for _, c in DISQUES do
		d = math.min(d, math.sqrt((x - c[1] * ECHELLE) ^ 2 + (z - c[2] * ECHELLE) ^ 2) - c[3] * ECHELLE)
	end
	return d
end

local function lisse(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- hauteur du sol en (x, z)
local function hauteur(x, z, dPave)
	local attenuation = lisse((dPave - 4) / 12) * lisse((R_PLAT - math.sqrt(x * x + z * z)) / 14)
	local bosse = math.clamp(math.noise(x / RELIEF_ONDE, z / RELIEF_ONDE, 4.4) * 1.4 + 0.1, 0, 1)
	return RELIEF_MAX * bosse * attenuation
end

local rec = CHS:TryBeginRecording("Terrain d'herbe")
local ok, err = pcall(function()
	-- Le Terrain lisse place la surface d'une colonne à c + 4 × occupation, où c est le centre de la
	-- dernière cellule non vide (vérifié au rayon : cellule -4..0 à 0,5 -> surface à y = 0).
	local T = workspace.Terrain
	local DEMI = math.ceil(R_HERBE / 4) * 4 + 4
	local NC = DEMI / 2
	local Y0, NY = -16, 6              -- cellules de -16 à +8
	T:Clear()
	local m, c = {}, {}
	for xi = 1, NC do
		m[xi], c[xi] = {}, {}
		for yi = 1, NY do m[xi][yi], c[xi][yi] = {}, {} end
		local x = -DEMI + (xi - 0.5) * 4
		for zi = 1, NC do
			local z = -DEMI + (zi - 0.5) * 4
			local inside = x * x + z * z <= R_HERBE * R_HERBE
			local dPave = distancePave(x, z)
			local h = inside and hauteur(x, z, dPave) or 0
			local mat = dPave <= MARGE and Enum.Material.LeafyGrass or Enum.Material.Grass
			for yi = 1, NY do
				local centre = Y0 + (yi - 0.5) * 4
				local occ = inside and math.clamp((h - centre) / 4, 0, 1) or 0
				m[xi][yi][zi] = occ > 0 and mat or Enum.Material.Air
				c[xi][yi][zi] = occ
			end
		end
	end
	T:WriteVoxels(Region3.new(Vector3.new(-DEMI, Y0, -DEMI), Vector3.new(DEMI, Y0 + NY * 4, DEMI)), 4, m, c)
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
return "Terrain d'herbe : rayon " .. R_HERBE .. ", relief jusqu'à " .. RELIEF_MAX .. " studs"
