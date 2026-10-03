-- Style commun des menus plein écran (inventaire, panneau des bâtiments…), d'après la référence du joueur
-- (03/10/2026) : couleurs, police, cartes d'objet par rareté, bouton fermer rond, bouton d'action en pilule,
-- bandeau titre à filet fin, mise à l'échelle depuis un écran de 1920 × 1080, interfaces masquées pendant l'ouverture.
local Players = game:GetService("Players")

local Style = {}

-- Nunito : la plus proche de la police de la référence parmi celles de Roblox (comparaison du 03/10/2026)
Style.POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
Style.POLICE_TITRE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)

Style.CREME = Color3.fromRGB(236, 229, 216)
Style.OR_PALE = Color3.fromRGB(219, 203, 165)     -- titres en haut à gauche
Style.ARDOISE = Color3.fromRGB(59, 66, 85)        -- texte et icônes sur fond clair
Style.TEXTE_FONCE = Color3.fromRGB(73, 83, 102)   -- quantités, effets, intitulés sur fond clair
Style.TEXTE_DESC = Color3.fromRGB(118, 121, 131)  -- texte courant sur fond clair
Style.ROUGE = Color3.fromRGB(196, 72, 60)         -- manque, refus (sur fond clair)
Style.VERT = Color3.fromRGB(82, 150, 76)          -- condition remplie (sur fond clair)
Style.FOND_ENTETE = Color3.fromRGB(92, 100, 128)
Style.BLANC = Color3.new(1, 1, 1)
-- dégradé des cartes selon la rareté : haut (plus sombre) -> bas
Style.RARETES = {
	{Color3.fromRGB(104, 108, 128), Color3.fromRGB(146, 148, 162)},
	{Color3.fromRGB(46, 96, 92), Color3.fromRGB(78, 150, 126)},
	{Color3.fromRGB(70, 94, 148), Color3.fromRGB(86, 140, 198)},
	{Color3.fromRGB(90, 78, 140), Color3.fromRGB(158, 116, 198)},
	{Color3.fromRGB(148, 94, 58), Color3.fromRGB(206, 130, 64)},
}
Style.IMAGES = {
	sac = "rbxassetid://97951001415611",           -- icônes du HUD (ui/hud_v01)
	constructions = "rbxassetid://75975097949320",
	etoile4 = "rbxassetid://73972245179955",       -- ui/inventaire_v01
	lueur = "rbxassetid://91456071127279",
	etoile = "rbxassetid://86250761898445",
	piece = "rbxassetid://134775045623355",
	epingle = "rbxassetid://99198141695774",
	bandeau = "rbxassetid://124393149078149",
	fanion = "rbxassetid://114982685153407",
	pastille = "rbxassetid://95746858867493",      -- fond du rond des boutons d'action
	fleche_haut = "rbxassetid://116627647332463",
	quetes = "rbxassetid://122967294472296",          -- icône du HUD
	onglet_quotidien = "rbxassetid://121228905160706",
	onglet_hebdo = "rbxassetid://89248754852567",
	onglet_histoire = "rbxassetid://115097566438449",
}

-- ---------------------------------------------------------------- briques
function Style.cree(classe: string, proprietes, parent: Instance?)
	local i = Instance.new(classe)
	for k, v in proprietes do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end
local cree = Style.cree

function Style.arrondi(parent, rayon: number?)
	return cree("UICorner", {CornerRadius = if rayon then UDim.new(0, rayon) else UDim.new(1, 0)}, parent)
end
local arrondi = Style.arrondi

