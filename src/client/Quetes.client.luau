-- Écran des quêtes (03/10/2026), dans le style des menus plein écran (StyleMenus) et d'après la maquette validée :
-- bannière à gauche avec les onglets Daily / Weekly / Story, liste des quêtes au milieu (la choisie en clair, « ! »
-- rouge sur celles à réclamer), détail à droite (objectif et avancement, texte, récompenses en cartes) et bouton
-- « Claim » en pilule claire. S'ouvre par l'icône quêtes du HUD ou la touche J. Le serveur fait foi (Services/Quetes).
-- Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Quetes)
local Objets = require(Shared.Config.Objets)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local LireQuetes = reseau:WaitForChild("LireQuetes")
local QuetesChange = reseau:WaitForChild("QuetesChange")
local ReclamerQuete = reseau:WaitForChild("ReclamerQuete")

local joueur = Players.LocalPlayer
local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, OR_PALE, ARDOISE, BLANC = Style.CREME, Style.OR_PALE, Style.ARDOISE, Style.BLANC
local IMAGES = Style.IMAGES
local FOND_LIGNE = Color3.fromRGB(62, 72, 94)
local OR_VIF = Color3.fromRGB(244, 201, 93)

local ONGLETS = {
	{id = "Quotidienne", nom = "Daily", titre = "Daily Quests", icone = IMAGES.onglet_quotidien},
	{id = "Hebdo", nom = "Weekly", titre = "Weekly Quests", icone = IMAGES.onglet_hebdo},
	{id = "Histoire", nom = "Story", titre = "Chapter I · " .. Config.CHAPITRE, icone = IMAGES.onglet_histoire},
}

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("Quetes", 20)
local voile = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(24, 32, 48), 0.4)

-- bannière à gauche (même dessin que l'inventaire), fanion doré qui porte l'icône des quêtes
cree("ImageLabel", {Image = IMAGES.bandeau, BackgroundTransparency = 1, Size = UDim2.new(0, 100, 1, 0),
	Position = UDim2.fromOffset(46, 0)}, racine)
cree("ImageLabel", {Image = IMAGES.fanion, BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 112),
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(96, 0)}, racine)
cree("ImageLabel", {Image = IMAGES.quetes, ImageColor3 = Color3.fromRGB(92, 70, 38), BackgroundTransparency = 1,
	Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 54), ZIndex = 2}, racine)

local onglets = {}
for i, o in ONGLETS do
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
	local icone = cree("ImageLabel", {Image = o.icone, ImageColor3 = CREME, BackgroundTransparency = 1, ZIndex = 2,
		Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	-- « ! » rouge sur l'onglet quand une récompense y attend
	local alerte = cadre(racine, UDim2.fromOffset(24, 24), UDim2.fromOffset(124, y - 30), Color3.fromRGB(226, 86, 70))
	alerte.AnchorPoint, alerte.ZIndex, alerte.Visible = Vector2.new(0.5, 0.5), 3, false
	arrondi(alerte)
	texte(alerte, "!", 18, BLANC, {Size = UDim2.fromScale(1, 1), ZIndex = 4})
	local bouton = cree("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 100), ZIndex = 5,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, y)}, racine)
	onglets[o.id] = {pilule = pilule, etoile = etoile, rond = rond, icone = icone, alerte = alerte, bouton = bouton}
end

local titre = Style.titre(racine, "Quests")
local montantOr = Style.bourse(racine)
local fermer = Style.boutonFermer(racine)

-- ---------------------------------------------------------------- liste (au milieu)
local enteteListe = texte(racine, "", 30, OR_PALE, {FontFace = Style.POLICE_TITRE, Position = UDim2.fromOffset(210, 112),
	Size = UDim2.fromOffset(560, 40), TextXAlignment = Enum.TextXAlignment.Left})
local remise = texte(racine, "", 22, CREME, {Position = UDim2.fromOffset(210, 112), Size = UDim2.fromOffset(560, 40),
	TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.25})
local liste = cree("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(200, 160),
	Size = UDim2.new(0, 580, 1, -200), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6, ScrollBarImageColor3 = CREME, ScrollBarImageTransparency = 0.5}, racine)
cree("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8)}, liste)
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)}, liste)
cadre(racine, UDim2.new(0, 1, 1, -160), UDim2.fromOffset(812, 110), CREME, 0.8)

