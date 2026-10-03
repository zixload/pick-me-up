-- Inventaire plein écran (03/10/2026), calqué sur la référence fournie par le joueur : jeu flouté derrière,
-- bandeau de catégories à gauche (catégorie choisie en pilule claire), titre « Inventory / <catégorie> »,
-- or et bouton fermer en haut à droite, grille de cartes (couleur de rareté, étoiles, quantité sur une bande
-- claire, badge « New »), fiche de l'objet choisi à droite (bandeau titre à filet fin, illustration, texte sur fond clair).
-- S'ouvre par l'icône sac du HUD ou la touche B. Le serveur envoie l'inventaire du joueur (Services/Inventaire).
-- Tout est dessiné pour un écran de 1920 × 1080 puis mis à l'échelle. Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Objets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Objets"))
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local LireInventaire = reseau:WaitForChild("LireInventaire")
local InventaireChange = reseau:WaitForChild("InventaireChange")

local joueur = Players.LocalPlayer
local playerGui = joueur:WaitForChild("PlayerGui")

local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, OR_PALE, ARDOISE, BLANC = Style.CREME, Style.OR_PALE, Style.ARDOISE, Style.BLANC
local TEXTE_FONCE, TEXTE_DESC = Style.TEXTE_FONCE, Style.TEXTE_DESC
local IMAGES = Style.IMAGES

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("Inventaire", 20)
local voile = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(24, 32, 48), 0.4)

-- ---------------------------------------------------------------- bandeau des catégories (à gauche)
-- bannière translucide (double filet, motifs, pointe en bas) dessinée par ui/inventaire_v01/bandeau.py
cree("ImageLabel", {Image = IMAGES.bandeau, BackgroundTransparency = 1, Size = UDim2.new(0, 100, 1, 0),
	Position = UDim2.fromOffset(46, 0)}, racine)
-- fanion doré en haut, qui porte le sac
cree("ImageLabel", {Image = IMAGES.fanion, BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 112),
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(96, 0)}, racine)
cree("ImageLabel", {Image = IMAGES.sac, ImageColor3 = Color3.fromRGB(92, 70, 38), BackgroundTransparency = 1,
	Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 54), ZIndex = 2}, racine)

local onglets = {}
local function pointOnglet(i: number): number
	return 192 + (i - 1) * 120
end
for i, cat in Objets.CATEGORIES do
	local y = pointOnglet(i)
	local pilule = cadre(racine, UDim2.fromOffset(198, 84), UDim2.fromOffset(-50, y), CREME)
	pilule.AnchorPoint = Vector2.new(0, 0.5)
	arrondi(pilule)
	local etincelle = cree("ImageLabel", {Image = IMAGES.etoile4, ImageColor3 = CREME, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(164, y)}, racine)
	local rond = cadre(racine, UDim2.fromOffset(78, 78), UDim2.fromOffset(96, y), Color3.fromRGB(46, 54, 74), 0.25)
	rond.AnchorPoint = Vector2.new(0.5, 0.5)
	arrondi(rond)
	filet(rond, Color3.fromRGB(196, 204, 224), 1.5, 0.6)
	local icone = cree("ImageLabel", {Image = cat.icone or "", ImageColor3 = CREME, BackgroundTransparency = 1, ZIndex = 2,
		Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 100), ZIndex = 3,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	onglets[cat.id] = {pilule = pilule, etincelle = etincelle, rond = rond, icone = icone, bouton = bouton}
end

-- ---------------------------------------------------------------- haut de l'écran
local titre = Style.titre(racine, "Inventory")
local montantOr = Style.bourse(racine)
local fermer = Style.boutonFermer(racine)

-- ---------------------------------------------------------------- grille
local grille = cree("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(240, 128),
	Size = UDim2.new(1, -940, 1, -150), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6, ScrollBarImageColor3 = CREME, ScrollBarImageTransparency = 0.5}, racine)
