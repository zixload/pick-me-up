-- Combat au corps à corps. Le client joue le geste et prévient le serveur ; le serveur vérifie le
-- rythme du combo, cherche lui-même les cibles devant le personnage au moment où la lame touche,
-- et inflige les dégâts. Un joueur en esquive ne prend aucun coup.
-- Cibles : les modèles étiquetés « Ennemi » (mobs) ou « Cible » (mannequins d'entraînement) ; les joueurs seulement
-- si les deux ont l'attribut PvP (arène, plus tard).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Donnees = require(script.Parent.Donnees)
local Config = require(ReplicatedStorage.Shared.Config.Combat)

local Combat = {}

local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
reseau.Name = "Reseau"
reseau.Parent = ReplicatedStorage
local function distant(classe, nom)
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end
local Attaquer = distant("RemoteEvent", "Attaquer")   -- client -> serveur : (numéro du coup)
local Esquiver = distant("RemoteEvent", "Esquiver")   -- client -> serveur : début d'esquive
local Impact = distant("RemoteEvent", "Impact")       -- serveur -> clients : (position, dégâts, modèle touché, auteur)
local Parer = distant("RemoteEvent", "Parer")         -- client -> serveur : début de parade
local Pare = distant("RemoteEvent", "Pare")           -- serveur -> clients : (position, modèle qui pare, attaquant paré)

-- par joueur : coup en cours, fin du geste, fin de la fenêtre de combo, invulnérabilité, recharge d'esquive
local etats: {[Player]: any} = {}
local hasard = Random.new()

local function niveau(joueur: Player): number
	local d = Donnees.profil(joueur)
	return d and d.Niveau or 1
end

-- points de vie du personnage selon le niveau ; un gain de niveau ajoute la différence
local function appliquerStats(joueur: Player)
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	local max = Config.pvMax(niveau(joueur))
	local ecart = max - h.MaxHealth
	h.MaxHealth = max
	h.Health = math.clamp(h.Health + math.max(ecart, 0), 0, max)
end

-- humanoïde touchable par cet attaquant, ou nil
function Combat.cible(attaquant: Player?, modele: Model): Humanoid?
	local h = modele:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	local joueur = Players:GetPlayerFromCharacter(modele)
	if joueur then
		if joueur == attaquant or joueur:GetAttribute("KO") then return nil end
		local pvp = attaquant == nil or attaquant:GetAttribute("PvP") == true
		-- en arène, on ne touche que les joueurs du même duel
		if attaquant and attaquant:GetAttribute("Arene") ~= joueur:GetAttribute("Arene") then return nil end
		return if pvp and joueur:GetAttribute("PvP") == true then h else nil
	end
	if CollectionService:HasTag(modele, "Ennemi") or CollectionService:HasTag(modele, "Cible") then
		return h
	end
	-- invocation d'un autre joueur : touchable seulement en duel, entre adversaires du même duel
	local camp = modele:GetAttribute("Camp")
	if attaquant and type(camp) == "string" and string.sub(camp, 1, 1) == "J" then
		local maitre = Players:GetPlayerByUserId(tonumber(string.sub(camp, 2)) or 0)
		if maitre and maitre ~= attaquant and attaquant:GetAttribute("PvP") and maitre:GetAttribute("PvP")
			and attaquant:GetAttribute("Arene") ~= nil and attaquant:GetAttribute("Arene") == maitre:GetAttribute("Arene") then
			return h
		end
	end
	return nil
end

-- Inflige des dégâts (joueurs, mobs, mannequins) ; renvoie false si la cible esquivait.
-- auteur : le joueur qui frappe, s'il y en a un (son écran marque l'impact d'un arrêt sur image).
function Combat.infliger(h: Humanoid, degats: number, auteur: Player?): boolean
	local joueur = Players:GetPlayerFromCharacter(h.Parent)
	local e = joueur and etats[joueur]
	if e and os.clock() < e.invulnerable then return false end
	if joueur and joueur:GetAttribute("KO") then return false end
	-- parade : coup reçu de face pendant la fenêtre, aucun dégât et l'attaquant est étourdi
	if e and os.clock() < e.parade then
		local racineCible = h.Parent:FindFirstChild("HumanoidRootPart")
		local persoAuteur = auteur and auteur.Character
		local racineAuteur = persoAuteur and persoAuteur:FindFirstChild("HumanoidRootPart")
		local deFace = true
		if racineCible and racineAuteur then
			local vers = (racineAuteur.Position - racineCible.Position) * Vector3.new(1, 0, 1)
			local regard = racineCible.CFrame.LookVector * Vector3.new(1, 0, 1)
			deFace = vers.Magnitude < 0.1
				or vers.Unit:Dot(regard.Unit) >= math.cos(math.rad(Config.PARADE.demiAngle))
		end
		if deFace then
			local ea = auteur and etats[auteur]
			if ea then
				ea.etourdi = os.clock() + Config.PARADE.etourdissement
				ea.geste += 1
				ea.coup = 0
			end
			e.parade, e.etourdi = 0, 0   -- parade réussie : libre aussitôt de riposter
			Pare:FireAllClients(if racineCible then racineCible.Position else h.Parent:GetPivot().Position, h.Parent, auteur)
			return false
		end
	end
	if joueur and joueur:GetAttribute("Arene") and h.Health - degats <= 0 then
		-- en arène, on ne meurt pas : on tombe à genoux et la manche est perdue
		h.Health = 0.01
		joueur:SetAttribute("KO", true)
		-- à terre, la vie reste à zéro jusqu'à la manche suivante (la régénération de Roblox la ferait remonter)
		local garde
		garde = h.HealthChanged:Connect(function(pv)
			if not joueur:GetAttribute("KO") or not h.Parent then
				garde:Disconnect()
			elseif pv > 0.01 then
				h.Health = 0.01
			end
		end)
		task.spawn(Combat.surKO, joueur)
	else
		h:TakeDamage(degats)
	end
	if e then
		-- touché : bref étourdissement, le coup qu'il préparait n'arrive jamais
		e.etourdi = os.clock() + Config.ETOURDISSEMENT
		e.geste += 1
		e.coup = 0
	end
	local racine = h.Parent:FindFirstChild("HumanoidRootPart")
	Impact:FireAllClients(racine and racine.Position or h.Parent:GetPivot().Position, degats, h.Parent, auteur)
	return true
end

-- appelé quand un joueur en arène tombe à 0 PV (le service Arene le remplace)
function Combat.surKO(_joueur: Player) end

-- remet un joueur en état de combattre (début de manche, fin de duel)
function Combat.reinitialiser(joueur: Player)
	local e = etats[joueur]
	if e then
		e.coup, e.libre, e.finCombo, e.invulnerable, e.esquive, e.etourdi = 0, 0, 0, 0, 0, 0
		e.parade, e.paradeDispo = 0, 0
		e.geste += 1
	end
	joueur:SetAttribute("KO", nil)
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if h then h.Health = h.MaxHealth end
end

-- le joueur peut-il agir (pas figé par le compte à rebours, pas à terre, pas étourdi) ?
local function libreDAgir(joueur: Player, e): boolean
	return not joueur:GetAttribute("Fige") and not joueur:GetAttribute("KO") and os.clock() >= e.etourdi
end

-- traînée de la lame, allumée par le serveur pendant la frappe : tous les joueurs la voient
local function trainee(perso: Model?, allumee: boolean)
	local epee = perso and perso:FindFirstChild("Epee")
	local t = epee and epee:FindFirstChild("Trainee", true)
	if t then t.Enabled = allumee end
end

-- le modèle à humanoïde qui contient cette pièce
local function modeleDe(piece: Instance): Model?
	local m = piece:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do
		m = m:FindFirstAncestorOfClass("Model")
	end
	return m
end

-- la lame touche : toutes les cibles à portée, dans l'angle du regard, au moment de l'impact
local function frapper(joueur: Player, coup)
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local h = perso and perso:FindFirstChildOfClass("Humanoid")
	if not racine or not h or h.Health <= 0 then return end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {perso}
	local origine = racine.Position
	local regard = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
	local cosMin = math.cos(math.rad(Config.EPEE.demiAngle))
	local vus = {}
	for _, piece in workspace:GetPartBoundsInRadius(origine, Config.EPEE.portee, params) do
		local m = modeleDe(piece)
		if m and not vus[m] then
			vus[m] = true
			local cible = Combat.cible(joueur, m)
			local rc = m:FindFirstChild("HumanoidRootPart")
			if cible and rc then
				local vers = (rc.Position - origine) * Vector3.new(1, 0, 1)
				if vers.Magnitude < 2 or vers.Unit:Dot(regard.Unit) >= cosMin then
					local degats = math.max(1, math.floor(Config.attaque(niveau(joueur)) * coup.multiplicateur
						* hasard:NextNumber(0.9, 1.1) + 0.5))
					if Combat.infliger(cible, degats, joueur) and coup.recul > 0 and not Players:GetPlayerFromCharacter(m)
						and not rc.Anchored and vers.Magnitude > 0 then
						rc:ApplyImpulse(vers.Unit * coup.recul * rc.AssemblyMass)
					end
				end
			end
		end
	end
end

-- épée de ServerStorage.Armes (kit Blender), ou une épée provisoire en blocs tant qu'elle manque
local function modeleEpee(): Model
	local armes = ServerStorage:FindFirstChild("Armes")
	local source = armes and armes:FindFirstChild("Epee")
	if source then return source:Clone() end
	local m = Instance.new("Model")
	local function bloc(nom, taille, y, couleur, matiere)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color, p.Material = nom, taille, CFrame.new(0, y, 0), couleur, matiere
		p.Parent = m
	end
	bloc("Lame", Vector3.new(0.3, 2.8, 0.07), 2.05, Color3.fromRGB(214, 222, 232), Enum.Material.Metal)
	bloc("Garde", Vector3.new(1.3, 0.17, 0.22), 0.53, Color3.fromRGB(150, 160, 176), Enum.Material.Metal)
	bloc("Poignee", Vector3.new(0.22, 0.9, 0.22), 0, Color3.fromRGB(58, 44, 34), Enum.Material.Leather)
	m.WorldPivot = CFrame.identity
	return m
end

-- traînée d'esquive, éteinte en temps normal : deux points sur la hauteur du corps
local function traineeEsquive(perso: Model)
	local racine = perso:WaitForChild("HumanoidRootPart", 5)
	if not racine or racine:FindFirstChild("TraineeEsquive") then return end
	local haut, bas = Instance.new("Attachment"), Instance.new("Attachment")
	haut.Name, bas.Name = "EsquiveHaut", "EsquiveBas"
	haut.Position, bas.Position = Vector3.new(0, 1.3, 0.4), Vector3.new(0, -2, 0.4)
	haut.Parent, bas.Parent = racine, racine
	local t = Instance.new("Trail")
	t.Name = "TraineeEsquive"
	t.Attachment0, t.Attachment1 = haut, bas
	t.Lifetime, t.MinLength = 0.22, 0.1
	t.Color = ColorSequence.new(Color3.fromRGB(200, 222, 255), Color3.fromRGB(120, 150, 220))
	t.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
	t.LightEmission, t.Enabled = 0.6, false
	t.Parent = racine
end

-- bouclier de ServerStorage.Armes (kit Blender), ou un bouclier provisoire tant qu'il manque ;
-- pivot au centre du dos, LookVector du côté de la face
local function modeleBouclier(): Model
	local armes = ServerStorage:FindFirstChild("Armes")
	local source = armes and armes:FindFirstChild("Bouclier")
	if source then return source:Clone() end
	local m = Instance.new("Model")
	local disque = Instance.new("Part")
	disque.Name, disque.Shape = "Bois", Enum.PartType.Cylinder
	disque.Size = Vector3.new(0.3, 2.6, 2.6)
	disque.CFrame = CFrame.new(0, 0, -0.15) * CFrame.Angles(0, math.rad(90), 0)
	disque.Color, disque.Material = Color3.fromRGB(92, 64, 42), Enum.Material.Wood
	disque.Parent = m
	local umbo = Instance.new("Part")
	umbo.Name, umbo.Shape, umbo.Size = "Umbo", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8)
	umbo.CFrame = CFrame.new(0, 0, -0.3)
	umbo.Color, umbo.Material = Color3.fromRGB(205, 212, 222), Enum.Material.Metal
	umbo.Parent = m
	m.WorldPivot = CFrame.identity
	return m
