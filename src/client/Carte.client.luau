-- Carte plein écran (03/10/2026), d'après la référence du joueur : la carte du lobby en grand sur fond bleu nuit,
-- noms des bâtiments en lettres blanches à contour, flèche du joueur, zoom (+ / − à gauche, molette) et
-- déplacement à la souris, nom du lieu en bas à droite. Même image que la mini-carte (ui/hud_v01/carte.py),
-- nord en haut (-Z), couvrant x et z de -210 à 210, découpée au cercle du rempart (ui/hud_v01/carte_cercle.py). S'ouvre par l'icône carte du HUD, un clic sur la
-- mini-carte ou la touche M. Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local Style = require(script.Parent:WaitForChild("StyleMenus"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Batiments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Batiments"))

local joueur = Players.LocalPlayer
local cree, arrondi, filet, texte, cadre = Style.cree, Style.arrondi, Style.filet, Style.texte, Style.cadre
local CREME, ARDOISE, BLANC = Style.CREME, Style.ARDOISE, Style.BLANC

local CARTE = {
	image = "rbxassetid://84856923036863", fleche = "rbxassetid://106719850484589", icone = "rbxassetid://96444988812766",
	origine = Vector2.new(-210, -210), cote = 420,   -- studs couverts par l'image
	taille = 960,                                    -- côté de la carte à l'écran au zoom 1 (écran de 1920 × 1080)
	zoomMin = 1, zoomMax = 3,
}
local SOCLES = {Academie_Magie = "Socle_Salle_Magie"}   -- socles nommés autrement que leur lot

-- ---------------------------------------------------------------- écran
local ecran, racine = Style.ecran("Carte", 20)
-- voile bleu nuit peu opaque : hors de la carte, on voit le jeu flouté
local fond = cadre(ecran, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(16, 24, 38), 0.6)

-- la vue (ce qui est à l'écran) et le plan (la carte, qu'on déplace et agrandit dedans)
local vue = cadre(racine, UDim2.fromScale(1, 1), UDim2.new())
vue.ClipsDescendants = true
local plan = cadre(vue, UDim2.fromOffset(CARTE.taille, CARTE.taille), UDim2.fromScale(0.5, 0.5))
plan.AnchorPoint = Vector2.new(0.5, 0.5)
local image = cree("ImageLabel", {Image = CARTE.image, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, plan)
-- la carte est un disque (le lobby est circulaire) : le cadre est arrondi en cercle pour que le liseré en fasse le tour
cree("UICorner", {CornerRadius = UDim.new(0.5, 0)}, image)
cree("UICorner", {CornerRadius = UDim.new(0.5, 0)}, plan)
-- liseré clair autour de l'image, comme le rivage de la référence
filet(plan, Color3.fromRGB(140, 220, 230), 2, 0.5)

local function versCarte(x: number, z: number): UDim2
	return UDim2.fromScale((x - CARTE.origine.X) / CARTE.cote, (z - CARTE.origine.Y) / CARTE.cote)
end

-- noms des lieux
local noms = {}
local lots = {}
for id, lot in Batiments.LOTS do lots[id] = {nom = lot.nom, position = lot.position} end
if Batiments.AUTOMATIQUES and Batiments.AUTOMATIQUES.Faille then
	lots.Faille = {nom = Batiments.AUTOMATIQUES.Faille.nom, position = {118, 50.5}}
end
for id, l in lots do
	local t = texte(plan, l.nom, 22, BLANC, {FontFace = Hud.POLICE, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(260, 30), Position = versCarte(l.position[1], l.position[2]), ZIndex = 3})
	cree("UIStroke", {Color = Color3.fromRGB(28, 32, 44), Thickness = 2, Transparency = 0.15}, t)
	noms[id] = t
end

-- position de chaque nom : centre du socle du lot quand il est chargé, sinon la position de la config
local function placerNoms()
	local sol = workspace:FindFirstChild("Batiments") and workspace.Batiments:FindFirstChild("Sol")
	for id, t in noms do
		local socle = sol and sol:FindFirstChild(SOCLES[id] or ("Socle_" .. id))
		if socle then
			local cf = if socle:IsA("Model") then socle:GetBoundingBox() else socle.CFrame
			t.Position = versCarte(cf.Position.X, cf.Position.Z)
		end
	end
end

-- flèche du joueur
local fleche = cree("ImageLabel", {Image = CARTE.fleche, BackgroundTransparency = 1, Size = UDim2.fromOffset(42, 42),
	AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4}, plan)

-- ---------------------------------------------------------------- habillage
cree("ImageLabel", {Image = CARTE.icone, BackgroundTransparency = 1, Size = UDim2.fromOffset(52, 52),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(200, 60)}, racine)
Style.titre(racine, "Map / Lobby")
local fermer = Style.boutonFermer(racine)

-- zoom : deux boutons ronds reliés par un trait, à gauche (comme la référence)
local function boutonZoom(signe: string, y: number)
	local b = cree("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(30, 38, 56),
		BackgroundTransparency = 0.2, Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 70, 0.5, y), ZIndex = 3}, racine)
	arrondi(b)
	filet(b, CREME, 2, 0.3)
	texte(b, signe, 34, CREME, {Size = UDim2.fromScale(1, 1), FontFace = Style.POLICE_TITRE, ZIndex = 4})
	return b
end
cadre(racine, UDim2.fromOffset(3, 230), UDim2.new(0, 69, 0.5, -115), CREME, 0.6)
local plus = boutonZoom("+", -140)
local moins = boutonZoom("−", 140)
local curseur = cadre(racine, UDim2.fromOffset(20, 20), UDim2.new(0, 70, 0.5, 0), CREME)
curseur.AnchorPoint, curseur.Rotation, curseur.ZIndex = Vector2.new(0.5, 0.5), 45, 3
filet(curseur, ARDOISE, 2)

-- nom du lieu en bas à droite
texte(racine, "Lobby", 44, BLANC, {FontFace = Hud.POLICE, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -60, 1, -78),
	Size = UDim2.fromOffset(600, 54), TextXAlignment = Enum.TextXAlignment.Right})
