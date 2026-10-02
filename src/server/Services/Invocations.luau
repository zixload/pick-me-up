-- Invocations, premier jet pour tester le combat (02/10/2026) : /summon archer (ou tank) fait apparaître
-- l'invocation à côté de son maître, /dismiss la renvoie. Comportement minimal : elle suit son maître ;
-- dès qu'une cible (mannequin « Cible » ou mob « Ennemi ») est à portée de détection, elle s'en approche
-- jusqu'à sa portée, se tourne vers elle et attaque (flèches pour l'archère, coups pour le tank).
-- Les ordres (suivre, maintenir, attaquer), la formation et le kiting viendront ensuite.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Combat = require(script.Parent.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Invocations)

local Invocations = {}

local dossier = workspace:FindFirstChild("Invocations") or Instance.new("Folder")
dossier.Name = "Invocations"
dossier.Parent = workspace

local actives = {}   -- [modèle] = état

local function racineDe(m: Model): BasePart?
	return m:FindFirstChild("HumanoidRootPart")
end

-- animations de repos et de marche jouées par le serveur (le LocalScript Animate ne tourne pas ici)
local function animer(m: Model, h: Humanoid, classe: string)
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
	h.Running:Connect(function(vitesse)
		if vitesse > 0.5 then
			if not pistes.marche.IsPlaying then pistes.marche:Play(0.2) end
			pistes.marche:AdjustSpeed(vitesse / 14)
		elseif pistes.marche.IsPlaying then
			pistes.marche:Stop(0.2)
		end
	end)
	return pistes
end

-- cible vivante la plus proche dans le rayon de détection
local function chercherCible(depuis: Vector3): (Model?, Humanoid?, number)
	local meilleur, hm, dist = nil, nil, Config.DETECTION
	for _, etiquette in {"Cible", "Ennemi"} do
		for _, m in CollectionService:GetTagged(etiquette) do
			local h = m:FindFirstChildOfClass("Humanoid")
			local r = racineDe(m)
			if h and r and h.Health > 0 then
				local d = (r.Position - depuis).Magnitude
				if d < dist then meilleur, hm, dist = m, h, d end
			end
		end
	end
	return meilleur, hm, dist
end

local function regarder(r: BasePart, vers: Vector3)
	local cible = Vector3.new(vers.X, r.Position.Y, vers.Z)
	if (cible - r.Position).Magnitude > 0.1 then
		r.CFrame = CFrame.lookAt(r.Position, cible)
	end
end

-- une flèche visible qui file de l'arc à la cible, puis inflige les dégâts
local function tirer(m: Model, stats, cible: Model, hc: Humanoid)
	local arc = m:FindFirstChild("Arc")
	local depart = (arc and arc:GetPivot().Position) or racineDe(m).Position
	local arrivee = racineDe(cible).Position + Vector3.new(0, 1, 0)
	local dir = arrivee - depart
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
	local duree = dir.Magnitude / stats.vitesseFleche
	TweenService:Create(fut, TweenInfo.new(duree, Enum.EasingStyle.Linear), {CFrame = CFrame.lookAt(arrivee, arrivee + dir)}):Play()
	task.delay(duree, function()
		if hc.Parent and hc.Health > 0 then
			Combat.infliger(hc, stats.degats, nil)
		end
		trainee.Enabled = false
		Debris:AddItem(fut, 0.3)
	end)
end

local function penser(m: Model, e)
	local h, r = e.h, racineDe(m)
	local maitre = e.maitre
	local mr = maitre.Character and maitre.Character:FindFirstChild("HumanoidRootPart")
	if not r or h.Health <= 0 then return end
	local stats = e.stats
	local cible, hc, dist = chercherCible(r.Position)
	if cible and hc then
		if dist > stats.portee then
			h.AutoRotate = true
			h:MoveTo(racineDe(cible).Position)
		else
			h:MoveTo(r.Position)
			h.AutoRotate = false
			regarder(r, racineDe(cible).Position)
			local t = os.clock()
			if t >= e.prochain then
				e.prochain = t + stats.cadence
				-- le geste se joue, et le coup porte à son moment (corde lâchée, gourdin qui touche)
				local piste = e.pistes and e.pistes.attaque
				local delai = 0
				if piste then
					piste:Play(0.1)
					delai = Config.ATTAQUES[stats.classe].moment
				end
				task.delay(delai, function()
					if not (m.Parent and h.Health > 0 and hc.Parent and hc.Health > 0) then return end
					if stats.classe == "Archer" then
						tirer(m, stats, cible, hc)
					elseif (racineDe(cible).Position - r.Position).Magnitude <= stats.portee + 1.5 then
						Combat.infliger(hc, stats.degats, nil)
					end
				end)
			end
		end
		return
	end
	h.AutoRotate = true
	if mr then
		local ecart = (mr.Position - r.Position) * Vector3.new(1, 0, 1)
		if ecart.Magnitude > Config.DISTANCE_SUIVI + 2 then
			h:MoveTo(mr.Position - ecart.Unit * Config.DISTANCE_SUIVI)
		end
	end
end

local function congedier(joueur: Player)
	for m, e in actives do
		if e.maitre == joueur then
			actives[m] = nil
			m:Destroy()
		end
	end
end

function Invocations.invoquer(joueur: Player, nom: string): Model?
	local source = ServerStorage:FindFirstChild("Invocations") and ServerStorage.Invocations:FindFirstChild(nom)
	local stats = Config.MODELES[nom]
	local mr = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not source or not stats or not mr then return nil end
	local m = source:Clone()
	local h = m:FindFirstChildOfClass("Humanoid")
	h.MaxHealth, h.Health, h.WalkSpeed = stats.pv, stats.pv, stats.vitesse
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	m:PivotTo(mr.CFrame * CFrame.new(4, 0, 3))
	m:SetAttribute("Maitre", joueur.UserId)
	CollectionService:AddTag(m, "Invocation")
	m.Parent = dossier
	local r = racineDe(m)
	r.Anchored = false
	pcall(function() r:SetNetworkOwner(nil) end)
	local pistes = animer(m, h, stats.classe)
	actives[m] = {maitre = joueur, h = h, stats = stats, prochain = 0, pistes = pistes}
	h.Died:Connect(function()
		actives[m] = nil
		Debris:AddItem(m, 3)
	end)
	return m
end

function Invocations.demarrer()
	local commandes = TextChatService:FindFirstChild("CommandesInvocations") or Instance.new("Folder")
	commandes.Name = "CommandesInvocations"
	commandes.Parent = TextChatService
	local NOMS = {archer = "Archere_P1", archere = "Archere_P1", tank = "Tank_P1"}
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
	commande("Renvoyer", "/dismiss", congedier)
	Players.PlayerRemoving:Connect(congedier)

	local cumul = 0
	RunService.Heartbeat:Connect(function(dt)
		cumul += dt
		if cumul < 0.2 then return end
		cumul = 0
		for m, e in actives do
			if m.Parent then penser(m, e) else actives[m] = nil end
		end
	end)
end

return Invocations