end

-- soude un modèle à une pièce du personnage, à la position donnée
local function souder(modele: Model, piece: BasePart, cf: CFrame)
	modele:PivotTo(cf)
	for _, p in modele:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.Massless = false, true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			local soudure = Instance.new("WeldConstraint")
			soudure.Part0, soudure.Part1 = piece, p
			soudure.Parent = p
		end
	end
end

local function equiperBouclier(perso: Model)
	local avantBras = perso:WaitForChild("LeftLowerArm", 5)
	if not avantBras or perso:FindFirstChild("Bouclier") then return end
	local bouclier = modeleBouclier()
	bouclier.Name = "Bouclier"
	souder(bouclier, avantBras, avantBras.CFrame * Config.BOUCLIER.prise)
	bouclier.Parent = perso
end

local function equiper(perso: Model)
	task.spawn(traineeEsquive, perso)
	task.spawn(equiperBouclier, perso)
	local main = perso:WaitForChild("RightHand", 5)
	if not main or perso:FindFirstChild("Epee") then return end
	local epee = modeleEpee()
	epee.Name = "Epee"
	epee:PivotTo(main.CFrame * Config.EPEE.prise)
	for _, p in epee:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.Massless = false, true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			local soudure = Instance.new("WeldConstraint")
			soudure.Part0, soudure.Part1 = main, p
			soudure.Parent = p
		end
	end
	-- traînée entre la garde et la pointe (positions dans le repère de l'épée : lame vers +Y)
	local lame = epee:FindFirstChild("Lame")
	if lame then
		local pivot = main.CFrame * Config.EPEE.prise
		local base, pointe = Instance.new("Attachment"), Instance.new("Attachment")
		base.Name, pointe.Name = "TraineeBase", "TraineePointe"
		base.Parent, pointe.Parent = lame, lame
		base.WorldPosition = (pivot * CFrame.new(0, 0.75, 0)).Position
		pointe.WorldPosition = (pivot * CFrame.new(0, 3.35, 0)).Position
		local t = Instance.new("Trail")
		t.Name = "Trainee"
		t.Attachment0, t.Attachment1 = base, pointe
		t.Lifetime, t.MinLength = 0.16, 0.05
		t.Color = ColorSequence.new(Color3.fromRGB(235, 242, 255), Color3.fromRGB(150, 175, 210))
		t.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
		t.LightEmission, t.FaceCamera, t.Enabled = 0.7, false, false
		t.Parent = lame
	end
	epee.Parent = perso
end

-- Mannequins d'entraînement posés par ChatGPT (modèles à l'attribut P1_AssetSource =
-- « P1_Mannequin_Entrainement », dans Decor_Lobby_P1) : on leur donne de la vie, une barre de vie,
-- un recul quand on les frappe. Ils ne meurent pas et se soignent quelques secondes après le dernier coup.
local function barreDeVie(racine: BasePart, hauteur: number)
	local affiche = Instance.new("BillboardGui")
	affiche.Name = "BarreDeVie"
	affiche.Size, affiche.StudsOffset = UDim2.fromScale(4.5, 0.9), Vector3.new(0, hauteur, 0)
	affiche.MaxDistance, affiche.Enabled = 70, false
	affiche.Adornee, affiche.Parent = racine, racine
	local nom = Instance.new("TextLabel")
	nom.BackgroundTransparency, nom.Size = 1, UDim2.fromScale(1, 0.45)
	nom.Font, nom.TextScaled, nom.Text = Enum.Font.GothamBold, true, "Training Dummy"
	nom.TextColor3, nom.TextStrokeTransparency = Color3.fromRGB(232, 236, 242), 0.4
	nom.Parent = affiche
	local fond = Instance.new("Frame")
	fond.Position, fond.Size = UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.4)
	fond.BackgroundColor3, fond.BorderSizePixel = Color3.fromRGB(26, 32, 44), 0
	fond.Parent = affiche
	Instance.new("UICorner", fond).CornerRadius = UDim.new(0.5, 0)
	local jauge = Instance.new("Frame")
	jauge.Size, jauge.BackgroundColor3, jauge.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(120, 210, 140), 0
	jauge.Parent = fond
	Instance.new("UICorner", jauge).CornerRadius = UDim.new(0.5, 0)
	return affiche, jauge
