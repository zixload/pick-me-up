-- Animations de combat (R15), rangées dans ReplicatedStorage.Animations : Coup1 (diagonale de haut à
-- droite vers bas à gauche), Coup2 (revers horizontal), Coup3 (bond et frappe verticale à deux mains),
-- Esquive. Version « cinéma » (02/10/2026) : corps entier, jambes comprises. Chaque coup suit le même
-- découpage : anticipation (le corps s'enroule, s'abaisse et marque un temps), frappe très rapide en
-- fente, la lame continue au-delà de l'impact, courte pose figée, puis retour lent à la garde.
-- Durées et moment de l'impact alignés sur src/shared/Config/Combat.luau.
-- En Studio, le jeu les joue directement. Pour le jeu publié : clic droit sur chaque séquence >
-- Save to Roblox, puis reporter l'identifiant dans Combat.ANIMATIONS. Relançable (remplace les séquences).
local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")

-- parent de chaque articulation dans l'arbre des poses R15
local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
}

-- Angles en degrés {x, y, z} dans le repère de la pièce parente :
--   x > 0 lève le membre vers l'avant (penche le buste en arrière), un genou plie avec x < 0 ;
--   y > 0 tourne vers la gauche ; z > 0 écarte le membre droit vers la droite.
-- LowerTorso accepte en plus un déplacement {x, y, z, dx, dy, dz} (studs) : dy < 0 abaisse le corps,
-- dz < 0 le porte vers l'avant.
-- Chaque clé : {temps, poses, transition vers la clé suivante}. « tendu » accélère (fin d'anticipation),
-- « lache » décélère (après la frappe), « doux » accélère puis décélère.
local TENDU = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.In}
local LACHE = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out}
local DOUX = {Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut}

-- jambes en fente, pied gauche devant (coups 1 et 3) ou pied droit devant (coup 2)
local function fenteGauche(prof)
	return {
		LeftUpperLeg = {50 * prof, 0, -5}, LeftLowerLeg = {-55 * prof, 0, 0}, LeftFoot = {5, 0, 0},
		RightUpperLeg = {-30 * prof, 0, 8}, RightLowerLeg = {-22 * prof, 0, 0}, RightFoot = {20 * prof, 0, 0},
	}
end
local function avec(base, ajout)
	local t = table.clone(base)
	for k, v in ajout do t[k] = v end
	return t
end

local COUP1_ARME = {
	LowerTorso = {0, -25, 0, 0, -0.25, 0.1}, UpperTorso = {8, -35, -5}, Head = {0, 45, 0},
	RightUpperArm = {150, 0, 50}, RightLowerArm = {55, 0, 0}, RightHand = {-20, 0, 0},
	LeftUpperArm = {35, 0, -30}, LeftLowerArm = {40, 0, 0},
	RightUpperLeg = {-10, 0, 8}, RightLowerLeg = {-25, 0, 0}, RightFoot = {10, 0, 0},
	LeftUpperLeg = {25, 0, -5}, LeftLowerLeg = {-30, 0, 0}, LeftFoot = {5, 0, 0},
}
local COUP1_FRAPPE = avec(fenteGauche(1), {
	LowerTorso = {-8, 30, 0, 0, -0.45, -0.35}, UpperTorso = {-15, 30, 5}, Head = {5, -45, 0},
	RightUpperArm = {45, 0, -50}, RightLowerArm = {5, 0, 0}, RightHand = {10, 0, 0},
	LeftUpperArm = {-30, 0, -35}, LeftLowerArm = {20, 0, 0},
})
local COUP1_SUITE = avec(COUP1_FRAPPE, {
	LowerTorso = {-10, 35, 0, 0, -0.5, -0.4}, UpperTorso = {-18, 40, 6}, Head = {5, -55, 0},
	RightUpperArm = {30, 0, -65}, RightHand = {15, 0, 0},
})

