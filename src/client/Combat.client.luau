-- Combat côté joueur : attaques à l'épée (combo de trois coups), esquive, chiffres de dégâts et barre
-- de vie. Le client joue les gestes et prévient le serveur, qui seul décide de ce qui est touché.
-- Commandes : clic gauche ou R2 pour frapper, Q ou B pour esquiver, F ou L2 pour parer, Ctrl pour le
-- mode visée ;
-- boutons à l'écran sur mobile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.Combat)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local Attaquer = reseau:WaitForChild("Attaquer")
local Esquiver = reseau:WaitForChild("Esquiver")
local Impact = reseau:WaitForChild("Impact")
local Parer = reseau:WaitForChild("Parer")
local Pare = reseau:WaitForChild("Pare")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ARDOISE = Color3.fromRGB(26, 32, 44)
local ARGENT = Color3.fromRGB(205, 212, 222)
local ROUGE = Color3.fromRGB(235, 110, 100)
local VIE = Color3.fromRGB(120, 210, 140)

-- ---------------------------------------------------------------- personnage et animations
local perso, humanoide, racine
local pistes = {}

-- identifiant publié, ou en Studio la séquence de ReplicatedStorage.Animations enregistrée à la volée
local function animation(nom: string): Animation?
	local id = Config.ANIMATIONS[nom]
	if id == nil or id == "" then
		local dossier = ReplicatedStorage:FindFirstChild("Animations")
		local sequence = dossier and dossier:FindFirstChild(nom)
		if not sequence or not RunService:IsStudio() then
			warn(`[Combat] Animation {nom} : pas d'identifiant publié dans Config.Combat.ANIMATIONS.`)
			return nil
		end
		local ok, provisoire = pcall(function()
			return game:GetService("AnimationClipProvider"):RegisterAnimationClip(sequence)
		end)
		if not ok then
			warn(`[Combat] Animation {nom} : impossible de l'enregistrer en Studio ({provisoire}).`)
			return nil
		end
		id = provisoire
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	return a
end

local function preparer(nouveau: Model)
	perso = nouveau
	humanoide = nouveau:WaitForChild("Humanoid")
	racine = nouveau:WaitForChild("HumanoidRootPart")
	local animateur = humanoide:WaitForChild("Animator")
	table.clear(pistes)
	for nom in Config.ANIMATIONS do
		local a = animation(nom)
		if a then
			local piste = animateur:LoadAnimation(a)
			piste.Priority = Enum.AnimationPriority.Action
			piste.Looped = false
			pistes[nom] = piste
		end
	end
end

local function vivant(): boolean
	return humanoide ~= nil and humanoide.Health > 0 and racine ~= nil and racine.Parent ~= nil
end

local function son(cle: string, parent: Instance, volume: number?)
	local s = Instance.new("Sound")
	local id = Config.SONS[cle]
	s.SoundId = if type(id) == "table" then id[math.random(#id)] else id   -- liste : une variante au hasard
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 80
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

-- tourne le personnage vers la cible la plus proche devant la caméra, sinon dans l'axe de la caméra
local function orienter()
	local regard = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if regard.Magnitude < 0.01 then return end
	regard = regard.Unit
	local meilleur, distance = nil, Config.EPEE.portee + 4
	for _, etiquette in {"Ennemi", "Cible"} do
		for _, m in CollectionService:GetTagged(etiquette) do
			local rc = m:FindFirstChild("HumanoidRootPart")
			if rc then
				local vers = (rc.Position - racine.Position) * Vector3.new(1, 0, 1)
				if vers.Magnitude < distance and vers.Magnitude > 0.1 and vers.Unit:Dot(regard) > 0.3 then
					meilleur, distance = vers.Unit, vers.Magnitude
				end
			end
		end
	end
	local direction = meilleur or regard
	racine.CFrame = CFrame.lookAt(racine.Position, racine.Position + direction)
end

-- ---------------------------------------------------------------- effets de frappe
local pisteEnCours: AnimationTrack? = nil

-- secousse de caméra : décalage aléatoire qui s'éteint en quelques images
local secousse = {force = 0, fin = 0, duree = 1}
local function secouer(force: number)
	secousse.force = math.max(force, if os.clock() < secousse.fin then secousse.force else 0)
	secousse.duree = Config.EFFETS.secousseDuree
	secousse.fin = os.clock() + secousse.duree
end
-- (appliquée chaque image avec le mode visée, plus bas)

-- la lame touche : le geste se fige un instant, comme un arrêt sur image
local function arretImage()
	local piste = pisteEnCours
	if not piste or not piste.IsPlaying then return end
	piste:AdjustSpeed(0.04)
	task.delay(Config.EFFETS.arretImage, function()
		if piste.IsPlaying then piste:AdjustSpeed(1) end
	end)
end

-- gerbe d'étincelles au point d'impact
local function etincelles(point: Attachment)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214), Color3.fromRGB(190, 210, 240))
	e.LightEmission, e.LightInfluence = 1, 0
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.15, 0.3)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag, e.Rate = 6, 0
	e.Parent = point
	e:Emit(14)
