-- Boutique en Robux (03/10/2026), dans le style des menus plein écran (StyleMenus, comme l'inventaire) :
-- bannière à gauche avec les rayons (offres, or, matériaux), articles en grandes cartes (carte de rareté, nom,
-- prix en Robux sur une pilule sombre, étiquette « Best value »…), fiche à droite (contenu, description) et bouton
-- « Buy » qui ouvre la fenêtre d'achat de Roblox. Le contenu est donné par le serveur (Services/Boutique).
-- S'ouvre par le coffre doré du HUD. Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Boutique)
local Materiaux = require(Shared.Config.Materiaux)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local LireAchats = reseau:WaitForChild("LireAchats")

local joueur = Players.LocalPlayer
local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, OR_PALE, ARDOISE, BLANC = Style.CREME, Style.OR_PALE, Style.ARDOISE, Style.BLANC
local TEXTE_FONCE, TEXTE_DESC = Style.TEXTE_FONCE, Style.TEXTE_DESC
local IMAGES = Style.IMAGES
local ROBUX = utf8.char(0xE002)   -- symbole Robux des polices de Roblox
local IMAGE_COFFRE = "rbxassetid://76413057251104"

local function milliers(n: number): string
	local s = tostring(math.floor(n))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("Boutique", 20)
local voile = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(24, 32, 48), 0.4)

cree("ImageLabel", {Image = IMAGES.bandeau, BackgroundTransparency = 1, Size = UDim2.new(0, 100, 1, 0),
	Position = UDim2.fromOffset(46, 0)}, racine)
cree("ImageLabel", {Image = IMAGES.fanion, BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 112),
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(96, 0)}, racine)
cree("ImageLabel", {Image = IMAGE_COFFRE, BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 52), ZIndex = 2}, racine)

local onglets = {}
for i, r in Config.RAYONS do
	local y = 192 + (i - 1) * 120
	local pilule = cadre(racine, UDim2.fromOffset(198, 84), UDim2.fromOffset(-50, y), CREME)
	pilule.AnchorPoint = Vector2.new(0, 0.5)
	arrondi(pilule)
	local etoile = cree("ImageLabel", {Image = IMAGES.etoile4, ImageColor3 = CREME, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(164, y)}, racine)
	local rond = cadre(racine, UDim2.fromOffset(78, 78), UDim2.fromOffset(96, y), Color3.fromRGB(46, 54, 74), 0.25)
	rond.AnchorPoint = Vector2.new(0.5, 0.5)
	arrondi(rond)
	filet(rond, Color3.fromRGB(196, 204, 224), 1.5, 0.6)
	local icone = cree("ImageLabel", {Image = r.icone, ImageColor3 = CREME, BackgroundTransparency = 1, ZIndex = 2,
		Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 100), ZIndex = 3,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	onglets[r.id] = {pilule = pilule, etoile = etoile, rond = rond, icone = icone, bouton = bouton}
end

local titre = Style.titre(racine, "Shop")
local montantOr = Style.bourse(racine)
local fermer = Style.boutonFermer(racine)

-- ---------------------------------------------------------------- articles (au milieu)
local grille = cree("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(230, 120),
	Size = UDim2.new(1, -930, 1, -150), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6, ScrollBarImageColor3 = CREME, ScrollBarImageTransparency = 0.5}, racine)
cree("UIPadding", {PaddingLeft = UDim.new(0, 20), PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 24)}, grille)
cree("UIGridLayout", {CellSize = UDim2.fromOffset(250, 380), CellPadding = UDim2.fromOffset(30, 30),
	SortOrder = Enum.SortOrder.LayoutOrder}, grille)

-- ---------------------------------------------------------------- fiche (à droite)
local fiche = cadre(racine, UDim2.fromOffset(615, 780), UDim2.new(1, -60, 0, 150))
fiche.AnchorPoint = Vector2.new(1, 0)
local nomArticle = Style.entete(fiche)
local illustration = cadre(fiche, UDim2.new(1, 0, 0, 284), UDim2.fromOffset(0, 72), BLANC)
cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(80, 88, 114), Color3.fromRGB(62, 68, 90))}, illustration)
cree("ImageLabel", {Image = IMAGES.lueur, ImageColor3 = Color3.fromRGB(255, 214, 120), ImageTransparency = 0.55,
	BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 360), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -165, 0.55, 0)}, illustration)
