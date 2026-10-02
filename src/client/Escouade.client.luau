-- Escouade côté joueur : les ordres (X Suivre, C Maintenir, V Attaquer, boutons à l'écran sur mobile) avec
-- leur indicateur, et l'éditeur de formation qui s'ouvre à la borne du centre d'entraînement : une grille
-- vue de dessus autour du héros, on choisit une invocation dans la liste puis sa case. Textes en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.Invocations)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local Ordre = reseau:WaitForChild("OrdreEscouade")
local Formation = reseau:WaitForChild("FormationEscouade")

local joueur = Players.LocalPlayer
local ARDOISE = Color3.fromRGB(26, 32, 44)
local ARGENT = Color3.fromRGB(205, 212, 222)
local TEXTE = Color3.fromRGB(232, 236, 242)
local DISCRET = Color3.fromRGB(150, 162, 180)
local OR = Color3.fromRGB(232, 182, 82)
local COULEURS_CLASSES = {
	Tank = Color3.fromRGB(120, 150, 200), Archer = Color3.fromRGB(120, 190, 120), Mage = Color3.fromRGB(150, 130, 220),
	Soigneur = Color3.fromRGB(230, 200, 120), Assassin = Color3.fromRGB(200, 100, 110), Guerrier = Color3.fromRGB(210, 140, 90),
}

local function cadre(parent, taille, position, ancre)
	local f = Instance.new("Frame")
	f.Size, f.Position, f.AnchorPoint = taille, position, ancre or Vector2.zero
	f.BackgroundColor3, f.BackgroundTransparency = ARDOISE, 0.12
	f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	local trait = Instance.new("UIStroke", f)
	trait.Color, trait.Thickness, trait.Transparency = ARGENT, 1.2, 0.35
	return f
end
local function bouton(parent, contenu, taille, position, fond)
	local b = Instance.new("TextButton")
	b.Size, b.Position = taille, position
	b.BackgroundColor3, b.AutoButtonColor = fond, true
	b.Text, b.TextColor3, b.Font, b.TextSize = contenu, ARDOISE, Enum.Font.GothamBold, 15
	b.TextWrapped = true
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local ecran = Instance.new("ScreenGui")
ecran.Name = "InterfaceEscouade"
ecran.ResetOnSpawn = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------- ordres
local barre = cadre(ecran, UDim2.fromOffset(276, 46), UDim2.new(0, 16, 1, -76), Vector2.new(0, 1))
local boutonsOrdre = {}
for i, o in Config.ORDRES do
	local b = bouton(barre, `{o.touche.Name}  {o.nom}`, UDim2.fromOffset(84, 34), UDim2.fromOffset(6 + (i - 1) * 90, 6),
		Color3.fromRGB(70, 80, 98))
	b.TextColor3 = TEXTE
	boutonsOrdre[o.id] = b
	b.Activated:Connect(function() Ordre:FireServer(o.id) end)
end
local function majOrdre()
	local actuel = joueur:GetAttribute("OrdreEscouade") or "Suivre"
	for id, b in boutonsOrdre do
		b.BackgroundColor3 = if id == actuel then OR else Color3.fromRGB(70, 80, 98)
		b.TextColor3 = if id == actuel then ARDOISE else TEXTE
	end
end
joueur:GetAttributeChangedSignal("OrdreEscouade"):Connect(majOrdre)
majOrdre()
for _, o in Config.ORDRES do
	ContextActionService:BindAction("PMU_Ordre_" .. o.id, function(_, etat)
		if etat == Enum.UserInputState.Begin then Ordre:FireServer(o.id) end
		return Enum.ContextActionResult.Sink
	end, false, o.touche)
end

