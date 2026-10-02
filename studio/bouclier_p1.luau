-- Range le bouclier rond (blender/export_p1/Bouclier_P1.fbx, importé dans Workspace) dans
-- ServerStorage.Armes.Bouclier : pivot au centre du dos, LookVector du côté de la face. Le service de
-- combat le soude à l'avant-bras gauche de chaque héros (prise dans src/shared/Config/Combat.luau).
-- Relançable (remplace le bouclier), annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ASPECT = {  -- suffixe du maillage -> couleur, matériau
	Bois = {Color3.fromRGB(92, 64, 42), Enum.Material.Wood},
	Metal = {Color3.fromRGB(120, 130, 145), Enum.Material.Metal},
	Argent = {Color3.fromRGB(205, 212, 222), Enum.Material.Metal},
	Cuir = {Color3.fromRGB(58, 44, 34), Enum.Material.Leather},
}

local rec = CHS:TryBeginRecording("Bouclier P1 (kit Blender)")
local ok, err = pcall(function()
	-- l'importeur ne garde pas toujours le nom du fichier : on cherche le modèle qui contient le bois
	local import
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "Bouclier_P1_Bois" then
			import = d:FindFirstAncestorOfClass("Model")
			break
		end
	end
	assert(import, "Importe d'abord blender/export_p1/Bouclier_P1.fbx.")
	local bouclier = Instance.new("Model")
	bouclier.Name = "Bouclier"
	local parts = {}
	for _, p in import:GetDescendants() do
		if p:IsA("MeshPart") then
			local sorte = p.Name:match("^Bouclier_P1_(%a+)")
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. p.Name)
			p.Color, p.Material = a[1], a[2]
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
			p.Name = sorte
			p.Parent = bouclier
			parts[sorte] = p
		end
	end
	assert(parts.Bois and parts.Argent and parts.Cuir, "Il manque une pièce (Bois, Argent ou Cuir).")
	-- face : du cuir (au dos) vers l'umbo d'argent (devant), sur l'axe le plus marqué
	local d = parts.Argent.Position - parts.Cuir.Position
	local axe = Vector3.new(0, 0, 1)
	if math.abs(d.X) > math.abs(d.Z) and math.abs(d.X) > math.abs(d.Y) then axe = Vector3.new(1, 0, 0) end
	local face = if d:Dot(axe) >= 0 then axe else -axe
	local epaisseur = math.abs(parts.Bois.Size:Dot(axe))
	local dos = parts.Bois.Position - face * (epaisseur / 2)
	bouclier.WorldPivot = CFrame.lookAt(dos, dos + face)
	local armes = SS:FindFirstChild("Armes") or Instance.new("Folder")
	armes.Name, armes.Parent = "Armes", SS
	if armes:FindFirstChild("Bouclier") then armes.Bouclier:Destroy() end
	bouclier:PivotTo(CFrame.identity)
	bouclier.Parent = armes
	import:Destroy()
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local b = SS.Armes.Bouclier
local _, taille = b:GetBoundingBox()
return string.format("Bouclier rangé : %.2f × %.2f × %.2f studs | umbo en z = %.2f (attendu négatif : face vers -Z)",
	taille.X, taille.Y, taille.Z, b.Argent.Position.Z)