end

-- ---------------------------------------------------------------- attaques
local coupActuel, libreA, finCombo = 0, 0, 0
local enAttente = false   -- un clic pendant le geste lance le coup suivant dès que possible
local etourdiJusque = 0   -- touché : ni coup ni esquive jusque-là
local jetonRalenti = 0    -- dernier coup qui a posé le ralenti de combat

-- figé par le compte à rebours de l'arène, ou à terre
local function bloque(): boolean
	return joueur:GetAttribute("Fige") == true or joueur:GetAttribute("KO") == true
end

local function attaquer()
	if not vivant() or bloque() then return end
	local t = os.clock()
	if t < libreA then
		if not enAttente then
			enAttente = true
			task.delay(libreA - t, function()
				enAttente = false
				attaquer()
			end)
		end
		return
	end
	local coups = Config.EPEE.coups
	local numero = if coupActuel < #coups and t <= finCombo then coupActuel + 1 else 1
	local coup = coups[numero]
	-- un peu plus strict que le serveur, pour qu'il ne refuse jamais un coup affiché
	coupActuel, libreA, finCombo = numero, t + coup.duree * 0.75, t + coup.duree + Config.EPEE.fenetreCombo
	orienter()
	humanoide.AutoRotate = false
	humanoide:SetAttribute("PMU_RalentiCombat", 0.35)
	local h = humanoide
	jetonRalenti += 1
	local jeton = jetonRalenti
	task.delay(coup.duree * 0.75, function()
		-- le ralenti du coup est toujours retiré (sinon, figé ou à terre à ce moment, on ne pouvait plus courir) ;
		-- seul le dernier coup du combo le retire, pour ne pas libérer un coup encore en cours
		if h.Parent and jeton == jetonRalenti then
			h:SetAttribute("PMU_RalentiCombat", nil)
			if not bloque() then h.AutoRotate = true end
		end
	end)
	local piste = pistes[coup.animation]
	if piste then
		-- le coup suivant coupe le retour à la garde du précédent, en fondu
		if pisteEnCours and pisteEnCours ~= piste then pisteEnCours:Stop(0.12) end
		piste:Play(0.1)
		pisteEnCours = piste
	end
	son(coup.son, racine)
	Attaquer:FireServer(numero)
end

-- ---------------------------------------------------------------- esquive
local esquiveDispo = 0

local function esquiver()
	if not vivant() or bloque() then return end
	local t = os.clock()
	if t < esquiveDispo or t < etourdiJusque then return end
	esquiveDispo = t + Config.ESQUIVE.recharge
	coupActuel = 0
	local direction = humanoide.MoveDirection * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = -racine.CFrame.LookVector * Vector3.new(1, 0, 1)   -- immobile : pas en arrière
	end
	direction = direction.Unit
	local point = Instance.new("Attachment")
	point.Parent = racine
	local poussee = Instance.new("LinearVelocity")
	poussee.Attachment0 = point
	poussee.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	poussee.PrimaryTangentAxis, poussee.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	poussee.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Config.ESQUIVE.vitesse
	poussee.MaxForce = math.huge
	poussee.Parent = racine
	Debris:AddItem(poussee, Config.ESQUIVE.duree)
	Debris:AddItem(point, Config.ESQUIVE.duree)
	if pisteEnCours then pisteEnCours:Stop(0.08) end
	if pistes.Esquive then pistes.Esquive:Play(0.05) end
	son("Esquive", racine, 0.5)
	Esquiver:FireServer()
