-- Invocations : escouade du héros (02/10/2026).
--   Formation : chaque invocation a sa case dans une grille autour du héros (borne du centre d'entraînement),
--               gardée dans le profil (Formation).
--   Ordres : Suivre (garde la formation, ne riposte que si on l'attaque), Maintenir (tient sa case de formation
--            autour de l'endroit où est le héros quand l'ordre est donné, rappuyer la déplace ; attaque ce qui
--            est à sa portée), Attaquer (s'engage selon sa classe : le tank s'interpose devant les
--            fragiles, l'archère et le mage gardent leurs distances et fuient au contact, la soigneuse reste
--            derrière l'équipe et soigne le plus blessé).
--   Camps : les invocations d'un joueur visent les mannequins, les mobs, l'escouade d'entraînement (/sparring)
--           et, quand le PvP est actif dans le même duel, le joueur adverse et ses invocations.
-- Commandes : /summon <archer|tank|mage|healer>, /squad (toute la formation), /dismiss, /sparring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Combat = require(script.Parent.Combat)
local Donnees = require(script.Parent.Donnees)
local Config = require(ReplicatedStorage.Shared.Config.Invocations)

local Invocations = {}

local dossier = workspace:FindFirstChild("Invocations") or Instance.new("Folder")
dossier.Name = "Invocations"
dossier.Parent = workspace

local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
reseau.Name, reseau.Parent = "Reseau", ReplicatedStorage
local function distant(classe, nom)
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name, r.Parent = nom, reseau
	return r
end
local Ordre = distant("RemoteEvent", "OrdreEscouade")           -- client -> serveur : id de l'ordre
local Formation = distant("RemoteFunction", "FormationEscouade") -- client -> serveur : ("lire") | ("ecrire", grille)

local actives = {}   -- [modèle] = état de l'invocation
local ordres = {}    -- [joueur] = "Suivre" | "Maintenir" | "Attaquer"

local function racineDe(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart")
end
local function vivant(m: Model?): boolean
	local h = m and m:FindFirstChildOfClass("Humanoid")
	if not (h and h.Health > 0 and racineDe(m)) then return false end
	local j = Players:GetPlayerFromCharacter(m)
	return not (j and j:GetAttribute("KO"))   -- un héros à terre en arène n'est plus une cible
end
local function plat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ---------------------------------------------------------------- animations (jouées par le serveur)
local function animer(h: Humanoid, classe: string)
	local animateur = h:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animateur.Parent = h
	local pistes = {}
	for nom, id in Config.ANIMATIONS do
		local a = Instance.new("Animation")
		a.AnimationId = id
		pistes[nom] = animateur:LoadAnimation(a)
		pistes[nom].Looped = true
		pistes[nom].Priority = Enum.AnimationPriority.Core
	end
	pistes.repos:Play()
	-- attaque de la classe : identifiant publié, ou en Studio la séquence enregistrée à la volée
	local attaque = Config.ATTAQUES[classe]
	local id = attaque and attaque.animation or ""
	if attaque and id == "" and RunService:IsStudio() then
		local seq = ReplicatedStorage:FindFirstChild("Animations") and ReplicatedStorage.Animations:FindFirstChild(attaque.sequence)
		if seq then
			local ok, provisoire = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
			end)
			if ok then id = provisoire else warn("[Invocations] " .. attaque.sequence .. " : " .. tostring(provisoire)) end
		end
	end
	if id ~= "" then
		local a = Instance.new("Animation")
		a.AnimationId = id
		pistes.attaque = animateur:LoadAnimation(a)
		pistes.attaque.Priority = Enum.AnimationPriority.Action
		pistes.attaque.Looped = false
	end
	-- réactions : coup reçu, mise à terre
	for nom, id in Config.REACTIONS do
		local a = Instance.new("Animation")
		a.AnimationId = id
		pistes[nom] = animateur:LoadAnimation(a)
		pistes[nom].Priority = Enum.AnimationPriority.Action2
		pistes[nom].Looped = nom == "mort"
	end
	return pistes
end

-- marche ou course selon la vitesse réelle, cadence de l'animation calée sur elle. Lue sur la vitesse du corps
-- (pas sur Humanoid.Running) : la physique d'une invocation est calculée chez son maître, pas sur le serveur
local function locomotion(e)
	local pistes = e.pistes
	local v = e.r.AssemblyLinearVelocity
	local vitesse = Vector3.new(v.X, 0, v.Z).Magnitude
	local court = vitesse > 18
	if vitesse > 0.8 then
		local active, autre = if court then pistes.course else pistes.marche, if court then pistes.marche else pistes.course
		if autre.IsPlaying then autre:Stop(0.25) end
		if not active.IsPlaying then active:Play(0.25) end
		active:AdjustSpeed(vitesse / (if court then 24 else 16))
	else
		if pistes.marche.IsPlaying then pistes.marche:Stop(0.3) end
		if pistes.course.IsPlaying then pistes.course:Stop(0.3) end
	end
end

-- flash rouge bref sur une invocation touchée
local function flash(m: Model)
	local hl = m:FindFirstChild("FlashCoup")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "FlashCoup"
		hl.FillColor, hl.OutlineTransparency = Color3.fromRGB(255, 80, 70), 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
		Debris:AddItem(hl, 0.4)   -- pas de Highlight qui traîne : Roblox n'en affiche que 31 à la fois
	end
	hl.FillTransparency = 0.35
	TweenService:Create(hl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
end

-- ---------------------------------------------------------------- camps : alliés et ennemis
-- camp d'un joueur : "J<id>" ; camp de l'escouade d'entraînement lancée par un joueur : "S<id>"
local function joueurDuCamp(camp: string): Player?
	return Players:GetPlayerByUserId(tonumber(string.sub(camp, 2)) or 0)
end

local function enDuel(a: Player, b: Player): boolean
	return a:GetAttribute("PvP") == true and b:GetAttribute("PvP") == true
		and a:GetAttribute("Arene") ~= nil and a:GetAttribute("Arene") == b:GetAttribute("Arene")
end

local function alliesDe(e): {Model}
	local t = {}
	if string.sub(e.camp, 1, 1) == "J" then
		local j = joueurDuCamp(e.camp)
		if j and vivant(j.Character) then table.insert(t, j.Character) end
	end
	for m, autre in actives do
		if autre.camp == e.camp and vivant(m) then table.insert(t, m) end
	end
	return t
end

local function ennemisDe(e): {Model}
	local t = {}
	local genre, joueur = string.sub(e.camp, 1, 1), joueurDuCamp(e.camp)
	if genre == "J" then
		for _, m in CollectionService:GetTagged("Cible") do
			if vivant(m) then table.insert(t, m) end
		end
		for _, m in CollectionService:GetTagged("Ennemi") do
			local camp = m:GetAttribute("Camp")
			if vivant(m) and (camp == nil or camp == "S" .. string.sub(e.camp, 2)) then table.insert(t, m) end
		end
		if joueur then
			for _, autre in Players:GetPlayers() do
				if autre ~= joueur and enDuel(joueur, autre) then
					if vivant(autre.Character) then table.insert(t, autre.Character) end
					for m, a in actives do
						if a.camp == "J" .. autre.UserId and vivant(m) then table.insert(t, m) end
					end
				end
			end
		end
	elseif joueur then   -- escouade d'entraînement : vise le joueur qui l'a lancée et ses invocations
		if vivant(joueur.Character) then table.insert(t, joueur.Character) end
		for m, a in actives do
			if a.camp == "J" .. joueur.UserId and vivant(m) then table.insert(t, m) end
		end
	end
	return t
end

local function plusProche(depuis: Vector3, liste: {Model}): (Model?, number)
	local meilleur, dist = nil, math.huge
	for _, m in liste do
		local d = (racineDe(m).Position - depuis).Magnitude
		if d < dist then meilleur, dist = m, d end
	end
	return meilleur, dist
end

local function centre(liste: {Model}): Vector3?
	if #liste == 0 then return nil end
	local s = Vector3.zero
	for _, m in liste do s += racineDe(m).Position end
	return s / #liste
end

-- ---------------------------------------------------------------- effets des attaques
-- se tourner vers un point : rotation physique progressive (AlignOrientation), pas de saut d'orientation
local function regarder(e, vers: Vector3)
	local r = e.r
	local cible = Vector3.new(vers.X, r.Position.Y, vers.Z)
	if (cible - r.Position).Magnitude < 0.1 then return end
	e.h.AutoRotate = false
	e.orientation.CFrame = CFrame.lookAt(r.Position, cible)
	e.orientation.Enabled = true
end

-- personnage (modèle avec Humanoid) auquel appartient une pièce touchée, en remontant les modèles d'armes
local function personnageDe(inst: Instance): Model?
	local m = inst:FindFirstAncestorWhichIsA("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	return m
end

-- Projectiles : visés sur la position de la cible au moment du tir, ils filent tout droit et ne touchent
-- que ce qu'ils rencontrent vraiment (balayage d'une sphère image par image). Une cible qui s'écarte
-- l'esquive ; un mur ou le sol les arrête ; les alliés du tireur sont traversés.
local projectiles = {}

local function lancer(e, piece: BasePart, depart: Vector3, vers: Vector3, vitesse: number, rayon: number, contact)
	local dir = vers - depart
	dir = if dir.Magnitude > 0.01 then dir.Unit else e.r.CFrame.LookVector
	piece.CFrame = CFrame.lookAt(depart, depart + dir)
	table.insert(projectiles, {e = e, piece = piece, pos = depart, dir = dir, vitesse = vitesse, rayon = rayon,
		reste = e.stats.portee + 12, contact = contact})
end

local function avancerProjectiles(dt: number)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local pas = math.min(p.vitesse * dt, p.reste)
		local ignores = alliesDe(p.e)
		table.insert(ignores, p.e.modele)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignores
		local res = workspace:Spherecast(p.pos, p.rayon, p.dir * pas, params)
		if res then
			table.remove(projectiles, i)
			local touche = personnageDe(res.Instance)
			if touche and not table.find(ennemisDe(p.e), touche) then touche = nil end
			p.piece.CFrame = CFrame.lookAt(res.Position, res.Position + p.dir)
			task.spawn(p.contact, touche, res.Position)   -- une erreur dans un effet ne bloque pas les autres projectiles
		else
			p.pos += p.dir * pas
			p.reste -= pas
			p.piece.CFrame = CFrame.lookAt(p.pos, p.pos + p.dir)
			if p.reste <= 0 then
				table.remove(projectiles, i)
				task.spawn(p.contact, nil, p.pos)
			end
		end
	end
end

local function tirer(e, cible: Model)
	local m, stats = e.modele, e.stats
	local arc = m:FindFirstChild("Arc")
	local depart = (arc and arc:GetPivot().Position) or racineDe(m).Position
	local arrivee = racineDe(cible).Position + Vector3.new(0, 1, 0)
	local fut = Instance.new("Part")
	fut.Name = "Fleche"
	fut.Size = Vector3.new(0.08, 0.08, 2.2)
	fut.Color, fut.Material = Color3.fromRGB(150, 112, 70), Enum.Material.Wood
	fut.Anchored, fut.CanCollide, fut.CanQuery, fut.CanTouch = true, false, false, false
	fut.CFrame = CFrame.lookAt(depart, arrivee)
	local pointe = Instance.new("Part")
	pointe.Size = Vector3.new(0.16, 0.16, 0.3)
	pointe.Color, pointe.Material = Color3.fromRGB(110, 112, 118), Enum.Material.Metal
	pointe.CanCollide, pointe.CanQuery, pointe.CanTouch, pointe.Massless = false, false, false, true
	pointe.CFrame = fut.CFrame * CFrame.new(0, 0, -1.2)
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0, soudure.Part1 = fut, pointe
	soudure.Parent = pointe
	pointe.Parent = fut
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.06, 1), Vector3.new(0, -0.06, 1)
	a0.Parent, a1.Parent = fut, fut
	local trainee = Instance.new("Trail")
	trainee.Attachment0, trainee.Attachment1 = a0, a1
	trainee.Lifetime, trainee.Transparency = 0.15, NumberSequence.new(0.4, 1)
	trainee.Color = ColorSequence.new(Color3.fromRGB(235, 235, 220))
	trainee.Parent = fut
	fut.Parent = workspace
	lancer(e, fut, depart, arrivee, stats.vitesseFleche, 0.3, function(touche: Model?, _point)
		local hc = touche and touche:FindFirstChildOfClass("Humanoid")
		if hc and hc.Health > 0 then
			Combat.infliger(hc, stats.degats, nil)
			fut:Destroy()
		else
			trainee.Enabled = false   -- plantée dans le mur ou le sol, ou partie dans le vide
			Debris:AddItem(fut, 1.5)
		end
	end)
end

-- orbe du mage : part de la pierre du bâton, file vers la cible et éclate au contact (ennemi, mur, sol, ou
-- au bout de sa portée) sur les ennemis tout proches du point d'éclat
local function lancerOrbe(m: Model, e, cible: Model)
	local stats = e.stats
	local baton = m:FindFirstChild("Baton")
	local pierre = baton and baton:FindFirstChild("Cristal")
	local depart = (pierre and pierre.Position) or racineDe(m).Position + Vector3.new(0, 2, 0)
	local arrivee = racineDe(cible).Position + Vector3.new(0, 0.5, 0)
	local orbe = Instance.new("Part")
	orbe.Name, orbe.Shape, orbe.Size = "Orbe", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7)
	orbe.Color, orbe.Material = Color3.fromRGB(150, 205, 240), Enum.Material.Neon
	orbe.Anchored, orbe.CanCollide, orbe.CanQuery, orbe.CanTouch = true, false, false, false
	orbe.CFrame = CFrame.new(depart)
	local lumiere = Instance.new("PointLight")
	lumiere.Color, lumiere.Range, lumiere.Brightness = orbe.Color, 8, 1.5
	lumiere.Parent = orbe
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.25, 0), Vector3.new(0, -0.25, 0)
	a0.Parent, a1.Parent = orbe, orbe
	local trainee = Instance.new("Trail")
	trainee.Attachment0, trainee.Attachment1 = a0, a1
	trainee.Lifetime, trainee.LightEmission = 0.25, 1
	trainee.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(110, 160, 230))
	trainee.Transparency = NumberSequence.new(0.2, 1)
	trainee.Parent = orbe
	orbe.Parent = workspace
	lancer(e, orbe, depart, arrivee, stats.vitesseOrbe, 0.35, function(touche: Model?, point: Vector3)
		local eclat = Instance.new("Part")
		eclat.Shape, eclat.Size = Enum.PartType.Ball, Vector3.new(1, 1, 1)
		eclat.Color, eclat.Material, eclat.Transparency = orbe.Color, Enum.Material.Neon, 0.3
		eclat.Anchored, eclat.CanCollide, eclat.CanQuery, eclat.CanTouch = true, false, false, false
		eclat.CFrame = CFrame.new(point)
		eclat.Parent = workspace
		local d = stats.zone * 2   -- la sphère visible fait exactement la zone de dégâts
		TweenService:Create(eclat, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(d, d, d), Transparency = 1}):Play()
		Debris:AddItem(eclat, 0.4)
		orbe:Destroy()
		for _, c in ennemisDe(e) do
			if c == touche or (racineDe(c).Position - point).Magnitude <= stats.zone then
				Combat.infliger(c:FindFirstChildOfClass("Humanoid"), stats.degats, nil)
			end
		end
	end)
