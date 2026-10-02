-- Range l'épée de départ (blender/export_p1/Epee_P1.fbx, importée dans Workspace) dans
-- ServerStorage.Armes.Epee, pivot au centre de la poignée et lame vers +Y : le service de combat la
-- soude à la main droite de chaque héros (prise réglée dans src/shared/Config/Combat.luau).
-- Relançable (remplace l'épée), annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ASPECT = {  -- suffixe du maillage -> couleur, matériau
	Lame = {Color3.fromRGB(214, 222, 232), Enum.Material.Metal},
	Garde = {Color3.fromRGB(150, 160, 176), Enum.Material.Metal},
	Poignee = {Color3.fromRGB(58, 44, 34), Enum.Material.Leather},
}

local rec = CHS:TryBeginRecording("Épée P1 (kit Blender)")
local ok, err = pcall(function()
	-- l'importeur ne garde pas toujours le nom du fichier : on cherche le modèle qui contient la lame
	local import
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "Epee_P1_Lame" then
			import = d:FindFirstAncestorOfClass("Model")
			break
		end
	end
	assert(import, "Importe d'abord blender/export_p1/Epee_P1.fbx.")
	local epee = Instance.new("Model")
	epee.Name = "Epee"
	local poignee
	for _, p in import:GetDescendants() do
		if p:IsA("MeshPart") then
			local sorte = p.Name:match("^Epee_P1_(%a+)")
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. p.Name)
			p.Color, p.Material = a[1], a[2]
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
			p.CastShadow = true
			p.Name = sorte
			p.Parent = epee
			if sorte == "Poignee" then poignee = p end
		end
	end
	assert(poignee, "Poignée introuvable dans l'import.")
	epee.WorldPivot = CFrame.new(poignee.Position)   -- l'import arrive lame vers +Y
	local armes = SS:FindFirstChild("Armes") or Instance.new("Folder")
	armes.Name, armes.Parent = "Armes", SS
	if armes:FindFirstChild("Epee") then armes.Epee:Destroy() end
	epee:PivotTo(CFrame.identity)
	epee.Parent = armes
	import:Destroy()
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local _, taille = SS.Armes.Epee:GetBoundingBox()
return string.format("Épée rangée dans ServerStorage.Armes.Epee : %.2f × %.2f × %.2f studs", taille.X, taille.Y, taille.Z)
