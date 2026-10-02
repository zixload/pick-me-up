-- Assemble le sol du palier P4 (quartz) à partir de l'import Blender (blender/export_p4/Sol_P4.fbx)
-- et le range dans ServerStorage.Batiments.Sol.P4. L'affichage ne change pas : la borne de test
-- (TestPaliers) fait passer le sol du P1 au P4 avec le rempart. Annulable d'un Ctrl+Z.
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

local rec = CHS:TryBeginRecording("Sol P4 (kit Blender)")
local ok, err = pcall(function()
	local import = workspace:FindFirstChild("Sol_P4")
	assert(import, "Importe d'abord blender/export_p4/Sol_P4.fbx (modèle Sol_P4 dans Workspace).")
	local ref = import:FindFirstChild(REF_NOM, true) or import:FindFirstChild(REF_NOM .. "_1", true)
	assert(ref, "Repère " .. REF_NOM .. " introuvable dans l'import.")
	import:PivotTo(import:GetPivot() + (REF_POS - ref.Position))

	local dossier = SS.Batiments:FindFirstChild("Sol") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Sol", SS.Batiments
	if dossier:FindFirstChild("P4") then dossier.P4:Destroy() end

	-- une pièce (Model) par allée, socle ou place, qui regroupe ses maillages
	local p4 = Instance.new("Model")
	p4.Name = "P4"
	p4:SetAttribute("LotId", "Sol")
	p4:SetAttribute("Palier", 4)
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
				g.Parent = p4
				groupes[piece] = g
			end
			p.Color, p.Material, p.CanCollide = a[1], a[2], a[3]
			p.CanTouch, p.Anchored = false, true
			if sorte == "Or" then p.CastShadow = false end
			p.Parent = g
		end
	end
	p4.Parent = dossier
	import:Destroy()
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local n = 0
for _, d in SS.Batiments.Sol.P4:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return string.format("Sol P4 : %d pièces, %d maillages, rangé dans ServerStorage.Batiments.Sol.P4", #SS.Batiments.Sol.P4:GetChildren(), n)
