-- Interface du lobby : affichage permanent (base, niveau, expérience, or) et panneau d'amélioration
-- qui s'ouvre aux bornes des bâtiments. Le serveur fait foi : ce script ne fait qu'afficher et demander.
-- Tout texte affiché est en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Batiments = require(Shared.Config.Batiments)
local Progression = require(Shared.Config.Progression)
local Regles = require(Shared.Regles)
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local EtatBase = reseau:WaitForChild("EtatBase")
local LireEtat = reseau:WaitForChild("LireEtat")
local Ameliorer = reseau:WaitForChild("Ameliorer")

local joueur = Players.LocalPlayer

-- palette du lobby P1 : ardoise, argent, or
local ARDOISE = Color3.fromRGB(26, 32, 44)
local ARGENT = Color3.fromRGB(205, 212, 222)
local TEXTE = Color3.fromRGB(232, 236, 242)
local DISCRET = Color3.fromRGB(150, 162, 180)
local OR = Color3.fromRGB(232, 182, 82)
local VERT = Color3.fromRGB(120, 210, 140)
local ROUGE = Color3.fromRGB(235, 110, 100)
local POLICE = Enum.Font.GothamMedium
local POLICE_FORTE = Enum.Font.GothamBold

local function milliers(n: number): string
	local s = tostring(math.floor(n))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end

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

local function texte(parent, contenu, taille, position, couleur, police, tailleTexte, alignement)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size, t.Position = taille, position
	t.Text, t.TextColor3 = contenu, couleur or TEXTE
	t.Font, t.TextSize = police or POLICE, tailleTexte or 16
	t.TextXAlignment = alignement or Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Parent = parent
	return t
end

local function bouton(parent, contenu, taille, position, fond)
	local b = Instance.new("TextButton")
	b.Size, b.Position = taille, position
	b.BackgroundColor3, b.AutoButtonColor = fond, true
	b.Text, b.TextColor3, b.Font, b.TextSize = contenu, ARDOISE, POLICE_FORTE, 17
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

-- ---------------------------------------------------------------- construction de l'interface
local ecran = Instance.new("ScreenGui")
ecran.Name = "InterfaceLobby"
ecran.ResetOnSpawn = false
ecran.IgnoreGuiInset = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

local hud = cadre(ecran, UDim2.fromOffset(270, 92), UDim2.fromOffset(16, 16))
local hudBase = texte(hud, "Loading…", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 8), DISCRET, POLICE, 14)
local hudNiveau = texte(hud, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 28), TEXTE, POLICE_FORTE, 19)
local barre = Instance.new("Frame")
barre.Size, barre.Position = UDim2.new(1, -24, 0, 6), UDim2.fromOffset(12, 54)
barre.BackgroundColor3, barre.BorderSizePixel = Color3.fromRGB(52, 62, 78), 0
barre.Parent = hud
Instance.new("UICorner", barre).CornerRadius = UDim.new(1, 0)
local remplissage = Instance.new("Frame")
remplissage.Size, remplissage.BackgroundColor3, remplissage.BorderSizePixel = UDim2.fromScale(0, 1), ARGENT, 0
remplissage.Parent = barre
Instance.new("UICorner", remplissage).CornerRadius = UDim.new(1, 0)
local hudOr = texte(hud, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 66), OR, POLICE_FORTE, 16)

