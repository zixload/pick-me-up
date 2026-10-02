-- Finit l'invocation 1 étoile « mage » (TRELLIS, riggée par Avatar Setup : Workspace.Scene_autosetup) :
-- bâton de mage (blender/export_p1/Sceptre_P1.fbx, importé dans Workspace) soudé à la main droite, animation de sort
-- ReplicatedStorage.Animations.BatonSort, rangement dans ServerStorage.Invocations.Mage_P1.
-- Les poses du geste sont calculées ici sur son propre squelette (cinématique directe, affinée autour d'une
-- pose naturelle) : bâton pointé vers la cible, pierre en avant, main gauche tendue vers elle.
-- Relançable tant que le mage et le bâton sont dans Workspace, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local ASPECT = {
	Bois = {Color3.fromRGB(96, 72, 52), Enum.Material.Wood},
	Cuir = {Color3.fromRGB(70, 50, 36), Enum.Material.Leather},
	Cristal = {Color3.fromRGB(156, 204, 228), Enum.Material.Glass},
}
local PRISE = 2.42   -- distance entre le pied du bâton et la prise de main (build_sceptre_p1.py)
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

local function ang(a)
	if not a then return CFrame.identity end
	return CFrame.new(a[4] or 0, a[5] or 0, a[6] or 0) * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end
local function avec(base, ajout)
	local t = table.clone(base)
	for k, v in ajout do t[k] = v end
	return t
end

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
			p.CFrame = ang(a)
		end
		kf.Parent = ks
	end
	return ks
end

