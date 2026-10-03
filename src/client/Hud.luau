-- HUD (02/10/2026), refait pas à pas d'après les captures de référence fournies par le joueur.
-- Étape 1 : barres de vie et chiffres de dégâts.
--   * Héros : barre fine en bas au centre, « Lv. N » à gauche, « PV / PV max » posé sur la barre.
--   * Ennemis : petite barre rouge au-dessus de la tête, taille fixe à l'écran (pas d'envahissement de loin),
--     « Lv. N » à gauche, partie perdue en jaune qui se résorbe. Les alliés (sa propre escouade, les joueurs
--     hors duel) n'ont pas de barre, comme dans la référence.
--   * Dégâts : chiffres qui sautent, montent et s'effacent ; plus gros sur un coup critique.
-- Les barres ont des bouts en pointe (losanges tournés de 45°), opaques pour que les recouvrements ne se voient pas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local joueur = Players.LocalPlayer
local Hud = {}

-- Merriweather gras : la plus proche de la référence parmi les polices Roblox (empattements évasés)
Hud.POLICE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
Hud.POLICE_CHIFFRES = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
-- cases à touche : sans empattements, gras, comme la référence
Hud.POLICE_TOUCHE = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
local CHIFFRES = {One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0"}
local function texteTouche(touche: Enum.KeyCode): string
	return CHIFFRES[touche.Name] or string.upper(touche.Name)
end
local BLANC = Color3.fromRGB(255, 255, 255)
local VERT = Color3.fromRGB(150, 214, 64)
local ROUGE = Color3.fromRGB(226, 86, 70)
local JAUNE = Color3.fromRGB(250, 205, 104)
local FOND = Color3.fromRGB(42, 40, 42)
local OMBRE = Color3.fromRGB(72, 72, 72)       -- contour gris des textes, comme la référence
local GRIS_CLAIR = Color3.fromRGB(222, 222, 214)   -- « Lv. N », blanc légèrement gris

local DISTANCE_BARRES = 60   -- studs : au-delà, plus de barre au-dessus des ennemis

-- ---------------------------------------------------------------- briques
local function cadre(parent, taille: UDim2, position: UDim2, couleur: Color3?, transparence: number?)
	local f = Instance.new("Frame")
	f.Size, f.Position = taille, position
	f.BackgroundColor3, f.BackgroundTransparency = couleur or FOND, transparence or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function etiquette(parent, contenu: string, taille: number, police: Font?)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = police or Hud.POLICE
	t.Text, t.TextSize, t.TextColor3 = contenu, taille, BLANC
	t.Size = UDim2.fromOffset(0, taille + 4)
	t.AutomaticSize = Enum.AutomaticSize.X
	local contour = Instance.new("UIStroke")
	contour.Color, contour.Thickness, contour.Transparency = OMBRE, 1.2, 0.1
	contour.Parent = t
	t.Parent = parent
	return t
end

-- barre à bouts pointus : fond sombre, partie perdue (jaune, en retard), remplissage
local function nouvelleBarre(parent, largeur: number, hauteur: number, couleur: Color3)
	local b = cadre(parent, UDim2.fromOffset(largeur, hauteur), UDim2.new(), FOND, 1)
	local cote = hauteur / math.sqrt(2)
	local function pointe(x: number, c: Color3, z: number)
		local p = cadre(b, UDim2.fromOffset(cote, cote), UDim2.new(x, 0, 0.5, 0), c)
		p.AnchorPoint, p.Rotation, p.ZIndex = Vector2.new(0.5, 0.5), 45, z
		return p
	end
	cadre(b, UDim2.fromScale(1, 1), UDim2.new(), FOND).ZIndex = 1
	pointe(0, FOND, 1)
	local finFond = pointe(1, FOND, 1)
	local perte = cadre(b, UDim2.fromScale(1, 1), UDim2.new(), JAUNE)
	perte.ZIndex = 2
	local remplissage = cadre(b, UDim2.fromScale(1, 1), UDim2.new(), couleur)
	remplissage.ZIndex = 3
	local debut = pointe(0, couleur, 3)
	local fraction, tweenPerte = 1, nil
	local barre = {cadre = b}
	function barre.regler(f: number)
		f = math.clamp(f, 0, 1)
		local avant = fraction
		fraction = f
		remplissage.Size = UDim2.fromScale(f, 1)
		debut.Visible = f > 0
		finFond.BackgroundColor3 = if f >= 0.999 then couleur elseif perte.Size.X.Scale >= 0.999 then JAUNE else FOND
		if tweenPerte then tweenPerte:Cancel() end
		if f < avant then
			-- la vie perdue reste un instant en jaune puis se résorbe
			tweenPerte = TweenService:Create(perte, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45),
				{Size = UDim2.fromScale(f, 1)})
			tweenPerte.Completed:Once(function()
				if fraction < 0.999 then finFond.BackgroundColor3 = FOND end
			end)
			tweenPerte:Play()
		else
			perte.Size = UDim2.fromScale(f, 1)
		end
	end
	function barre.couleur(c: Color3)
		couleur = c
		remplissage.BackgroundColor3, debut.BackgroundColor3 = c, c
		barre.regler(fraction)
	end
	return barre
end

local function pv(h: Humanoid): string
	return `{if h.Health < 1 then 0 else math.ceil(h.Health)} / {math.floor(h.MaxHealth)}`
end

-- ---------------------------------------------------------------- écran
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)

local ecran = Instance.new("ScreenGui")
ecran.Name, ecran.ResetOnSpawn, ecran.IgnoreGuiInset, ecran.DisplayOrder = "Hud", false, true, 9
ecran.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ecran.Parent = joueur:WaitForChild("PlayerGui")
local echelle = Instance.new("UIScale")
echelle.Parent = ecran

-- barre du héros, en bas au centre
local bas = cadre(ecran, UDim2.fromOffset(300, 20), UDim2.new(0.5, 0, 1, -58), FOND, 1)
bas.AnchorPoint = Vector2.new(0.5, 1)
local barreHeros = nouvelleBarre(bas, 300, 8, VERT)
barreHeros.cadre.Position = UDim2.new(0, 0, 0.5, -4)
local niveauHeros = etiquette(bas, "Lv. 1", 14)
niveauHeros.TextColor3 = GRIS_CLAIR
niveauHeros.AnchorPoint, niveauHeros.Position = Vector2.new(1, 0.5), UDim2.new(0, -14, 0.5, 0)
local valeurHeros = etiquette(bas, "", 15, Hud.POLICE_CHIFFRES)
valeurHeros.AnchorPoint, valeurHeros.Position, valeurHeros.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 5

