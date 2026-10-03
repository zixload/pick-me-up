-- Mobs (PvE), 03/10/2026. Modèles dans ServerStorage.Mobs (studio/monter_mob.luau), réglages dans Config.Mobs.
-- Comportement :
--   * apparition : se relève du sol (animation Relever), figé pendant ce temps ;
--   * cible : le joueur ou l'invocation de joueur la plus proche dans son rayon de détection (pas les joueurs à
--     terre, ni ceux en duel d'arène) ; il la garde tant qu'elle reste à 1,5 fois ce rayon ;
--   * déplacement : se tourne vers là où il va (AutoRotate du Humanoid), marche près de sa cible et court quand elle
--     est loin ; la cadence des animations suit sa vitesse réelle (pas de glissade) ;
--   * au contact : pivote vers sa cible (AlignOrientation, pas de saut d'orientation) et frappe ; le coup porte au
--     « moment » de l'animation si la cible est encore à portée et devant lui ;
--   * coup reçu : animation Touche (pas plus d'une fois toutes les 0,5 s) ; mort : animation Mort puis fondu.
-- Tag « Ennemi » : l'épée du héros, les invocations et le HUD (barre rouge, « Lv. N ») le reconnaissent.
-- Commande de test (Studio ou comptes développeurs) : /goblins [nombre] fait apparaître des gobelins autour de soi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Combat = require(script.Parent.Combat)
local Commandes = require(script.Parent.Commandes)
local Config = require(ReplicatedStorage.Shared.Config.Mobs)

local Mobs = {}

local dossier = workspace:FindFirstChild("Mobs") or Instance.new("Folder")
dossier.Name, dossier.Parent = "Mobs", workspace

local actifs = {}   -- [modèle] = état

local function racineDe(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart")
end
local function plat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- cibles possibles : joueurs debout hors duel, invocations des joueurs
local function cibles(): {Model}
	local t = {}
	for _, j in Players:GetPlayers() do
		local h = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and racineDe(j.Character) and not j:GetAttribute("KO") and not j:GetAttribute("Arene") then
			table.insert(t, j.Character)
		end
	end
	for _, m in CollectionService:GetTagged("Invocation") do
		local camp = m:GetAttribute("Camp")
		local h = m:FindFirstChildOfClass("Humanoid")
		if type(camp) == "string" and string.sub(camp, 1, 1) == "J" and h and h.Health > 0 and racineDe(m) then
			table.insert(t, m)
		end
	end
	return t
end

-- En Studio (Test Here), on joue la dernière version construite dans ServerStorage.RBX_ANIMSAVES.<Nom> plutôt
-- que la version publiée : on peut tester sans republier. En Team Test et en jeu publié, ce sont les identifiants
-- publiés de la config. Une séquence n'est enregistrée qu'une fois par session.
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local provisoires = {}
local function identifiant(nomMob: string, nomAnim: string, publie: string): string
	if not RunService:IsStudio() then return publie end
	local cle = nomMob .. "_" .. nomAnim
	if provisoires[cle] == nil then
		provisoires[cle] = false
		local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		local dossierSaves = saves and saves:FindFirstChild(nomMob)
		local seq = dossierSaves and dossierSaves:FindFirstChild(cle)
		if seq and seq:IsA("KeyframeSequence") then
			local ok, id = pcall(function() return KeyframeSequenceProvider:RegisterKeyframeSequence(seq) end)
			if ok then provisoires[cle] = id end
		end
	end
	return provisoires[cle] or publie
end

local function charger(e, animateur: Animator)
	for nom, id in e.stats.animations do
		local a = Instance.new("Animation")
		a.AnimationId = identifiant(e.nom, nom, id)
		local piste = animateur:LoadAnimation(a)
		piste.Looped = nom == "Repos" or nom == "Marche" or nom == "Course"
		piste.Priority = if nom == "Mort" then Enum.AnimationPriority.Action4
			elseif nom == "Touche" then Enum.AnimationPriority.Action3
			elseif nom == "Attaque" or nom == "Relever" then Enum.AnimationPriority.Action2
			else Enum.AnimationPriority.Core
		e.pistes[nom] = piste
	end
	e.pistes.Repos:Play(0.3)
end

-- joue une animation d'action à la vitesse réglée dans la config (vitesseAnimations)
local function jouer(e, nom: string, fondu: number)
	local piste = e.pistes[nom]
	piste:Play(fondu)
	piste:AdjustSpeed((e.stats.vitesseAnimations or {})[nom] or 1)
	return piste
end

-- repos, marche ou course selon la vitesse réelle ; cadence calée dessus
local function locomotion(e)
	local p = e.pistes
	local v = plat(e.r.AssemblyLinearVelocity).Magnitude
	local s = e.stats
	local voulue = if v < 0.8 then p.Repos elseif v > (s.vitesseMarche + s.vitesseCourse) / 2 then p.Course else p.Marche
	for _, nom in {"Repos", "Marche", "Course"} do
		local piste = p[nom]
		if piste == voulue then
			if not piste.IsPlaying then piste:Play(0.25) end
		elseif piste.IsPlaying then
			piste:Stop(0.25)
		end
	end
	if voulue == p.Marche then voulue:AdjustSpeed(math.max(0.5, v / s.cadenceMarche))
	elseif voulue == p.Course then voulue:AdjustSpeed(math.max(0.6, v / s.cadenceCourse)) end
end

local function choisirCible(e): Model?
	local s, pos = e.stats, e.r.Position
	if e.cible then
		local rc = racineDe(e.cible)
		local h = e.cible:FindFirstChildOfClass("Humanoid")
		local j = Players:GetPlayerFromCharacter(e.cible)
		local valide = rc and h and h.Health > 0 and e.cible.Parent and not (j and (j:GetAttribute("KO") or j:GetAttribute("Arene")))
		if valide and (rc.Position - pos).Magnitude <= s.detection * 1.5 then return e.cible end
	end
	local meilleure, dist = nil, s.detection
	for _, c in cibles() do
		local d = (racineDe(c).Position - pos).Magnitude
		if d < dist then meilleure, dist = c, d end
	end
	if not meilleure then
		-- aggro de groupe : un voisin de la troupe a déjà une cible, on la prend aussi
		for _, autre in actifs do
			if autre ~= e and autre.cible and autre.cible.Parent and (autre.r.Position - pos).Magnitude < (s.aggroGroupe or 30) then
				return autre.cible
			end
		end
	end
	return meilleure
end

local function frapper(e, cible: Model)
	local s = e.stats
	local t = os.clock()
	if t < e.prochaineAttaque or e.occupe then return end
	-- un peu de hasard : vingt mobs ne frappent pas tous au même rythme
	e.prochaineAttaque = t + s.cadence + math.random() * (s.cadenceHasard or 0)
	e.occupe = true
	local vitesse = (s.vitesseAnimations or {}).Attaque or 1
	jouer(e, "Attaque", 0.1)
	task.delay(s.moment / vitesse, function()
		local rc, hc = racineDe(cible), cible:FindFirstChildOfClass("Humanoid")
		if e.h.Health > 0 and rc and hc and hc.Health > 0 then
			local vers = plat(rc.Position - e.r.Position)
			local devant = vers.Magnitude < 0.1 or vers.Unit:Dot(plat(e.r.CFrame.LookVector).Unit) > 0.3
			if vers.Magnitude <= s.portee + 1.5 and devant then
				Combat.infliger(hc, s.degats, nil, {type = "Griffe"})
			end
		end
	end)
	task.delay(math.max(s.moment / vitesse + 0.3, e.pistes.Attaque.Length * 0.8 / vitesse), function() e.occupe = false end)
end

-- au plus ATTAQUANTS_MAX mobs frappent la même cible ; les autres attendent en retrait
local ATTAQUANTS_MAX = 3
local function peutAttaquer(e, cible: Model): boolean
	if e.attaquant then return true end
	local n = 0
	for _, autre in actifs do
		if autre ~= e and autre.cible == cible and autre.attaquant and autre.h.Health > 0 then n += 1 end
	end
	return n < ATTAQUANTS_MAX
end

-- répulsion des mobs voisins : vecteur qui écarte celui-ci des autres trop proches (pas d'empilement)
local ESPACE = 7   -- studs entre deux mobs si la config n'en donne pas (à la taille 1)
local function repousse(e): Vector3
	local total = Vector3.zero
	for _, autre in actifs do
		if autre ~= e and autre.h.Health > 0 then
			local ecart = plat(e.r.Position - autre.r.Position)
			local d = ecart.Magnitude
			local espace = e.stats.espace or ESPACE
			if d < espace then
				total += (if d > 0.05 then ecart.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit) * (espace - d)
			end
		end
	end
	return total
end

local function penser(e)
	local s, h, r = e.stats, e.h, e.r
	if h.Health <= 0 or e.fige then return end
	locomotion(e)
	local cible = choisirCible(e)
	if cible ~= e.cible then e.attaquant = false end   -- nouvelle cible : il refait la queue
	e.cible = cible
	if not cible then
		e.orientation.Enabled, h.AutoRotate = false, true
		h:MoveTo(r.Position)
		return
	end
	local rc = racineDe(cible)
	local vers = plat(rc.Position - r.Position)
	local d = vers.Magnitude
	-- une place d'attaquant se libère dès qu'il s'éloigne de sa cible
	if e.attaquant and d > s.portee + 4 then e.attaquant = false end
	if d <= s.portee + 4 and not peutAttaquer(e, cible) then
		-- en attente : se tient en retrait, tourné vers sa cible, écarté de ses voisins
		local retrait = rc.Position - (if d > 0.1 then vers.Unit else Vector3.zero) * (s.portee + 10)
		local cote = repousse(e)
		h.WalkSpeed = s.vitesseMarche
		h:MoveTo(retrait + cote * 1.5)
		h.AutoRotate = false
		e.orientation.CFrame = CFrame.lookAt(r.Position, Vector3.new(rc.Position.X, r.Position.Y, rc.Position.Z))
		e.orientation.Enabled = true
		return
	end
	if d > s.portee then
		-- se rapproche, tourné vers là où il va
		e.orientation.Enabled, h.AutoRotate = false, true
		h.WalkSpeed = if d > s.distanceCourse then s.vitesseCourse else s.vitesseMarche
		-- chacun vise sa propre place autour de la cible (de son côté), décalée par ses voisins
		local place = rc.Position - (if d > 0.1 then vers.Unit else Vector3.zero) * (s.portee * 0.8)
		h:MoveTo(place + repousse(e) * 1.5)
	else
		-- au contact : pivote vers sa cible et frappe ; s'il est collé à un autre, il se décale sur le côté
		local ecart = repousse(e)
		if ecart.Magnitude > 0.6 then
			h.WalkSpeed = s.vitesseMarche
			h:MoveTo(r.Position + ecart * 1.5)
		else
			h:MoveTo(r.Position)
		end
		h.AutoRotate = false
		e.orientation.CFrame = CFrame.lookAt(r.Position, Vector3.new(rc.Position.X, r.Position.Y, rc.Position.Z))
		e.orientation.Enabled = true
		e.attaquant = true
		frapper(e, cible)
	end
end

-- réglages à la taille du mob : portée et vitesses suivent l'échelle (calculés une fois par modèle)
local reglages = {}
local function aLEchelle(nom: string)
	if reglages[nom] then return reglages[nom] end
	local s = table.clone(Config.MODELES[nom])
	local k = s.echelle or 1
	for _, cle in {"portee", "vitesseMarche", "vitesseCourse", "distanceCourse", "cadenceMarche", "cadenceCourse", "espace"} do
		if s[cle] then s[cle] *= k end
	end
	reglages[nom] = s
	return s
end

function Mobs.apparaitre(nom: string, cadre: CFrame): Model?
	local source = ServerStorage:FindFirstChild("Mobs") and ServerStorage.Mobs:FindFirstChild(nom)
	if not (source and Config.MODELES[nom]) then
		warn("[Mobs] modèle ou réglages introuvables : " .. nom)
		return nil
	end
	local stats = aLEchelle(nom)
	local m = source:Clone()
	if stats.echelle and stats.echelle ~= 1 then
		m:ScaleTo(stats.echelle)
		-- hauteur des hanches fixée à la main : sinon le Humanoid soulève le mob à la hauteur de la taille 1
		local hs = m:FindFirstChildOfClass("Humanoid")
		hs.HipHeight = source:FindFirstChildOfClass("Humanoid").HipHeight * stats.echelle
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	local r = racineDe(m)
	h.MaxHealth, h.Health, h.WalkSpeed = stats.pv, stats.pv, stats.vitesseMarche
	m:SetAttribute("Niveau", stats.niveau)
	m:SetAttribute("NomAffiche", stats.nom)
	CollectionService:AddTag(m, "Ennemi")
	CollectionService:AddTag(m, "Mob")
	m:PivotTo(cadre)
	m.Parent = dossier
	pcall(function() r:SetNetworkOwner(nil) end)
	-- jamais renversé par une bousculade (sinon il reste couché au sol après s'être relevé)
	for _, etat in {Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.PlatformStanding} do
		h:SetStateEnabled(etat, false)
	end
	local point = Instance.new("Attachment")
	point.Parent = r
	local orientation = Instance.new("AlignOrientation")
	orientation.Mode, orientation.Attachment0 = Enum.OrientationAlignmentMode.OneAttachment, point
	orientation.MaxTorque, orientation.MaxAngularVelocity, orientation.Responsiveness = math.huge, math.huge, 14
	orientation.Enabled = false
	orientation.Parent = r
	local e = {modele = m, nom = nom, h = h, r = r, stats = stats, pistes = {}, orientation = orientation,
		prochaineAttaque = 0, occupe = false, fige = true}
	actifs[m] = e
	charger(e, h:FindFirstChildOfClass("Animator"))
	-- apparition : se relève, immobile
	r.Anchored = true
	local relever = jouer(e, "Relever", 0)
	local vitesseRelever = (stats.vitesseAnimations or {}).Relever or 1
	task.spawn(function()
		local debut = os.clock()
		while relever.Length == 0 and os.clock() - debut < 3 do task.wait(0.1) end
		-- libéré à la fin du geste ; celui-ci s'efface en douceur pendant que le repos ou la marche prend le relais
		task.wait(if relever.Length > 0 then math.max(0.3, relever.Length / vitesseRelever - (os.clock() - debut) - 0.05) else 2)
		if m.Parent and h.Health > 0 then
			relever:Stop(0.3)
			r.Anchored, e.fige = false, false
		end
	end)
	-- coup reçu
	local pv, derniere = h.Health, 0
	h.HealthChanged:Connect(function(nouveau)
		if nouveau < pv and nouveau > 0 and os.clock() - derniere > 0.5 and not e.fige then
			derniere = os.clock()
			jouer(e, "Touche", 0.05)
		end
		pv = nouveau
	end)
	-- mort
	h.Died:Connect(function()
		actifs[m] = nil
		r.Anchored = true
		orientation.Enabled = false
		for nomPiste, piste in e.pistes do
			if nomPiste ~= "Mort" then piste:Stop(0.15) end
		end
		jouer(e, "Mort", 0.1)
		task.delay(2.6, function()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					TweenService:Create(p, TweenInfo.new(1.2), {Transparency = 1}):Play()
				end
			end
		end)
		Debris:AddItem(m, 4)
	end)
	return m
end

function Mobs.demarrer()
	-- commande de test : /goblins [nombre], une troupe devant le joueur, tournée vers lui, posée sur le sol
	local gabarit = ServerStorage:FindFirstChild("Mobs") and ServerStorage.Mobs:FindFirstChild("Gobelin_Guerrier")
	local hauteurRacine = 4.4   -- du sol au centre de la racine (hanches + demi-racine)
	if gabarit then
		local hg, rg = gabarit:FindFirstChildOfClass("Humanoid"), racineDe(gabarit)
		hauteurRacine = (hg.HipHeight + rg.Size.Y / 2) * (Config.MODELES.Gobelin_Guerrier.echelle or 1)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local commandes = TextChatService:FindFirstChild("CommandesMobs") or Instance.new("Folder")
	commandes.Name, commandes.Parent = "CommandesMobs", TextChatService
	local c = commandes:FindFirstChild("Gobelins") or Instance.new("TextChatCommand")
	c.Name, c.PrimaryAlias = "Gobelins", "/goblins"
	c.Parent = commandes
	c.Triggered:Connect(function(source, texte)
		local joueur = Players:GetPlayerByUserId(source.UserId)
		local rc = joueur and racineDe(joueur.Character)
		if not rc then return end
		if not Commandes.autorise(joueur) then return end
		local n = math.clamp(tonumber(string.match(texte, "%d+")) or 5, 1, 40)
		local ignores = {dossier}
		for _, j in Players:GetPlayers() do if j.Character then table.insert(ignores, j.Character) end end
		params.FilterDescendantsInstances = ignores
		-- en troupe : rangs de 5 un peu irréguliers, à ~35 studs devant le joueur, tournés vers lui
		local devant = rc.CFrame.LookVector * Vector3.new(1, 0, 1)
		devant = if devant.Magnitude > 0.1 then devant.Unit else Vector3.new(0, 0, -1)
		local cote = devant:Cross(Vector3.yAxis)
		local reglage = Config.MODELES.Gobelin_Guerrier
		local pas = (reglage.espace or 7) * (reglage.echelle or 1)
		local centre = rc.Position + devant * 35
		local parRang = math.min(5, n)
		for i = 1, n do
			local rang, place = (i - 1) // parRang, (i - 1) % parRang
			local pos = centre + cote * ((place - (parRang - 1) / 2) * pas + (math.random() - 0.5) * pas * 0.35)
				+ devant * (rang * pas + (math.random() - 0.5) * pas * 0.35)
			local sol = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
			local y = (if sol then sol.Position.Y else rc.Position.Y - 3) + hauteurRacine
			pos = Vector3.new(pos.X, y, pos.Z)
			Mobs.apparaitre("Gobelin_Guerrier", CFrame.lookAt(pos, Vector3.new(rc.Position.X, y, rc.Position.Z)))
		end
	end)

	local cumul = 0
	RunService.Heartbeat:Connect(function(dt)
		cumul += dt
		if cumul < 0.15 then return end
		cumul = 0
		for m, e in actifs do
			if m.Parent then penser(e) else actifs[m] = nil end
		end
	end)
end

return Mobs