end

local function preparerMannequin(m: Model)
	if m:FindFirstChildOfClass("Humanoid") then return end
	local centre, taille = m:GetBoundingBox()
	local base = m:GetPivot()
	-- racine invisible au centre du mannequin : sert de point d'impact et de repère aux coups
	local racine = Instance.new("Part")
	racine.Name = "HumanoidRootPart"
	racine.Size = Vector3.new(2, taille.Y * 0.7, 1)
	racine.CFrame = centre
	racine.Transparency, racine.Anchored = 1, true
	racine.CanCollide, racine.CanTouch, racine.CanQuery = false, false, false
	racine.Parent = m
	local h = Instance.new("Humanoid")
	h.MaxHealth, h.Health = 400, 400
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	h.Parent = m
	CollectionService:AddTag(m, "Cible")

	local affiche, jauge = barreDeVie(racine, taille.Y / 2 + 1.2)
	local inclinaison = Instance.new("NumberValue")
	inclinaison.Changed:Connect(function(a)
		m:PivotTo(base * CFrame.Angles(math.rad(a), 0, 0))   -- bascule autour de son pied
	end)
	local dernier, pvAvant = 0, h.Health
	h.HealthChanged:Connect(function(pv)
		local part = math.clamp(pv / h.MaxHealth, 0, 1)
		jauge.Size = UDim2.fromScale(part, 1)
		jauge.BackgroundColor3 = if part > 0.3 then Color3.fromRGB(120, 210, 140) else Color3.fromRGB(235, 110, 100)
		local touche = pv < pvAvant
		pvAvant = pv
		if not touche then return end
		affiche.Enabled = true
		-- le mannequin encaisse : il bascule en arrière puis revient en oscillant
		inclinaison.Value = -9
		TweenService:Create(inclinaison, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{Value = 0}):Play()
		dernier = os.clock()
		local moment = dernier
		task.delay(3, function()
			if dernier == moment and h.Parent then
				h.Health = h.MaxHealth
				task.delay(2, function()
					if dernier == moment then affiche.Enabled = false end
				end)
			end
		end)
	end)