local function majNiveau()
	niveauHeros.Text = `Lv. {joueur:GetAttribute("NiveauCombat") or 1}`
end
joueur:GetAttributeChangedSignal("NiveauCombat"):Connect(majNiveau)
majNiveau()

local function suivreHeros(perso: Model)
	local h = perso:WaitForChild("Humanoid", 10)
	if not h then return end
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local function maj()
		barreHeros.regler(h.Health / math.max(1, h.MaxHealth))
		valeurHeros.Text = pv(h)
	end
	h.HealthChanged:Connect(maj)
	h:GetPropertyChangedSignal("MaxHealth"):Connect(maj)
	maj()
end
if joueur.Character then task.spawn(suivreHeros, joueur.Character) end
joueur.CharacterAdded:Connect(suivreHeros)

-- ---------------------------------------------------------------- barres au-dessus des ennemis
local function enDuelAvec(autre: Player): boolean
	return joueur:GetAttribute("PvP") == true and autre:GetAttribute("PvP") == true
		and joueur:GetAttribute("Arene") ~= nil and joueur:GetAttribute("Arene") == autre:GetAttribute("Arene")
end

-- un modèle qui doit porter une barre rouge pour ce joueur
local function estEnnemi(m: Model): boolean
	local autre = Players:GetPlayerFromCharacter(m)
	if autre then return autre ~= joueur and enDuelAvec(autre) end
	if CollectionService:HasTag(m, "Cible") then return true end
	local camp = m:GetAttribute("Camp")
	if type(camp) == "string" then
		local proprietaire = Players:GetPlayerByUserId(tonumber(string.sub(camp, 2)) or 0)
		if string.sub(camp, 1, 1) == "S" then return proprietaire == joueur end   -- sparring : seulement le sien
		return proprietaire ~= nil and proprietaire ~= joueur and enDuelAvec(proprietaire)
	end
	return CollectionService:HasTag(m, "Ennemi")
end

local suivis = {}   -- [modèle] = {h, racine, affiche, barre, niveau}

local function niveauDe(m: Model): number
	local autre = Players:GetPlayerFromCharacter(m)
	if autre then return autre:GetAttribute("NiveauCombat") or 1 end
	return m:GetAttribute("Niveau") or 1
end

local function suivre(h: Humanoid)
	local m = h.Parent
	if not (m and m:IsA("Model")) or suivis[m] or m == joueur.Character then return end
	local racine = m:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- l'ancienne barre que le serveur pose sur les mannequins (Combat.luau, « BarreDeVie ») est masquée ici
	local function masquer(d: Instance)
		if d:IsA("BillboardGui") and d.Name == "BarreDeVie" then
			d.Enabled = false
			d:GetPropertyChangedSignal("Enabled"):Connect(function() d.Enabled = false end)
		end
	end
	for _, d in m:GetDescendants() do masquer(d) end
	m.DescendantAdded:Connect(masquer)
	local hauteur = m:GetExtentsSize().Y
	local affiche = Instance.new("BillboardGui")
	affiche.Name = "HudVie"
	affiche.Adornee, affiche.Size = racine, UDim2.fromOffset(150, 16)
	affiche.StudsOffsetWorldSpace = Vector3.new(0, math.clamp(hauteur * 0.5 + 0.9, 2.6, 9), 0)
	affiche.AlwaysOnTop, affiche.MaxDistance, affiche.Enabled = true, DISTANCE_BARRES, false
	affiche.Parent = joueur.PlayerGui   -- un BillboardGui ne s'affiche pas rangé dans un ScreenGui
	local barre = nouvelleBarre(affiche, 96, 6, ROUGE)
	barre.cadre.AnchorPoint, barre.cadre.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 18, 0.5, 0)
	local niveau = etiquette(affiche, "", 12)
	niveau.TextColor3 = GRIS_CLAIR
	niveau.AnchorPoint, niveau.Position = Vector2.new(1, 0.5), UDim2.new(0.5, -38, 0.5, 0)
	local s = {h = h, affiche = affiche, barre = barre, niveau = niveau}
	suivis[m] = s
	local function maj() barre.regler(h.Health / math.max(1, h.MaxHealth)) end
	h.HealthChanged:Connect(maj)
	h:GetPropertyChangedSignal("MaxHealth"):Connect(maj)
	maj()
	m.Destroying:Once(function()
		affiche:Destroy()
		suivis[m] = nil
	end)
end

local function essayer(h: Humanoid)
	task.defer(function()
		if h.Parent then suivre(h) end
	end)
end
for _, d in workspace:GetDescendants() do
	if d:IsA("Humanoid") then essayer(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then
		essayer(d)
	elseif d.Name == "HumanoidRootPart" and d.Parent then
		local h = d.Parent:FindFirstChildOfClass("Humanoid")
		if h then essayer(h) end
	end
end)

-- qui est ennemi change (duel qui commence, invocations qui arrivent) : on réévalue régulièrement
local cumul = 0
RunService.Heartbeat:Connect(function(dt)
	cumul += dt
	if cumul < 0.25 then return end
	cumul = 0
	local camera = workspace.CurrentCamera
	if camera then echelle.Scale = math.clamp(camera.ViewportSize.Y / 1080, 0.7, 1.4) end
	for m, s in suivis do
		local montrer = m.Parent ~= nil and s.h.Health > 0 and estEnnemi(m)
		s.affiche.Enabled = montrer
		if montrer then s.niveau.Text = `Lv. {niveauDe(m)}` end
	end
end)

-- ---------------------------------------------------------------- escouade, colonne de droite (étape 2)
-- Une ligne par membre, de droite à gauche : portrait rond, nom aligné à droite, fine barre verte dessous.
-- Le héros est en tête avec le petit ◀ du personnage actif et sans barre (sa vie est en bas de l'écran).
-- Sous la liste, les ordres de l'escouade (X, C, V) avec la case à touche ; l'ordre en cours est en blanc.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigInvocations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Invocations"))

local colonne = cadre(ecran, UDim2.fromOffset(300, 0), UDim2.new(1, -28, 0.4, 0), FOND, 1)
colonne.AnchorPoint, colonne.AutomaticSize = Vector2.new(1, 0.5), Enum.AutomaticSize.Y
local disposition = Instance.new("UIListLayout")
disposition.SortOrder, disposition.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 8)
disposition.HorizontalAlignment = Enum.HorizontalAlignment.Right
disposition.Parent = colonne