-- ---------------------------------------------------------------- détail (à droite)
local detail = cadre(racine, UDim2.new(1, -920, 1, -260), UDim2.fromOffset(860, 120))
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 18)}, detail)
local nomQuete = texte(detail, "", 48, BLANC, {FontFace = Style.POLICE_TITRE, Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1})
local ligneLieu = cadre(detail, UDim2.new(1, 0, 0, 34), UDim2.new())
ligneLieu.LayoutOrder = 2
cree("ImageLabel", {Image = IMAGES.epingle, ImageColor3 = OR_PALE, BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26),
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0)}, ligneLieu)
local lieu = texte(ligneLieu, "", 26, OR_PALE, {Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left})
Style.separateur(detail, OR_PALE).LayoutOrder = 3
local objectif = cadre(detail, UDim2.new(1, 0, 0, 62), UDim2.new(), Color3.fromRGB(16, 22, 36), 0.45)
objectif.LayoutOrder = 4
texte(objectif, "▸", 26, OR_PALE, {Position = UDim2.fromOffset(22, 0), Size = UDim2.fromOffset(20, 62)})
local objectifTexte = texte(objectif, "", 28, CREME, {Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -200, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left})
local avancement = texte(objectif, "", 28, CREME, {Position = UDim2.new(1, -160, 0, 0), Size = UDim2.fromOffset(140, 62),
	TextXAlignment = Enum.TextXAlignment.Right})
local barre = cadre(objectif, UDim2.new(1, 0, 0, 4), UDim2.new(0, 0, 1, -4), BLANC, 0.85)
local remplissage = cadre(barre, UDim2.fromScale(0, 1), UDim2.new(), OR_PALE)
local description = texte(detail, "", 28, CREME, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 1.1, LayoutOrder = 5})
texte(detail, "Rewards:", 28, CREME, {Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left,
	TextTransparency = 0.3, LayoutOrder = 6})
