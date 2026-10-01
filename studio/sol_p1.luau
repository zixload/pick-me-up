-- Assemble le sol du palier P1 à partir de l'import Blender (blender/export_p1/Sol_P1.fbx)
-- et range les deux paliers du lot « Sol » dans ServerStorage.Batiments.Sol (P1 et P4).
-- Le sol en quartz (Workspace.PMU_Sol) devient le P4 ; son point d'apparition en sort d'abord,
-- pour rester en place quel que soit le palier affiché. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- repère : l'anneau d'argent de la place doit être centré en (0, 0.365, 12), comme dans Blender
-- (place en z = 8 sur le plan, multiplié par 1,5 depuis l'agrandissement de la base)
local REF_NOM, REF_POS = "Place_Centrale_Argent", Vector3.new(0, 0.365, 12)
local ASPECT = {  -- suffixe du maillage -> couleur, matériau, collision
	Pierre = {Color3.fromRGB(92, 108, 130), Enum.Material.Slate, true},
	Terre = {Color3.fromRGB(186, 160, 118), Enum.Material.Ground, true},
	Mousse = {Color3.fromRGB(88, 128, 56), Enum.Material.LeafyGrass, false},
	Argent = {Color3.fromRGB(205, 212, 222), Enum.Material.Metal, false},
}

local rec = CHS:TryBeginRecording("Sol P1 (kit Blender)")
local ok, err = pcall(function()
	local import = workspace:FindFirstChild("Sol_P1")
	assert(import, "Importe d'abord blender/export_p1/Sol_P1.fbx (modèle Sol_P1 dans Workspace).")
	local ref = import:FindFirstChild(REF_NOM, true)
	import:PivotTo(import:GetPivot() + (REF_POS - ref.Position))

	local batiments = SS:FindFirstChild("Batiments")
	local dossier = batiments:FindFirstChild("Sol") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Sol", batiments
	local ancien = dossier:FindFirstChild("P1")
	if ancien then ancien:Destroy() end

	-- une pièce (Model) par allée, socle ou place, qui regroupe ses maillages
	local p1 = Instance.new("Model")
	p1.Name = "P1"
	p1:SetAttribute("LotId", "Sol")
	p1:SetAttribute("Palier", 1)
	local groupes = {}
	for _, p in import:GetDescendants() do
		if p:IsA("BasePart") then
			local piece, sorte = p.Name:match("^(.-)_(%a+)_?%d*$")
			local aspect = ASPECT[sorte]
			assert(aspect, "Maillage inattendu : " .. p.Name)
			local g = groupes[piece]
			if not g then
				g = Instance.new("Model")
				g.Name = piece
				g.Parent = p1
				groupes[piece] = g
			end
			p.Color, p.Material, p.CanCollide = aspect[1], aspect[2], aspect[3]
			p.CanTouch, p.Anchored = false, true
			if sorte ~= "Pierre" and sorte ~= "Terre" then p.CastShadow = false end
			if p:IsA("MeshPart") then
				pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end)
			end
			p.Parent = g
		end
	end
	p1.Parent = dossier
	import:Destroy()

	-- le sol en quartz devient le P4, sans son point d'apparition
	local quartz = workspace:FindFirstChild("PMU_Sol")
	if quartz and not dossier:FindFirstChild("P4") then
		local spawn = quartz:FindFirstChild("Spawn_Heros", true)
		if spawn then spawn.Parent = workspace end
		quartz.Name = "P4"
		quartz:SetAttribute("LotId", "Sol")
		quartz:SetAttribute("Palier", 4)
		quartz.Parent = dossier
	end

	-- affichage : le sol suit le palier du rempart s'il est déjà affiché, sinon le P1
	local scene = workspace:FindFirstChild("Batiments") or Instance.new("Folder")
	scene.Name, scene.Parent = "Batiments", workspace
	local rempart = scene:FindFirstChild("Rempart")
	local palier = rempart and rempart:GetAttribute("Palier") or 1
	local montre = scene:FindFirstChild("Sol")
	if montre then montre:Destroy() end
	local copie = dossier:FindFirstChild("P" .. palier):Clone()
	copie.Name = "Sol"
	copie.Parent = scene
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local n = 0
for _, d in SS.Batiments.Sol.P1:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return string.format("Sol P1 : %d pièces, %d maillages | paliers du sol : %s", #SS.Batiments.Sol.P1:GetChildren(), n,
	table.concat((function() local t = {} for _, c in SS.Batiments.Sol:GetChildren() do table.insert(t, c.Name) end return t end)(), ", "))
