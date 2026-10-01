-- Assemble le rempart du palier P1 à partir du kit Blender (blender/build_rempart_p1.py, exports dans export_p1/).
-- Même cercle et même entraxe que le P4 (44 travées de 20 studs) : les paliers se remplacent sans décalage.
-- Construit ServerStorage.Batiments.Rempart.P1 et range les pièces importées dans ServerStorage.Kit_Rempart_P1.
-- Relançable, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local N, MODULE = 66, 20   -- rayon 210,2 : base agrandie de 1,5 le 01/10/2026 (44 travées avant)
local RAYON = (MODULE / 2) / math.sin(math.pi / N)
local UP = Vector3.yAxis
-- Les FBX exportés de Blender arrivent face avant (-Y Blender) tournée vers -Z dans Studio.
local AVANT_IMPORT = Vector3.new(0, 0, -1)

-- boîtes englobantes Blender (min, max), affichées par build_rempart_p1.py
local BBOX = {
	Travee = {Vector3.new(-10, -3, 0), Vector3.new(10, 2.6, 31.12)},
	Pilier = {Vector3.new(-3, -4.8, 0), Vector3.new(3, 3.2, 35.8)},
	Mousse_Travee_A = {Vector3.new(-10, -3.05, 0.05), Vector3.new(9.498, 1.397, 31.13)},
	Mousse_Travee_B = {Vector3.new(-7.287, -3.05, 0.05), Vector3.new(10, 1.891, 31.13)},
	Mousse_Travee_C = {Vector3.new(-10, -3.05, 0.05), Vector3.new(9.779, 1.036, 31.13)},
	Mousse_Pilier_A = {Vector3.new(-2.85, -4.67, 20.424), Vector3.new(2.85, 0.812, 35.9)},
	Mousse_Pilier_B = {Vector3.new(-2.85, -4.67, 23.404), Vector3.new(2.85, 0.861, 35.9)},
}
local ASPECT = {  -- motif dans le nom de la pièce -> couleur, matériau, collision
	{"Pierre", Color3.fromRGB(92, 108, 130), Enum.Material.Slate, true},
	{"Argent", Color3.fromRGB(205, 212, 222), Enum.Material.Metal, false},
	{"Mousse", Color3.fromRGB(88, 128, 56), Enum.Material.LeafyGrass, false},
}
local MOUSSE_TRAVEE = {"Mousse_Travee_A", "Mousse_Travee_B", "Mousse_Travee_C"}
local MOUSSE_PILIER = {"Mousse_Pilier_A", "Mousse_Pilier_B"}

local function parts(inst)
	local t = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end

local function aabb(list)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in list do
		local h = p.Size / 2
		for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
			local c = p.CFrame:PointToWorldSpace(h * Vector3.new(sx, sy, sz))
			mn, mx = mn:Min(c), mx:Max(c)
		end end end
	end
	return mn, mx
end

-- repère : X = +X Blender, Y = haut, Z = face avant (-Y Blender)
local function repere(avant, pos)
	return CFrame.fromMatrix(pos, (-avant):Cross(UP), UP)
end
local function blender(bx, by, bz)
	return CFrame.new(bx, bz, -by)
end

local rec = CHS:TryBeginRecording("Rempart P1 (kit Blender)")
local ok, err = pcall(function()
	-- pièces importées : d'abord dans le kit rangé, sinon dans Workspace
	local kit = SS:FindFirstChild("Kit_Rempart_P1") or Instance.new("Folder")
	kit.Name, kit.Parent = "Kit_Rempart_P1", SS
	local T = {}
	for cle in BBOX do
		local nom = "Rempart_P1_" .. cle
		T[cle] = kit:FindFirstChild(nom) or workspace:FindFirstChild(nom)
		assert(T[cle], "Pièce introuvable : " .. nom .. ". Importe-la depuis blender/export_p1/.")
		T[cle].Parent = kit
	end

	-- décalage entre l'origine Blender de chaque pièce et son pivot Roblox
	local DECALAGE = {}
	for cle, t in T do
		local a, b = aabb(parts(t))
		local cb = (BBOX[cle][1] + BBOX[cle][2]) / 2
		local origine = repere(AVANT_IMPORT, (a + b) / 2) * blender(-cb.X, -cb.Y, -cb.Z)
		DECALAGE[cle] = origine:ToObjectSpace(t:GetPivot())
	end

	local dossier = SS:WaitForChild("Batiments"):WaitForChild("Rempart")
	local ancien = dossier:FindFirstChild("P1")
	if ancien then ancien:Destroy() end
	local p1 = Instance.new("Model")
	p1.Name = "P1"
	p1:SetAttribute("LotId", "Rempart")
	p1:SetAttribute("Palier", 1)

	local rng = Random.new(7)
	local function poser(cle, cadre)
		local c = T[cle]:Clone()
		c:PivotTo(cadre * DECALAGE[cle])
		for _, p in parts(c) do
			p.Anchored = true
			for _, a in ASPECT do
				if p.Name:find(a[1]) then
					p.Color, p.Material, p.CanCollide = a[2], a[3], a[4]
					p.CanTouch = a[4]
					if a[1] == "Mousse" then p.CastShadow = false end
					break
				end
			end
		end
		c.Name = cle
		c.Parent = p1
	end

	for k = 0, N - 1 do
		local a = 2 * math.pi * k / N
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * RAYON
		local cadre = repere((-pos).Unit, pos)
		poser("Pilier", cadre)
		poser(MOUSSE_PILIER[rng:NextInteger(1, #MOUSSE_PILIER)], cadre)

		local am = a + math.pi / N
		local posm = Vector3.new(math.cos(am), 0, math.sin(am)) * RAYON * math.cos(math.pi / N)
		local cadreT = repere((-posm).Unit, posm)
		poser("Travee", cadreT)
		poser(MOUSSE_TRAVEE[rng:NextInteger(1, #MOUSSE_TRAVEE)], cadreT)
	end
	p1.Parent = dossier
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return string.format("Rempart P1 assemblé : %d pièces, rayon %.1f", #parts(SS.Batiments.Rempart.P1), RAYON)
