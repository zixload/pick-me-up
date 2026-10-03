-- Offres du jour (03/10/2026), dans le style des menus plein écran (StyleMenus, comme la boutique) :
-- le cadeau gratuit en première carte, puis les 3 échanges du marché payés en or (prix sur une pilule, achats
-- restants), fiche à droite (contenu, description, limite) et bouton « Claim » / « Trade ». Compte à rebours
-- avant le renouvellement. S'ouvre par l'icône diamant du HUD, qui porte un « ! » tant que le cadeau attend.
-- Le serveur fait foi (Services/Offres). Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Offres)
local Materiaux = require(Shared.Config.Materiaux)
local Objets = require(Shared.Config.Objets)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local LireOffres = reseau:WaitForChild("LireOffres")
local PrendreCadeau = reseau:WaitForChild("PrendreCadeau")
local EchangerOffre = reseau:WaitForChild("EchangerOffre")

local joueur = Players.LocalPlayer
local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, BLANC = Style.CREME, Style.BLANC
local TEXTE_FONCE, TEXTE_DESC = Style.TEXTE_FONCE, Style.TEXTE_DESC
local IMAGES = Style.IMAGES
local ICONE_OFFRES = "rbxassetid://120810365077873"   -- diamant du HUD
local IMAGE_CADEAU = "rbxassetid://76413057251104"    -- coffre doré

local function milliers(n: number): string
	local s = tostring(math.floor(n))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end

-- image et rareté d'une offre : celles du premier matériau qu'elle donne
local function apparence(contenu)
	for _, id in Materiaux.ORDRE do
		if (contenu.Materiaux or {})[id] then
			local f = Objets.LISTE[id]
			return f and f.image or "", f and f.rarete or 2
		end
	end
	return IMAGES.piece, 4
end

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("OffresDuJour", 20)
local voile = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(24, 32, 48), 0.4)
cree("ImageLabel", {Image = IMAGES.bandeau, BackgroundTransparency = 1, Size = UDim2.new(0, 100, 1, 0),
	Position = UDim2.fromOffset(46, 0)}, racine)
cree("ImageLabel", {Image = IMAGES.fanion, BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 112),
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(96, 0)}, racine)
cree("ImageLabel", {Image = ICONE_OFFRES, ImageColor3 = Color3.fromRGB(92, 70, 38), BackgroundTransparency = 1,
	Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 54), ZIndex = 2}, racine)

local titre = Style.titre(racine, "Daily Offers")
local remise = texte(racine, "", 24, CREME, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(250, 100),
	Size = UDim2.fromOffset(600, 30), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.25})
local montantOr = Style.bourse(racine)
local fermer = Style.boutonFermer(racine)

local grille = cree("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(230, 130),
	Size = UDim2.new(1, -930, 1, -160), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6, ScrollBarImageColor3 = CREME, ScrollBarImageTransparency = 0.5}, racine)
cree("UIPadding", {PaddingLeft = UDim.new(0, 20), PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 24)}, grille)
cree("UIGridLayout", {CellSize = UDim2.fromOffset(250, 380), CellPadding = UDim2.fromOffset(30, 30),
	SortOrder = Enum.SortOrder.LayoutOrder}, grille)

-- fiche à droite
local fiche = cadre(racine, UDim2.fromOffset(615, 780), UDim2.new(1, -60, 0, 150))
fiche.AnchorPoint = Vector2.new(1, 0)
local nomOffre = Style.entete(fiche)
local illustration = cadre(fiche, UDim2.new(1, 0, 0, 284), UDim2.fromOffset(0, 72), BLANC)
cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(80, 88, 114), Color3.fromRGB(62, 68, 90))}, illustration)
cree("ImageLabel", {Image = IMAGES.lueur, ImageColor3 = Color3.fromRGB(255, 214, 120), ImageTransparency = 0.55,
	BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 360), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -165, 0.55, 0)}, illustration)