local prixFiche = texte(illustration, "", 34, BLANC, {FontFace = Style.POLICE_TITRE, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(36, 44), Size = UDim2.fromOffset(300, 44), TextXAlignment = Enum.TextXAlignment.Left})
local grandeImage = cree("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(240, 240),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -165, 0.55, 0)}, illustration)
local corps = cree("ScrollingFrame", {BackgroundColor3 = CREME, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 356),
	Size = UDim2.new(1, 0, 1, -356), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4, ScrollBarImageColor3 = TEXTE_DESC}, fiche)
cree("UIPadding", {PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36), PaddingTop = UDim.new(0, 34),
	PaddingBottom = UDim.new(0, 30)}, corps)
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14)}, corps)
texte(corps, "Contents", 30, TEXTE_FONCE, {FontFace = Style.POLICE_TITRE, Size = UDim2.new(1, 0, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1})
local blocContenu = cadre(corps, UDim2.new(1, 0, 0, 0), UDim2.new())
blocContenu.AutomaticSize, blocContenu.LayoutOrder = Enum.AutomaticSize.Y, 2
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, blocContenu)
Style.separateur(corps, Color3.fromRGB(184, 154, 90)).LayoutOrder = 3
local description = texte(corps, "", 28, TEXTE_DESC, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.08, LayoutOrder = 4})
local message = texte(corps, "", 26, Style.ROUGE, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5})

local acheter = Style.boutonAction(racine, "Buy")
acheter.icone.Image = ""
local robuxBouton = texte(acheter.icone.Parent, ROBUX, 30, Color3.fromRGB(232, 196, 110), {Size = UDim2.fromScale(1, 1),
	FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold), ZIndex = 6})

-- ---------------------------------------------------------------- état
local rayon = Config.RAYONS[1].id
local selection: string? = nil
local achats = {}       -- id -> true : articles uniques déjà achetés
local cartes = {}
local ouvert = false
local reafficher = nil
local flou: BlurEffect? = nil

local function achete(a): boolean
	return a.unique == true and achats[a.id] == true
end

local function lignesContenu(a): {string}
	local t = {}
	if a.contenu.Or then table.insert(t, milliers(a.contenu.Or) .. " Gold") end
	for _, id in Materiaux.ORDRE do
		local n = (a.contenu.Materiaux or {})[id]
		if n then table.insert(t, milliers(n) .. " " .. Materiaux.NOMS[id]) end
	end
	return t
end

local function majFiche()
	local a = selection and Config.article(selection)
	fiche.Visible = a ~= nil
	acheter.bouton.Visible = a ~= nil
	if not a then return end
	nomArticle.Text = a.nom
	prixFiche.Text = ROBUX .. " " .. milliers(a.prix)
	grandeImage.Image = a.image
	for _, c in blocContenu:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	for i, l in lignesContenu(a) do
		texte(blocContenu, "· " .. l, 30, TEXTE_FONCE, {Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i})
	end
	description.Text = a.description
	local deja = achete(a)
	acheter.texte.Text = if deja then "Purchased" else "Buy"
	acheter.activer(not deja)
end

local function majSelection()
	for id, c in cartes do
		local choisie = id == selection
		c.carte.contour.Enabled = choisie
		c.carte.lueur.Visible = choisie
		c.fond.BackgroundTransparency = if choisie then 0.1 else 0.35
	end
	majFiche()
end