function Style.filet(parent, couleur: Color3, epaisseur: number, transparence: number?)
	return cree("UIStroke", {Color = couleur, Thickness = epaisseur, Transparency = transparence or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
end
local filet = Style.filet

function Style.texte(parent, contenu: string, taille: number, couleur: Color3, proprietes)
	local t = cree("TextLabel", {BackgroundTransparency = 1, FontFace = Style.POLICE, Text = contenu, TextSize = taille,
		TextColor3 = couleur}, parent)
	if proprietes then
		for k, v in proprietes do (t :: any)[k] = v end
	end
	return t
end
local texte = Style.texte

function Style.cadre(parent, taille: UDim2, position: UDim2, couleur: Color3?, transparence: number?)
	return cree("Frame", {Size = taille, Position = position, BackgroundColor3 = couleur or Style.BLANC,
		BackgroundTransparency = transparence or (if couleur then 0 else 1), BorderSizePixel = 0}, parent)
end
local cadre = Style.cadre

-- ---------------------------------------------------------------- écran plein
-- ScreenGui caché + racine dessinée en 1920 × 1080 (pleine largeur : ce qui est calé à gauche colle au bord).
function Style.ecran(nom: string, ordre: number)
	local joueur = Players.LocalPlayer
	local ecran = cree("ScreenGui", {Name = nom, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = ordre,
		Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, joueur:WaitForChild("PlayerGui"))
	-- libère la souris (mode visée) tant que l'écran est ouvert
	cree("TextButton", {Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1)}, ecran)
	local racine = cadre(ecran, UDim2.fromOffset(1920, 1080), UDim2.fromScale(0.5, 0.5))
	racine.AnchorPoint = Vector2.new(0.5, 0.5)
	racine.ZIndex = 2
	local echelle = cree("UIScale", {}, racine)
	local function ajuster()
		local vue = workspace.CurrentCamera.ViewportSize
		local s = math.min(vue.Y / 1080, vue.X / 1500)
		echelle.Scale = s
		racine.Size = UDim2.fromOffset(vue.X / s, vue.Y / s)
	end
	ajuster()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajuster)
	return ecran, racine
end

-- masque les autres interfaces du joueur (HUD…) et renvoie de quoi les réafficher
function Style.masquerAutres(garde: ScreenGui): () -> ()
	local caches = {}
	for _, g in Players.LocalPlayer.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= garde and g.Enabled then
			g.Enabled = false
			table.insert(caches, g)
		end
	end
	return function()
		for _, g in caches do
			if g.Parent then g.Enabled = true end
		end
	end
end

-- ---------------------------------------------------------------- éléments
-- titre en haut à gauche (« Inventory / Materials »), assez à droite pour ne pas passer sous les boutons de Roblox
function Style.titre(racine, contenu: string)
	return texte(racine, contenu, 34, Style.OR_PALE, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(250, 60),
		Size = UDim2.fromOffset(900, 44), TextXAlignment = Enum.TextXAlignment.Left})
end

-- bouton fermer : rond clair, anneau blanc translucide, croix ardoise
function Style.boutonFermer(racine)
	local b = cree("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Style.CREME, Size = UDim2.fromOffset(72, 72),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -96, 0, 60), ZIndex = 3}, racine)
	arrondi(b)
	filet(b, Style.BLANC, 5, 0.55)
	for _, angle in {45, -45} do
		local barre = cadre(b, UDim2.fromOffset(36, 6), UDim2.fromScale(0.5, 0.5), Style.ARDOISE)
		barre.AnchorPoint, barre.Rotation = Vector2.new(0.5, 0.5), angle
		arrondi(barre, 3)
	end
	return b
end

-- or du joueur : pilule sombre à gauche du bouton fermer ; renvoie l'étiquette du montant
function Style.bourse(racine)
	local bourse = cadre(racine, UDim2.fromOffset(200, 54), UDim2.new(1, -150, 0, 60), Color3.fromRGB(26, 32, 46), 0.35)
	bourse.AnchorPoint = Vector2.new(1, 0.5)
	arrondi(bourse)
	filet(bourse, Style.BLANC, 1.5, 0.85)
	cree("ImageLabel", {Image = Style.IMAGES.piece, BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0)}, bourse)
	return texte(bourse, "0", 32, Style.BLANC, {Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(54, 0)})
end

-- bandeau titre d'une fiche : fond ardoise bleutée, filet fin intérieur, losange à chaque bout ; renvoie le texte
function Style.entete(parent, hauteur: number?)
	local h = hauteur or 72
	local entete = cadre(parent, UDim2.new(1, 0, 0, h), UDim2.new(), Style.FOND_ENTETE)
	local interieur = cadre(entete, UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6))
	filet(interieur, Color3.fromRGB(198, 204, 220), 1.5, 0.2)
	for _, x in {0, 1} do
		local losange = cadre(entete, UDim2.fromOffset(13, 13), UDim2.new(x, if x == 0 then 8 else -8, 0.5, 0), Style.FOND_ENTETE)
		losange.AnchorPoint, losange.Rotation, losange.ZIndex = Vector2.new(0.5, 0.5), 45, 2
		filet(losange, Color3.fromRGB(198, 204, 220), 1.5, 0.2)
	end
	local nom = texte(entete, "", 46, Style.BLANC, {FontFace = Style.POLICE_TITRE, Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -72, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3})
	cree("UIStroke", {Color = Color3.fromRGB(40, 46, 64), Thickness = 1, Transparency = 0.6}, nom)
	return nom, entete
end

-- séparateur fin terminé par deux petits losanges
function Style.separateur(parent, couleur: Color3)
	local s = cadre(parent, UDim2.new(1, 0, 0, 12), UDim2.new())
	local ligne = cadre(s, UDim2.new(1, -24, 0, 1), UDim2.new(0, 12, 0.5, 0), couleur, 0.35)
	ligne.AnchorPoint = Vector2.new(0, 0.5)
	for _, x in {0, 1} do
		local l = cadre(s, UDim2.fromOffset(7, 7), UDim2.new(x, if x == 0 then 6 else -6, 0.5, 0), couleur, 0.2)
		l.AnchorPoint, l.Rotation = Vector2.new(0.5, 0.5), 45
	end
	return s
end