local panneau = cadre(ecran, UDim2.fromOffset(400, 214), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))
panneau.Visible = false
local pTitre = texte(panneau, "", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 12), TEXTE, POLICE_FORTE, 21)
local pNiveau = texte(panneau, "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 42), DISCRET, POLICE, 15)
local pCout = texte(panneau, "", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 72), OR, POLICE_FORTE, 17)
local pCondition = texte(panneau, "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 98), TEXTE, POLICE, 15)
local pMessage = texte(panneau, "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 124), VERT, POLICE, 15)
local bAmeliorer = bouton(panneau, "Upgrade", UDim2.new(0.62, -22, 0, 40), UDim2.new(0, 16, 1, -54), OR)
local bFermer = bouton(panneau, "Close", UDim2.new(0.38, -14, 0, 40), UDim2.new(0.62, 2, 1, -54), Color3.fromRGB(150, 162, 180))

-- ---------------------------------------------------------------- état et mise à jour
local etat = nil
local lotOuvert: string? = nil
local borneOuverte: BasePart? = nil
local envoiEnCours = false

local function estProprietaire()
	return etat and etat.proprietaireId == joueur.UserId
end

local function majHud()
	if not etat or not etat.donnees then
		hudBase.Text = "Loading base…"
		return
	end
	local d = etat.donnees
	hudBase.Text = if estProprietaire() then "Your base" else `{etat.proprietaireNom}'s base`
	hudNiveau.Text = `Level {d.Niveau}`
	local besoin = Progression.xpPourNiveau(d.Niveau)
	remplissage.Size = UDim2.fromScale(if d.Niveau >= Progression.NIVEAU_MAX then 1 else math.clamp(d.XP / besoin, 0, 1), 1)
	hudOr.Text = `{milliers(d.Or)} gold`
end

local function majPanneau()
	if not lotOuvert or not etat or not etat.donnees then return end
	local lot = Batiments.LOTS[lotOuvert]
	local ok, raison, detail = Regles.verifier(etat.donnees, lotOuvert)
	pTitre.Text = lot.nom
	if detail.niveau == 0 then
		pNiveau.Text = "Reserved plot: not built yet"
	else
		pNiveau.Text = `Level {detail.niveau} / {Batiments.NIVEAU_MAX}  ·  tier P{detail.palierActuel}`
	end
	if detail.niveau >= Batiments.NIVEAU_MAX then
		pCout.Text = "Max level reached"
		pCondition.Text = ""
	else
		local action = if detail.niveau == 0 then "Build" else `Level {detail.cible}`
		local palier = if detail.palierCible ~= detail.palierActuel then `  ·  new tier P{detail.palierCible}` else ""
		pCout.Text = `{action}: {milliers(detail.cout)} gold{palier}`
		local requisOk = etat.donnees.Niveau >= detail.requis
		pCondition.Text = `Global level required: {detail.requis}` .. (if requisOk then "  ✓" else "")
		pCondition.TextColor3 = if requisOk then TEXTE else ROUGE
	end
	local peut = ok and estProprietaire()
	bAmeliorer.Text = if detail.niveau == 0 then "Build" else "Upgrade"
	bAmeliorer.Active = peut and not envoiEnCours
	bAmeliorer.AutoButtonColor = peut
	bAmeliorer.BackgroundColor3 = if peut then OR else Color3.fromRGB(96, 104, 118)
	if not estProprietaire() then
		pMessage.Text, pMessage.TextColor3 = `Only {etat.proprietaireNom} can upgrade this base.`, DISCRET
	elseif not ok and pMessage.Text == "" then
		pMessage.Text, pMessage.TextColor3 = raison, ROUGE
	end
end

local function fermer()
	panneau.Visible = false
	lotOuvert, borneOuverte = nil, nil
end

local function ouvrir(lotId: string, borne: BasePart)
	lotOuvert, borneOuverte = lotId, borne
	pMessage.Text = ""
	panneau.Visible = true
	majPanneau()
end

local function recevoir(nouvelEtat)
	etat = nouvelEtat
	majHud()
	if lotOuvert then
		pMessage.Text = ""
		majPanneau()
	end
end

-- ---------------------------------------------------------------- événements
EtatBase.OnClientEvent:Connect(recevoir)
task.spawn(function()
	recevoir(LireEtat:InvokeServer())
end)

ProximityPromptService.PromptTriggered:Connect(function(invite)
	local lotId = invite:GetAttribute("LotId")
	if lotId and Batiments.LOTS[lotId] then
		ouvrir(lotId, invite.Parent)
	end
end)

bFermer.Activated:Connect(fermer)
bAmeliorer.Activated:Connect(function()
	if not lotOuvert or envoiEnCours or not bAmeliorer.Active then return end
	envoiEnCours = true
	majPanneau()
	local ok, message = Ameliorer:InvokeServer(lotOuvert)
	envoiEnCours = false
	pMessage.Text, pMessage.TextColor3 = message or "", if ok then VERT else ROUGE
	majPanneau()
end)

-- le panneau se ferme quand on s'éloigne de la borne
RunService.Heartbeat:Connect(function()
	if not borneOuverte then return end
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not racine or (racine.Position - borneOuverte.Position).Magnitude > 26 then
		fermer()
	end
end)