-- portrait rond : vue 3D figée d'une copie du modèle, cadrée sur la tête
local function portrait(parent, modele: Model?)
	local rond = Instance.new("CanvasGroup")
	rond.Size, rond.AnchorPoint, rond.Position = UDim2.fromOffset(56, 56), Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0)
	rond.BackgroundColor3, rond.BackgroundTransparency = Color3.fromRGB(70, 74, 86), 0.45
	Instance.new("UICorner", rond).CornerRadius = UDim.new(1, 0)
	rond.Parent = parent
	if not modele then
		-- héros : portrait de l'avatar du joueur
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency, image.Size = 1, UDim2.fromScale(1, 1)
		image.Parent = rond
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(joueur.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok then image.Image = url end
		end)
		return rond
	end
	local vue = Instance.new("ViewportFrame")
	vue.BackgroundTransparency, vue.Size = 1, UDim2.fromScale(1, 1)
	vue.Ambient, vue.LightColor, vue.LightDirection = Color3.fromRGB(170, 170, 175), Color3.new(1, 1, 1), Vector3.new(-0.4, -0.6, -1)
	vue.Parent = rond
	local archivable = modele.Archivable
	modele.Archivable = true
	local copie = modele:Clone()
	modele.Archivable = archivable
	if not copie then return rond end
	for _, d in copie:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	copie.Parent = vue
	local tete = copie:FindFirstChild("Head") or copie:FindFirstChild("HumanoidRootPart")
	if tete then
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		local c = tete.CFrame
		local recul = math.max(tete.Size.Magnitude, 1) * 2.4
		camera.CFrame = CFrame.lookAt(c.Position + c.LookVector * recul + Vector3.new(0, tete.Size.Y * 0.15, 0), c.Position)
		camera.Parent = vue
		vue.CurrentCamera = camera
	end
	return rond
end

-- nom d'un membre : sans contour, avec une ombre portée douce décalée d'un pixel
local function nomOmbre(parent, contenu: string, taille: number)
	-- l'ombre est une sœur placée dessous (un enfant passerait devant), qui suit le texte et sa position
	local ombre = etiquette(parent, contenu, taille)
	ombre:FindFirstChildOfClass("UIStroke").Enabled = false
	ombre.TextColor3, ombre.TextTransparency, ombre.ZIndex = Color3.new(0, 0, 0), 0.55, 1
	local t = etiquette(parent, contenu, taille)
	t:FindFirstChildOfClass("UIStroke").Enabled = false
	t.ZIndex = 2
	local function suivreTexte()
		ombre.Text, ombre.AnchorPoint = t.Text, t.AnchorPoint
		ombre.Position = t.Position + UDim2.fromOffset(1, 1)
	end
	for _, p in {"Text", "Position", "AnchorPoint"} do t:GetPropertyChangedSignal(p):Connect(suivreTexte) end
	return t
end

local function ligne(nom: string, ordre: number, modele: Model?)
	local l = cadre(colonne, UDim2.fromOffset(300, 60), UDim2.new(), FOND, 1)
	l.LayoutOrder = ordre
	local rond = portrait(l, modele)
	local etiquetteNom = nomOmbre(l, nom, 17)
	etiquetteNom.AnchorPoint = Vector2.new(1, 0.5)
	return l, rond, etiquetteNom
end

-- le héros, actif : bande claire qui s'estompe vers la gauche, ◀ après le nom
local ligneHeros, _, nomHeros = ligne(joueur.DisplayName, 0, nil)
nomHeros.Position = UDim2.new(1, -86, 0.5, 0)
local actif = nomOmbre(ligneHeros, "◀", 11)
actif.AnchorPoint, actif.Position = Vector2.new(1, 0.5), UDim2.new(1, -68, 0.5, 0)
local bande = cadre(ligneHeros, UDim2.new(1, 20, 0, 34), UDim2.new(1, 0, 0.5, 0), BLANC, 0)
bande.AnchorPoint, bande.ZIndex = Vector2.new(1, 0.5), 0
local fondu = Instance.new("UIGradient")
fondu.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.85),
	NumberSequenceKeypoint.new(1, 0.7)})
fondu.Parent = bande

local membres = {}   -- [modèle] = ligne

local function ajouterMembre(m: Model)
	if membres[m] or m:GetAttribute("Camp") ~= "J" .. joueur.UserId then return end
	local h = m:WaitForChild("Humanoid", 5)
	if not (h and m:WaitForChild("HumanoidRootPart", 5)) or membres[m] or not m.Parent then return end
	task.wait(0.3)   -- laisse arriver les pièces du modèle avant d'en faire le portrait
	if not m.Parent then return end
	local nom = ConfigInvocations.NOMS[m.Name] or h.DisplayName
	local l, rond, etiquetteNom = ligne(nom, 1, m)
	etiquetteNom.Position = UDim2.new(1, -68, 0.5, -7)
	-- halo sombre très léger autour de la barre, posé dessous
	local halo = cadre(l, UDim2.fromOffset(76, 9), UDim2.new(1, -65, 0.5, 11), Color3.new(0, 0, 0), 0.82)
	halo.AnchorPoint, halo.ZIndex = Vector2.new(1, 0.5), 0
	Instance.new("UICorner", halo).CornerRadius = UDim.new(0, 4)
	local barre = cadre(l, UDim2.fromOffset(70, 4), UDim2.new(1, -68, 0.5, 11), FOND, 0.3)
	barre.AnchorPoint = Vector2.new(1, 0.5)
	Instance.new("UICorner", barre).CornerRadius = UDim.new(1, 0)   -- bouts arrondis
	local vie = cadre(barre, UDim2.fromScale(1, 1), UDim2.new(), VERT)
	Instance.new("UICorner", vie).CornerRadius = UDim.new(1, 0)
	membres[m] = l
	local function maj()
		local f = math.clamp(h.Health / math.max(1, h.MaxHealth), 0, 1)
		vie.Size = UDim2.fromScale(f, 1)
		-- à terre : ligne grisée jusqu'à la disparition du modèle
		local mort = h.Health <= 0
		rond.GroupTransparency = if mort then 0.6 else 0
		etiquetteNom.TextColor3 = if mort then Color3.fromRGB(140, 140, 140) else BLANC
	end
	h.HealthChanged:Connect(maj)
	maj()
	m.AncestryChanged:Connect(function()
		if not m:IsDescendantOf(workspace) and membres[m] then
			membres[m]:Destroy()
			membres[m] = nil
		end
	end)