local recompenses = cadre(detail, UDim2.new(1, 0, 0, 160), UDim2.new())
recompenses.LayoutOrder = 7
cree("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder}, recompenses)
local message = texte(detail, "", 26, Color3.fromRGB(150, 214, 64), {Size = UDim2.new(1, 0, 0, 34),
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 8})

local action = Style.boutonAction(racine, "Claim")

-- ---------------------------------------------------------------- état
local etat = nil
local onglet = "Quotidienne"
local selection: string? = nil       -- id de la quête choisie dans l'onglet
local ouvert = false
local reafficher = nil
local flou: BlurEffect? = nil
local envoiEnCours = false

-- éléments de l'onglet : {genre, id, quete, progres, reclamee, verrouillee}
local function elements(id: string)
	local t = {}
	if not etat then return t end
	if id == "Quotidienne" then
		local reclamees = 0
		for _, e in etat.quotidiennes or {} do
			local q = Config.trouver(Config.QUOTIDIENNES, e.id)
			if q then
				table.insert(t, {genre = "Quotidienne", id = e.id, quete = q, progres = e.progres, reclamee = e.reclamee})
				if e.reclamee then reclamees += 1 end
			end
		end
		if #t > 0 then
			table.insert(t, {genre = "Bonus", id = "Bonus", progres = reclamees, reclamee = etat.bonusPris, quete = {
				nom = "Daily Bonus", objectif = "Claim every daily quest", cible = #t, lieu = "Anywhere",
				recompense = Config.BONUS_QUOTIDIEN,
				description = "Finish all of today's quests and claim them to earn an extra reward."}})
		end
	elseif id == "Hebdo" then
		for _, q in Config.HEBDOMADAIRES do
			local e = (etat.hebdo or {})[q.id] or {progres = 0, reclamee = false}
			table.insert(t, {genre = "Hebdo", id = q.id, quete = q, progres = e.progres, reclamee = e.reclamee})
		end
	else
		for i, q in Config.HISTOIRE do
			local fait, actuel = i < etat.histoire, i == etat.histoire
			table.insert(t, {genre = "Histoire", id = q.id, quete = q, progres = if fait then q.cible elseif actuel then etat.histoireProgres else 0,
				reclamee = fait, verrouillee = i > etat.histoire})
		end
	end
	return t
end

local function aReclamer(el): boolean
	return not el.reclamee and not el.verrouillee and el.progres >= el.quete.cible
end

local function carteRecompense(image: string, rarete: number, quantite: number, ordre: number)
	local c = Style.carte(recompenses, {image = image, rarete = rarete, etoiles = false, texte = tostring(quantite)})
	c.case.LayoutOrder = ordre
	cree("UIScale", {Scale = 0.8}, c.case)
end

local function majDetail(el)
	detail.Visible = el ~= nil
	if not el then
		action.bouton.Visible = false
		return
	end
	local q = el.quete
	nomQuete.Text = q.nom
	local genre = if el.genre == "Hebdo" then "Weekly" elseif el.genre == "Histoire" then "Story" else "Daily"
	lieu.Text = genre .. " · " .. (q.lieu or "Anywhere")
	objectifTexte.Text = q.objectif
	avancement.Text = `{math.min(el.progres, q.cible)} / {q.cible}`
	remplissage.Size = UDim2.fromScale(math.clamp(el.progres / q.cible, 0, 1), 1)
	description.Text = if el.verrouillee then "Complete the previous step to unlock this one." else q.description
	for _, c in recompenses:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	local r, ordre = q.recompense or {}, 0
	if r.Or then ordre += 1; carteRecompense(IMAGES.piece, 5, r.Or, ordre) end
	if r.XP then ordre += 1; carteRecompense(IMAGES.etoile4, 4, r.XP, ordre) end
	for _, id in Objets.ORDRE do
		local n = (r.Materiaux or {})[id]
		local fiche = Objets.LISTE[id]
		if n and fiche then ordre += 1; carteRecompense(fiche.image, fiche.rarete, n, ordre) end
	end
	action.bouton.Visible = not el.reclamee and not el.verrouillee
	action.texte.Text = "Claim"
	action.activer(aReclamer(el) and not envoiEnCours)
end

local remplir: () -> ()   -- défini plus bas : une ligne choisie reconstruit la liste

local function ligne(el, ordre: number)
	local choisie = el.id == selection
	local fond = if choisie then CREME else FOND_LIGNE
	local b = cree("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = fond, BackgroundTransparency = if el.reclamee then 0.55 else 0.05,
		Size = UDim2.new(1, 0, 0, 94), LayoutOrder = ordre}, liste)
	arrondi(b, 4)
	if choisie then filet(b, BLANC, 2) end
	local couleur = if choisie then ARDOISE else CREME
	local attenue = if el.reclamee or el.verrouillee then 0.45 else 0
	texte(b, el.quete.nom, 30, couleur, {FontFace = Style.POLICE_TITRE, Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -110, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = attenue, TextTruncate = Enum.TextTruncate.AtEnd})
	local sous = if el.reclamee then "Claimed"
		elseif el.verrouillee then "Locked"
		elseif aReclamer(el) then "Complete · claim your reward"
		else `{math.min(el.progres, el.quete.cible)} / {el.quete.cible} · {el.quete.lieu or "Anywhere"}`
	texte(b, sous, 22, couleur, {Position = UDim2.fromOffset(22, 52), Size = UDim2.new(1, -110, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.25 + attenue * 0.5})
	if aReclamer(el) then
		local alerte = cadre(b, UDim2.fromOffset(26, 26), UDim2.new(1, -8, 0, -8), Color3.fromRGB(226, 86, 70))
		alerte.AnchorPoint = Vector2.new(0.5, 0.5)
		arrondi(alerte)
		texte(alerte, "!", 18, BLANC, {Size = UDim2.fromScale(1, 1)})
	end
	if choisie then
		-- losange doré de la quête choisie
		local losange = cadre(b, UDim2.fromOffset(26, 26), UDim2.new(1, -46, 0.5, 0), OR_VIF)
		losange.AnchorPoint, losange.Rotation = Vector2.new(0.5, 0.5), 45
		filet(losange, Color3.fromRGB(201, 147, 44), 3)
	end
	b.Activated:Connect(function()
		selection = el.id
		message.Text = ""
		remplir()   -- déplace la mise en avant
	end)
end

function remplir()
	for _, c in liste:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local els = elements(onglet)
	local trouve = nil
	for _, el in els do
		if el.id == selection then trouve = el end
	end
	if not trouve then
		-- par défaut : la première à réclamer, sinon la première en cours
		for _, el in els do
			if aReclamer(el) then trouve = el break end
		end
		if not trouve then
			for _, el in els do
				if not el.reclamee and not el.verrouillee then trouve = el break end
			end
		end
		trouve = trouve or els[1]
		selection = trouve and trouve.id
	end
	for i, el in els do ligne(el, i) end
	majDetail(trouve)
	for _, o in ONGLETS do
		local w = onglets[o.id]
		local actif = o.id == onglet
		w.pilule.Visible, w.etoile.Visible, w.rond.Visible = actif, actif, not actif
		w.icone.ImageColor3 = if actif then ARDOISE else CREME
		local attend = false
		for _, el in elements(o.id) do
			if aReclamer(el) then attend = true end
		end
		w.alerte.Visible = attend
		if actif then
			titre.Text = "Quests / " .. o.nom
			enteteListe.Text = o.titre
		end
	end
end

for id, w in onglets do
	w.bouton.Activated:Connect(function()
		if onglet == id then return end
		onglet, selection = id, nil
		message.Text = ""
		remplir()
	end)
end

-- compte à rebours de la remise à zéro
task.spawn(function()
	while true do
		if ouvert and etat then
			local fin = if onglet == "Hebdo" then etat.prochaineSemaine elseif onglet == "Quotidienne" then etat.prochainJour else nil
			if fin then
				local reste = math.max(0, math.floor(fin - workspace:GetServerTimeNow()))
				local j, h, m, s = reste // 86400, (reste % 86400) // 3600, (reste % 3600) // 60, reste % 60
				remise.Text = if j > 0 then string.format("Resets in %dd %02d:%02d:%02d", j, h, m, s)
					else string.format("Resets in %02d:%02d:%02d", h, m, s)
			else
				remise.Text = ""
			end
		end
		task.wait(1)
	end
end)

-- ---------------------------------------------------------------- ouverture et fermeture
local function ouvrir()
	if ouvert then return end
	ouvert = true
	reafficher = Style.masquerAutres(ecran)
	flou = cree("BlurEffect", {Name = "FlouQuetes", Size = 0}, Lighting)
	TweenService:Create(flou :: BlurEffect, TweenInfo.new(0.2), {Size = 18}):Play()
	voile.BackgroundTransparency = 1
	TweenService:Create(voile, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
	message.Text = ""
	remplir()
	ecran.Enabled = true
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
end

-- ouvre l'écran directement sur une quête (clic dans le suivi du HUD)
local function ouvrirSur(ongletVoulu: string, id: string)
	if ouvert then return end
	onglet, selection = ongletVoulu, id
	ouvrir()
end

local function fermerQuetes()
	if not ouvert then return end
	ouvert = false
	ecran.Enabled = false
	if reafficher then reafficher() end
	reafficher = nil
	if flou then flou:Destroy() end
	flou = nil
end

fermer.Activated:Connect(fermerQuetes)
UserInputService.InputBegan:Connect(function(entree, traite)
	if traite then return end
	if entree.KeyCode == Enum.KeyCode.J then
		if ouvert then fermerQuetes() else ouvrir() end
	elseif ouvert and entree.KeyCode == Enum.KeyCode.ButtonB then
		fermerQuetes()
	end
end)

-- l'or affiché suit l'attribut OrCombat du joueur (tenu à jour par le service Combat)
joueur:GetAttributeChangedSignal("OrCombat"):Connect(function()
	montantOr.Text = tostring(math.floor(joueur:GetAttribute("OrCombat") or 0))
end)

-- icône quêtes du HUD (Hud.luau, en haut à droite)
task.spawn(function()
	local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	local b = hud and hud:WaitForChild("Quetes", 30)
	if b then (b :: GuiButton).Activated:Connect(ouvrir) end
end)

action.bouton.Activated:Connect(function()
	if envoiEnCours or not action.estActif() or not selection then return end
	local el = nil
	for _, e in elements(onglet) do
		if e.id == selection then el = e end
	end
	if not el then return end
	envoiEnCours = true
	majDetail(el)
	local ok, reponse = ReclamerQuete:InvokeServer(el.genre, el.id)
	envoiEnCours = false
	message.Text = reponse or ""
	message.TextColor3 = if ok then Color3.fromRGB(150, 214, 64) else Color3.fromRGB(235, 110, 100)
	if ouvert then remplir() end
end)

-- ---------------------------------------------------------------- suivi dans le HUD, sous la mini-carte
-- Les quêtes en cours (l'étape d'histoire, puis les quotidiennes, celles à réclamer d'abord), trois au plus :
-- petite étoile, nom, objectif et avancement. Cliquer sur une ligne ouvre l'écran des quêtes sur elle.
-- Le cadre vit dans le ScreenGui du HUD : même échelle, et il se cache avec lui quand un menu s'ouvre.
local Hud = require(script.Parent:WaitForChild("Hud"))
local SUIVI_MAX = 3
local suivi = nil
local function creerSuivi()
	local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	if not hud then return end
	suivi = cadre(hud, UDim2.fromOffset(370, 0), UDim2.fromOffset(52, 276))
	suivi.Name = "SuiviQuetes"
	suivi.AutomaticSize = Enum.AutomaticSize.Y
	cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)}, suivi)
