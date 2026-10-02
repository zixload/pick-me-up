-- Assemble le sol du palier P3 (quartz, allées à médaillons d'or) à partir de l'import Blender
-- (blender/export_p4/Sol_P4.fbx) et le range dans ServerStorage.Batiments.Sol.P3, qui est remplacé.
-- Le jeu l'affiche tout seul quand l'étage de Tour du P3 est franchi. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- repère : les ors de la place sont centrés en (0, 0.47, 12), comme dans Blender (plan ×1,5)
local REF_NOM, REF_POS = "Place_Centrale_Or", Vector3.new(0, 0.47, 12)
local ASPECT = {  -- suffixe du maillage -> couleur, matériau, collision
	QuartzA = {Color3.fromRGB(250, 242, 238), Enum.Material.Marble, true},
	QuartzB = {Color3.fromRGB(244, 233, 229), Enum.Material.Marble, true},
	Bord = {Color3.fromRGB(234, 219, 213), Enum.Material.Marble, true},
	Or = {Color3.fromRGB(232, 182, 82), Enum.Material.Foil, false},
}

local rec = CHS:TryBeginRecording("Sol P3 (kit Blender)")
local ok, err = pcall(function()
	-- l'importeur ne garde pas toujours le nom du fichier : on cherche le modèle qui contient le repère,
	-- hors de la copie affichée par le jeu
	local import = workspace:FindFirstChild("Sol_P4")
	if not import then
		local affiche = workspace:FindFirstChild("Batiments")
		for _, d in workspace:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == REF_NOM and not (affiche and d:IsDescendantOf(affiche)) then
				import = d:FindFirstAncestorOfClass("Model")
				break
			end
		end
	end
	assert(import, "Importe d'abord blender/export_p4/Sol_P4.fbx.")
	local ref = import:FindFirstChild(REF_NOM, true) or import:FindFirstChild(REF_NOM .. "_1", true)
	assert(ref, "Repère " .. REF_NOM .. " introuvable dans l'import.")
	import:PivotTo(import:GetPivot() + (REF_POS - ref.Position))

	local dossier = SS.Batiments:FindFirstChild("Sol") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Sol", SS.Batiments
	if dossier:FindFirstChild("P3") then dossier.P3:Destroy() end

	-- une pièce (Model) par allée, socle ou place, qui regroupe ses maillages
	local p3 = Instance.new("Model")
	p3.Name = "P3"
	p3:SetAttribute("LotId", "Sol")
	p3:SetAttribute("Palier", 3)
	local groupes = {}
	for _, p in import:GetDescendants() do
		if p:IsA("BasePart") then
			local piece, sorte = p.Name:match("^(.-)_(%a+)_?%d*$")
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. p.Name)
			local g = groupes[piece]
			if not g then
				g = Instance.new("Model")
				g.Name = piece
				g.Parent = p3
				groupes[piece] = g
			end
			p.Color, p.Material, p.CanCollide = a[1], a[2], a[3]
			p.CanTouch, p.Anchored = false, true
			if sorte == "Or" then p.CastShadow = false end
			p.Parent = g
		end
	end
	p3.Parent = dossier
	import:Destroy()
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local n = 0
for _, d in SS.Batiments.Sol.P3:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return string.format("Sol P3 : %d pièces, %d maillages, rangé dans ServerStorage.Batiments.Sol.P3", #SS.Batiments.Sol.P3:GetChildren(), n)