cree("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingTop = UDim.new(0, 22), PaddingBottom = UDim.new(0, 22)}, grille)
cree("UIGridLayout", {CellSize = UDim2.fromOffset(154, 190), CellPadding = UDim2.fromOffset(29, 28),
	SortOrder = Enum.SortOrder.LayoutOrder}, grille)
local vide = texte(racine, "No items yet", 30, CREME, {Position = UDim2.fromOffset(240, 128), Size = UDim2.new(1, -940, 0, 200),
	TextTransparency = 0.35, Visible = false})

-- ---------------------------------------------------------------- fiche de l'objet (à droite)
local fiche = cadre(racine, UDim2.fromOffset(615, 780), UDim2.new(1, -60, 0, 150))
fiche.AnchorPoint = Vector2.new(1, 0)
local nomObjet = Style.entete(fiche)

local illustration = cadre(fiche, UDim2.new(1, 0, 0, 284), UDim2.fromOffset(0, 72), BLANC)
cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(80, 88, 114), Color3.fromRGB(62, 68, 90))}, illustration)
local filigrane = cree("ImageLabel", {BackgroundTransparency = 1, ImageColor3 = BLANC, ImageTransparency = 0.93,
	Size = UDim2.fromOffset(300, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5)}, illustration)
local iconeType = cree("ImageLabel", {BackgroundTransparency = 1, ImageColor3 = CREME, Size = UDim2.fromOffset(34, 34),
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(36, 42)}, illustration)
local typeObjet = texte(illustration, "", 30, CREME, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(82, 42),
	Size = UDim2.fromOffset(400, 40), TextXAlignment = Enum.TextXAlignment.Left})
local grandeIcone = cree("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(250, 250),
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.55, 0)}, illustration)

local corpsFiche = cree("ScrollingFrame", {BackgroundColor3 = CREME, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 356),
	Size = UDim2.new(1, 0, 1, -356), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4, ScrollBarImageColor3 = TEXTE_DESC}, fiche)
cree("UIPadding", {PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36), PaddingTop = UDim.new(0, 40),
	PaddingBottom = UDim.new(0, 30)}, corpsFiche)
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16)}, corpsFiche)
local blocEffets = cadre(corpsFiche, UDim2.new(1, 0, 0, 0), UDim2.new())
blocEffets.AutomaticSize, blocEffets.LayoutOrder = Enum.AutomaticSize.Y, 1
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, blocEffets)
local description = texte(corpsFiche, "", 29, TEXTE_DESC, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.08, LayoutOrder = 2})
local enteteSource = cadre(corpsFiche, UDim2.new(1, 0, 0, 44), UDim2.new())
enteteSource.LayoutOrder = 3
cree("ImageLabel", {Image = IMAGES.epingle, ImageColor3 = TEXTE_FONCE, BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28),
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 4)}, enteteSource)
texte(enteteSource, "Source", 29, TEXTE_FONCE, {Position = UDim2.fromOffset(44, 4), Size = UDim2.new(1, -44, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left})
local boiteSource = cadre(corpsFiche, UDim2.new(1, 0, 0, 58), UDim2.new(), Color3.fromRGB(243, 239, 232))
boiteSource.LayoutOrder = 4
filet(boiteSource, Color3.fromRGB(214, 206, 192), 1.5)
local source = texte(boiteSource, "", 27, TEXTE_FONCE, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})

-- bouton d'action en bas à droite (pilule claire) : seulement pour un objet qui a une action
local action = Style.boutonAction(racine, "Use")
action.bouton.Visible = false

-- ---------------------------------------------------------------- état
local inventaire = {Or = 0, Objets = {}}
local categorie = Objets.CATEGORIES[1].id
local selection: string? = nil
local cartes = {}          -- id -> {contour, lueur, badge}
local vus = nil            -- quantités à la dernière fermeture (nil : jamais ouvert)
local nouveaux = {}        -- id -> true : quantité en hausse depuis la dernière visite
local ouvert = false
local reafficher = nil     -- réaffiche les interfaces masquées pendant l'ouverture
local flou: BlurEffect? = nil

local function idsDe(cat: string): {string}
	local t = {}
	for _, id in Objets.ORDRE do
		local f = Objets.LISTE[id]
		if f and f.categorie == cat and (inventaire.Objets[id] or 0) > 0 then table.insert(t, id) end
	end
	return t
end

local function nomCategorie(cat: string): string
	for _, c in Objets.CATEGORIES do
		if c.id == cat then return c.nom end
	end
	return ""
end

local function iconeCategorie(cat: string): string
	for _, c in Objets.CATEGORIES do
		if c.id == cat then return c.icone or "" end
	end
	return ""
end