local COUP2_ARME = {
	LowerTorso = {0, 35, 0, 0, -0.3, 0}, UpperTorso = {5, 40, 0}, Head = {0, -55, 0},
	RightUpperArm = {85, 0, -80}, RightLowerArm = {70, 0, 0}, RightHand = {0, 0, 0},
	LeftUpperArm = {20, 0, -20}, LeftLowerArm = {50, 0, 0},
	RightUpperLeg = {30, 0, 5}, RightLowerLeg = {-40, 0, 0}, RightFoot = {10, 0, 0},
	LeftUpperLeg = {-10, 0, -5}, LeftLowerLeg = {-25, 0, 0}, LeftFoot = {10, 0, 0},
}
local COUP2_FRAPPE = {
	LowerTorso = {-5, -35, 0, 0, -0.45, -0.2}, UpperTorso = {-8, -40, 0}, Head = {0, 55, 0},
	RightUpperArm = {90, 0, 70}, RightLowerArm = {0, 0, 0}, RightHand = {0, 0, -15},
	LeftUpperArm = {-20, 0, -40}, LeftLowerArm = {15, 0, 0},
	RightUpperLeg = {45, 0, 10}, RightLowerLeg = {-50, 0, 0}, RightFoot = {5, 0, 0},
	LeftUpperLeg = {-30, 0, -5}, LeftLowerLeg = {-20, 0, 0}, LeftFoot = {20, 0, 0},
}
local COUP2_SUITE = avec(COUP2_FRAPPE, {
	LowerTorso = {-6, -42, 0, 0, -0.5, -0.25}, UpperTorso = {-10, -50, 0}, Head = {0, 65, 0},
	RightUpperArm = {80, 0, 85}, RightHand = {0, 0, -25},
})

-- coup 3 : l'épée se tient à une main ; le bras gauche fait contrepoids (tendu vers l'avant à l'armé
-- et pendant le bond, rejeté en arrière et sur le côté quand la lame s'abat)
local COUP3_ACCROUPI = {
	LowerTorso = {10, 0, 0, 0, -0.7, 0.15}, UpperTorso = {15, -10, 0}, Head = {-15, 10, 0},
	RightUpperArm = {175, 0, 15}, RightLowerArm = {30, 0, 0}, RightHand = {0, 0, 0},
	LeftUpperArm = {60, 0, -25}, LeftLowerArm = {25, 0, 0}, LeftHand = {0, 0, 0},
	RightUpperLeg = {40, 0, 8}, RightLowerLeg = {-75, 0, 0}, RightFoot = {35, 0, 0},
	LeftUpperLeg = {40, 0, -8}, LeftLowerLeg = {-75, 0, 0}, LeftFoot = {35, 0, 0},
}
local COUP3_SAUT = {
	LowerTorso = {18, 0, 0, 0, 0.6, 0}, UpperTorso = {20, -15, 0}, Head = {-20, 15, 0},
	RightUpperArm = {190, 0, 10}, RightLowerArm = {45, 0, 0}, RightHand = {-10, 0, 0},
	LeftUpperArm = {95, 0, -45}, LeftLowerArm = {15, 0, 0}, LeftHand = {0, 0, -10},
	RightUpperLeg = {50, 0, 5}, RightLowerLeg = {-80, 0, 0}, RightFoot = {20, 0, 0},
	LeftUpperLeg = {50, 0, -5}, LeftLowerLeg = {-80, 0, 0}, LeftFoot = {20, 0, 0},
}
local COUP3_IMPACT = {
	LowerTorso = {-25, 0, 0, 0, -0.75, -0.4}, UpperTorso = {-30, 12, 0}, Head = {15, -12, 0},
	RightUpperArm = {40, 0, -5}, RightLowerArm = {0, 0, 0}, RightHand = {15, 0, 0},
	LeftUpperArm = {-45, 0, -55}, LeftLowerArm = {30, 0, 0}, LeftHand = {0, 0, -10},
	LeftUpperLeg = {70, 0, -5}, LeftLowerLeg = {-80, 0, 0}, LeftFoot = {10, 0, 0},
	RightUpperLeg = {-20, 0, 10}, RightLowerLeg = {-60, 0, 0}, RightFoot = {30, 0, 0},
}
local COUP3_ECRASE = avec(COUP3_IMPACT, {LowerTorso = {-27, 0, 0, 0, -0.8, -0.42}, UpperTorso = {-34, 14, 0},
	LeftUpperArm = {-52, 0, -62}})