local sousTitre = texte(racine, "", 26, CREME, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -60, 1, -44),
	Size = UDim2.fromOffset(600, 34), TextXAlignment = Enum.TextXAlignment.Right})

-- ---------------------------------------------------------------- zoom et déplacement
local zoom = 1
local decalage = Vector2.zero   -- déplacement du centre de la carte par rapport au centre de l'écran (px de design)

local function limiter()
	-- la carte ne quitte pas l'écran : on peut aller jusqu'à ses bords, pas au-delà
	local demi = CARTE.taille * zoom / 2
	local limite = math.max(0, demi - 300)
	decalage = Vector2.new(math.clamp(decalage.X, -limite, limite), math.clamp(decalage.Y, -limite, limite))
end

local function appliquer(anime: boolean?)
	limiter()
	local cible = {Size = UDim2.fromOffset(CARTE.taille * zoom, CARTE.taille * zoom),
		Position = UDim2.new(0.5, decalage.X, 0.5, decalage.Y)}
	if anime then
		TweenService:Create(plan, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), cible):Play()
	else
		plan.Size, plan.Position = cible.Size, cible.Position
	end
	local t = (zoom - CARTE.zoomMin) / (CARTE.zoomMax - CARTE.zoomMin)
	curseur.Position = UDim2.new(0, 70, 0.5, 100 - 200 * t)
end

local function zoomer(facteur: number)
	local ancien = zoom
	zoom = math.clamp(zoom * facteur, CARTE.zoomMin, CARTE.zoomMax)
	decalage *= zoom / ancien   -- garde le même point au centre de l'écran
	appliquer(true)
end
plus.Activated:Connect(function() zoomer(1.4) end)
moins.Activated:Connect(function() zoomer(1 / 1.4) end)

-- centre la carte sur le joueur
local function centrerSurJoueur()
	local r = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local u = (r.Position.X - CARTE.origine.X) / CARTE.cote - 0.5
	local v = (r.Position.Z - CARTE.origine.Y) / CARTE.cote - 0.5
	decalage = Vector2.new(-u, -v) * CARTE.taille * zoom
end

-- ---------------------------------------------------------------- ouverture et fermeture
local ouvert = false
local reafficher = nil
local flou: BlurEffect? = nil
local glisse: Vector2? = nil
local suivi: RBXScriptConnection? = nil

