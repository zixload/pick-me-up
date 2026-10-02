-- Assemble le sol du palier P2 (basalte noir nuit et argent, allées à rosaces) à partir de l'import Blender
-- (blender/export_p2/Sol_P2.fbx) et le range dans ServerStorage.Batiments.Sol.P2.
-- Le jeu l'affiche tout seul quand l'enceinte atteint le niveau 5. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- repère : les argents de la place sont centrés en (0, 0.47, 12), comme dans Blender (plan ×1,5)
local REF_NOM, REF_POS = "Place_Centrale_Argent", Vector3.new(0, 0.47, 12)
-- dalles d'une seule teinte, en Slate comme le rempart P2 : le Marble brillait trop sur ce ton sombre
local ASPECT = {  -- suffixe du maillage -> couleur, matériau, collision
	Dalle = {Color3.fromRGB(30, 40, 58), Enum.Material.Slate, true},
	Bord = {Color3.fromRGB(40, 54, 78), Enum.Material.Slate, true},
	Argent = {Color3.fromRGB(205, 212, 222), Enum.Material.Metal, false},
}

local rec = CHS:TryBeginRecording("Sol P2 (kit Blender)")
local ok, err = pcall(function()
	-- l'importeur ne garde pas toujours le nom du fichier : on cherche le modèle qui contient le repère
	local import = workspace:FindFirstChild("Sol_P2")
	if not import then
		local affiche = workspace:FindFirstChild("Batiments")   -- copie affichée par le jeu, à ne pas prendre
		for _, d in workspace:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == REF_NOM and not (affiche and d:IsDescendantOf(affiche)) then
				import = d:FindFirstAncestorOfClass("Model")
				break
			end
		end
	end
	assert(import, "Importe d'abord blender/export_p2/Sol_P2.fbx.")
	local ref = import:FindFirstChild(REF_NOM, true)
	import:PivotTo(import:GetPivot() + (REF_POS - ref.Position))

	local dossier = SS.Batiments:FindFirstChild("Sol") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Sol", SS.Batiments
	if dossier:FindFirstChild("P2") then dossier.P2:Destroy() end
	local p2 = Instance.new("Model")
	p2.Name = "P2"
	p2:SetAttribute("LotId", "Sol")
	p2:SetAttribute("Palier", 2)
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
				g.Parent = p2
				groupes[piece] = g
			end
			p.Color, p.Material, p.CanCollide = a[1], a[2], a[3]
			p.CanTouch, p.Anchored = false, true
			if sorte == "Argent" then p.CastShadow = false end
			p.Parent = g
		end
	end
	p2.Parent = dossier
	import:Destroy()
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local P2 = SS.Batiments.Sol.P2
local function centre(nom)
	local m = P2:FindFirstChild(nom)
	if not m then return "absent" end
	local cf = m:GetBoundingBox()
	return string.format("(%.1f, %.1f)", cf.Position.X, cf.Position.Z)
end
local n = 0
for _, d in P2:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return string.format("Sol P2 : %d pièces, %d maillages | faille %s (attendu 117, 43.5) | invocation %s (attendu 18, -123)",
	#P2:GetChildren(), n, centre("Socle_Faille"), centre("Socle_Invocation"))