end

-- ---------------------------------------------------------------- parade
local paradeDispo = 0

local function parer()
	if not vivant() or bloque() then return end
	local t = os.clock()
	if t < paradeDispo or t < etourdiJusque then return end
	paradeDispo = t + Config.PARADE.recharge
	-- pendant la parade et juste après, rien d'autre (une parade réussie libère aussitôt)
	etourdiJusque = t + Config.PARADE.fenetre + Config.PARADE.recuperation
	libreA = math.max(libreA, etourdiJusque)
	coupActuel = 0
	if pisteEnCours then pisteEnCours:Stop(0.05) end
	pisteEnCours = pistes.Parade
	if pistes.Parade then pistes.Parade:Play(0.04) end
	Parer:FireServer()
end

-- ---------------------------------------------------------------- commandes
UserInputService.InputBegan:Connect(function(entree, traite)
	if traite then return end
	if entree.UserInputType == Enum.UserInputType.MouseButton1 then attaquer() end
end)
ContextActionService:BindAction("PMU_Attaquer", function(_, etat)
	if etat == Enum.UserInputState.Begin then attaquer() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("PMU_Esquiver", function(_, etat)
	if etat == Enum.UserInputState.Begin then esquiver() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
ContextActionService:BindAction("PMU_Parer", function(_, etat)
	if etat == Enum.UserInputState.Begin then parer() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:SetTitle("PMU_Attaquer", "Attack")
ContextActionService:SetTitle("PMU_Esquiver", "Dodge")
ContextActionService:SetTitle("PMU_Parer", "Parry")
ContextActionService:SetPosition("PMU_Parer", UDim2.new(1, -90, 1, -80))
ContextActionService:SetPosition("PMU_Attaquer", UDim2.new(1, -150, 1, -140))
ContextActionService:SetPosition("PMU_Esquiver", UDim2.new(1, -210, 1, -80))

-- ---------------------------------------------------------------- barre de vie
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
local ecran = Instance.new("ScreenGui")
ecran.Name = "InterfaceCombat"
ecran.ResetOnSpawn = false
ecran.Parent = joueur:WaitForChild("PlayerGui")
local cadre = Instance.new("Frame")
cadre.AnchorPoint = Vector2.new(0.5, 1)
cadre.Position, cadre.Size = UDim2.new(0.5, 0, 1, -18), UDim2.fromOffset(280, 22)
cadre.BackgroundColor3, cadre.BackgroundTransparency = ARDOISE, 0.15
cadre.Parent = ecran
Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 8)
local trait = Instance.new("UIStroke", cadre)
trait.Color, trait.Transparency = ARGENT, 0.35
local jauge = Instance.new("Frame")
jauge.Position, jauge.Size = UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -6)
jauge.BackgroundColor3, jauge.BorderSizePixel = VIE, 0
jauge.Parent = cadre
Instance.new("UICorner", jauge).CornerRadius = UDim.new(0, 6)
local valeur = Instance.new("TextLabel")
valeur.BackgroundTransparency, valeur.Size = 1, UDim2.fromScale(1, 1)
valeur.Font, valeur.TextSize, valeur.TextColor3 = Enum.Font.GothamBold, 14, Color3.new(1, 1, 1)
valeur.TextStrokeTransparency = 0.5
valeur.Parent = cadre

local function majVie()
	if not humanoide then return end
	local part = math.clamp(humanoide.Health / math.max(humanoide.MaxHealth, 1), 0, 1)
	jauge.Size = UDim2.new(part, -6 * part, 1, -6)
	jauge.BackgroundColor3 = if part > 0.3 then VIE else ROUGE
	local pv = if humanoide.Health < 1 then 0 else math.ceil(humanoide.Health)   -- à terre en arène : 0,01
	valeur.Text = `{pv} / {math.floor(humanoide.MaxHealth)}`
end

-- ---------------------------------------------------------------- impacts : chiffres et sons
Impact.OnClientEvent:Connect(function(position: Vector3, degats: number, modele: Instance, auteur: Player?)
	local surMoi = modele == perso
	local point = Instance.new("Attachment")
	point.WorldPosition = position + Vector3.new(0, 2.5, 0)
	point.Parent = workspace.Terrain
	son(if surMoi then "Blessure" else "Impact", point, 0.55)
	etincelles(point)
	if surMoi then
		secouer(Config.EFFETS.secousseBlessure)
		-- étourdi : le geste en cours est coupé, recul, pas d'action pendant un instant
		etourdiJusque = os.clock() + Config.ETOURDISSEMENT
		libreA = math.max(libreA, etourdiJusque)
		coupActuel = 0
		if pisteEnCours then pisteEnCours:Stop(0.05) end
		pisteEnCours = nil
		if pistes.Touche and not joueur:GetAttribute("KO") then pistes.Touche:Play(0.03) end
	elseif auteur == joueur then
		arretImage()
		secouer(Config.EFFETS.secousseFrappe)
	end
	local affiche = Instance.new("BillboardGui")
	affiche.Size, affiche.AlwaysOnTop = UDim2.fromOffset(120, 40), true
	affiche.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 0, 0)
	affiche.Adornee, affiche.Parent = point, point
	local texte = Instance.new("TextLabel")
	texte.BackgroundTransparency, texte.Size = 1, UDim2.fromScale(1, 1)
	texte.Font, texte.TextSize = Enum.Font.GothamBlack, 26
	texte.TextColor3 = if surMoi then ROUGE else Color3.new(1, 1, 1)
	texte.TextStrokeTransparency, texte.Text = 0.3, tostring(degats)
	texte.Parent = affiche
	TweenService:Create(affiche, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{StudsOffsetWorldSpace = affiche.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0)}):Play()
	TweenService:Create(texte, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(point, 3)
end)