local prixFiche = texte(illustration, "", 34, BLANC, {FontFace = Style.POLICE_TITRE, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(36, 44), Size = UDim2.fromOffset(300, 44), TextXAlignment = Enum.TextXAlignment.Left})
local grandeImage = cree("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 220),
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
local limite = texte(corps, "", 26, TEXTE_FONCE, {Size = UDim2.new(1, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5})
local message = texte(corps, "", 26, Style.ROUGE, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 6})

local action = Style.boutonAction(racine, "Claim", IMAGES.piece)
action.icone.ImageColor3 = BLANC   -- la pièce garde ses couleurs

-- ---------------------------------------------------------------- état
local etat = nil
local selection = "Cadeau"
local cartes = {}
local ouvert = false
local reafficher = nil
local flou: BlurEffect? = nil
local envoiEnCours = false

local function offresDuJour()
	local t = {{id = "Cadeau", nom = Config.CADEAU.nom, contenu = Config.CADEAU.contenu, description = Config.CADEAU.description,
		gratuit = true, epuise = etat and etat.cadeau or false, image = IMAGE_CADEAU, rarete = 5}}
	for _, e in (etat and etat.echanges) or {} do
		local o = Config.echange(e.id)
		if o then
			local image, rarete = apparence(o.contenu)
			table.insert(t, {id = o.id, nom = o.nom, contenu = o.contenu, description = o.description, prix = o.prix,
				limite = o.limite, achats = e.achats, epuise = e.achats >= o.limite, image = image, rarete = o.rarete or rarete})
		end
	end
	return t
end

local function lignesContenu(o): {string}
	local t = {}
	if o.contenu.Or then table.insert(t, milliers(o.contenu.Or) .. " Gold") end
	for _, id in Materiaux.ORDRE do
		local n = (o.contenu.Materiaux or {})[id]
		if n then table.insert(t, milliers(n) .. " " .. Materiaux.NOMS[id]) end
	end
	return t
end

local function trouver(id: string)
	for _, o in offresDuJour() do
		if o.id == id then return o end
	end
	return nil
end

local function majFiche()
	local o = trouver(selection)
	fiche.Visible = o ~= nil
	action.bouton.Visible = o ~= nil
	if not o then return end
	nomOffre.Text = o.nom
	prixFiche.Text = if o.gratuit then "Free" else milliers(o.prix) .. " gold"
	grandeImage.Image = o.image
	for _, c in blocContenu:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	for i, l in lignesContenu(o) do
		texte(blocContenu, "· " .. l, 30, TEXTE_FONCE, {Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i})
	end
	description.Text = o.description
	limite.Text = if o.gratuit then "Once a day" else `Today: {o.achats} / {o.limite}`
	action.texte.Text = if o.epuise then (if o.gratuit then "Claimed" else "Sold out") elseif o.gratuit then "Claim" else "Trade"
	action.activer(not o.epuise and not envoiEnCours)
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

local function carteOffre(o, ordre: number)
	local case = cadre(grille, UDim2.new(), UDim2.new(), Color3.fromRGB(30, 38, 56), 0.35)
	case.LayoutOrder = ordre
	arrondi(case, 10)
	filet(case, Color3.fromRGB(196, 204, 224), 1.5, 0.7)
	local support = cadre(case, UDim2.fromOffset(154, 190), UDim2.new(0.5, 0, 0, 22))
	support.AnchorPoint = Vector2.new(0.5, 0)
	cree("UIScale", {Scale = 1.3}, support)
	local premier = lignesContenu(o)[1] or ""
	local c = Style.carte(support, {image = o.image, rarete = o.rarete, etoiles = false,
		texte = if o.gratuit then "Gift" else (premier:match("^[%d,]+") or "")})
	if o.gratuit then
		c.badge.Visible = true
		local libelle = c.badge:FindFirstChildOfClass("TextLabel")
		if libelle then libelle.Text = "Free" end
	end
	texte(case, o.nom, 28, CREME, {FontFace = Style.POLICE_TITRE, Position = UDim2.fromOffset(0, 272), Size = UDim2.new(1, 0, 0, 36)})
	local pilule = cadre(case, UDim2.fromOffset(190, 46), UDim2.new(0.5, 0, 0, 316), Color3.fromRGB(18, 24, 38), 0.2)
	pilule.AnchorPoint = Vector2.new(0.5, 0)
	arrondi(pilule)
	filet(pilule, Color3.fromRGB(232, 196, 110), 1.5, 0.4)
	if o.epuise then
		texte(pilule, if o.gratuit then "Claimed" else "Sold out", 26, TEXTE_DESC, {Size = UDim2.fromScale(1, 1)})
		case.BackgroundTransparency = 0.6
	elseif o.gratuit then
		texte(pilule, "Free", 28, BLANC, {Size = UDim2.fromScale(1, 1), FontFace = Style.POLICE_TITRE})
	else
		cree("ImageLabel", {Image = IMAGES.piece, BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0)}, pilule)
		texte(pilule, `{milliers(o.prix)}  ·  {o.limite - o.achats} left`, 24, BLANC, {Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -54, 1, 0), TextXAlignment = Enum.TextXAlignment.Left})
	end
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8}, case)
	bouton.Activated:Connect(function()
		selection = o.id
		message.Text = ""
		majSelection()
	end)
	cartes[o.id] = {carte = c, fond = case}