end

local function preparerMannequins()
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("P1_AssetSource") == "P1_Mannequin_Entrainement" then
			preparerMannequin(m)
		end
	end
end

function Combat.demarrer()
	Players.RespawnTime = Config.REAPPARITION

	local function arrivee(joueur: Player)
		etats[joueur] = {coup = 0, libre = 0, finCombo = 0, invulnerable = 0, esquive = 0, etourdi = 0, geste = 0,
			parade = 0, paradeDispo = 0}
		joueur.CharacterAdded:Connect(function(perso)
			etats[joueur].coup = 0
			task.spawn(equiper, perso)
			local h = perso:WaitForChild("Humanoid", 5)
			if h then
				h.MaxHealth = Config.pvMax(niveau(joueur))
				h.Health = h.MaxHealth
			end
		end)
		if joueur.Character then
			task.spawn(equiper, joueur.Character)
			appliquerStats(joueur)
		end
	end
	Players.PlayerAdded:Connect(arrivee)
	for _, j in Players:GetPlayers() do arrivee(j) end
	Players.PlayerRemoving:Connect(function(joueur) etats[joueur] = nil end)
	Donnees.Change:Connect(appliquerStats)   -- profil chargé, /level…

	Attaquer.OnServerEvent:Connect(function(joueur, numero)
		local e = etats[joueur]
		local coups = Config.EPEE.coups
		if not e or type(numero) ~= "number" then return end
		numero = math.floor(numero)
		if numero < 1 or numero > #coups then return end
		local t = os.clock()
		if t < e.libre or not libreDAgir(joueur, e) then return end   -- geste précédent pas fini, figé, à terre…
		local suivant = if e.coup < #coups and t <= e.finCombo then e.coup + 1 else 1
		if numero ~= suivant and numero ~= 1 then return end
		local coup = coups[numero]
		-- un peu de marge sur le rythme : le message du client arrive avec la latence
		e.coup, e.libre, e.finCombo = numero, t + coup.duree * 0.7, t + coup.duree + Config.EPEE.fenetreCombo
		-- le coup ne part que si rien ne l'a interrompu entre-temps (coup reçu, esquive)
		e.geste += 1
		local jeton = e.geste
		local perso = joueur.Character
		task.delay(coup.impact, function()
			if e.geste == jeton then frapper(joueur, coup) end
		end)
		task.delay(math.max(coup.impact - 0.1, 0), function()
			if e.geste == jeton then trainee(perso, true) end
		end)
		task.delay(coup.impact + 0.14, trainee, perso, false)
	end)

	Esquiver.OnServerEvent:Connect(function(joueur)
		local e = etats[joueur]
		local t = os.clock()
		if not e or t < e.esquive or not libreDAgir(joueur, e) then return end
		e.geste += 1
		e.esquive = t + Config.ESQUIVE.recharge * 0.8
		e.invulnerable = t + Config.ESQUIVE.invulnerable + 0.1
		e.coup = 0
		-- traînée derrière le héros pendant la poussée, vue par tous
		local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		local t2 = racine and racine:FindFirstChild("TraineeEsquive")
		if t2 then
			t2.Enabled = true
			task.delay(Config.ESQUIVE.duree + 0.08, function() t2.Enabled = false end)
		end
	end)

	Parer.OnServerEvent:Connect(function(joueur)
		local e = etats[joueur]
		local t = os.clock()
		if not e or t < e.paradeDispo or not libreDAgir(joueur, e) then return end
		e.paradeDispo = t + Config.PARADE.recharge * 0.8
		e.parade = t + Config.PARADE.fenetre + 0.08   -- un peu de marge pour la latence
		-- pendant la parade et juste après, on ne peut rien faire d'autre (sauf si elle réussit)
		e.etourdi = t + Config.PARADE.fenetre + Config.PARADE.recuperation
		e.geste += 1   -- la parade coupe l'attaque en préparation
		e.coup = 0
	end)

	preparerMannequins()
end

return Combat
