-- Finit l'invocation 1 étoile « tank » (version TRELLIS, riggée par Avatar Setup : Workspace.Scene_autosetup) :
-- gourdin soudé à la main droite, bouclier à la main gauche (blender/export_p1/Armes_Tank_P1.fbx, importé
-- dans Workspace), animation de frappe ReplicatedStorage.Animations.GourdinFrappe, puis rangement dans
-- ServerStorage.Invocations.Tank_P1. Poses calculées sur son squelette (cinématique directe) : gourdin armé
-- au-dessus de l'épaule puis abattu devant lui, bouclier levé face à la cible pendant tout le geste.
-- Relançable tant que le tank et les armes sont dans Workspace, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local ASPECT = {
	Bois = {Color3.fromRGB(124, 88, 58), Enum.Material.Wood},
	Fer = {Color3.fromRGB(96, 98, 104), Enum.Material.Metal},
	Corde = {Color3.fromRGB(176, 150, 108), Enum.Material.Fabric},
}
local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
}
local TENDU = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.In}
local LACHE = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out}
local DOUX = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut}
local function avec(base, ajout)
	local t = table.clone(base)
	for k, v in ajout do t[k] = v end
	return t
end

-- armer : poids sur la jambe arrière, buste tourné, gourdin au-dessus de l'épaule, bouclier devant
local ARMER = {
	LowerTorso = {0, -10, 0, 0, -0.1, 0.1}, UpperTorso = {-8, -20, 0}, Head = {0, 15, 0},
	RightUpperArm = {111, -5, -39}, RightLowerArm = {75, 0, 0}, RightHand = {-24, 0, 13},
	LeftUpperArm = {-34, -95, -2}, LeftLowerArm = {148, 0, 0}, LeftHand = {26, 0, 51},
	RightUpperLeg = {-12, 0, 6}, RightLowerLeg = {-25, 0, 0}, LeftUpperLeg = {14, 0, -5}, LeftLowerLeg = {-10, 0, 0},
}
-- frapper : fente avant, buste qui suit le coup, gourdin abattu devant, bouclier toujours levé
local FRAPPER = {
	LowerTorso = {0, 12, 0, 0, -0.25, -0.15}, UpperTorso = {18, 22, 0}, Head = {-10, -18, 0},
	RightUpperArm = {40, -19, 10}, RightLowerArm = {0, 0, 0}, RightHand = {-42, 0, 11},
	LeftUpperArm = {67, -42, 74}, LeftLowerArm = {49, 0, 0}, LeftHand = {-55, 0, 31},
	LeftUpperLeg = {38, 0, -5}, LeftLowerLeg = {-40, 0, 0}, RightUpperLeg = {-22, 0, 8}, RightLowerLeg = {-18, 0, 0},
}
local CLES = {
	{0, {}, DOUX},
	{0.3, ARMER, DOUX},
	{0.42, avec(ARMER, {RightUpperArm = {116, -5, -39}, UpperTorso = {-10, -23, 0}}), TENDU},   -- temps marqué
	{0.55, FRAPPER, LACHE},
	{0.7, avec(FRAPPER, {UpperTorso = {20, 25, 0}}), DOUX},
	{1.0, {}, DOUX},
}
local function sequence(nom, cles)
	local animees = {}
	for _, cle in cles do
		for art in cle[2] do animees[art] = true end
	end
	local ks = Instance.new("KeyframeSequence")
	ks.Name, ks.Loop, ks.Priority = nom, false, Enum.AnimationPriority.Action
	for _, cle in cles do
		local kf = Instance.new("Keyframe")
		kf.Time = cle[1]
		local poses = {}
		local function pose(art)
			if poses[art] then return poses[art] end
			local p = Instance.new("Pose")
			p.Name = art
			p.EasingStyle, p.EasingDirection = cle[3][1], cle[3][2]
			p.Weight = 0
			poses[art] = p
			p.Parent = if PARENT[art] then pose(PARENT[art]) else kf
			return p
		end
		for art in animees do
			local a = cle[2][art] or {0, 0, 0}
			local p = pose(art)
			p.Weight = 1
			p.CFrame = CFrame.new(a[4] or 0, a[5] or 0, a[6] or 0)
				* CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
		end
		kf.Parent = ks
	end
	return ks
end