-- ---------------------------------------------------------------- éditeur de formation
local F = Config.FORMATION
local CASE = 62
local panneau = cadre(ecran, UDim2.fromOffset(F.colonnes * (CASE + 6) + 230, F.rangees * (CASE + 6) + 120),
	UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
panneau.Visible = false
local titre = Instance.new("TextLabel")
titre.BackgroundTransparency, titre.Size, titre.Position = 1, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(14, 8)
titre.Font, titre.TextSize, titre.TextColor3 = Enum.Font.GothamBlack, 20, TEXTE
titre.TextXAlignment, titre.Text = Enum.TextXAlignment.Left, "Squad formation"
titre.Parent = panneau
local aide = Instance.new("TextLabel")
aide.BackgroundTransparency, aide.Size, aide.Position = 1, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(14, 36)
aide.Font, aide.TextSize, aide.TextColor3 = Enum.Font.GothamMedium, 13, DISCRET
aide.TextXAlignment = Enum.TextXAlignment.Left
aide.Text = "Pick a summon on the right, then a cell. Click a placed summon to remove it. Front is up."
aide.Parent = panneau

local grille = {}         -- [col][rang] = bouton
local placement = {}      -- nom du modèle -> {col, rang}
local modeles = {}        -- liste reçue du serveur
local choisi = nil
local boutonsListe = {}

local function occupant(col, rang)
	for nom, c in placement do
		if c[1] == col and c[2] == rang then return nom end
	end
	return nil
end
local function infoModele(nom)
	for _, m in modeles do
		if m.id == nom then return m end
	end
	return nil
end
local function abrege(nom)
	return (nom:gsub("^Rookie ", ""))
end

local function majGrille()
	for col = 1, F.colonnes do
		for rang = 1, F.rangees do
			local b = grille[col][rang]
			if col == F.heros[1] and rang == F.heros[2] then
				b.Text, b.BackgroundColor3, b.TextColor3 = "YOU", OR, ARDOISE
			else
				local nom = occupant(col, rang)
				local info = nom and infoModele(nom)
				if info then
					b.Text, b.TextColor3 = abrege(info.nom), ARDOISE
					b.BackgroundColor3 = COULEURS_CLASSES[info.classe] or ARGENT
				else
					b.Text, b.BackgroundColor3 = "", Color3.fromRGB(52, 60, 76)
				end
			end
		end
	end
	for nom, b in boutonsListe do
		local info = infoModele(nom)
		local place = placement[nom] ~= nil
		b.BackgroundColor3 = if nom == choisi then OR elseif place then Color3.fromRGB(70, 80, 98) else (COULEURS_CLASSES[info.classe] or ARGENT)
		b.TextColor3 = if place and nom ~= choisi then DISCRET else ARDOISE
	end
end

for col = 1, F.colonnes do
	grille[col] = {}
	for rang = 1, F.rangees do
		local b = bouton(panneau, "", UDim2.fromOffset(CASE, CASE),
			UDim2.fromOffset(14 + (col - 1) * (CASE + 6), 64 + (rang - 1) * (CASE + 6)), Color3.fromRGB(52, 60, 76))
		b.TextSize = 12
		grille[col][rang] = b
		b.Activated:Connect(function()
			if col == F.heros[1] and rang == F.heros[2] then return end
			local deja = occupant(col, rang)
			if choisi then
				if deja then placement[deja] = nil end
				placement[choisi] = {col, rang}
				choisi = nil
			elseif deja then
				placement[deja] = nil
			end
			majGrille()
		end)
	end
end

local liste = Instance.new("Frame")
liste.BackgroundTransparency = 1
liste.Size = UDim2.fromOffset(200, F.rangees * (CASE + 6))
liste.Position = UDim2.fromOffset(14 + F.colonnes * (CASE + 6) + 6, 64)
liste.Parent = panneau
local disposition = Instance.new("UIListLayout")
disposition.Padding = UDim.new(0, 6)
disposition.Parent = liste

local enregistrer = bouton(panneau, "Save", UDim2.fromOffset(110, 36), UDim2.new(1, -244, 1, -48), OR)
local fermer = bouton(panneau, "Close", UDim2.fromOffset(110, 36), UDim2.new(1, -124, 1, -48), Color3.fromRGB(150, 162, 180))
local message = Instance.new("TextLabel")
message.BackgroundTransparency, message.Size, message.Position = 1, UDim2.new(1, -270, 0, 36), UDim2.new(0, 14, 1, -48)
message.Font, message.TextSize, message.TextColor3 = Enum.Font.GothamMedium, 14, DISCRET
message.TextXAlignment, message.Text = Enum.TextXAlignment.Left, ""
message.Parent = panneau

local function ouvrir()
	local etat = Formation:InvokeServer("lire")
	if not etat then return end
	modeles = etat.modeles
	placement = {}
	for nom, c in etat.formation do placement[nom] = {c[1], c[2]} end
	choisi = nil
	for _, b in boutonsListe do b:Destroy() end
	table.clear(boutonsListe)
	for _, m in modeles do
		local b = bouton(liste, `{m.nom}\n{m.classe}`, UDim2.new(1, 0, 0, 44), UDim2.new(), COULEURS_CLASSES[m.classe] or ARGENT)
		b.TextSize = 13
		boutonsListe[m.id] = b
		b.Activated:Connect(function()
			choisi = if choisi == m.id then nil else m.id
			majGrille()
		end)
	end
	message.Text = ""
	majGrille()
	panneau.Visible = true
end

enregistrer.Activated:Connect(function()
	local ok = Formation:InvokeServer("ecrire", placement)
	message.Text = if ok then "Formation saved." else "Couldn't save this formation."
	message.TextColor3 = if ok then Color3.fromRGB(120, 210, 140) else Color3.fromRGB(235, 110, 100)
end)
fermer.Activated:Connect(function() panneau.Visible = false end)
ProximityPromptService.PromptTriggered:Connect(function(invite)
	if invite:GetAttribute("Formation") then ouvrir() end
end)
UserInputService.InputBegan:Connect(function(entree, traite)
	if not traite and entree.KeyCode == Enum.KeyCode.Escape and panneau.Visible then panneau.Visible = false end
end)