local function majFiche()
	local f = selection and Objets.LISTE[selection]
	fiche.Visible = f ~= nil
	action.bouton.Visible = f ~= nil and f.action ~= nil
	if not f then return end
	nomObjet.Text = f.nom
	typeObjet.Text = f.type
	iconeType.Image = iconeCategorie(f.categorie)
	filigrane.Image = iconeCategorie(f.categorie)
	grandeIcone.Image = f.image
	for _, c in blocEffets:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	for i, e in f.effets or {} do
		texte(blocEffets, "· " .. e, 30, TEXTE_FONCE, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i})
	end
	description.Text = f.description
	source.Text = f.source
	if f.action then action.texte.Text = f.action end
	corpsFiche.CanvasPosition = Vector2.zero
end

local function majSelection()
	for id, c in cartes do
		local choisie = id == selection
		c.contour.Enabled = choisie
		c.lueur.Visible = choisie
		c.badge.Visible = nouveaux[id] == true
	end
	majFiche()
end

local function choisir(id: string)
	selection = id
	nouveaux[id] = nil
	majSelection()
end

local function carte(id: string, quantite: number, ordre: number)
	local f = Objets.LISTE[id]
	local c = Style.carte(grille, {image = f.image, rarete = f.rarete, texte = tostring(quantite)})
	c.case.LayoutOrder = ordre
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7}, c.case)
	bouton.Activated:Connect(function() choisir(id) end)
	cartes[id] = c
end

local function remplir()
	for _, c in grille:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	table.clear(cartes)
	local ids = idsDe(categorie)
	for i, id in ids do
		carte(id, inventaire.Objets[id], i)
	end
	if not (selection and table.find(ids, selection)) then
		selection = ids[1]
	end
	vide.Visible = #ids == 0
	titre.Text = "Inventory / " .. nomCategorie(categorie)
	montantOr.Text = tostring(math.floor(inventaire.Or or 0))
	for id, o in onglets do
		local actif = id == categorie
		o.pilule.Visible, o.etincelle.Visible, o.rond.Visible = actif, actif, not actif
		o.icone.ImageColor3 = if actif then ARDOISE else CREME
	end
	majSelection()
end

for id, o in onglets do
	o.bouton.Activated:Connect(function()
		if categorie == id then return end
		categorie, selection = id, nil
		remplir()
	end)
end

-- ---------------------------------------------------------------- ouverture et fermeture
local function ouvrir()
	if ouvert then return end
	ouvert = true
	table.clear(nouveaux)
	if vus then
		for id, n in inventaire.Objets do
			if n > (vus[id] or 0) then nouveaux[id] = true end
		end
	end
	reafficher = Style.masquerAutres(ecran)
	flou = cree("BlurEffect", {Name = "FlouInventaire", Size = 0}, Lighting)
	TweenService:Create(flou :: BlurEffect, TweenInfo.new(0.2), {Size = 18}):Play()
	voile.BackgroundTransparency = 1
	TweenService:Create(voile, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
	remplir()
	ecran.Enabled = true
end

local function fermerInventaire()
	if not ouvert then return end
	ouvert = false
	ecran.Enabled = false
	if reafficher then reafficher() end
	reafficher = nil
	if flou then flou:Destroy() end
	flou = nil
	vus = table.clone(inventaire.Objets)
end

fermer.Activated:Connect(fermerInventaire)

UserInputService.InputBegan:Connect(function(entree, traite)
	if traite then return end
	if entree.KeyCode == Enum.KeyCode.B then
		if ouvert then fermerInventaire() else ouvrir() end
	elseif ouvert and entree.KeyCode == Enum.KeyCode.ButtonB then
		fermerInventaire()
	end
end)

-- icône sac du HUD (Hud.luau, en haut à droite)
task.spawn(function()
	local hud = playerGui:WaitForChild("Hud", 30)
	local sac = hud and hud:WaitForChild("Inventaire", 30)
	if sac then (sac :: GuiButton).Activated:Connect(ouvrir) end
end)

-- ---------------------------------------------------------------- données
local function recevoir(contenu)
	if type(contenu) ~= "table" then return end
	inventaire = contenu
	if ouvert then remplir() end
end
InventaireChange.OnClientEvent:Connect(recevoir)
task.spawn(function()
	local ok, contenu = pcall(function() return LireInventaire:InvokeServer() end)
	if ok then recevoir(contenu) end
end)