end

local function remplir()
	for _, c in grille:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	table.clear(cartes)
	for i, o in offresDuJour() do carteOffre(o, i) end
	if not trouver(selection) then selection = "Cadeau" end
	majSelection()
end

-- « ! » rouge sur le diamant du HUD tant que le cadeau du jour attend
local alerteHud = nil
local function majAlerte()
	if alerteHud then alerteHud.Visible = etat ~= nil and not etat.cadeau end
end

local function recevoir(e)
	if type(e) ~= "table" then return end
	etat = e
	majAlerte()
	if ouvert then remplir() end
end

-- ---------------------------------------------------------------- ouverture et fermeture
local function ouvrir()
	if ouvert then return end
	ouvert = true
	reafficher = Style.masquerAutres(ecran)
	flou = cree("BlurEffect", {Name = "FlouOffres", Size = 0}, Lighting)
	TweenService:Create(flou :: BlurEffect, TweenInfo.new(0.2), {Size = 18}):Play()
	voile.BackgroundTransparency = 1
	TweenService:Create(voile, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
	message.Text = ""
	remplir()
	ecran.Enabled = true
	task.spawn(function()
		local ok, e = pcall(function() return LireOffres:InvokeServer() end)
		if ok then recevoir(e) end
	end)
end

local function fermerOffres()
	if not ouvert then return end
	ouvert = false
	ecran.Enabled = false
	if reafficher then reafficher() end
	reafficher = nil
	if flou then flou:Destroy() end
	flou = nil
end
fermer.Activated:Connect(fermerOffres)
UserInputService.InputBegan:Connect(function(entree, traite)
	if ouvert and not traite and entree.KeyCode == Enum.KeyCode.ButtonB then fermerOffres() end
end)

joueur:GetAttributeChangedSignal("OrCombat"):Connect(function()
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
end)

action.bouton.Activated:Connect(function()
	local o = trouver(selection)
	if not o or envoiEnCours or not action.estActif() then return end
	envoiEnCours = true
	majFiche()
	local ok, reponse, e
	if o.gratuit then
		ok, reponse, e = PrendreCadeau:InvokeServer()
	else
		ok, reponse, e = EchangerOffre:InvokeServer(o.id)
	end
	envoiEnCours = false
	recevoir(e)
	message.Text = reponse or ""
	message.TextColor3 = if ok then Style.VERT else Style.ROUGE
	majFiche()
end)

-- compte à rebours du renouvellement
task.spawn(function()
	while true do
		if ouvert and etat and etat.prochainJour then
			local reste = math.max(0, math.floor(etat.prochainJour - workspace:GetServerTimeNow()))
			remise.Text = string.format("New offers in %02d:%02d:%02d", reste // 3600, (reste % 3600) // 60, reste % 60)
		end
		task.wait(1)
	end
end)

-- diamant du HUD : ouvre l'écran et porte l'alerte du cadeau
task.spawn(function()
	local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	local b = hud and hud:WaitForChild("Offres", 30)
	if not b then return end
	(b :: GuiButton).Activated:Connect(ouvrir)
	alerteHud = cadre(b, UDim2.fromOffset(20, 20), UDim2.new(1, -2, 0, 2), Color3.fromRGB(226, 86, 70))
	alerteHud.AnchorPoint, alerteHud.ZIndex = Vector2.new(0.5, 0.5), 3
	arrondi(alerteHud)
	texte(alerteHud, "!", 15, BLANC, {Size = UDim2.fromScale(1, 1), FontFace = Style.POLICE_TITRE, ZIndex = 4})
	majAlerte()
end)

task.spawn(function()
	for _ = 1, 30 do
		local ok, e = pcall(function() return LireOffres:InvokeServer() end)
		if ok and type(e) == "table" then
			recevoir(e)
			break
		end
		task.wait(2)
	end
end)