local ESQUIVE_BAS = {
	LowerTorso = {-30, 0, 0, 0, -0.55, 0}, UpperTorso = {-15, 0, 0}, Head = {10, 0, 0},
	RightUpperArm = {-50, 0, 20}, RightLowerArm = {20, 0, 0}, LeftUpperArm = {-50, 0, -20}, LeftLowerArm = {20, 0, 0},
	RightUpperLeg = {40, 0, 0}, RightLowerLeg = {-70, 0, 0}, RightFoot = {20, 0, 0},
	LeftUpperLeg = {-25, 0, 0}, LeftLowerLeg = {-40, 0, 0}, LeftFoot = {15, 0, 0},
}

local SEQUENCES = {
	Coup1 = {   -- 0,75 s, impact à 0,34
		{0, {}, DOUX},
		{0.18, COUP1_ARME, TENDU},
		{0.27, avec(COUP1_ARME, {RightUpperArm = {155, 0, 52}, UpperTorso = {9, -38, -5}}), TENDU},   -- temps marqué
		{0.34, COUP1_FRAPPE, LACHE},
		{0.44, COUP1_SUITE, DOUX},
		{0.52, COUP1_SUITE, DOUX},
		{0.75, {}, DOUX},
	},
	Coup2 = {   -- 0,75 s, impact à 0,32
		{0, {}, DOUX},
		{0.16, COUP2_ARME, TENDU},
		{0.25, avec(COUP2_ARME, {UpperTorso = {5, 48, 0}, RightUpperArm = {88, 0, -85}}), TENDU},
		{0.32, COUP2_FRAPPE, LACHE},
		{0.42, COUP2_SUITE, DOUX},
		{0.5, COUP2_SUITE, DOUX},
		{0.75, {}, DOUX},
	},
	Coup3 = {   -- 1,05 s, impact à 0,6
		{0, {}, DOUX},
		{0.22, COUP3_ACCROUPI, DOUX},
		{0.42, COUP3_SAUT, TENDU},
		{0.6, COUP3_IMPACT, LACHE},
		{0.7, COUP3_ECRASE, DOUX},
		{0.85, COUP3_ECRASE, DOUX},
		{1.05, {}, DOUX},
	},
	Esquive = {   -- 0,45 s
		{0, {}, LACHE},
		{0.08, ESQUIVE_BAS, DOUX},
		{0.3, avec(ESQUIVE_BAS, {LowerTorso = {-25, 0, 0, 0, -0.5, 0}}), DOUX},
		{0.45, {}, DOUX},
	},
}

local function sequence(nom, cles)
	-- toutes les articulations animées dans au moins une clé : présentes dans toutes (au repos sinon)
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

local rec = CHS:TryBeginRecording("Animations de combat")
local ok, err = pcall(function()
	local dossier = RS:FindFirstChild("Animations") or Instance.new("Folder")
	dossier.Name = "Animations"
	dossier.Parent = RS
	for nom, cles in SEQUENCES do
		local ancien = dossier:FindFirstChild(nom)
		if ancien then ancien:Destroy() end
		sequence(nom, cles).Parent = dossier
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local noms = {}
for _, k in RS.Animations:GetChildren() do table.insert(noms, k.Name .. " (" .. #k:GetChildren() .. " clés)") end
return "Animations : " .. table.concat(noms, ", ")