end

task.spawn(function()
	local dossier = workspace:WaitForChild("Invocations")
	for _, m in dossier:GetChildren() do task.spawn(ajouterMembre, m) end
	dossier.ChildAdded:Connect(function(m) task.spawn(ajouterMembre, m) end)
end)

-- ordres : case à touche claire + nom de l'ordre ; visibles seulement quand l'escouade est là
local ordres = cadre(colonne, UDim2.fromOffset(300, 0), UDim2.new(), FOND, 1)
ordres.LayoutOrder, ordres.AutomaticSize = 2, Enum.AutomaticSize.Y
local listeOrdres = Instance.new("UIListLayout")
listeOrdres.Padding, listeOrdres.HorizontalAlignment = UDim.new(0, 4), Enum.HorizontalAlignment.Right
listeOrdres.SortOrder = Enum.SortOrder.LayoutOrder
listeOrdres.Parent = ordres
local Reseau = ReplicatedStorage:WaitForChild("Reseau")
local lignesOrdre = {}
for i, o in ConfigInvocations.ORDRES do
	local b = Instance.new("TextButton")
	b.Text, b.AutoButtonColor, b.BackgroundTransparency = "", false, 1
	b.Size, b.LayoutOrder = UDim2.fromOffset(160, 24), i
	b.Parent = ordres
	local touche = cadre(b, UDim2.fromOffset(22, 22), UDim2.new(1, -17, 0.5, 0), Color3.fromRGB(226, 226, 220), 0.1)
	touche.AnchorPoint = Vector2.new(0.5, 0.5)
	Instance.new("UICorner", touche).CornerRadius = UDim.new(0, 3)
	local lettre = etiquette(touche, texteTouche(o.touche), 13, Hud.POLICE_TOUCHE)
	lettre.AnchorPoint, lettre.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	lettre.TextColor3 = Color3.fromRGB(60, 60, 64)
	lettre:FindFirstChildOfClass("UIStroke").Enabled = false
	local texte = etiquette(b, o.nom, 15)
	texte.AnchorPoint, texte.Position = Vector2.new(1, 0.5), UDim2.new(1, -36, 0.5, 0)
	b.Activated:Connect(function()
		local distant = Reseau:FindFirstChild("OrdreEscouade")
		if distant then distant:FireServer(o.id) end
	end)
	lignesOrdre[o.id] = {texte = texte, touche = touche}
end
local function majOrdres()
	local actuel = joueur:GetAttribute("OrdreEscouade") or "Suivre"
	for id, l in lignesOrdre do
		l.texte.TextColor3 = if id == actuel then BLANC else Color3.fromRGB(150, 150, 150)
		l.texte.TextTransparency = if id == actuel then 0 else 0.25
		l.touche.BackgroundTransparency = if id == actuel then 0.05 else 0.5
	end
end
joueur:GetAttributeChangedSignal("OrdreEscouade"):Connect(majOrdres)
majOrdres()
RunService.Heartbeat:Connect(function()
	ordres.Visible = next(membres) ~= nil
end)

-- ---------------------------------------------------------------- effets lumineux animés (boutons, icônes)
-- Un support placé sous l'élément porte un halo qui respire (facultatif) et des particules qui tournent autour,
-- s'écartent en montant un peu, apparaissent puis s'éteignent, sans fin. Le style règle leur nombre et leur allure.
local LUEUR, ETINCELLE = "rbxassetid://91456071127279", "rbxassetid://83051981965404"
local hasardEffets = Random.new()
local STYLE_TECHNIQUE = {image = ETINCELLE, nb = 10, taille = {5, 10}, duree = {1.4, 2.4}, vitesse = {0.35, 0.8},
	opacite = 0.9, ecart = 0.4, montee = 10, halo = true, eclaircir = 0.55}

local function effetLumineux(taille: number, position: UDim2, ancre: Vector2, couleur: Color3, style)
	local support = cadre(ecran, UDim2.fromOffset(taille, taille), position, FOND, 1)
	support.AnchorPoint = ancre
	local halo
	if style.halo then
		halo = Instance.new("ImageLabel")
		halo.BackgroundTransparency, halo.Image, halo.ImageColor3 = 1, LUEUR, couleur
		halo.AnchorPoint, halo.Position, halo.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.9, 1.9)
		halo.ImageTransparency = 0.2
		halo.Parent = support
		local respiration = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(halo, respiration, {ImageTransparency = 0.5, Size = UDim2.fromScale(2.08, 2.08)}):Play()
	end
	local particules = {}
	for i = 1, style.nb do
		local e = Instance.new("ImageLabel")
		e.BackgroundTransparency, e.Image = 1, style.image
		e.ImageColor3 = couleur:Lerp(Color3.new(1, 1, 1), style.eclaircir)
		e.AnchorPoint, e.ImageTransparency = Vector2.new(0.5, 0.5), 1
		e.Parent = support
		table.insert(particules, {image = e, phase = i / style.nb, angle = hasardEffets:NextNumber(0, 2 * math.pi),
			vitesse = hasardEffets:NextNumber(style.vitesse[1], style.vitesse[2]),
			duree = hasardEffets:NextNumber(style.duree[1], style.duree[2]),
			taille = hasardEffets:NextNumber(style.taille[1], style.taille[2])})
	end
	return {support = support, halo = halo, particules = particules, rayon = taille / 2, style = style}
end

local function animerEffet(effet, actif: boolean, dt: number)
	local style = effet.style
	if effet.halo then effet.halo.Visible = actif end
	for _, e in effet.particules do
		e.image.Visible = actif
		if actif then
			e.phase += dt / e.duree
			if e.phase >= 1 then
				e.phase -= 1
				e.angle = hasardEffets:NextNumber(0, 2 * math.pi)
			end
			e.angle += e.vitesse * dt
			local r = effet.rayon * (0.95 + style.ecart * e.phase)
			e.image.Position = UDim2.new(0.5, math.cos(e.angle) * r, 0.5, math.sin(e.angle) * r - style.montee * e.phase)
			local t = e.taille * (1 - 0.4 * e.phase)
			e.image.Size = UDim2.fromOffset(t, t)
			e.image.ImageTransparency = 1 - math.sin(math.pi * e.phase) * style.opacite
		end
	end
end