-- ---------------------------------------------------------------- parade réussie
Pare.OnClientEvent:Connect(function(position: Vector3, modele: Instance, attaquant: Player?)
	local point = Instance.new("Attachment")
	point.WorldPosition = position + Vector3.new(0, 2.5, 0)
	point.Parent = workspace.Terrain
	son("Parade", point, 0.7)
	etincelles(point)
	etincelles(point)
	Debris:AddItem(point, 3)
	if modele == perso then
		-- j'ai paré : libre de riposter tout de suite
		etourdiJusque = 0
		libreA = os.clock()
		secouer(Config.EFFETS.secousseFrappe)
	elseif attaquant == joueur then
		-- je suis paré : déséquilibré, longuement exposé
		etourdiJusque = os.clock() + Config.PARADE.etourdissement
		libreA = math.max(libreA, etourdiJusque)
		coupActuel = 0
		if pisteEnCours then pisteEnCours:Stop(0.05) end
		pisteEnCours = nil
		if pistes.Touche then
			pistes.Touche:Play(0.03)
			pistes.Touche:AdjustSpeed(0.5)   -- recul deux fois plus lent : on sent le déséquilibre
		end
		secouer(Config.EFFETS.secousseBlessure)
	end
end)

-- ---------------------------------------------------------------- arène : figé, à terre
joueur:GetAttributeChangedSignal("Fige"):Connect(function()
	if not humanoide then return end
	local fige = joueur:GetAttribute("Fige") == true
	-- la vitesse est gérée par Course.client (attributs Fige et KO) ; un coup interrompu ne doit pas
	-- laisser son ralenti derrière lui
	jetonRalenti += 1
	humanoide:SetAttribute("PMU_RalentiCombat", nil)
	humanoide.AutoRotate = not fige
	if fige and pisteEnCours then pisteEnCours:Stop(0.2) end
end)
joueur:GetAttributeChangedSignal("KO"):Connect(function()
	if humanoide then
		jetonRalenti += 1
		humanoide:SetAttribute("PMU_RalentiCombat", nil)
	end
	local piste = pistes.KO
	if not piste then return end
	if joueur:GetAttribute("KO") then
		if pisteEnCours then pisteEnCours:Stop(0.1) end
		piste.Looped = true
		piste.Priority = Enum.AnimationPriority.Action4
		piste:Play(0.25)
	else
		piste:Stop(0.3)
	end
end)