local rec = CHS:TryBeginRecording("Invocation mage P1")
local ok, err = pcall(function()
	local perso = workspace:FindFirstChild("Scene_autosetup")
	assert(perso and perso:FindFirstChildOfClass("Humanoid"), "Mage riggé introuvable (Workspace.Scene_autosetup).")
	local import
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "Sceptre_Bois" then import = d:FindFirstAncestorOfClass("Model") break end
	end
	assert(import, "Importe d'abord blender/export_p1/Sceptre_P1.fbx.")

	-- ---------------------------------------------------------------- squelette et cinématique directe
	local par = {}
	for _, j in perso:GetDescendants() do
		if j:IsA("AnimationConstraint") or j:IsA("Motor6D") then
			local p0 = if j:IsA("Motor6D") then j.Part0 else j.Attachment0.Parent
			local p1 = if j:IsA("Motor6D") then j.Part1 else j.Attachment1.Parent
			local c0 = if j:IsA("Motor6D") then j.C0 else j.Attachment0.CFrame
			local c1 = if j:IsA("Motor6D") then j.C1 else j.Attachment1.CFrame
			par[p1.Name] = {p0.Name, c0, c1}
		end
	end
	local function fk(p)
		local cf = {HumanoidRootPart = CFrame.identity}
		local function get(n)
			if cf[n] then return cf[n] end
			local q = par[n]
			cf[n] = get(q[1]) * q[2] * ang(p[n]) * q[3]:Inverse()
			return cf[n]
		end
		for n in par do get(n) end
		return cf
	end
	local repos = fk({})
	local function articulation(cf, partie) return (cf[par[partie][1]] * par[partie][2]).Position end
	local epD, epG = articulation(repos, "RightUpperArm"), articulation(repos, "LeftUpperArm")
	-- le bâton, dans le repère de la main droite : vertical au repos, prise au creux de la main
	local batonDansMain = repos.RightHand:Inverse() * CFrame.new(repos.RightHand.Position)

	local function pose(base, bras, v)
		return avec(base, {[bras .. "UpperArm"] = {v[1], v[2], v[3]}, [bras .. "LowerArm"] = {v[4], 0, 0},
			[bras .. "Hand"] = {v[5], 0, v[6]}})
	end
	local function affiner(base, bras, depart, evaluer)
		local function s(v)
			local e = 0
			for i = 1, 6 do e += ((v[i] - depart[i]) / 60) ^ 2 end
			return evaluer(fk(pose(base, bras, v))) + e * 0.15
		end
		local meilleur, sb = table.clone(depart), s(depart)
		for _, pas in {12, 6, 3, 1} do
			local mieux = true
			while mieux do
				mieux = false
				for i = 1, 6 do
					for _, sens in {-1, 1} do
						local v = table.clone(meilleur)
						v[i] += sens * pas
						if i == 4 then v[i] = math.clamp(v[i], 0, 145) end
						local sc = s(v)
						if sc < sb - 1e-4 then sb, meilleur, mieux = sc, v, true end
					end
				end
			end
		end
		return meilleur
	end
	-- le buste s'avance vers la cible, épaule droite en avant
	local BUSTE = {LowerTorso = {0, 5, 0}, UpperTorso = {8, 12, 0}, Head = {-6, -8, 0}}
	local AVANT = Vector3.new(0, 0, -1)
	local DIR_BATON = Vector3.new(0, 0.55, -0.83).Unit   -- pierre pointée vers la cible
	local droite = affiner(BUSTE, "Right", {100, 0, -15, 45, 0, 0}, function(cf)
		local b = cf.RightHand * batonDansMain
		return 4 * (1 - b.UpVector:Dot(DIR_BATON)) + (cf.RightHand.Position - (epD + Vector3.new(-0.1, 0.15, -0.7))).Magnitude
	end)
	local gauche = affiner(BUSTE, "Left", {75, 0, 15, 15, 0, 0}, function(cf)
		local dir = (cf.LeftHand.Position - articulation(cf, "LeftUpperArm")).Unit
		return 4 * (1 - dir:Dot(Vector3.new(0.15, -0.05, -1).Unit))
	end)
	local LEVER = pose(pose(BUSTE, "Right", droite), "Left", gauche)
	local CLES = {
		{0, {}, DOUX},
		{0.35, LEVER, TENDU},
		{0.6, avec(LEVER, {UpperTorso = {10, 14, 0}}), LACHE},   -- moment où l'orbe part
		{0.85, LEVER, DOUX},
		{1.2, {}, DOUX},
	}

	-- ---------------------------------------------------------------- bâton soudé à la main droite
	local baton = Instance.new("Model")
	baton.Name = "Baton"
	for _, m in import:GetDescendants() do
		if m:IsA("MeshPart") then
			local sorte = m.Name:match("^Sceptre_(%a+)")
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. m.Name)
			m.Color, m.Material = a[1], a[2]
			m.Anchored, m.Massless = false, true
			m.CanCollide, m.CanTouch, m.CanQuery = false, false, false
			m.Name = sorte
			m.Parent = baton
		end
	end
	local bois = baton.Bois
	baton.WorldPivot = CFrame.new(bois.Position - Vector3.yAxis * (bois.Size.Y / 2 - PRISE))
	local r = perso.HumanoidRootPart.CFrame
	baton:PivotTo(CFrame.fromMatrix(perso.RightHand.Position, r.RightVector, r.UpVector, -r.LookVector))
	for _, m in baton:GetChildren() do
		local s = Instance.new("WeldConstraint")
		s.Part0, s.Part1 = perso.RightHand, m
		s.Parent = m
	end
	baton.Parent = perso
	import:Destroy()

	local dossier = RS:FindFirstChild("Animations") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Animations", RS
	if dossier:FindFirstChild("BatonSort") then dossier.BatonSort:Destroy() end
	sequence("BatonSort", CLES).Parent = dossier

	perso.Name = "Mage_P1"
	perso:FindFirstChildOfClass("Humanoid").DisplayName = "Rookie Mage"
	perso:SetAttribute("Classe", "Mage")
	perso:SetAttribute("Etoiles", 1)
	local anim = perso:FindFirstChild("AnimateScript")
	if anim then anim:Destroy() end
	perso.HumanoidRootPart.Anchored = false
	local inv = SS:FindFirstChild("Invocations") or Instance.new("Folder")
	inv.Name, inv.Parent = "Invocations", SS
	if inv:FindFirstChild("Mage_P1") then inv.Mage_P1:Destroy() end
	perso.Parent = inv
	print(string.format("BatonSort : bras droit {%d,%d,%d} coude %d poignet {%d,0,%d} | bras gauche {%d,%d,%d} coude %d",
		droite[1], droite[2], droite[3], droite[4], droite[5], droite[6], gauche[1], gauche[2], gauche[3], gauche[4]))
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local s = SS.Invocations.Mage_P1
local _, t = s.Baton:GetBoundingBox()
return string.format("Mage_P1 rangé : bâton de %.1f studs sur %s | BatonSort %d clés", t.Y,
	s.Baton.Bois:FindFirstChildOfClass("WeldConstraint").Part0.Name, #RS.Animations.BatonSort:GetChildren())