-- bouton d'action en pilule claire, en bas à droite : pastille ardoise cerclée d'or avec une icône dorée
-- (icone : image blanche teintée, par défaut la petite étoile), libellé ardoise
function Style.boutonAction(racine, libelle: string, icone: string?)
	local b = cree("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Style.CREME, Size = UDim2.fromOffset(300, 80),
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -70, 1, -40), ZIndex = 3}, racine)
	arrondi(b)
	local pastille = cree("ImageLabel", {Image = Style.IMAGES.pastille, BackgroundTransparency = 1, Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 4}, b)
	local symbole = cree("ImageLabel", {Image = icone or Style.IMAGES.etoile4, ImageColor3 = Color3.fromRGB(232, 196, 110),
		BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5}, pastille)
	local etiquette = texte(b, libelle, 40, Style.ARDOISE, {Position = UDim2.fromOffset(74, 0), Size = UDim2.new(1, -84, 1, 0), ZIndex = 4})
	local actif = true
	local bouton = {bouton = b, texte = etiquette, icone = symbole}
	function bouton.activer(oui: boolean)
		actif = oui
		b.BackgroundTransparency = if oui then 0 else 0.45
		etiquette.TextTransparency = if oui then 0 else 0.45
		pastille.ImageTransparency = if oui then 0 else 0.5
		symbole.ImageTransparency = if oui then 0 else 0.5
	end
	function bouton.estActif(): boolean
		return actif
	end
	-- léger grossissement au survol
	local grossir = cree("UIScale", {}, b)
	b.MouseEnter:Connect(function()
		if actif then grossir.Scale = 1.03 end
	end)
	b.MouseLeave:Connect(function()
		grossir.Scale = 1
	end)
	return bouton
end

-- carte d'objet (154 × 190) : couleur de rareté, coin bas droit arrondi, icône, étoiles, bande claire avec un texte.
-- Renvoie {case, contour, lueur, badge, bas}. options : image, rarete, texte, couleurTexte, etoiles (true par défaut).
function Style.carte(parent, options)
	local rarete = math.clamp(options.rarete or 1, 1, 5)
	local degrade = Style.RARETES[rarete]
	local case = cadre(parent, UDim2.fromOffset(154, 190), UDim2.new())
	arrondi(case, 8)   -- arrondit aussi le contour de sélection
	local lueur = cree("ImageLabel", {Image = Style.IMAGES.lueur, ImageColor3 = Style.BLANC, ImageTransparency = 0.45,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1.45, 1.35), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Visible = false}, case)
	local corps = cree("CanvasGroup", {BackgroundColor3 = Style.CREME, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 2}, case)
	arrondi(corps, 8)
	-- zone de couleur : le haut dépasse (coins cachés), le bas gauche est comblé, seul le bas droit reste arrondi
	local couleur = cadre(corps, UDim2.new(1, 0, 0, 192), UDim2.fromOffset(0, -40), Style.BLANC)
	arrondi(couleur, 26)
	cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(degrade[1], degrade[2])}, couleur)
	cadre(corps, UDim2.fromOffset(30, 30), UDim2.fromOffset(0, 122), degrade[2])
	cree("ImageLabel", {Image = options.image or "", BackgroundTransparency = 1, Size = UDim2.fromOffset(124, 124),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(77, 72)}, corps)
	if options.etoiles ~= false then
		local etoiles = cadre(corps, UDim2.fromOffset(rarete * 25, 26), UDim2.fromOffset(77, 142))
		etoiles.AnchorPoint = Vector2.new(0.5, 0.5)
		cree("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, -1)}, etoiles)
		for _ = 1, rarete do
			cree("ImageLabel", {Image = Style.IMAGES.etoile, BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26)}, etoiles)
		end
	end
	local bas = texte(corps, options.texte or "", 28, options.couleurTexte or Style.TEXTE_FONCE,
		{Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 36)})
	local contour = filet(case, Style.BLANC, 3)
	contour.Enabled = false
	-- badge « New » en haut à droite, avec sa petite étoile
	local badge = cadre(case, UDim2.fromOffset(84, 38), UDim2.new(1, 8, 0, -10), Style.BLANC)
	badge.AnchorPoint, badge.ZIndex, badge.Visible = Vector2.new(1, 0), 4, false
	arrondi(badge, 5)
	filet(badge, Color3.fromRGB(255, 248, 214), 2)
	cree("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 236, 150), Color3.fromRGB(250, 196, 72))}, badge)
	texte(badge, "New", 28, Color3.fromRGB(204, 110, 14), {Size = UDim2.fromScale(1, 1), ZIndex = 5})
	cree("ImageLabel", {Image = Style.IMAGES.etoile4, ImageColor3 = Color3.fromRGB(255, 240, 180), BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0), ZIndex = 6}, badge)
	return {case = case, contour = contour, lueur = lueur, badge = badge, bas = bas}
end

return Style
