-- Finit l'invocation 1 étoile « archère » : le personnage riggé par Avatar Setup
-- (Workspace.Archere_P1_Node_autosetup) reçoit son arc (blender/export_p1/Arc_P1.fbx, importé dans
-- Workspace), soudé à la main gauche, puis le tout est rangé dans ServerStorage.Invocations.Archere_P1.
-- Relançable tant que les deux sont dans Workspace, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ASPECT = {
	Bois = {Color3.fromRGB(140, 100, 64), Enum.Material.Wood},
	Cuir = {Color3.fromRGB(90, 62, 42), Enum.Material.Leather},
	Corde = {Color3.fromRGB(212, 202, 172), Enum.Material.Fabric},
}

local rec = CHS:TryBeginRecording("Invocation archère P1")
local ok, err = pcall(function()
	local perso = workspace:FindFirstChild("Archere_P1_Node_autosetup")
	assert(perso and perso:FindFirstChildOfClass("Humanoid"), "Archère riggée introuvable (Workspace.Archere_P1_Node_autosetup).")
	local import
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "Arc_P1_Bois" then
			import = d:FindFirstAncestorOfClass("Model")
			break
		end
	end
	assert(import, "Importe d'abord blender/export_p1/Arc_P1.fbx.")

	-- l'arc : pivot au centre de la poignée, vertical (+Y), dos de l'arc vers -Z
	local arc = Instance.new("Model")
	arc.Name = "Arc"
	local poignee
	for _, m in import:GetDescendants() do
		if m:IsA("MeshPart") then
			local sorte = m.Name:match("^Arc_P1_(%a+)")
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. m.Name)
			m.Color, m.Material = a[1], a[2]
			m.Anchored, m.Massless = false, true
			m.CanCollide, m.CanTouch, m.CanQuery = false, false, false
			m.Name = sorte
			m.Parent = arc
			if sorte == "Cuir" then poignee = m end
		end
	end
	arc.WorldPivot = CFrame.new(poignee.Position)

	-- dans la main gauche : poignée au creux de la main, arc vertical, dos vers l'avant du personnage
	local racine = perso.HumanoidRootPart
	local main = perso.LeftHand
	local position = main.Position - racine.CFrame.UpVector * 0.05
	arc:PivotTo(CFrame.fromMatrix(position, racine.CFrame.RightVector, racine.CFrame.UpVector))
	for _, m in arc:GetChildren() do
		local soudure = Instance.new("WeldConstraint")
		soudure.Part0, soudure.Part1 = main, m
		soudure.Parent = m
	end
	arc.Parent = perso
	import:Destroy()

	perso.Name = "Archere_P1"
	local h = perso:FindFirstChildOfClass("Humanoid")
	h.DisplayName = "Rookie Huntress"
	perso:SetAttribute("Classe", "Archer")
	perso:SetAttribute("Etoiles", 1)
	-- l'AnimateScript d'Avatar Setup est un LocalScript : il ne tourne pas sur un personnage du serveur ;
	-- le service des invocations joue lui-même les animations
	local anim = perso:FindFirstChild("AnimateScript")
	if anim then anim:Destroy() end
	racine.Anchored = false

	local dossier = SS:FindFirstChild("Invocations") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Invocations", SS
	if dossier:FindFirstChild("Archere_P1") then dossier.Archere_P1:Destroy() end
	perso.Parent = dossier
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local a = SS.Invocations.Archere_P1
return string.format("Archere_P1 rangée dans ServerStorage.Invocations, arc soudé : %s", tostring(a:FindFirstChild("Arc") ~= nil))