local function carteArticle(a, ordre: number)
	local case = cadre(grille, UDim2.new(), UDim2.new(), Color3.fromRGB(30, 38, 56), 0.35)
	case.LayoutOrder = ordre
	arrondi(case, 10)
	filet(case, Color3.fromRGB(196, 204, 224), 1.5, 0.7)
	-- grande carte de rareté en haut (154 × 190 agrandie)
	local support = cadre(case, UDim2.fromOffset(154, 190), UDim2.new(0.5, 0, 0, 22))
	support.AnchorPoint = Vector2.new(0.5, 0)
	cree("UIScale", {Scale = 1.3}, support)
	local principal = lignesContenu(a)[1] or ""
	local c = Style.carte(support, {image = a.image, rarete = a.rarete, etoiles = false, texte = principal:match("^[%d,]+") or ""})
	if a.etiquette then
		c.badge.Visible = true
		local libelle = c.badge:FindFirstChildOfClass("TextLabel")
		if libelle then
			libelle.Text = a.etiquette
			libelle.TextSize = if #a.etiquette > 5 then 20 else 26
		end
		c.badge.Size = UDim2.fromOffset(if #a.etiquette > 5 then 112 else 84, 38)
	end
	texte(case, a.nom, 28, CREME, {FontFace = Style.POLICE_TITRE, Position = UDim2.fromOffset(0, 272), Size = UDim2.new(1, 0, 0, 36)})
	-- prix sur une pilule sombre
	local pilule = cadre(case, UDim2.fromOffset(170, 46), UDim2.new(0.5, 0, 0, 316), Color3.fromRGB(18, 24, 38), 0.2)
	pilule.AnchorPoint = Vector2.new(0.5, 0)
	arrondi(pilule)
	filet(pilule, Color3.fromRGB(232, 196, 110), 1.5, 0.4)
	local deja = achete(a)
	texte(pilule, if deja then "Purchased" else (ROBUX .. " " .. milliers(a.prix)), 28, if deja then TEXTE_DESC else BLANC,
		{Size = UDim2.fromScale(1, 1), FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)})
	if deja then case.BackgroundTransparency = 0.6 end
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8}, case)
	bouton.Activated:Connect(function()
		selection = a.id
		message.Text = ""
		majSelection()
	end)
	cartes[a.id] = {carte = c, fond = case}
end

local function remplir()
	for _, c in grille:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	table.clear(cartes)
	local premier = nil
	local present = false
	for i, a in Config.ARTICLES do
		if a.rayon == rayon then
			carteArticle(a, i)
			premier = premier or a.id
			if a.id == selection then present = true end
		end
	end
	if not present then selection = premier end
	titre.Text = "Shop / " .. (function()
		for _, r in Config.RAYONS do
			if r.id == rayon then return r.nom end
		end
		return ""
	end)()
	for id, o in onglets do
		local actif = id == rayon
		o.pilule.Visible, o.etoile.Visible, o.rond.Visible = actif, actif, not actif
		o.icone.ImageColor3 = if actif then ARDOISE else CREME
	end
	majSelection()
end

for id, o in onglets do
	o.bouton.Activated:Connect(function()
		if rayon == id then return end
		rayon, selection = id, nil
		message.Text = ""
		remplir()
	end)
end

local function lireAchats()
	local ok, a = pcall(function() return LireAchats:InvokeServer() end)
	if ok and type(a) == "table" then achats = a end
end

-- ---------------------------------------------------------------- ouverture et fermeture
local function ouvrir()
	if ouvert then return end
	ouvert = true
	reafficher = Style.masquerAutres(ecran)
	flou = cree("BlurEffect", {Name = "FlouBoutique", Size = 0}, Lighting)
	TweenService:Create(flou :: BlurEffect, TweenInfo.new(0.2), {Size = 18}):Play()
	voile.BackgroundTransparency = 1
	TweenService:Create(voile, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
	message.Text = ""
	remplir()
	ecran.Enabled = true
	task.spawn(function()
		lireAchats()
		if ouvert then remplir() end
	end)
end

local function fermerBoutique()
	if not ouvert then return end
	ouvert = false
	ecran.Enabled = false
	if reafficher then reafficher() end
	reafficher = nil
	if flou then flou:Destroy() end
	flou = nil
end

fermer.Activated:Connect(fermerBoutique)
UserInputService.InputBegan:Connect(function(entree, traite)
	if ouvert and not traite and entree.KeyCode == Enum.KeyCode.ButtonB then fermerBoutique() end
end)

joueur:GetAttributeChangedSignal("OrCombat"):Connect(function()
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
end)

acheter.bouton.Activated:Connect(function()
	local a = selection and Config.article(selection)
	if not a or not acheter.estActif() then return end
	if a.produit == 0 then
		message.Text, message.TextColor3 = "This offer isn't available yet.", Style.ROUGE
		return
	end
	MarketplaceService:PromptProductPurchase(joueur, a.produit)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _produit, achete_)
	if userId ~= joueur.UserId or not achete_ then return end
	message.Text, message.TextColor3 = "Thank you! Your purchase has been delivered.", Style.VERT
	task.wait(1)
	lireAchats()
	if ouvert then remplir() end
end)

-- coffre doré du HUD (Hud.luau)
task.spawn(function()
	local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	local b = hud and hud:WaitForChild("Boutique", 30)
	if b then (b :: GuiButton).Activated:Connect(ouvrir) end
end)
