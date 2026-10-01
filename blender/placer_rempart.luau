-- Pose le kit « Rempart quartz » en cercle autour de la base.
-- À coller dans la barre de commande de Studio (View > Command Bar). Relançable : il remplace l'enceinte déjà posée.
-- Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local N, CENTRE, MODULE = 44, Vector3.new(0, 0, 0), 20
local RAYON = (MODULE / 2) / math.sin(math.pi / N)
local UP = Vector3.yAxis

-- boîtes englobantes Blender (min, max), relevées dans rempart_quartz.blend
local BBOX = {
	Travee = {Vector3.new(-10, -2.5, 0), Vector3.new(10, 2.0, 32)},
	Pilier = {Vector3.new(-2.9, -3.5, 0), Vector3.new(2.9, 2.3, 39.4)},
	Balustrade = {Vector3.new(-10, -1.8, 32), Vector3.new(10, 0, 36)},
	Haie = {Vector3.new(-7.645, -1.566, -0.047), Vector3.new(7.644, 1.599, 3.476)},
	-- lierre du kit ChatGPT (assets/murailles_v01), il garde sa propre texture
	Lierre_Grimpant = {Vector3.new(-1.948, -0.239, -0.015), Vector3.new(1.892, -0.065, 7.615)},
}
local COULEURS = {
	{"_Or", Color3.fromRGB(226, 170, 70), Enum.Material.Foil},
	{"Pierre", Color3.fromRGB(242, 206, 192), Enum.Material.SmoothPlastic},
	{"Haie", Color3.fromRGB(78, 128, 52), Enum.Material.SmoothPlastic},
	{"Feuilles", Color3.fromRGB(70, 120, 50), Enum.Material.SmoothPlastic},
	{"Fleurs", Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic},
}

local function parts(inst)
	local t = {}
	if inst:IsA("BasePart") then table.insert(t, inst) end
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

local ancienne = workspace:FindFirstChild("PMU_Rempart")
local function trouver(cle)
	local kit = SS:FindFirstChild("Kit_Rempart")
	local base = workspace:FindFirstChild("PMU_Base")
	for _, racine in {kit, workspace} do
		local best
		if racine then
			for _, d in racine:GetDescendants() do
				if (d:IsA("Model") or d:IsA("BasePart")) and d.Name:find(cle)
					and not (base and d:IsDescendantOf(base))
					and not (ancienne and d:IsDescendantOf(ancienne))
					and #parts(d) > 0
					and (not best or #d:GetFullName() < #best:GetFullName()) then
					best = d
				end
			end
		end
		if best then return best end
	end
	error("Pièce introuvable : " .. cle .. ". Vérifie qu'elle est bien importée dans Workspace.")
end

local rec = CHS:TryBeginRecording("Rempart quartz")
local ok, err = pcall(function()
	local T = {}
	for cle in BBOX do T[cle] = trouver(cle) end

	-- orientation et échelle déduites de la travée (20 de large, 32 de haut)
	local tp = parts(T.Travee)
	local mn, mx = aabb(tp)
	local ext = mx - mn
	local largeurX = ext.X >= ext.Z
	local echelle = (largeurX and ext.X or ext.Z) / MODULE
	if math.abs(echelle - 1) > 0.02 then
		for _, t in T do
			if t:IsA("Model") then t:ScaleTo(t:GetScale() / echelle) end
		end
		mn, mx = aabb(tp)
		ext = mx - mn
	end
	if math.abs(ext.Y - 32) > 1.5 then
		error(string.format("La travée mesure %.1f de haut au lieu de 32 : elle est sans doute couchée.", ext.Y))
	end

	local orPart, pierre
	for _, p in tp do
		if p.Name:find("_Or") then orPart = p else pierre = pierre or p end
	end
	if not orPart then
		table.sort(tp, function(a, b) return a.Size.X * a.Size.Y * a.Size.Z < b.Size.X * b.Size.Y * b.Size.Z end)
		orPart, pierre = tp[1], tp[#tp]
	end
	local pmn, pmx = aabb({pierre})
	local axe = largeurX and Vector3.zAxis or Vector3.xAxis
	local AVANT = axe * math.sign((orPart.Position - (pmn + pmx) / 2):Dot(axe))

	-- décalage entre l'origine Blender de chaque pièce et son pivot Roblox
	local DECALAGE = {}
	for cle, t in T do
		local a, b = aabb(parts(t))
		local cb = (BBOX[cle][1] + BBOX[cle][2]) / 2
		local origine = repere(AVANT, (a + b) / 2) * blender(-cb.X, -cb.Y, -cb.Z)
		DECALAGE[cle] = origine:ToObjectSpace(t:GetPivot())
	end

	if ancienne then ancienne:Destroy() end
	local sortie = Instance.new("Model")
	sortie.Name = "PMU_Rempart"

	local function poser(cle, cadre, bx, by, bz)
		local c = T[cle]:Clone()
		c:PivotTo(cadre * blender(bx or 0, by or 0, bz or 0) * DECALAGE[cle])
		for _, p in parts(c) do
			p.Anchored = true
			if cle == "Lierre_Grimpant" then p.CanCollide = false end
			for _, r in COULEURS do
				if p.Name:find(r[1]) then p.Color, p.Material = r[2], r[3]; break end
			end
		end
		c.Parent = sortie
	end

	for k = 0, N - 1 do
		local a = 2 * math.pi * k / N
		local pos = CENTRE + Vector3.new(math.cos(a), 0, math.sin(a)) * RAYON
		poser("Pilier", repere((CENTRE - pos).Unit, pos))

		local am = a + math.pi / N
		local posm = CENTRE + Vector3.new(math.cos(am), 0, math.sin(am)) * RAYON * math.cos(math.pi / N)
		local cadre = repere((CENTRE - posm).Unit, posm)
		poser("Travee", cadre)
		poser("Balustrade", cadre)
		poser("Haie", cadre, 0, -4.3)
		poser("Lierre_Grimpant", cadre, -6.6, -1.55, 3)
		poser("Lierre_Grimpant", cadre, 6.6, -1.55, 3)
	end
	sortie.Parent = workspace

	-- les originaux importés sont rangés, l'enceinte de Codex est mise de côté (pas supprimée)
	local kit = SS:FindFirstChild("Kit_Rempart") or Instance.new("Folder")
	kit.Name, kit.Parent = "Kit_Rempart", SS
	for _, t in T do t.Parent = kit end
	local base = workspace:FindFirstChild("PMU_Base")
	local codex = base and base:FindFirstChild("02_Enceinte", true)
	if codex then
		codex.Name = "Enceinte_Codex_Ancienne"
		codex.Parent = SS
	end
	print(string.format("Rempart posé : %d travées, rayon %.1f studs (échelle corrigée x%.3f)", N, RAYON, 1 / echelle))
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then warn("Rempart : " .. tostring(err)) end