end

-- soin : PV rendus, éclats verts et chiffre « +N » qui s'envole, vus par tous
local function soigner(hc: Humanoid, quantite: number)
	local avant = hc.Health
	hc.Health = math.min(hc.MaxHealth, hc.Health + quantite)
	local rendu = math.floor(hc.Health - avant + 0.5)
	local r = racineDe(hc.Parent)
	if not r or rendu <= 0 then return end
	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, 1, 0)
	point.Parent = r
	local eclats = Instance.new("ParticleEmitter")
	eclats.Color = ColorSequence.new(Color3.fromRGB(170, 255, 170), Color3.fromRGB(90, 200, 120))
	eclats.LightEmission, eclats.LightInfluence = 0.8, 0
	eclats.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	eclats.Transparency = NumberSequence.new(0.2, 1)
	eclats.Lifetime = NumberRange.new(0.6, 1)
	eclats.Speed = NumberRange.new(2, 5)
	eclats.SpreadAngle = Vector2.new(60, 60)
	eclats.EmissionDirection = Enum.NormalId.Top
	eclats.Acceleration = Vector3.new(0, 4, 0)
	eclats.Rate = 0
	eclats.Parent = point
	eclats:Emit(18)
	local affiche = Instance.new("BillboardGui")
	affiche.Size, affiche.AlwaysOnTop = UDim2.fromOffset(120, 40), true
	affiche.StudsOffset = Vector3.new(0, 2.5, 0)
	affiche.Adornee, affiche.Parent = point, point
	local texte = Instance.new("TextLabel")
	texte.BackgroundTransparency, texte.Size = 1, UDim2.fromScale(1, 1)
	texte.Font, texte.TextSize, texte.Text = Enum.Font.GothamBlack, 24, "+" .. rendu
	texte.TextColor3, texte.TextStrokeTransparency = Color3.fromRGB(140, 240, 150), 0.3
	texte.Parent = affiche
	TweenService:Create(affiche, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{StudsOffset = Vector3.new(0, 4.5, 0)}):Play()
	TweenService:Create(texte, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(point, 1.6)
end

-- ---------------------------------------------------------------- gestes de base
-- se déplacer vers un point, sans piétiner : on s'arrête à « arrivee », on ne repart qu'au-delà de « depart » ;
-- loin derrière, on court pour rattraper
local function aller(e, vers: Vector3)
	local D = Config.DEPLACEMENT
	e.orientation.Enabled = false
	e.h.AutoRotate = true
	local d = plat(vers - e.r.Position).Magnitude
	if e.enRoute then
		if d < D.arrivee then
			e.enRoute = false
			e.h:MoveTo(e.r.Position)
		end
	elseif d > D.depart then
		e.enRoute = true
	end
	if e.enRoute then
		e.h.WalkSpeed = if d > D.rattrapage then math.max(e.stats.vitesse, D.vitesseRattrapage) else e.stats.vitesse
		e.h:MoveTo(vers)
	end
end

local function sArreter(e)
	if e.enRoute then
		e.enRoute = false
		e.h:MoveTo(e.r.Position)
	end
	e.h.WalkSpeed = e.stats.vitesse
end

-- attaque (ou soin) sur une cible à portée : le geste se joue, l'effet arrive à son moment
local function agir(e, cible: Model)
	local h, r, stats, m = e.h, e.r, e.stats, e.modele
	sArreter(e)
	regarder(e, racineDe(cible).Position)
	local t = os.clock()
	if t < e.prochain then return end
	e.prochain = t + stats.cadence
	local piste = e.pistes.attaque
	local delai = 0
	if piste then
		piste:Play(0.1)
		delai = Config.ATTAQUES[stats.classe].moment
	end
	local hc = cible:FindFirstChildOfClass("Humanoid")
	task.delay(delai, function()
		if not (m.Parent and h.Health > 0 and hc.Parent and hc.Health > 0) then return end
		if stats.classe == "Soigneur" then
			soigner(hc, stats.soin)
		elseif stats.classe == "Mage" then
			lancerOrbe(m, e, cible)
		elseif stats.classe == "Archer" then
			tirer(e, cible)
		elseif (racineDe(cible).Position - r.Position).Magnitude <= stats.portee + 1.5 then
			Combat.infliger(hc, stats.degats, nil)
		end
	end)
end

local function fuir(e, menace: Vector3)
	local loin = plat(e.r.Position - menace)
	if loin.Magnitude < 0.1 then loin = -e.r.CFrame.LookVector end
	aller(e, e.r.Position + loin.Unit * 10)
end

-- allié le plus blessé (proportionnellement) dans le rayon de détection
local function plusBlesse(e): Model?
	local meilleur, part = nil, 0.999
	for _, m in alliesDe(e) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local p = h.Health / h.MaxHealth
		if p < part and (racineDe(m).Position - e.r.Position).Magnitude <= Config.DETECTION then meilleur, part = m, p end
	end
	return meilleur
end

-- case de la formation en coordonnées du monde, autour du héros (tourne avec lui)
local function caseFormation(e): Vector3?
	local j = joueurDuCamp(e.camp)
	local mr = j and racineDe(j.Character)
	if not mr then return nil end
	local F = Config.FORMATION
	local dx = (e.case[1] - F.heros[1]) * F.ecart
	local dz = (e.case[2] - F.heros[2]) * F.ecart   -- rangées plus grandes = plus en arrière
	local regard = plat(mr.CFrame.LookVector)
	regard = if regard.Magnitude > 0.1 then regard.Unit else Vector3.new(0, 0, -1)
	local droite = regard:Cross(Vector3.yAxis)
	return mr.Position + droite * dx - regard * dz
end

-- ---------------------------------------------------------------- comportements
local function attaquerDansSaPortee(e, ennemis): boolean
	if e.stats.classe == "Soigneur" then
		local blesse = plusBlesse(e)
		if blesse and (racineDe(blesse).Position - e.r.Position).Magnitude <= e.stats.portee then
			agir(e, blesse)
			return true
		end
		return false
	end
	local cible, d = plusProche(e.r.Position, ennemis)
	if cible and d <= e.stats.portee then
		agir(e, cible)
		return true
	end
	return false
end

local COMPORTEMENTS = {}

function COMPORTEMENTS.Tank(e, ennemis)
	-- s'interpose devant les membres fragiles : vise l'ennemi le plus proche d'eux
	local fragiles = {}
	for _, m in alliesDe(e) do
		local a = actives[m]
		if not a or (a.stats.classe ~= "Tank" and a.stats.classe ~= "Guerrier") then table.insert(fragiles, m) end
	end
	local c = centre(fragiles) or e.r.Position
	local cible = plusProche(c, ennemis)
	if not cible then return end
	local pc = racineDe(cible).Position
	if (pc - e.r.Position).Magnitude <= e.stats.portee then
		agir(e, cible)
	else
		local vers = plat(c - pc)
		vers = if vers.Magnitude > 0.1 then vers.Unit else Vector3.zero
		aller(e, pc + vers * (e.stats.portee - 1.5))
	end
end

local function tireurADistance(e, ennemis, cible: Model?)
	local reglage = Config.COMPORTEMENT[e.stats.classe]
	local menace, dm = plusProche(e.r.Position, ennemis)
	if menace and dm < reglage.fuite then
		fuir(e, racineDe(menace).Position)   -- kiting : il reprend ses distances avant de tirer
		return
	end
	cible = cible or menace
	if not cible then return end
	local d = (racineDe(cible).Position - e.r.Position).Magnitude
	if d > e.stats.portee then
		local pc = racineDe(cible).Position
		aller(e, pc + plat(e.r.Position - pc).Unit * reglage.ideal)
	else
		agir(e, cible)
	end
end

function COMPORTEMENTS.Archer(e, ennemis)
	tireurADistance(e, ennemis, nil)
end

function COMPORTEMENTS.Mage(e, ennemis)
	-- vise l'ennemi autour duquel l'éclat touchera le plus de monde
	local meilleur, nb = nil, 0
	for _, c in ennemis do
		local pc, n = racineDe(c).Position, 0
		for _, autre in ennemis do
			if (racineDe(autre).Position - pc).Magnitude <= e.stats.zone then n += 1 end
		end
		if n > nb or (n == nb and meilleur and (pc - e.r.Position).Magnitude < (racineDe(meilleur).Position - e.r.Position).Magnitude) then
			meilleur, nb = c, n
		end
	end
	tireurADistance(e, ennemis, meilleur)
end

function COMPORTEMENTS.Soigneur(e, ennemis)
	local reglage = Config.COMPORTEMENT.Soigneur
	local menace, dm = plusProche(e.r.Position, ennemis)
	if menace and dm < reglage.fuite then
		fuir(e, racineDe(menace).Position)
		return
	end
	local blesse = plusBlesse(e)
	if blesse then
		local d = (racineDe(blesse).Position - e.r.Position).Magnitude
		if d <= e.stats.portee then agir(e, blesse) else aller(e, racineDe(blesse).Position) end
		return
	end
	-- personne à soigner : se tenir derrière l'équipe, du côté opposé aux ennemis
	local equipe = {}
	for _, m in alliesDe(e) do
		if m ~= e.modele then table.insert(equipe, m) end
	end
	local c = centre(equipe)
	if c and menace then
		local recul = plat(c - racineDe(menace).Position)
		if recul.Magnitude > 0.1 then aller(e, c + recul.Unit * reglage.recul) end
	end
end

COMPORTEMENTS.Guerrier = COMPORTEMENTS.Tank
COMPORTEMENTS.Assassin = function(e, ennemis)
	local cible = plusProche(e.r.Position, ennemis)
	if not cible then return end
	if (racineDe(cible).Position - e.r.Position).Magnitude <= e.stats.portee then agir(e, cible) else aller(e, racineDe(cible).Position) end
end

local function penser(e)
	local m, h = e.modele, e.h
	if not e.r or h.Health <= 0 then return end
	locomotion(e)
	local maitre = joueurDuCamp(e.camp)
	if maitre and maitre:GetAttribute("Fige") then   -- compte à rebours de l'arène : l'escouade attend aussi
		sArreter(e)
		return
	end
	local ordre = if string.sub(e.camp, 1, 1) == "S" then "Attaquer" else (ordres[joueurDuCamp(e.camp)] or "Suivre")
	local ennemis = {}
	for _, c in ennemisDe(e) do
		if (racineDe(c).Position - e.r.Position).Magnitude <= Config.DETECTION then table.insert(ennemis, c) end
	end
	if ordre == "Attaquer" then
		if #ennemis > 0 or e.stats.classe == "Soigneur" then
			COMPORTEMENTS[e.stats.classe](e, ennemis)
			return
		end
		ordre = "Suivre"   -- plus d'ennemis : reprend sa place dans la formation
	end
	if ordre == "Maintenir" then
		if not attaquerDansSaPortee(e, ennemis) then aller(e, e.ancre or e.r.Position) end
		return
	end
	-- Suivre : garde sa case ; ne riposte que si on vient de l'attaquer (ou soigne si besoin)
	local attaque = os.clock() - e.dernierCoup < Config.DEFENSE
	if (attaque or e.stats.classe == "Soigneur") and attaquerDansSaPortee(e, ennemis) then return end
	local case = caseFormation(e)
	if case then aller(e, case) end
end

-- ---------------------------------------------------------------- invoquer, renvoyer
local function caseDe(joueur: Player?, nom: string, classe: string): {number}
	local d = joueur and Donnees.profil(joueur)
	local c = d and d.Formation and d.Formation[nom]
	if type(c) == "table" and #c == 2 then return {c[1], c[2]} end
	return table.clone(Config.FORMATION.defaut[classe] or {3, 3})
end

function Invocations.invoquer(joueur: Player, nom: string, camp: string?, position: CFrame?): Model?
	local source = ServerStorage:FindFirstChild("Invocations") and ServerStorage.Invocations:FindFirstChild(nom)
	local stats = Config.MODELES[nom]
	local mr = racineDe(joueur.Character)
	if not source or not stats or not mr then return nil end
	camp = camp or ("J" .. joueur.UserId)
	local m = source:Clone()
	local h = m:FindFirstChildOfClass("Humanoid")
	h.MaxHealth, h.Health, h.WalkSpeed = stats.pv, stats.pv, stats.vitesse
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	m:SetAttribute("Camp", camp)
	m:SetAttribute("Maitre", joueur.UserId)
	CollectionService:AddTag(m, "Invocation")
	if string.sub(camp, 1, 1) == "S" then
		CollectionService:AddTag(m, "Ennemi")   -- le joueur peut les frapper à l'épée
		h.DisplayName = "Sparring " .. h.DisplayName
	end
	m:PivotTo(position or (mr.CFrame * CFrame.new(4, 0, 3)))
	m.Parent = dossier
	local r = racineDe(m)
	r.Anchored = false
	-- l'escouade d'un joueur est simulée chez lui (déplacements fluides comme son héros) ; le serveur garde
	-- les décisions (où aller, qui frapper) et les dégâts. L'escouade de sparring reste au serveur.
	pcall(function() r:SetNetworkOwner(if string.sub(camp, 1, 1) == "J" then joueur else nil) end)
	-- demi-tour vers une cible : la contrainte fait pivoter le corps progressivement (activée par regarder)
	local point = Instance.new("Attachment")
	point.Name = "PointOrientation"
	point.Parent = r
	local orientation = Instance.new("AlignOrientation")
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = point
	orientation.MaxTorque, orientation.MaxAngularVelocity = math.huge, math.huge
	orientation.Responsiveness = Config.DEPLACEMENT.rotation
	orientation.CFrame, orientation.Enabled = r.CFrame.Rotation, false
	orientation.Parent = r
	h.BreakJointsOnDeath = false
	local e = {modele = m, camp = camp, h = h, r = r, stats = stats, nom = nom, prochain = 0, dernierCoup = -math.huge,
		pistes = animer(h, stats.classe), case = caseDe(joueur, nom, stats.classe), ancre = r.Position,
		orientation = orientation, enRoute = false}
	actives[m] = e
	local pv, derniereReaction = h.Health, 0
	h.HealthChanged:Connect(function(nouveau)
		if nouveau < pv then
			e.dernierCoup = os.clock()
			flash(m)
			-- recul visible, sans le rejouer à chaque flèche d'une salve
			if nouveau > 0 and os.clock() - derniereReaction > 0.4 then
				derniereReaction = os.clock()
				e.pistes.touche:Play(0.05)
			end
		end
		pv = nouveau
	end)
	h.Died:Connect(function()
		actives[m] = nil
		task.spawn(Invocations.surMort, camp)
		-- tombe à genoux puis s'efface, au lieu de se désarticuler
		r.Anchored = true
		orientation.Enabled = false
		for cle, piste in e.pistes do
			if cle ~= "mort" then piste:Stop(0.15) end
		end
		e.pistes.mort:Play(0.15)
		task.delay(1.4, function()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					TweenService:Create(p, TweenInfo.new(1.2), {Transparency = 1}):Play()
				elseif p:IsA("Decal") then
					TweenService:Create(p, TweenInfo.new(1.2), {Transparency = 1}):Play()
				end
			end
		end)
		Debris:AddItem(m, 3)
	end)
	return m
end

-- appelée quand une invocation meurt (l'arène la remplace pour compter les camps encore debout)
function Invocations.surMort(_camp: string) end

local function renvoyer(joueur: Player, genre: string?)
	for m, e in actives do
		local g = string.sub(e.camp, 1, 1)
		if joueurDuCamp(e.camp) == joueur and (genre == nil or g == genre) then
			actives[m] = nil
			m:Destroy()
		end
	end
end

function Invocations.renvoyer(joueur: Player)
	renvoyer(joueur, "J")
end

-- invocations encore debout de ce joueur
function Invocations.vivantes(joueur: Player): number
	local n = 0
	for m, e in actives do
		if e.camp == "J" .. joueur.UserId and vivant(m) then n += 1 end
	end
	return n
end

-- déploie toute la formation du joueur autour d'une position (début de manche en arène)
function Invocations.deployer(joueur: Player, base: CFrame)
	renvoyer(joueur, "J")
	local d = Donnees.profil(joueur)
	local formation = d and d.Formation or {}
	local noms = {}
	for nom in formation do
		if Config.MODELES[nom] then table.insert(noms, nom) end
	end
	if #noms == 0 then
		for nom in Config.MODELES do table.insert(noms, nom) end
	end
	local F = Config.FORMATION
	for _, nom in noms do
		local c = caseDe(joueur, nom, Config.MODELES[nom].classe)
		local decalage = CFrame.new((c[1] - F.heros[1]) * F.ecart, 0, (c[2] - F.heros[2]) * F.ecart)
		Invocations.invoquer(joueur, nom, nil, base * decalage)
	end
end

local function escouade(joueur: Player)
	renvoyer(joueur, "J")
	local d = Donnees.profil(joueur)
	local formation = d and d.Formation or {}
	local n = 0
	for nom in formation do
		if Config.MODELES[nom] then
			Invocations.invoquer(joueur, nom)
			n += 1
		end
	end
	if n == 0 then   -- formation vide : toutes les invocations disponibles, à leur case par défaut
		for nom in Config.MODELES do Invocations.invoquer(joueur, nom) end
	end
end

-- escouade d'entraînement : une copie de chaque invocation, en face du joueur, qui l'attaque
local function sparring(joueur: Player)
	local deja = false
	for _, e in actives do
		if e.camp == "S" .. joueur.UserId then deja = true end
	end
	renvoyer(joueur, "S")
	if deja then return end
	local mr = racineDe(joueur.Character)
	if not mr then return end
	local i = 0
	for nom in Config.MODELES do
		local pos = mr.CFrame * CFrame.new(-6 + i * 4, 0, -28) * CFrame.Angles(0, math.pi, 0)
		Invocations.invoquer(joueur, nom, "S" .. joueur.UserId, pos)
		i += 1
	end
end

-- ---------------------------------------------------------------- formation : lecture et écriture
local function grilleValide(g): boolean
	if type(g) ~= "table" then return false end
	local F, prises = Config.FORMATION, {}
	for nom, c in g do
		if not Config.MODELES[nom] or type(c) ~= "table" then return false end
		local col, rang = c[1], c[2]
		if type(col) ~= "number" or type(rang) ~= "number" then return false end
		if col < 1 or col > F.colonnes or rang < 1 or rang > F.rangees or col % 1 ~= 0 or rang % 1 ~= 0 then return false end
		if col == F.heros[1] and rang == F.heros[2] then return false end
		local cle = col .. ":" .. rang
		if prises[cle] then return false end
		prises[cle] = true
	end
	return true
end

function Invocations.demarrer()
	Formation.OnServerInvoke = function(joueur, action, grille)
		local d = Donnees.profil(joueur)
		if not d then return nil end
		if action == "ecrire" then
			if not grilleValide(grille) then return false end
			local copie = {}
			for nom, c in grille do copie[nom] = {c[1], c[2]} end
			Donnees.modifier(joueur, function(x) x.Formation = copie end)
			for _, e in actives do   -- les invocations déjà présentes prennent leur nouvelle case
				if e.camp == "J" .. joueur.UserId then e.case = caseDe(joueur, e.nom, e.stats.classe) end
			end
			return true
		end
		local modeles = {}
		for nom, s in Config.MODELES do
			table.insert(modeles, {id = nom, nom = Config.NOMS[nom] or nom, classe = s.classe})
		end
		table.sort(modeles, function(a, b) return a.id < b.id end)
		return {formation = d.Formation or {}, modeles = modeles}
	end

	Ordre.OnServerEvent:Connect(function(joueur, id)
		local valide = false
		for _, o in Config.ORDRES do
			if o.id == id then valide = true end
		end
		if not valide then return end
		ordres[joueur] = id
		joueur:SetAttribute("OrdreEscouade", id)
		-- Maintenir : chacune tient sa case de formation autour de l'endroit où est le héros à cet instant ;
		-- appuyer de nouveau pendant un Maintenir déplace le point tenu là où le héros se trouve maintenant
		if id == "Maintenir" then
			for _, e in actives do
				if e.camp == "J" .. joueur.UserId then e.ancre = caseFormation(e) or e.r.Position end
			end
		end
	end)

	-- borne « Formation » à l'entrée du centre d'entraînement (l'interface s'ouvre côté client)
	local borne = workspace:FindFirstChild("Borne_Formation") or Instance.new("Part")
	borne.Name = "Borne_Formation"
	borne.Anchored, borne.CanCollide, borne.CanTouch, borne.CanQuery = true, false, false, false
	borne.Transparency, borne.Size = 1, Vector3.new(2, 4, 2)
	borne.CFrame = CFrame.new(Config.FORMATION.borne)
	borne:ClearAllChildren()
	local invite = Instance.new("ProximityPrompt")
	invite.ObjectText, invite.ActionText = "Squad formation", "Edit"
	invite.HoldDuration, invite.MaxActivationDistance, invite.RequiresLineOfSight = 0.2, 14, false
	invite:SetAttribute("Formation", true)
	invite.Parent = borne
	borne.Parent = workspace

	local commandes = TextChatService:FindFirstChild("CommandesInvocations") or Instance.new("Folder")
	commandes.Name = "CommandesInvocations"
	commandes.Parent = TextChatService
	local NOMS = {archer = "Archere_P1", archere = "Archere_P1", tank = "Tank_P1",
		healer = "Soigneuse_P1", soigneuse = "Soigneuse_P1", mage = "Mage_P1"}
	local function commande(nom, alias, action)
		local c = commandes:FindFirstChild(nom) or Instance.new("TextChatCommand")
		c.Name, c.PrimaryAlias = nom, alias
		c.Parent = commandes
		c.Triggered:Connect(function(source, texte)
			local j = Players:GetPlayerByUserId(source.UserId)
			if j then action(j, texte) end
		end)
	end
	commande("Invoquer", "/summon", function(j, texte)
		local quoi = (string.match(texte, "^%S+%s+(%a+)") or "archer"):lower()
		if NOMS[quoi] then Invocations.invoquer(j, NOMS[quoi]) end
	end)
	commande("Escouade", "/squad", escouade)
	commande("Renvoyer", "/dismiss", function(j) renvoyer(j, nil) end)
	commande("Sparring", "/sparring", sparring)
	Players.PlayerRemoving:Connect(function(j)
		renvoyer(j, nil)
		ordres[j] = nil
	end)

	local cumul = 0
	RunService.Heartbeat:Connect(function(dt)
		avancerProjectiles(dt)
		cumul += dt
		if cumul < 0.2 then return end
		cumul = 0
		for m, e in actives do
			if m.Parent then penser(e) else actives[m] = nil end
		end
	end)
end

return Invocations