-- ---------------------------------------------------------------- icônes en haut à droite (étape 3)
-- Cinq emplacements de gauche à droite, le dernier collé au bord comme la référence ; images générées avec Meshy (fond vert),
-- détourées par ui/hud_v01/detourer.py.
-- Emplacements : 1 carte, 2 événement, 3 offres du jour, 4 quêtes quotidiennes, 5 inventaire.
local ICONES = {
	{id = "Carte", emplacement = 1, image = "rbxassetid://96444988812766"},
	{id = "Evenement", emplacement = 2, image = "rbxassetid://109209037564164"},
	{id = "Offres", emplacement = 3, image = "rbxassetid://120810365077873"},
	{id = "Quetes", emplacement = 4, image = "rbxassetid://122967294472296"},
	{id = "Inventaire", emplacement = 5, image = "rbxassetid://97951001415611"},
}
local TAILLE_ICONE, PAS_ICONES = 50, 72
for _, icone in ICONES do
	local position = UDim2.new(1, -40 - (#ICONES - icone.emplacement) * PAS_ICONES, 0, 18)
	local b = Instance.new("ImageButton")
	b.Name, b.Image, b.BackgroundTransparency = icone.id, icone.image, 1
	b.Size, b.AnchorPoint = UDim2.fromOffset(TAILLE_ICONE, TAILLE_ICONE), Vector2.new(1, 0)
	b.Position = position
	b.Parent = ecran
	local grossir = Instance.new("UIScale")
	grossir.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(grossir, TweenInfo.new(0.12), {Scale = 1.1}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(grossir, TweenInfo.new(0.12), {Scale = 1}):Play()
	end)
end

-- ---------------------------------------------------------------- techniques, en bas à droite (étape 4)
-- Bouton moyen puis grand bouton à droite, comme la référence ; la touche dans une petite case dessous.
-- En recharge : icône assombrie et secondes restantes au centre ; prête : petit sursaut.
-- La recharge vient du serveur (attribut Recharge_<id> = heure serveur où la technique redevient prête).
local UserInputService = game:GetService("UserInputService")
local ConfigCombat = require(ReplicatedStorage.Shared.Config.Combat)
-- le HUD ne dépend pas de l'état du travail sur le combat : valeurs par défaut si la config ne les a pas encore
local ORDRE_TECHNIQUES = ConfigCombat.ORDRE_TECHNIQUES or {}
local TECHNIQUES = ConfigCombat.TECHNIQUES or {}
local TECHNIQUES_HUD = {
	SkyCleave = {taille = 70, position = UDim2.new(1, -150, 1, -50), image = "rbxassetid://133109436582674",
		couleur = Color3.fromRGB(90, 190, 255)},
	BladeStorm = {taille = 94, position = UDim2.new(1, -36, 1, -44), image = "rbxassetid://72812852817947",
		couleur = Color3.fromRGB(190, 130, 255)},
}
local boutonsTechnique = {}
for _, id in ORDRE_TECHNIQUES do
	local format, technique = TECHNIQUES_HUD[id], TECHNIQUES[id]
	if not (format and technique) then continue end
	local effet = effetLumineux(format.taille, format.position, Vector2.new(1, 1), format.couleur, STYLE_TECHNIQUE)
	local b = Instance.new("ImageButton")
	b.Name, b.AutoButtonColor, b.ZIndex = id, false, 2   -- devant le halo et les étincelles
	b.Size, b.AnchorPoint, b.Position = UDim2.fromOffset(format.taille, format.taille), Vector2.new(1, 1), format.position
	b.BackgroundColor3, b.BackgroundTransparency = Color3.fromRGB(32, 36, 44), if format.image then 1 else 0.3
	b.Image = format.image or ""
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	b.Parent = ecran
	if not format.image then
		-- en attendant l'icône : anneau clair et nom de la technique
		local anneau = Instance.new("UIStroke")
		anneau.Color, anneau.Thickness, anneau.Transparency = Color3.fromRGB(200, 204, 212), 2, 0.2
		anneau.Parent = b
		local nomTechnique = etiquette(b, technique.nom, 13)
		nomTechnique.AutomaticSize, nomTechnique.Size = Enum.AutomaticSize.None, UDim2.fromScale(0.8, 0.5)
		nomTechnique.TextWrapped, nomTechnique.AnchorPoint = true, Vector2.new(0.5, 0.5)
		nomTechnique.Position = UDim2.fromScale(0.5, 0.5)
	end
	-- voile de recharge et secondes restantes
	local voile = cadre(b, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(0, 0, 0), 0.45)
	voile.ZIndex = 2
	Instance.new("UICorner", voile).CornerRadius = UDim.new(1, 0)
	local secondes = etiquette(b, "", if format.taille > 80 then 26 else 21, Hud.POLICE_CHIFFRES)
	secondes.AnchorPoint, secondes.Position, secondes.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 3
	-- touche dans une petite case claire, sous le bouton
	local case = cadre(b, UDim2.fromOffset(18, 18), UDim2.new(0.5, 0, 1, 6), Color3.fromRGB(236, 236, 230), 0.05)
	case.AnchorPoint = Vector2.new(0.5, 0)
	Instance.new("UICorner", case).CornerRadius = UDim.new(0, 3)
	local lettre = etiquette(case, texteTouche(technique.touche), 13, Hud.POLICE_TOUCHE)
	lettre.AnchorPoint, lettre.Position, lettre.TextColor3 = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(50, 50, 56)
	lettre:FindFirstChildOfClass("UIStroke").Enabled = false
	local sursaut = Instance.new("UIScale")
	sursaut.Parent = b
	b.Activated:Connect(function()
		if Hud.onTechnique then Hud.onTechnique(id) end
	end)
	boutonsTechnique[id] = {bouton = b, voile = voile, secondes = secondes, sursaut = sursaut, pret = true, effet = effet}
end

RunService.RenderStepped:Connect(function(dt)
	local maintenant = workspace:GetServerTimeNow()
	for id, t in boutonsTechnique do
		local restant = math.max(0, (joueur:GetAttribute("Recharge_" .. id) or 0) - maintenant)
		local pret = restant <= 0
		animerEffet(t.effet, pret, dt)
		t.voile.Visible = not pret
		t.bouton.ImageColor3 = if pret then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		t.secondes.Text = if pret then "" else string.format("%.1f", restant)
		if pret and not t.pret then
			t.sursaut.Scale = 1.18
			TweenService:Create(t.sursaut, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
		t.pret = pret
	end
end)

-- ---------------------------------------------------------------- mini-carte, en haut à gauche (étape 5)
-- Image du lobby vue du dessus (ui/hud_v01/carte.py, d'après le relevé carte_lobby.txt), nord en haut (-Z),
-- couvrant x et z de -210 à 210. Le cercle (un seul CanvasGroup) reste centré sur le héros : la carte glisse
-- dessous ; la flèche tourne avec le personnage, le cône clair avec la caméra. Anneau blanc fin et « N » sur le bord.
local CARTE = {
	image = "rbxassetid://73535242224879", fleche = "rbxassetid://106719850484589", cone = "rbxassetid://72673449868031",
	origine = Vector2.new(-210, -210), cote = 420,   -- studs couverts par l'image
	diametre = 190, champ = 110,                     -- px du cercle à l'écran, studs visibles d'un bord à l'autre
	position = UDim2.fromOffset(62, 70),             -- sous la barre de Roblox (menu, chat, micro)
}
local pxParStud = CARTE.diametre / CARTE.champ
local rondCarte = Instance.new("CanvasGroup")
rondCarte.Name, rondCarte.Size = "MiniCarte", UDim2.fromOffset(CARTE.diametre, CARTE.diametre)
rondCarte.Position = CARTE.position
rondCarte.BackgroundColor3 = Color3.fromRGB(166, 189, 108)   -- herbe : ce qui sort de l'image (l'arène, au sud)
Instance.new("UICorner", rondCarte).CornerRadius = UDim.new(1, 0)
rondCarte.Parent = ecran
local fond = Instance.new("ImageLabel")
fond.BackgroundTransparency, fond.Image = 1, CARTE.image
fond.Size = UDim2.fromOffset(CARTE.cote * pxParStud, CARTE.cote * pxParStud)
fond.Parent = rondCarte
-- cône de vue : la moitié haute d'un carré centré, qui tourne autour du centre du cercle
local pivotCone = cadre(rondCarte, UDim2.fromOffset(120, 120), UDim2.fromScale(0.5, 0.5), FOND, 1)
pivotCone.AnchorPoint, pivotCone.ZIndex = Vector2.new(0.5, 0.5), 2
local cone = Instance.new("ImageLabel")
cone.BackgroundTransparency, cone.Image, cone.Size = 1, CARTE.cone, UDim2.fromScale(1, 0.5)
cone.ZIndex = 2
cone.Parent = pivotCone
local fleche = Instance.new("ImageLabel")
fleche.BackgroundTransparency, fleche.Image = 1, CARTE.fleche
fleche.Size, fleche.AnchorPoint, fleche.Position = UDim2.fromOffset(26, 26), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
fleche.ZIndex = 3
fleche.Parent = rondCarte
-- anneau fin et « N » posés par-dessus (hors du CanvasGroup pour ne pas être rognés)
local anneau = cadre(ecran, rondCarte.Size, rondCarte.Position, FOND, 1)
Instance.new("UICorner", anneau).CornerRadius = UDim.new(1, 0)
local trait = Instance.new("UIStroke")
trait.Color, trait.Thickness, trait.Transparency = BLANC, 2, 0.35
trait.Parent = anneau
local nord = nomOmbre(anneau, "N", 13)
nord.AnchorPoint, nord.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 2)

local function cap(v: Vector3): number
	-- angle à l'écran : 0 vers le nord (-Z), positif vers l'est (+X), comme la rotation des GuiObject
	return math.deg(math.atan2(v.X, -v.Z))
end
RunService.RenderStepped:Connect(function()
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (racine and camera) then return end
	local p = racine.Position
	local u, v = (p.X - CARTE.origine.X) * pxParStud, (p.Z - CARTE.origine.Y) * pxParStud
	fond.Position = UDim2.fromOffset(CARTE.diametre / 2 - u, CARTE.diametre / 2 - v)
	fleche.Rotation = cap(racine.CFrame.LookVector)
	pivotCone.Rotation = cap(camera.CFrame.LookVector)
end)

-- ---------------------------------------------------------------- compteur de coups (étape 6)
-- En haut au centre : grand nombre (seuls les chiffres sont de biais, angle différent à chaque coup) de coups portés par le héros, « HITS », palier (GREAT, AMAZING,
-- EXCELLENT) dessous et une fine barre qui se vide jusqu'à la fin du combo (Config.COMBO_HUD.expiration).
-- Chaque coup : coup de zoom et tremblement (plus forts sur un critique). La couleur change par paliers.
-- Une technique lancée écrase son nom en grand au milieu de l'écran, dans sa couleur.
local COMBO = ConfigCombat.COMBO_HUD or {expiration = 3.5, great = 25, amazing = 50, excellent = 100}
local ITALIQUE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
-- compteur : graisse « Heavy » de Merriweather (la plus épaisse de Roblox), lettres plus larges et plus pleines
local LARGE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local LARGE_DROITE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
local PALIERS = {   -- nombre de coups minimal, couleur
	{0, Color3.fromRGB(255, 236, 170)},    -- doré pâle dès le premier coup
	{10, Color3.fromRGB(255, 205, 90)},
	{25, Color3.fromRGB(255, 150, 60)},
	{50, Color3.fromRGB(255, 70, 80)},
	{100, Color3.fromRGB(200, 120, 255)},
}
local function couleurPalier(n: number): Color3
	local c = PALIERS[1][2]
	for _, p in PALIERS do
		if n >= p[1] then c = p[2] end
	end
	return c
end

local POSITION_COMBO = UDim2.new(0.5, 0, 0, 128)
local combo = cadre(ecran, UDim2.fromOffset(380, 130), POSITION_COMBO, FOND, 1)
combo.AnchorPoint, combo.Visible = Vector2.new(0.5, 0), false
local sautCombo = Instance.new("UIScale")
sautCombo.Parent = combo
-- ligne « 12 HITS » centrée : seuls les chiffres sont de biais, leur angle change à chaque coup
local ligne = cadre(combo, UDim2.fromOffset(0, 80), UDim2.new(0.5, 0, 0, 0), FOND, 1)
ligne.AnchorPoint, ligne.AutomaticSize = Vector2.new(0.5, 0), Enum.AutomaticSize.X
local rangee = Instance.new("UIListLayout")
rangee.FillDirection, rangee.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Bottom
rangee.Padding, rangee.SortOrder = UDim.new(0, 8), Enum.SortOrder.LayoutOrder
rangee.Parent = ligne
local nombreCoups = etiquette(ligne, "0", 78, LARGE)
nombreCoups.LayoutOrder = 1
nombreCoups:FindFirstChildOfClass("UIStroke").Thickness, nombreCoups:FindFirstChildOfClass("UIStroke").Transparency = 1, 0.35
local motHits = etiquette(ligne, "HITS", 30, LARGE_DROITE)
motHits:FindFirstChildOfClass("UIStroke").Transparency = 0.35
motHits.LayoutOrder = 2
-- minuterie collée sous la ligne, de sa largeur (suit le nombre qui grandit)
local fondMinuterie = cadre(combo, UDim2.fromOffset(80, 4), UDim2.new(0.5, 0, 0, 80), FOND, 0.3)
fondMinuterie.AnchorPoint = Vector2.new(0.5, 0)
Instance.new("UICorner", fondMinuterie).CornerRadius = UDim.new(1, 0)
local minuterie = cadre(fondMinuterie, UDim2.fromScale(1, 1), UDim2.new(), BLANC)
Instance.new("UICorner", minuterie).CornerRadius = UDim.new(1, 0)
local palier = etiquette(combo, "", 24, LARGE)
palier.AnchorPoint, palier.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 88)
palier:FindFirstChildOfClass("UIStroke").Transparency = 0.35
local coups, dernierCoup = 0, 0
local tremblement, forceTremblement, dureeTremblement = 0, 0, 0.25
local hasardCombo = Random.new()

local function trembler(force: number, duree: number)
	tremblement, forceTremblement, dureeTremblement = duree, force, duree
end

function Hud.coup(critique: boolean?)
	local t = os.clock()
	if t - dernierCoup >= COMBO.expiration then coups = 0 end
	coups += 1
	dernierCoup = t
	local couleur = couleurPalier(coups)
	nombreCoups.Text = tostring(coups)
	nombreCoups.TextColor3, motHits.TextColor3, minuterie.BackgroundColor3 = couleur, couleur:Lerp(GRIS_CLAIR, 0.4), couleur
	-- nouvel angle à chaque coup, toujours penché vers la droite
	nombreCoups.Rotation = hasardCombo:NextNumber(-16, -4)
	palier.Text = if coups >= COMBO.excellent then "EXCELLENT!" elseif coups >= COMBO.amazing then "AMAZING!"
		elseif coups >= COMBO.great then "GREAT!" else ""
	palier.TextColor3 = couleur
	combo.Visible = true
	sautCombo.Scale = if critique then 1.8 else 1.5
	TweenService:Create(sautCombo, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	trembler(if critique then 30 else 20, if critique then 0.42 else 0.32)
end

-- nom de la technique posé sur le compteur (chevauche le haut des chiffres), dans sa police (Merriweather Heavy italique), couleur unie,
-- contour à peine visible. Une étiquette par lettre, espacement normal (écart nul).
local function annoncerTechnique(nom: string, couleur: Color3)
	-- posé sur le haut des chiffres du compteur, devant lui, penché comme eux
	local bloc = cadre(ecran, UDim2.fromOffset(0, 50), UDim2.new(0.5, 0, 0, 136), FOND, 1)
	bloc.AnchorPoint, bloc.AutomaticSize = Vector2.new(0.5, 0.5), Enum.AutomaticSize.X
	bloc.Rotation, bloc.ZIndex = -9, 5
	local serre = Instance.new("UIListLayout")
	serre.FillDirection, serre.Padding, serre.SortOrder = Enum.FillDirection.Horizontal, UDim.new(0, 0), Enum.SortOrder.LayoutOrder
	serre.VerticalAlignment = Enum.VerticalAlignment.Center
	serre.Parent = bloc
	local lettres = {}
	for i, c in utf8.codes(string.upper(nom)) do
		local l = etiquette(bloc, utf8.char(c), 42, LARGE)
		l.LayoutOrder, l.TextColor3 = i, couleur
		local trait = l:FindFirstChildOfClass("UIStroke")
		trait.Thickness, trait.Transparency = 1, 0.6
		if utf8.char(c) == " " then l.Size = UDim2.fromOffset(12, 46) l.AutomaticSize = Enum.AutomaticSize.None end
		table.insert(lettres, l)
	end
	local taille = Instance.new("UIScale")
	taille.Scale = 2.2
	taille.Parent = bloc
	TweenService:Create(taille, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
	task.delay(0.75, function()
		local fondu = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(bloc, fondu, {Position = UDim2.new(0.5, 0, 0, 124)}):Play()
		for _, l in lettres do
			TweenService:Create(l, fondu, {TextTransparency = 1}):Play()
			TweenService:Create(l:FindFirstChildOfClass("UIStroke"), fondu, {Transparency = 1}):Play()
		end
		Debris:AddItem(bloc, 0.4)
	end)
	trembler(32, 0.45)
end
-- une technique est lancée quand le serveur repousse sa recharge (attribut Recharge_<id>)
for id, format in TECHNIQUES_HUD do
	local technique = TECHNIQUES[id]
	if technique then
		joueur:GetAttributeChangedSignal("Recharge_" .. id):Connect(function()
			if (joueur:GetAttribute("Recharge_" .. id) or 0) > workspace:GetServerTimeNow() + 0.5 then
				annoncerTechnique(technique.nom, format.couleur)
			end
		end)
	end
end

RunService.RenderStepped:Connect(function(dt)
	-- tremblement qui s'amortit
	if tremblement > 0 then
		tremblement = math.max(0, tremblement - dt)
		local a = forceTremblement * (tremblement / dureeTremblement) ^ 1.5
		combo.Position = POSITION_COMBO + UDim2.fromOffset(hasardCombo:NextNumber(-a, a), hasardCombo:NextNumber(-a, a))
		combo.Rotation = hasardCombo:NextNumber(-a, a) * 0.4
	else
		combo.Position, combo.Rotation = POSITION_COMBO, 0
	end
	if not combo.Visible then return end
	-- la minuterie prend la largeur de « 12 HITS » et se colle juste dessous
	fondMinuterie.Size = UDim2.fromOffset(ligne.AbsoluteSize.X / (echelle.Scale * sautCombo.Scale), 4)
	local reste = 1 - (os.clock() - dernierCoup) / COMBO.expiration
	if reste <= 0 then
		combo.Visible, coups = false, 0
	else
		minuterie.Size = UDim2.fromScale(reste, 1)
	end
end)
joueur.CharacterAdded:Connect(function()
	combo.Visible, coups = false, 0
end)

-- ---------------------------------------------------------------- noms des bâtiments vus de loin (étape 7)
-- Le nom anglais de chaque lot flotte au-dessus de lui (Config.Batiments), à taille fixe à l'écran. Il n'apparaît
-- qu'à distance (fondu entre 45 et 60 studs) : sur le lot, il ne sert plus ; il rapetisse jusqu'à 220 studs, puis disparaît. Position : centre du socle du lot
-- (workspace.Batiments.Sol.Socle_<Lot>), hauteur : haut du bâtiment affiché (Workspace.Batiments.<Lot>) ; avant
-- que le socle ne soit chargé (streaming), la position de la config sert.
local ConfigBatiments = require(ReplicatedStorage.Shared.Config.Batiments)
local PROCHE, NET, LOIN = 45, 60, 220
local PETIT = 0.65   -- taille à LOIN (100 % à NET) : de loin, les noms se chevauchent moins
local SOCLES = {Academie_Magie = "Socle_Salle_Magie"}   -- socles nommés autrement que leur lot
local noms = {}
local lots = {}
for id, lot in ConfigBatiments.LOTS do lots[id] = lot.nom end
if ConfigBatiments.AUTOMATIQUES and ConfigBatiments.AUTOMATIQUES.Faille then lots.Faille = ConfigBatiments.AUTOMATIQUES.Faille.nom end

for id, nom in lots do
	local point = Instance.new("Attachment")
	point.Name = "NomBatiment_" .. id
	local p = ConfigBatiments.LOTS[id] and ConfigBatiments.LOTS[id].position
	point.Position = if p then Vector3.new(p[1], 14, p[2]) else Vector3.new(118, 14, 50.5)
	point.Parent = workspace.Terrain
	local affiche = Instance.new("BillboardGui")
	affiche.Name, affiche.Adornee = "Nom_" .. id, point
	affiche.Size, affiche.AlwaysOnTop, affiche.MaxDistance = UDim2.fromOffset(260, 30), true, LOIN
	affiche.LightInfluence = 0
	affiche.Parent = joueur.PlayerGui
	local texte = etiquette(affiche, nom, 17, Hud.POLICE)
	texte.AnchorPoint, texte.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local taille = Instance.new("UIScale")
	taille.Parent = texte
	noms[id] = {point = point, texte = texte, trait = texte:FindFirstChildOfClass("UIStroke"), taille = taille}
end

-- centre du socle et haut du bâtiment, relus de temps en temps (streaming, bâtiments posés ou remplacés)
local function placerNoms()
	local sol = workspace:FindFirstChild("Batiments") and workspace.Batiments:FindFirstChild("Sol")
	for id, n in noms do
		local socle = sol and sol:FindFirstChild(SOCLES[id] or ("Socle_" .. id))
		local x, z = n.point.Position.X, n.point.Position.Z
		if socle then
			local cf = if socle:IsA("Model") then socle:GetBoundingBox() else socle.CFrame
			x, z = cf.Position.X, cf.Position.Z
		end
		local y = 14
		-- palier affiché par le système de paliers (Workspace.Batiments.<Lot>), sinon un modèle posé à la main
		-- (<Lot>_P<n>, éventuellement suivi d'un suffixe ; Logements ne prend pas Logements_Annexe)
		local bat = workspace:FindFirstChild("Batiments") and workspace.Batiments:FindFirstChild(id)
		if not (bat and bat:IsA("Model")) then
			bat = nil
			for _, c in workspace:GetChildren() do
				if c:IsA("Model") and string.match(c.Name, "^" .. id .. "_P%d+") then bat = c end
			end
		end
		if bat then
			local cf, taille = bat:GetBoundingBox()
			y = cf.Position.Y + taille.Y / 2 + 4
		end
		n.point.Position = Vector3.new(x, y, z)
	end
end
task.spawn(function()
	while true do
		placerNoms()
		task.wait(5)
	end
end)

-- fondu selon la distance à la caméra
local cumulNoms = 0
RunService.RenderStepped:Connect(function(dt)
	cumulNoms += dt
	if cumulNoms < 0.1 then return end
	cumulNoms = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	for _, n in noms do
		local d = (n.point.WorldPosition - camera.CFrame.Position).Magnitude
		local opacite = math.clamp((d - PROCHE) / (NET - PROCHE), 0, 1)
		n.texte.TextTransparency = 1 - opacite
		n.trait.Transparency = 1 - opacite * 0.9
		n.texte.Visible = opacite > 0
		n.taille.Scale = 1 - (1 - PETIT) * math.clamp((d - NET) / (LOIN - NET), 0, 1)
	end
end)

-- ---------------------------------------------------------------- chiffres de dégâts
local hasard = Random.new()

-- couleur selon la source du coup (details.type envoyé par le serveur) ; blanc pour tout le reste
local COULEURS_DEGATS = {
	Orbe = Color3.fromRGB(150, 220, 255),   -- orbe du mage : bleu glacé
}

function Hud.degats(position: Vector3, montant: number, critique: boolean?, details)
	local point = Instance.new("Attachment")
	point.WorldPosition = position + Vector3.new(hasard:NextNumber(-1, 1), 2 + hasard:NextNumber(0, 0.8), hasard:NextNumber(-1, 1))
	point.Parent = workspace.Terrain
	local affiche = Instance.new("BillboardGui")
	affiche.Adornee, affiche.Size, affiche.AlwaysOnTop = point, UDim2.fromOffset(200, 60), true
	affiche.Parent = point
	local chiffre = Instance.new("TextLabel")
	chiffre.BackgroundTransparency, chiffre.Size = 1, UDim2.fromScale(1, 1)
	chiffre.FontFace, chiffre.Text = Hud.POLICE_CHIFFRES, tostring(math.floor(montant + 0.5))
	chiffre.TextSize = if critique then 40 else 30
	chiffre.TextColor3 = if typeof(details) == "Color3" then details
		elseif type(details) == "table" and COULEURS_DEGATS[details.type] then COULEURS_DEGATS[details.type]
		else BLANC
	chiffre.Parent = affiche
	local contour = Instance.new("UIStroke")
	contour.Color, contour.Thickness, contour.Transparency = OMBRE, 1.5, 0.2
	contour.Parent = chiffre
	-- saut à l'apparition, puis montée lente et effacement
	local taille = Instance.new("UIScale")
	taille.Scale = if critique then 1.8 else 1.45
	taille.Parent = chiffre
	TweenService:Create(taille, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(affiche, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)}):Play()
	local fondu = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6)
	TweenService:Create(chiffre, fondu, {TextTransparency = 1}):Play()
	TweenService:Create(contour, fondu, {Transparency = 1}):Play()
	Debris:AddItem(point, 1)
end

return Hud
