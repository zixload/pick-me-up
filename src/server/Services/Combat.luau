-- Combat au corps à corps. Le client joue le geste et prévient le serveur ; le serveur vérifie le
-- rythme du combo, cherche lui-même les cibles devant le personnage au moment où la lame touche,
-- et inflige les dégâts. Un joueur en esquive ne prend aucun coup.
-- Cibles : les modèles étiquetés « Ennemi » (mobs) ou « Cible » (mannequins) ; les joueurs seulement
-- si les deux ont l'attribut PvP (arène, plus tard).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

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
		if joueur == attaquant then return nil end
		local pvp = attaquant == nil or attaquant:GetAttribute("PvP") == true
		return if pvp and joueur:GetAttribute("PvP") == true then h else nil
	end
	if CollectionService:HasTag(modele, "Ennemi") or CollectionService:HasTag(modele, "Cible") then
		return h
	end
	return nil
end

-- Inflige des dégâts (joueurs, mobs, mannequins) ; renvoie false si la cible esquivait.
-- auteur : le joueur qui frappe, s'il y en a un (son écran marque l'impact d'un arrêt sur image).
function Combat.infliger(h: Humanoid, degats: number, auteur: Player?): boolean
	local joueur = Players:GetPlayerFromCharacter(h.Parent)
	local e = joueur and etats[joueur]
	if e and os.clock() < e.invulnerable then return false end
	h:TakeDamage(degats)
	local racine = h.Parent:FindFirstChild("HumanoidRootPart")
	Impact:FireAllClients(racine and racine.Position or h.Parent:GetPivot().Position, degats, h.Parent, auteur)
	return true
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

local function equiper(perso: Model)
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

-- mannequins de test : se soignent quelques secondes après le dernier coup, ne meurent pas
local function poserMannequins()
	local dossier = workspace:FindFirstChild("Mannequins_Test") or Instance.new("Folder")
	dossier.Name = "Mannequins_Test"
	dossier:ClearAllChildren()
	dossier.Parent = workspace
	local bois = Color3.fromRGB(139, 108, 72)
	for i, x in {-96, -84, -72} do
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor, desc.TorsoColor = bois, bois
		desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = bois, bois, bois, bois
		local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		m.Name = "Mannequin_" .. i
		local h = m:FindFirstChildOfClass("Humanoid")
		h.MaxHealth, h.Health = 400, 400
		h.DisplayName = "Training Dummy"
		h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		h.BreakJointsOnDeath = false
		-- debout sur le dallage du lot (dessus à y = 0,86), face à la place
		local y = 0.86 + h.HipHeight + m.HumanoidRootPart.Size.Y / 2
		m:PivotTo(CFrame.new(x, y, -112) * CFrame.Angles(0, math.pi, 0))
		m.HumanoidRootPart.Anchored = true
		CollectionService:AddTag(m, "Cible")
		local dernierCoup = 0
		h.HealthChanged:Connect(function(pv)
			if pv >= h.MaxHealth then return end
			dernierCoup = os.clock()
			local moment = dernierCoup
			task.delay(3, function()
				if dernierCoup == moment and h.Parent then h.Health = h.MaxHealth end
			end)
		end)
		m.Parent = dossier
	end
end

function Combat.demarrer()
	Players.RespawnTime = Config.REAPPARITION

	local function arrivee(joueur: Player)
		etats[joueur] = {coup = 0, libre = 0, finCombo = 0, invulnerable = 0, esquive = 0}
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
		if t < e.libre then return end   -- le geste précédent n'est pas fini
		local suivant = if e.coup < #coups and t <= e.finCombo then e.coup + 1 else 1
		if numero ~= suivant and numero ~= 1 then return end
		local coup = coups[numero]
		-- un peu de marge sur le rythme : le message du client arrive avec la latence
		e.coup, e.libre, e.finCombo = numero, t + coup.duree * 0.7, t + coup.duree + Config.EPEE.fenetreCombo
		task.delay(coup.impact, frapper, joueur, coup)
		local perso = joueur.Character
		task.delay(math.max(coup.impact - 0.1, 0), trainee, perso, true)
		task.delay(coup.impact + 0.14, trainee, perso, false)
	end)

	Esquiver.OnServerEvent:Connect(function(joueur)
		local e = etats[joueur]
		local t = os.clock()
		if not e or t < e.esquive then return end
		e.esquive = t + Config.ESQUIVE.recharge * 0.8
		e.invulnerable = t + Config.ESQUIVE.invulnerable + 0.1
		e.coup = 0
	end)

	if Config.MANNEQUINS_TEST then
		task.spawn(poserMannequins)
	end
end

return Combat