-- ---------------------------------------------------------------- mode visée (Ctrl)
-- Ctrl bascule le mode visée : la souris reste bloquée au centre et la caméra suit directement ses
-- mouvements (plus besoin du clic droit), le héros regarde dans l'axe de la caméra, la caméra passe
-- au-dessus de l'épaule droite et un petit viseur s'affiche au centre de l'écran.
local visee = false
local EPAULE = Vector3.new(1.75, 0.35, 0)

local viseur = Instance.new("Frame")
viseur.Name = "Viseur"
viseur.AnchorPoint, viseur.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
viseur.Size, viseur.BackgroundTransparency = UDim2.fromOffset(22, 22), 1
viseur.Visible = false
viseur.Parent = ecran
for _, b in {{0, -1}, {0, 1}, {-1, 0}, {1, 0}} do   -- quatre petits traits autour d'un point vide
	local trait = Instance.new("Frame")
	trait.AnchorPoint = Vector2.new(0.5, 0.5)
	trait.Size = if b[1] == 0 then UDim2.fromOffset(2, 6) else UDim2.fromOffset(6, 2)
	trait.Position = UDim2.new(0.5, b[1] * 7, 0.5, b[2] * 7)
	trait.BackgroundColor3, trait.BorderSizePixel = Color3.new(1, 1, 1), 0
	trait.Parent = viseur
	local bord = Instance.new("UIStroke")
	bord.Color, bord.Transparency, bord.Thickness = Color3.new(0, 0, 0), 0.5, 1
	bord.Parent = trait
end
local point = Instance.new("Frame")
point.AnchorPoint, point.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
point.Size, point.BackgroundColor3, point.BorderSizePixel = UDim2.fromOffset(2, 2), Color3.new(1, 1, 1), 0
point.Parent = viseur

local function basculerVisee()
	visee = not visee
	viseur.Visible = visee
	UserInputService.MouseIconEnabled = not visee
	if not visee then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if humanoide and not bloque() then humanoide.AutoRotate = true end
	end
end
UserInputService.InputBegan:Connect(function(entree, traite)
	if traite then return end
	if entree.KeyCode == Enum.KeyCode.LeftControl or entree.KeyCode == Enum.KeyCode.RightControl then
		basculerVisee()
	end
end)

-- après la caméra de Roblox, à chaque image : décalage d'épaule et secousse, puis en visée la souris
-- bloquée au centre et le héros tourné dans l'axe de la caméra
RunService:BindToRenderStep("PMU_Camera", Enum.RenderPriority.Camera.Value + 1, function()
	if not humanoide then return end
	local decalage = if visee then EPAULE else Vector3.zero
	local reste = secousse.fin - os.clock()
	if reste > 0 then
		local a = secousse.force * reste / secousse.duree
		decalage += Vector3.new(math.random(-100, 100), math.random(-100, 100), 0) / 100 * a
	end
	if humanoide.CameraOffset ~= decalage then humanoide.CameraOffset = decalage end
	if not visee then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	if vivant() and not bloque() then
		humanoide.AutoRotate = false
		local regard = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if regard.Magnitude > 0.01 then
			racine.CFrame = CFrame.lookAt(racine.Position, racine.Position + regard.Unit)
		end
	end
end)

-- ---------------------------------------------------------------- démarrage
local function arrivee(nouveau: Model)
	preparer(nouveau)
	coupActuel, libreA, finCombo, esquiveDispo = 0, 0, 0, 0
	humanoide.HealthChanged:Connect(majVie)
	humanoide:GetPropertyChangedSignal("MaxHealth"):Connect(majVie)
	majVie()
end
joueur.CharacterAdded:Connect(arrivee)
if joueur.Character then task.spawn(arrivee, joueur.Character) end
