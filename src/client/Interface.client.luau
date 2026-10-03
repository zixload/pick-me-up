-- Panneau d'un bâtiment (03/10/2026), dans le style des menus plein écran (StyleMenus, comme l'inventaire) :
-- s'ouvre à la borne du lot ; la caméra cadre le bâtiment à gauche, du côté où se tient le joueur ; à droite,
-- la fiche (bandeau du nom, niveau et style actuels, coût en cartes « possédé / demandé », conditions,
-- les trois styles P1/P2/P3) et le bouton « Upgrade » (ou « Build ») en pilule claire.
-- Le serveur fait foi (Regles.verifier, remote Ameliorer) : ce script ne fait qu'afficher et demander.
-- Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Batiments = require(Shared.Config.Batiments)
local Materiaux = require(Shared.Config.Materiaux)
local Objets = require(Shared.Config.Objets)
local Regles = require(Shared.Regles)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local EtatBase = reseau:WaitForChild("EtatBase")
local LireEtat = reseau:WaitForChild("LireEtat")
local Ameliorer = reseau:WaitForChild("Ameliorer")

local joueur = Players.LocalPlayer
local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, ARDOISE, BLANC = Style.CREME, Style.ARDOISE, Style.BLANC
local TEXTE_FONCE, TEXTE_DESC = Style.TEXTE_FONCE, Style.TEXTE_DESC
local OR_BARRE = Color3.fromRGB(226, 201, 138)
local SOCLES = {Academie_Magie = "Socle_Salle_Magie"}   -- socles nommés autrement que leur lot
-- styles : matériaux montrés sous chaque palier
local STYLES = {
	{nom = "P1", niveau = 1},
	{nom = "P2", niveau = 5},
	{nom = "P3", niveau = 20},
}

local function milliers(n: number): string
	local s = tostring(math.floor(n))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("PanneauBatiment", 19)
-- le bâtiment reste visible à gauche ; la droite s'assombrit sous la fiche
local voile = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(18, 26, 42), 0)
cree("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
	NumberSequenceKeypoint.new(0.62, 0.25), NumberSequenceKeypoint.new(1, 0.1),
})}, voile)

cree("ImageLabel", {Image = Style.IMAGES.constructions, ImageColor3 = Style.OR_PALE, BackgroundTransparency = 1,
	Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(110, 60)}, racine)
local titre = Style.titre(racine, "Buildings")
local montantOr = Style.bourse(racine)
local fermer = Style.boutonFermer(racine)

-- ---------------------------------------------------------------- fiche (à droite)
local fiche = cadre(racine, UDim2.fromOffset(640, 800), UDim2.new(1, -60, 0, 150))
fiche.AnchorPoint = Vector2.new(1, 0)
local nomBatiment = Style.entete(fiche)

local infos = cadre(fiche, UDim2.new(1, 0, 0, 170), UDim2.fromOffset(0, 72), BLANC)
cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(80, 88, 114), Color3.fromRGB(62, 68, 90))}, infos)
local niveau = texte(infos, "", 52, BLANC, {FontFace = Style.POLICE_TITRE, RichText = true, Position = UDim2.fromOffset(36, 16),
	Size = UDim2.new(1, -72, 0, 64), TextXAlignment = Enum.TextXAlignment.Left})
local barre = cadre(infos, UDim2.new(1, -72, 0, 10), UDim2.fromOffset(36, 92), BLANC, 0.85)
arrondi(barre)
local remplissage = cadre(barre, UDim2.fromScale(0, 1), UDim2.new(), OR_BARRE)
arrondi(remplissage)
local styleActuel = texte(infos, "", 27, CREME, {Position = UDim2.fromOffset(36, 116), Size = UDim2.new(1, -72, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left})

local corps = cree("ScrollingFrame", {BackgroundColor3 = CREME, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 242),
	Size = UDim2.new(1, 0, 1, -242), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4, ScrollBarImageColor3 = TEXTE_DESC}, fiche)