local molette: (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult   -- défini plus bas

local function ouvrir()
	if ouvert then return end
	ouvert = true
	reafficher = Style.masquerAutres(ecran)
	flou = cree("BlurEffect", {Name = "FlouCarte", Size = 0}, Lighting)
	TweenService:Create(flou :: BlurEffect, TweenInfo.new(0.2), {Size = 18}):Play()
	placerNoms()
	zoom = 1.6
	centrerSurJoueur()
	appliquer(false)
	ecran.Enabled = true
	ContextActionService:BindActionAtPriority("MoletteCarte", molette, false, Enum.ContextActionPriority.High.Value + 10,
		Enum.UserInputType.MouseWheel)
	suivi = RunService.RenderStepped:Connect(function()
		local r = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		if r then
			fleche.Visible = true
			fleche.Position = versCarte(r.Position.X, r.Position.Z)
			local regard = r.CFrame.LookVector
			fleche.Rotation = math.deg(math.atan2(regard.X, -regard.Z))
		else
			fleche.Visible = false
		end
	end)
end

local function fermerCarte()
	if not ouvert then return end
	ouvert = false
	ecran.Enabled = false
	glisse = nil
	ContextActionService:UnbindAction("MoletteCarte")
	if suivi then suivi:Disconnect() end
	suivi = nil
	if reafficher then reafficher() end
	reafficher = nil
	if flou then flou:Destroy() end
	flou = nil
end
fermer.Activated:Connect(fermerCarte)

-- glisser la carte, molette pour zoomer
vue.InputBegan:Connect(function(entree)
	if entree.UserInputType == Enum.UserInputType.MouseButton1 or entree.UserInputType == Enum.UserInputType.Touch then
		glisse = Vector2.new(entree.Position.X, entree.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(entree)
	if entree.UserInputType == Enum.UserInputType.MouseButton1 or entree.UserInputType == Enum.UserInputType.Touch then
		glisse = nil
	end
end)
UserInputService.InputChanged:Connect(function(entree)
	if not ouvert then return end
	if glisse and (entree.UserInputType == Enum.UserInputType.MouseMovement or entree.UserInputType == Enum.UserInputType.Touch) then
		local p = Vector2.new(entree.Position.X, entree.Position.Y)
		local echelle = racine:FindFirstChildOfClass("UIScale")
		decalage += (p - glisse) / (if echelle then echelle.Scale else 1)
		glisse = p
		appliquer(false)
	end
end)

-- molette : zoome la carte et rien d'autre (la caméra du héros ne bouge pas tant que la carte est ouverte)
function molette(_, etatEntree, entree)
	if ouvert and etatEntree == Enum.UserInputState.Change then
		zoomer(if entree.Position.Z > 0 then 1.15 else 1 / 1.15)
	end
	return Enum.ContextActionResult.Sink
end

UserInputService.InputBegan:Connect(function(entree, traite)
	if traite then return end
	if entree.KeyCode == Enum.KeyCode.M then
		if ouvert then fermerCarte() else ouvrir() end
	elseif ouvert and entree.KeyCode == Enum.KeyCode.ButtonB then
		fermerCarte()
	end
end)

-- icône carte du HUD, et clic sur la mini-carte
task.spawn(function()
	local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	if not hud then return end
	local b = hud:WaitForChild("Carte", 30)
	if b then (b :: GuiButton).Activated:Connect(ouvrir) end
	local mini = hud:WaitForChild("MiniCarte", 30)
	if mini then
		local clic = cree("TextButton", {Name = "OuvrirCarte", Text = "", BackgroundTransparency = 1, Size = mini.Size,
			Position = mini.Position, AnchorPoint = mini.AnchorPoint, ZIndex = 10}, hud)
		arrondi(clic)
		clic.Activated:Connect(ouvrir)
	end
end)

-- nom du propriétaire de la base, sous « Lobby »
task.spawn(function()
	local reseau = ReplicatedStorage:WaitForChild("Reseau")
	local EtatBase = reseau:WaitForChild("EtatBase")
	local function maj(e)
		if type(e) == "table" and e.proprietaireNom and e.proprietaireNom ~= "" then
			sousTitre.Text = if e.proprietaireId == joueur.UserId then "Your base" else e.proprietaireNom .. "'s base"
		end
	end
	EtatBase.OnClientEvent:Connect(maj)
	local ok, e = pcall(function() return reseau:WaitForChild("LireEtat"):InvokeServer() end)
	if ok then maj(e) end
end)