local rec = CHS:TryBeginRecording("Invocation tank P1 (TRELLIS)")
local ok, err = pcall(function()
	local perso = workspace:FindFirstChild("Scene_autosetup")
	assert(perso and perso:FindFirstChildOfClass("Humanoid"), "Tank riggé introuvable (Workspace.Scene_autosetup).")
	local import = workspace:FindFirstChild("Armes_Tank_P1")
	if not import then
		for _, d in workspace:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == "Gourdin_Bois" then import = d:FindFirstAncestorOfClass("Model") break end
		end
	end
	assert(import, "Importe d'abord blender/export_p1/Armes_Tank_P1.fbx.")
	local gourdin, bouclier = Instance.new("Model"), Instance.new("Model")
	gourdin.Name, bouclier.Name = "Gourdin", "Bouclier"
	for _, m in import:GetDescendants() do
		if m:IsA("MeshPart") then
			local arme, sorte = m.Name:match("^(%a+)_(%a+)")
			local a = ASPECT[sorte]
			assert(a and (arme == "Gourdin" or arme == "Bouclier"), "Maillage inattendu : " .. m.Name)
			m.Color, m.Material = a[1], a[2]
			m.Anchored, m.Massless = false, true
			m.CanCollide, m.CanTouch, m.CanQuery = false, false, false
			m.Name = sorte
			m.Parent = if arme == "Gourdin" then gourdin else bouclier
		end
	end
	-- pivots : poignée du gourdin (son bout le plus fin, du côté du pommeau) et poignée du bouclier
	local gb = gourdin:FindFirstChild("Bois")
	local cfG, tailleG = gb.CFrame, gb.Size
	gourdin.WorldPivot = CFrame.new(cfG.Position - cfG.UpVector * (tailleG.Y / 2 - 0.56))   -- poignée à 0,56 du pommeau
	local _, tailleB = bouclier:GetBoundingBox()
	local bb = bouclier:FindFirstChild("Bois")
	-- la poignée est au dos du bouclier : du côté opposé aux clous (face avant)
	local face = (bouclier.Fer.Position - bb.Position) * Vector3.new(0, 0, 1)
	local sensZ = if face.Z < 0 then 1 else -1
	local cfB = bouclier:GetBoundingBox()
	bouclier.WorldPivot = CFrame.new(cfB.Position + Vector3.new(0, 0, sensZ * (tailleB.Z / 2 - 0.1)))

	local r = perso.HumanoidRootPart.CFrame
	local X, Y, Zf = r.RightVector, r.UpVector, r.LookVector
	local dG = (Zf - Y * 0.35).Unit
	gourdin:PivotTo(CFrame.fromMatrix(perso.RightHand.Position, X, dG, X:Cross(dG)))
	local N = (-X * math.cos(math.rad(35)) + Zf * math.sin(math.rad(35))).Unit
	bouclier:PivotTo(CFrame.fromMatrix(perso.LeftHand.Position, Y:Cross(-N), Y, -N))
	for arme, main in {[gourdin] = perso.RightHand, [bouclier] = perso.LeftHand} do
		for _, m in arme:GetChildren() do
			local s = Instance.new("WeldConstraint")
			s.Part0, s.Part1 = main, m
			s.Parent = m
		end
		arme.Parent = perso
	end
	import:Destroy()

	local dossier = RS:FindFirstChild("Animations") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Animations", RS
	if dossier:FindFirstChild("GourdinFrappe") then dossier.GourdinFrappe:Destroy() end
	sequence("GourdinFrappe", CLES).Parent = dossier

	perso.Name = "Tank_P1"
	perso:FindFirstChildOfClass("Humanoid").DisplayName = "Rookie Shieldbearer"
	perso:SetAttribute("Classe", "Tank")
	perso:SetAttribute("Etoiles", 1)
	local anim = perso:FindFirstChild("AnimateScript")
	if anim then anim:Destroy() end
	perso.HumanoidRootPart.Anchored = false
	local inv = SS:FindFirstChild("Invocations") or Instance.new("Folder")
	inv.Name, inv.Parent = "Invocations", SS
	if inv:FindFirstChild("Tank_P1") then inv.Tank_P1:Destroy() end
	perso.Parent = inv
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local t = SS.Invocations.Tank_P1
return string.format("Tank_P1 rangé : gourdin sur %s, bouclier sur %s | GourdinFrappe %d clés",
	t.Gourdin.Bois:FindFirstChildOfClass("WeldConstraint").Part0.Name, t.Bouclier.Bois:FindFirstChildOfClass("WeldConstraint").Part0.Name,
	#RS.Animations.GourdinFrappe:GetChildren())
