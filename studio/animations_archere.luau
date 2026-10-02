-- Animation de tir de l'archère (ReplicatedStorage.Animations.ArcTir), poses calculées sur son squelette
-- R15 (Avatar Setup) par cinématique directe : bras gauche tendu droit vers la cible, poignet tourné pour
-- tenir l'arc vertical dos vers la cible, main droite qui bande la corde jusqu'à la joue.
-- 1,2 s : lever l'arc (0,25), encocher, bander (0,6), tenir, lâcher à 0,88 (la flèche part), revenir.
-- Ressoude aussi l'arc perpendiculaire à l'avant-bras (au repos : branches vers l'avant, dos vers le bas).
-- Relançable, annulable d'un Ctrl+Z. Pour le jeu publié : publier ArcTir et reporter l'identifiant.
local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

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

-- buste de profil (épaule gauche vers la cible), tête tournée vers elle, appuis écartés et genoux souples
local CORPS = {
	LowerTorso = {0, -25, 0, 0, -0.08, 0}, UpperTorso = {0, -35, 0}, Head = {0, 55, 0},
	LeftUpperLeg = {0, 25, -8}, RightUpperLeg = {-6, 25, 8}, LeftLowerLeg = {-10, 0, 0}, RightLowerLeg = {-8, 0, 0},
	LeftUpperArm = {45, -10, -35}, LeftLowerArm = {0, 0, 0}, LeftHand = {40, 30, -40},
}
local ENCOCHE = avec(CORPS, {RightUpperArm = {40, 70, -10}, RightLowerArm = {70, 0, 0}, RightHand = {0, 0, 0}})
local BANDE = avec(CORPS, {RightUpperArm = {16, 120, -10}, RightLowerArm = {135, 0, 0}, RightHand = {0, 0, 0},
	UpperTorso = {-3, -37, 0}})
local LACHER = avec(BANDE, {RightUpperArm = {5, 130, 5}, RightLowerArm = {150, 0, 0}, RightHand = {0, 0, 15},
	LeftUpperArm = {47, -10, -35}})

local CLES = {
	{0, {}, DOUX},
	{0.25, avec(ENCOCHE, {LeftUpperArm = {40, -10, -35}}), DOUX},
	{0.6, BANDE, TENDU},
	{0.86, avec(BANDE, {RightUpperArm = {17, 121, -10}}), TENDU},
	{0.92, LACHER, LACHE},
	{1.2, {}, DOUX},
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

local rec = CHS:TryBeginRecording("Animation de tir de l'archère")
local ok, err = pcall(function()
	local dossier = RS:FindFirstChild("Animations") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Animations", RS
	if dossier:FindFirstChild("ArcTir") then dossier.ArcTir:Destroy() end
	sequence("ArcTir", CLES).Parent = dossier

	-- arc ressoudé perpendiculaire à l'avant-bras : au repos, branches vers l'avant, dos de l'arc vers le bas
	local perso = SS.Invocations.Archere_P1
	local arc, main, racine = perso.Arc, perso.LeftHand, perso.HumanoidRootPart
	for _, m in arc:GetChildren() do
		local s = m:FindFirstChildOfClass("WeldConstraint")
		if s then s:Destroy() end
	end
	local r = racine.CFrame
	arc:PivotTo(CFrame.fromMatrix(main.Position, r.RightVector, r.LookVector, r.UpVector))
	for _, m in arc:GetChildren() do
		local s = Instance.new("WeldConstraint")
		s.Part0, s.Part1 = main, m
		s.Parent = m
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return "ArcTir : " .. #RS.Animations.ArcTir:GetChildren() .. " clés | arc ressoudé perpendiculaire à l'avant-bras"