cree("UIPadding", {PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36), PaddingTop = UDim.new(0, 30),
	PaddingBottom = UDim.new(0, 30)}, corps)
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 18)}, corps)

local section = texte(corps, "", 32, TEXTE_FONCE, {FontFace = Style.POLICE_TITRE, Size = UDim2.new(1, 0, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1})
-- cartes du coût, réduites à 80 % (123 × 152)
local ligneCartes = cadre(corps, UDim2.new(1, 0, 0, 162), UDim2.new())
ligneCartes.LayoutOrder = 2
cree("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center}, ligneCartes)
local conditions = cadre(corps, UDim2.new(1, 0, 0, 0), UDim2.new())
conditions.AutomaticSize, conditions.LayoutOrder = Enum.AutomaticSize.Y, 3
cree("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, conditions)
Style.separateur(corps, Color3.fromRGB(184, 154, 90)).LayoutOrder = 4
texte(corps, "Building styles", 30, TEXTE_FONCE, {FontFace = Style.POLICE_TITRE, Size = UDim2.new(1, 0, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5})
-- les trois styles : losange plein pour ceux atteints, contour pour les autres, reliés par un trait
local piste = cadre(corps, UDim2.new(1, 0, 0, 70), UDim2.new())
piste.LayoutOrder = 6
cadre(piste, UDim2.new(1, -80, 0, 2), UDim2.new(0, 40, 0, 16), TEXTE_DESC, 0.6)
local jalons = {}
for i, s in STYLES do
	local x = (i - 1) / (#STYLES - 1)
	local losange = cadre(piste, UDim2.fromOffset(20, 20), UDim2.new(x, if i == 1 then 40 elseif i == #STYLES then -40 else 0, 0, 17), CREME)
	losange.AnchorPoint, losange.Rotation = Vector2.new(0.5, 0.5), 45
	local trait = filet(losange, TEXTE_FONCE, 2)
	local etiquette = texte(piste, s.nom .. " · Lv. " .. s.niveau, 24, TEXTE_DESC, {AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(x, if i == 1 then 40 elseif i == #STYLES then -40 else 0, 0, 36), Size = UDim2.fromOffset(160, 30)})
	jalons[i] = {losange = losange, trait = trait, etiquette = etiquette}
end
local message = texte(corps, "", 27, Style.ROUGE, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 7})

local action = Style.boutonAction(racine, "Upgrade", Style.IMAGES.fleche_haut)

-- ---------------------------------------------------------------- état
local etat = nil
local lotOuvert: string? = nil
local borneOuverte: BasePart? = nil
local envoiEnCours = false
local messageServeur: string? = nil   -- réponse à la dernière demande (prioritaire sur la raison du refus)
local messageOk = false
local reafficher = nil
local cameraAvant: Enum.CameraType? = nil

local function estProprietaire()
	return etat and etat.proprietaireId == joueur.UserId
end

local function ligneCondition(contenu: string, remplie: boolean, ordre: number)
	texte(conditions, "· " .. contenu, 27, if remplie then Style.VERT else Style.ROUGE, {Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ordre})
end

local function carteCout(image: string, rarete: number, possede: number, demande: number, ordre: number, etoiles: boolean)
	local c = Style.carte(ligneCartes, {image = image, rarete = rarete, etoiles = etoiles,
		texte = `{milliers(possede)}/{milliers(demande)}`, couleurTexte = if possede >= demande then TEXTE_FONCE else Style.ROUGE})
	c.case.LayoutOrder = ordre
	c.bas.TextSize = 24
	cree("UIScale", {Scale = 0.8}, c.case)
end

local function maj()
	if not lotOuvert then return end
	local lot = Batiments.LOTS[lotOuvert]
	nomBatiment.Text = lot.nom
	titre.Text = "Buildings / " .. lot.nom
	for _, c in ligneCartes:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, c in conditions:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	if not etat or not etat.donnees then
		niveau.Text, styleActuel.Text, section.Text = "Loading…", "", ""
		action.activer(false)
		return
	end
	local d = etat.donnees
	montantOr.Text = tostring(math.floor(d.Or or 0))
	local ok, raison, detail = Regles.verifier(d, lotOuvert)
	local n = detail.niveau or 0
	niveau.Text = if n == 0 then "Not built" else `Lv. {n} <font size="30" color="#ECE5D8">/ {Batiments.NIVEAU_MAX}</font>`
	remplissage.Size = UDim2.fromScale(n / Batiments.NIVEAU_MAX, 1)
	local palier = detail.palierActuel or 1
	local mats = Materiaux.PAR_PALIER[palier] or Materiaux.PAR_PALIER[1]
	styleActuel.Text = `Style P{palier} · {Materiaux.NOMS[mats[1]]} & {Materiaux.NOMS[mats[2]]}`
	for i, j in jalons do
		local atteint = n >= STYLES[i].niveau
		j.losange.BackgroundColor3 = if atteint then OR_BARRE else CREME
		j.trait.Color = if atteint then Color3.fromRGB(150, 118, 66) else TEXTE_DESC
		j.etiquette.TextColor3 = if i == palier and n > 0 then TEXTE_FONCE else TEXTE_DESC
	end

	if n >= Batiments.NIVEAU_MAX then
		section.Text = "Max level reached"
		ligneCartes.Visible = false
	else
		ligneCartes.Visible = true
		section.Text = if n == 0 then "Build" else `Upgrade to Lv. {detail.cible}`
		carteCout(Style.IMAGES.piece, 5, d.Or or 0, detail.cout, 1, false)
		for i, m in detail.materiaux do
			local fiche_ = Objets.LISTE[m[1]]
			carteCout(fiche_ and fiche_.image or "", fiche_ and fiche_.rarete or 1, d.Materiaux and d.Materiaux[m[1]] or 0, m[2], i + 1, true)
		end
		local ordre = 0
		if detail.parent then
			local id, requis = detail.parent[1], detail.parent[2]
			ordre += 1
			ligneCondition(`{Batiments.LOTS[id].nom} level {requis}`, (d.Batiments[id] or 0) >= requis, ordre)
		end
		if (detail.etage or 0) > 0 then
			ordre += 1
			ligneCondition(`Tower Floor {detail.etage} cleared`, (d.Etage or 0) >= detail.etage, ordre)
		end
		if detail.palierCible and detail.palierCible ~= palier and n > 0 then
			ordre += 1
			ligneCondition(`Unlocks style P{detail.palierCible}`, true, ordre)
		end
	end

	local peut = ok and estProprietaire() and not envoiEnCours
	action.texte.Text = if n == 0 then "Build" else "Upgrade"
	action.activer(peut)
	action.bouton.Visible = n < Batiments.NIVEAU_MAX
	if messageServeur then
		message.Text, message.TextColor3 = messageServeur, if messageOk then Style.VERT else Style.ROUGE
	elseif not estProprietaire() then
		message.Text, message.TextColor3 = `Only {etat.proprietaireNom} can upgrade this base.`, TEXTE_DESC
	else
		message.Text, message.TextColor3 = if ok then "" else (raison or ""), Style.ROUGE
	end
end

-- ---------------------------------------------------------------- caméra : le bâtiment à gauche de l'écran
local function cadrer(lotId: string)
	local lot = Batiments.LOTS[lotId]
	local scene = workspace:FindFirstChild("Batiments")
	local modele = scene and scene:FindFirstChild(lot.visuels[1])
	if not modele and scene and scene:FindFirstChild("Sol") then
		modele = scene.Sol:FindFirstChild(SOCLES[lotId] or ("Socle_" .. lotId))
	end
	local centre, taille
	if modele and modele:IsA("Model") then
		local cf, s = modele:GetBoundingBox()
		centre, taille = cf.Position, s
	else
		centre, taille = Vector3.new(lot.position[1], 0, lot.position[2]), Vector3.new(30, 12, 30)
	end
	local perso = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	local cote = if perso then (perso.Position - centre) * Vector3.new(1, 0, 1) else Vector3.zero
	cote = if cote.Magnitude > 1 then cote.Unit else Vector3.new(0, 0, -1)
	local rayon, h = math.max(taille.X, taille.Z) / 2, taille.Y
	local distance = math.max(rayon * 2.2, h * 1.6, 30)
	local position = centre + cote * distance + Vector3.yAxis * (h * 0.45 + distance * 0.18)
	local regard = (centre - position).Unit
	local droite = regard:Cross(Vector3.yAxis).Unit
	local cible = centre + Vector3.yAxis * (h * 0.15) + droite * (distance * 0.38)
	local camera = workspace.CurrentCamera
	cameraAvant = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = CFrame.lookAt(position, cible)}):Play()
end

local function rendreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = if cameraAvant and cameraAvant ~= Enum.CameraType.Scriptable then cameraAvant else Enum.CameraType.Custom
	local humain = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if humain then camera.CameraSubject = humain end
	cameraAvant = nil
end

-- ---------------------------------------------------------------- ouverture et fermeture
local function fermerPanneau()
	if not lotOuvert then return end
	lotOuvert, borneOuverte = nil, nil
	ecran.Enabled = false
	if reafficher then reafficher() end
	reafficher = nil
	rendreCamera()
end

local demanderEtat: () -> ()   -- défini plus bas, avec la réception de l'état

local function ouvrir(lotId: string, borne: BasePart)
	if lotOuvert == lotId then return end
	if lotOuvert then fermerPanneau() end
	lotOuvert, borneOuverte = lotId, borne
	messageServeur = nil
	reafficher = Style.masquerAutres(ecran)
	maj()
	ecran.Enabled = true
	cadrer(lotId)
	if not (etat and etat.donnees) then task.spawn(demanderEtat) end
end

local function recevoir(nouvelEtat)
	etat = nouvelEtat
	maj()
end

-- l'état arrive par EtatBase à chaque changement ; on le demande aussi au démarrage, puis toutes les deux secondes
-- tant que la sauvegarde du propriétaire n'est pas chargée (sinon un panneau ouvert tôt resterait sur « Loading… »)
function demanderEtat()
	local ok, e = pcall(function() return LireEtat:InvokeServer() end)
	if ok and type(e) == "table" then recevoir(e) end
end
EtatBase.OnClientEvent:Connect(recevoir)
task.spawn(function()
	for _ = 1, 60 do
		demanderEtat()
		if etat and etat.donnees then break end
		task.wait(2)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(invite)
	local lotId = invite:GetAttribute("LotId")
	if lotId and Batiments.LOTS[lotId] then
		ouvrir(lotId, invite.Parent)
	end
end)

fermer.Activated:Connect(fermerPanneau)
UserInputService.InputBegan:Connect(function(entree, traite)
	if lotOuvert and not traite and entree.KeyCode == Enum.KeyCode.ButtonB then fermerPanneau() end
end)

action.bouton.Activated:Connect(function()
	if not lotOuvert or envoiEnCours or not action.estActif() then return end
	envoiEnCours = true
	maj()
	local ok, reponse = Ameliorer:InvokeServer(lotOuvert)
	envoiEnCours = false
	messageServeur, messageOk = reponse, ok == true
	maj()
end)

-- le panneau se ferme quand on s'éloigne de la borne
RunService.Heartbeat:Connect(function()
	if not borneOuverte then return end
	local racinePerso = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not racinePerso or (racinePerso.Position - borneOuverte.Position).Magnitude > 26 then
		fermerPanneau()
	end
end)