end

local function texteHud(parent, contenu: string, taille: number, couleur: Color3, proprietes)
	local l = texte(parent, contenu, taille, couleur, proprietes)
	l.FontFace = Hud.POLICE
	cree("UIStroke", {Color = Color3.fromRGB(72, 72, 72), Thickness = 1.2, Transparency = 0.1}, l)
	return l
end

local function majSuivi()
	if not suivi then return end
	for _, c in suivi:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if not etat then return end
	local choix = {}
	for _, el in elements("Histoire") do
		if not el.reclamee and not el.verrouillee then table.insert(choix, {onglet = "Histoire", el = el}) end
	end
	local quotidiennes = {}
	for _, el in elements("Quotidienne") do
		if el.genre == "Quotidienne" and not el.reclamee then table.insert(quotidiennes, el) end
	end
	table.sort(quotidiennes, function(a, b)
		local ra, rb = aReclamer(a), aReclamer(b)
		if ra ~= rb then return ra end
		return a.progres / a.quete.cible > b.progres / b.quete.cible
	end)
	for _, el in quotidiennes do table.insert(choix, {onglet = "Quotidienne", el = el}) end
	for i = 1, math.min(SUIVI_MAX, #choix) do
		local c, el = choix[i], choix[i].el
		local fini = aReclamer(el)
		local b = cree("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = i}, suivi)
		-- voile sombre en dégradé derrière la ligne, pour rester lisible sur le ciel
		local fond = cadre(b, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(0, 0, 0), 0.7)
		arrondi(fond, 12)
		cree("UIGradient", {Transparency = NumberSequence.new(0, 1)}, fond)
		-- petite étoile arrondie à quatre branches (comme les onglets des menus), dorée quand la quête est finie
		cree("ImageLabel", {Image = IMAGES.etoile4, ImageColor3 = if fini then Color3.fromRGB(250, 205, 104) else CREME,
			BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(18, 17)}, b)
		texteHud(b, el.quete.nom, 20, if fini then Color3.fromRGB(250, 205, 104) else BLANC, {Position = UDim2.fromOffset(36, 4),
			Size = UDim2.new(1, -44, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
		local ligneObjectif = if fini then "Complete · claim your reward"
			else `{el.quete.objectif}  {math.min(el.progres, el.quete.cible)}/{el.quete.cible}`
		texteHud(b, ligneObjectif, 16, Color3.fromRGB(222, 222, 214), {Position = UDim2.fromOffset(36, 31),
			Size = UDim2.new(1, -44, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
		b.MouseEnter:Connect(function() fond.BackgroundTransparency = 0.5 end)
		b.MouseLeave:Connect(function() fond.BackgroundTransparency = 0.7 end)
		b.Activated:Connect(function() ouvrirSur(c.onglet, el.id) end)
	end
end
task.spawn(function()
	creerSuivi()
	majSuivi()
end)

-- ---------------------------------------------------------------- données
local function recevoir(nouvel)
	if type(nouvel) ~= "table" then return end
	etat = nouvel
	if ouvert then remplir() end
	majSuivi()
end
QuetesChange.OnClientEvent:Connect(recevoir)
task.spawn(function()
	for _ = 1, 30 do
		local ok, e = pcall(function() return LireQuetes:InvokeServer() end)
		if ok and type(e) == "table" then
			recevoir(e)
			break
		end
		task.wait(2)
	end
end)
