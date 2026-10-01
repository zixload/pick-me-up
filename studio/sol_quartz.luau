-- Sol de la base, version finale « quartz » (palier P4), d'après docs/plan_base.html.
-- Relançable : remplace Workspace.PMU_Sol. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local DALLAGE = {Enum.Material.Pavement, "Quartz_Dallage", Color3.fromRGB(255, 250, 246)}
local PIERRE = {Enum.Material.Marble, "Quartz_Pierre", Color3.fromRGB(246, 232, 226)}
local OR = {Enum.Material.Foil, "", Color3.fromRGB(226, 170, 70)}

local rec = CHS:TryBeginRecording("Sol quartz")
local ok, err = pcall(function()
	local old = workspace:FindFirstChild("PMU_Sol")
	if old then old:Destroy() end
	local sol = Instance.new("Model")
	sol.Name = "PMU_Sol"
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = sol
		return f
	end
	local fPlace, fAllees, fSocles, fOr = folder("Place"), folder("Allees"), folder("Socles"), folder("Incrustations")

	local function part(parent, name, size, cf, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Material, p.MaterialVariant, p.Color = mat[1], mat[2], mat[3]
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- dalle rectangulaire définie par ses bornes (x0..x1, z0..z1), dessus à la hauteur top
	local function dalle(parent, name, x0, x1, z0, z1, top, mat, thick)
		thick = thick or 2
		return part(parent, name, Vector3.new(x1 - x0, thick, z1 - z0),
			CFrame.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2), mat)
	end
	local function disque(parent, name, x, z, r, top, mat, thick)
		thick = thick or 2
		local p = part(parent, name, Vector3.new(thick, r * 2, r * 2),
			CFrame.new(x, top - thick / 2, z) * CFrame.Angles(0, 0, math.pi / 2), mat)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function filet(parent, a, b, w, top)
		local d = b - a
		local p = part(parent, "Filet_Or", Vector3.new(w, 0.1, d.Magnitude),
			CFrame.lookAt((a + b) / 2, b) , OR)
		p.Position = Vector3.new(p.Position.X, top + 0.03, p.Position.Z)
		p.CanCollide = false
		return p
	end
	local function anneau(parent, x, z, r, w, top, n)
		for i = 1, n do
			local a, b = (i - 1) * 2 * math.pi / n, i * 2 * math.pi / n
			filet(parent, Vector3.new(x + math.cos(a) * r, 0, z + math.sin(a) * r),
				Vector3.new(x + math.cos(b) * r, 0, z + math.sin(b) * r), w, top)
		end
	end

	-- herbe : le Terrain couvre l'enceinte et ses abords (quai du dirigeable compris).
	-- Le Terrain lisse dessine sa surface entre deux centres de voxels : avec des cellules
	-- pleines jusqu'à y = 0, l'herbe affleure à y = 2. On remplit donc la couche -4..0
	-- à moitié, ce qui place la surface exactement à y = 0 (vérifié au rayon).
	local T = workspace.Terrain
	local R = 215
	T:Clear()
	T:FillCylinder(CFrame.new(0, -10, 0), 12, R, Enum.Material.Grass)
	local N = 108
	local m, c = {}, {}
	for xi = 1, N do
		m[xi], c[xi] = {{}}, {{}}
		local x = -216 + (xi - 0.5) * 4
		for zi = 1, N do
			local z = -216 + (zi - 0.5) * 4
			local inside = x * x + z * z <= R * R
			m[xi][1][zi] = inside and Enum.Material.Grass or Enum.Material.Air
			c[xi][1][zi] = inside and 0.5 or 0
		end
	end
	T:WriteVoxels(Region3.new(Vector3.new(-216, -4, -216), Vector3.new(216, 0, 216)), 4, m, c)
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(98, 150, 72))

	-- place centrale et rosace
	local PX, PZ, PR, PTOP = 0, 8, 25, 0.55
	disque(fPlace, "Marche_Place", PX, PZ, PR + 1.6, PTOP - 0.25, PIERRE)
	disque(fPlace, "Place_Centrale", PX, PZ, PR, PTOP, DALLAGE)
	anneau(fOr, PX, PZ, 20, 0.5, PTOP, 72)
	anneau(fOr, PX, PZ, 12, 0.4, PTOP, 56)
	for i = 0, 7 do
		local a = i * math.pi / 4
		filet(fOr, Vector3.new(PX + math.cos(a) * 3.2, 0, PZ + math.sin(a) * 3.2),
			Vector3.new(PX + math.cos(a) * 20, 0, PZ + math.sin(a) * 20), 0.35, PTOP)
	end
	local medaillon = disque(fOr, "Medaillon", PX, PZ, 3.2, PTOP + 0.08, OR, 0.3)
	medaillon.CanCollide = false

	-- allées : dallage sur un liseré de pierre un peu plus large et plus bas
	local ATOP = 0.35
	local ALLEES = {
		{"Avenue_Sud", -8, 8, 30, 130},
		{"Allee_Nord", -8, 8, -62, -14},
		{"Allee_Ouest", -76, -22, 2, 14},
		{"Allee_Est", 22, 66, 2, 14},
		{"Allee_Logements", -64, -52, -69, 2},
		{"Allee_Artisans", -64, -52, 14, 40},
		{"Allee_Invocation_Admin", 12, 86, -63, -51},
		{"Allee_Faille_Nord", 61, 73, 18, 92},
		-- raccords vers les lots
		{"Raccord_Infirmerie", 47, 67, 86, 96},
		{"Raccord_Salle_Magie", 49, 61, -13, 2},
		{"Raccord_Synthese", 44, 56, -76, -63},
		{"Raccord_Transfert", -20, -8, -60, -52},
		{"Raccord_Logements", -74, -64, -56, -48},
		{"Raccord_Cantine", -98, -86, 14, 21},
	}
	for _, a in ALLEES do
		dalle(fAllees, a[1] .. "_Liseré", a[2] - 0.8, a[3] + 0.8, a[4] - 0.8, a[5] + 0.8, ATOP - 0.12, PIERRE)
		dalle(fAllees, a[1], a[2], a[3], a[4], a[5], ATOP, DALLAGE)
	end

	-- socles des lots (repris du plan) ; l'attribut LotId servira au back end
	local STOP = 0.8
	local LOTS = {
		{"Logements", "existant", -100, -74, -66, -38},
		{"Logements_Annexe", "existant", -101, -75, -25, 3},
		{"Cantine", "existant", -107, -79, 21, 49},
		{"Infirmerie", "existant", 21, 47, 78, 106},
		{"Administration", "existant", 81, 111, -58, -32},
		{"Entrainement", "existant", -78.5, -33.5, -99.5, -68.5},
		{"Quartier_Artisanal", "existant", -70, -20, 40, 106},
		{"Salle_Magie", "reserve", 40, 70, -41, -13},
		{"Terrain_Magique", "reserve", -33, -11, -112, -90},
		{"Station_Transfert", "reserve", -40, -20, -65, -47},
		{"Chambre_Synthese", "reserve", 36, 64, -104, -76},
	}
	for _, l in LOTS do
		local p = dalle(fSocles, "Socle_" .. l[1], l[3], l[4], l[5], l[6], STOP, PIERRE)
		p:SetAttribute("LotId", l[1])
		p:SetAttribute("Statut", l[2])
		CS:AddTag(p, "PMU_Lot")
		if l[2] == "reserve" then  -- liseré doré : emplacement à construire
			local x0, x1, z0, z1 = l[3] + 0.6, l[4] - 0.6, l[5] + 0.6, l[6] - 0.6
			filet(fOr, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), 0.35, STOP)
			filet(fOr, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), 0.35, STOP)
			filet(fOr, Vector3.new(x1, 0, z1), Vector3.new(x0, 0, z1), 0.35, STOP)
			filet(fOr, Vector3.new(x0, 0, z1), Vector3.new(x0, 0, z0), 0.35, STOP)
		end
	end
	for _, c in {{"Faille", 78, 29, 24}, {"Invocation", 12, -82, 22}} do
		local p = disque(fSocles, "Socle_" .. c[1], c[2], c[3], c[4], STOP, PIERRE)
		p:SetAttribute("LotId", c[1])
		p:SetAttribute("Statut", "existant")
		CS:AddTag(p, "PMU_Lot")
	end

	-- les brins d'herbe du Terrain traversent les dalles : sous tout ce qui est dallé,
	-- l'herbe devient de l'herbe rase (LeafyGrass, sans brins)
	local rects, discs = {}, {}
	for _, f in {fPlace, fAllees, fSocles} do
		for _, p in f:GetChildren() do
			if p.Shape == Enum.PartType.Cylinder then
				table.insert(discs, {p.Position.X, p.Position.Z, p.Size.Y / 2})
			else
				table.insert(rects, {p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2,
					p.Position.Z - p.Size.Z / 2, p.Position.Z + p.Size.Z / 2})
			end
		end
	end
	local MARGE = 1.5
	local function pave(x, z)
		for _, r in rects do
			if x >= r[1] - MARGE and x <= r[2] + MARGE and z >= r[3] - MARGE and z <= r[4] + MARGE then return true end
		end
		for _, d in discs do
			if (x - d[1]) ^ 2 + (z - d[2]) ^ 2 <= (d[3] + MARGE) ^ 2 then return true end
		end
		return false
	end
	local surface = Region3.new(Vector3.new(-216, -4, -216), Vector3.new(216, 0, 216))
	local sm, sc = T:ReadVoxels(surface, 4)
	for xi = 1, sm.Size.X do
		for zi = 1, sm.Size.Z do
			if sm[xi][1][zi] == Enum.Material.Grass and pave(-216 + (xi - 0.5) * 4, -216 + (zi - 0.5) * 4) then
				sm[xi][1][zi] = Enum.Material.LeafyGrass
			end
		end
	end
	T:WriteVoxels(surface, 4, sm, sc)
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(98, 150, 72))

	-- point d'apparition sur l'avenue sud
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_Heros"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, ATOP + 0.1, 92)
	spawn.Anchored, spawn.Neutral, spawn.Transparency = true, true, 1
	spawn.CanCollide, spawn.CanTouch, spawn.Duration = false, false, 0
	spawn.Parent = sol
	CS:AddTag(spawn, "PMU_HeroSpawn")

	sol.Parent = workspace

	-- originaux du kit restés au centre : rangés avec les autres
	local kit = game.ServerStorage:FindFirstChild("Kit_Rempart")
	if kit then
		for _, n in {"Rempart_Balustrade", "PMU_Lierre_Grimpant"} do
			local m = workspace:FindFirstChild(n)
			if m then m.Parent = kit end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local n = 0
for _, d in workspace.PMU_Sol:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return "PMU_Sol posé : " .. n .. " pièces"
