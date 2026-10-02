-- Assemble le rempart du palier P2 à partir du kit Blender (blender/build_rempart_p2.py, exports dans export_p2/).
-- Même cercle et même entraxe que le P1 et le P4 (66 travées de 20 studs, rayon 210,2).
-- Construit ServerStorage.Batiments.Rempart.P2 et range les pièces importées dans ServerStorage.Kit_Rempart_P2.
-- Le jeu l'affiche tout seul dès que l'enceinte atteint le niveau 5. Relançable, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local N, MODULE = 66, 20
local RAYON = (MODULE / 2) / math.sin(math.pi / N)
local UP = Vector3.yAxis
local AVANT_IMPORT = Vector3.new(0, 0, -1)   -- les FBX de Blender arrivent face avant vers -Z

-- boîtes englobantes Blender (min, max), affichées par build_rempart_p2.py
local BBOX = {
	Travee_A = {Vector3.new(-10, -3.46, 0), Vector3.new(10, 2.2, 36.48)},
	Travee_B = {Vector3.new(-10, -3.46, 0), Vector3.new(10, 2.2, 36.48)},
	Pilier = {Vector3.new(-3.84, -6.827, 0), Vector3.new(3.84, 3.524, 43)},
}
local ASPECT = {  -- suffixe du maillage -> couleur, matériau, collision
	PierreA = {Color3.fromRGB(30, 40, 58), Enum.Material.Slate, true},
	PierreB = {Color3.fromRGB(37, 50, 72), Enum.Material.Slate, true},
	PierreC = {Color3.fromRGB(25, 33, 48), Enum.Material.Slate, true},
	Joint = {Color3.fromRGB(13, 18, 27), Enum.Material.Slate, true},
	Gravure = {Color3.fromRGB(52, 66, 92), Enum.Material.Slate, false},
	Argent = {Color3.fromRGB(205, 212, 222), Enum.Material.Metal, false},
	Mousse = {Color3.fromRGB(26, 52, 13), Enum.Material.LeafyGrass, false},
	Lumiere = {Color3.fromRGB(196, 232, 255), Enum.Material.Neon, false},
}

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
local function repere(avant, pos) return CFrame.fromMatrix(pos, (-avant):Cross(UP), UP) end
local function blender(bx, by, bz) return CFrame.new(bx, bz, -by) end
local function cadre(k, travee)
	local a = 2 * math.pi * k / N + (travee and math.pi / N or 0)
	local r = travee and RAYON * math.cos(math.pi / N) or RAYON
	local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * r
	return repere((-pos).Unit, pos)
end

local rec = CHS:TryBeginRecording("Rempart P2 (kit Blender)")
local ok, err = pcall(function()
	local kit = SS:FindFirstChild("Kit_Rempart_P2") or Instance.new("Folder")
	kit.Name, kit.Parent = "Kit_Rempart_P2", SS
	-- pièces importées : par nom exact, sinon par les maillages qu'elles contiennent (l'importeur
	-- ne garde pas toujours le nom du fichier)
	local function trouver(cle)
		local nom = "Rempart_P2_" .. cle
		local m = kit:FindFirstChild(nom) or workspace:FindFirstChild(nom)
		if m then return m end
		for _, d in workspace:GetDescendants() do
			if d:IsA("MeshPart") and d.Name:find("^P2_" .. cle .. "_") then
				local modele = d:FindFirstAncestorOfClass("Model")
				if modele and modele.Parent == workspace then return modele end
			end
		end
		return nil
	end
	local T = {}
	for cle in BBOX do
		T[cle] = trouver(cle)
		assert(T[cle], "Pièce introuvable : Rempart_P2_" .. cle .. ". Importe-la depuis blender/export_p2/.")
	end
	for cle, t in T do
		t.Name = "Rempart_P2_" .. cle
		t.Parent = kit
	end
	local DECALAGE = {}
	for cle, t in T do
		local a, b = aabb(parts(t))
		local cb = (BBOX[cle][1] + BBOX[cle][2]) / 2
		DECALAGE[cle] = (repere(AVANT_IMPORT, (a + b) / 2) * blender(-cb.X, -cb.Y, -cb.Z)):ToObjectSpace(t:GetPivot())
	end

	local dossier = SS.Batiments.Rempart
	if dossier:FindFirstChild("P2") then dossier.P2:Destroy() end
	local p2 = Instance.new("Model")
	p2.Name = "P2"
	p2:SetAttribute("LotId", "Rempart")
	p2:SetAttribute("Palier", 2)

	local function poser(cle, c0)
		local c = T[cle]:Clone()
		c:PivotTo(c0 * DECALAGE[cle])
		for _, p in parts(c) do
			p.Anchored = true
			local sorte = p.Name:match("_(%a+)$")
			local a = ASPECT[sorte]
			if a then
				p.Color, p.Material, p.CanCollide, p.CanTouch = a[1], a[2], a[3], a[3]
				if not a[3] then p.CastShadow = sorte == "Argent" end
				if sorte == "Lumiere" then   -- halo des lanternes
					local l = Instance.new("PointLight")
					l.Color, l.Brightness, l.Range, l.Shadows = a[1], 1.4, 12, false
					l.Parent = p
				end
			end
		end
		c.Name = cle
		c.Parent = p2
	end
	for k = 0, N - 1 do
		poser("Pilier", cadre(k, false))
		poser(k % 2 == 0 and "Travee_A" or "Travee_B", cadre(k, true))
	end
	p2.Parent = dossier
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return string.format("Rempart P2 : %d pièces sur %d travées, rayon %.1f", #SS.Batiments.Rempart.P2:GetChildren(), N, RAYON)
