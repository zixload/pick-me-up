-- Interface de l'arène classée : son rang (insigne, nom, cote), la file d'attente, le bandeau du duel
-- (score en manches), les annonces (manche, compte à rebours, FIGHT!, résultat de manche) et l'écran
-- de fin avec la cote gagnée ou perdue et l'animation de montée de rang. Textes en anglais.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Arene = require(ReplicatedStorage:WaitForChild("Shared").Config.Arene)
local Insigne = require(script.Parent:WaitForChild("Insigne"))
local reseau = ReplicatedStorage:WaitForChild("Reseau")
local Message = reseau:WaitForChild("Arene")
local Demande = reseau:WaitForChild("AreneFile")

local joueur = Players.LocalPlayer

local ARDOISE = Color3.fromRGB(26, 32, 44)
local ARGENT = Color3.fromRGB(205, 212, 222)
local TEXTE = Color3.fromRGB(232, 236, 242)
local DISCRET = Color3.fromRGB(150, 162, 180)
local BLEU = Color3.fromRGB(120, 190, 255)
local ROUGE = Color3.fromRGB(235, 110, 100)
local VERT = Color3.fromRGB(120, 210, 140)

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
	t.Font, t.TextSize = police or Enum.Font.GothamMedium, tailleTexte or 16
	t.TextXAlignment = alignement or Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

local ecran = Instance.new("ScreenGui")
ecran.Name = "InterfaceArene"
ecran.ResetOnSpawn, ecran.IgnoreGuiInset = false, false   -- même repère que l'affichage de la base
ecran.DisplayOrder = 5
ecran.Parent = joueur:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------- son rang (sous l'affichage de la base)
local fiche = cadre(ecran, UDim2.fromOffset(270, 62), UDim2.fromOffset(16, 136))
local petitInsigne = Insigne.creer(fiche, 54)
petitInsigne.cadre.Position = UDim2.fromOffset(6, 4)
local ficheRang = texte(fiche, "", UDim2.new(1, -76, 0, 22), UDim2.fromOffset(66, 9), TEXTE, Enum.Font.GothamBlack, 18)
local ficheDetail = texte(fiche, "", UDim2.new(1, -76, 0, 18), UDim2.fromOffset(66, 33), DISCRET, Enum.Font.GothamMedium, 14)
fiche.Visible = false

local function majFiche(cote: number, victoires: number?, defaites: number?)
	local r = petitInsigne.maj(cote)
	ficheRang.Text = string.upper(r.nom) .. (if r.division ~= "" then " " .. r.division else "")
	ficheRang.TextColor3 = r.clair
	local bilan = if victoires then `  ·  {victoires}W {defaites}L` else ""
	ficheDetail.Text = `{r.titre}  ·  {cote}{bilan}`
	fiche.Visible = false   -- insigne retiré du HUD (02/10/2026), le nouveau HUD le reprendra
end

-- ---------------------------------------------------------------- file d'attente
local file = cadre(ecran, UDim2.fromOffset(300, 54), UDim2.new(1, -16, 1, -96), Vector2.new(1, 1))
file.Visible = false
local fileTexte = texte(file, "", UDim2.new(1, -110, 1, 0), UDim2.fromOffset(14, 0), TEXTE, Enum.Font.GothamMedium, 15)
local quitter = Instance.new("TextButton")
quitter.Size, quitter.Position = UDim2.fromOffset(84, 34), UDim2.new(1, -94, 0.5, -17)
quitter.BackgroundColor3, quitter.Text = Color3.fromRGB(150, 162, 180), "Leave"
quitter.Font, quitter.TextSize, quitter.TextColor3 = Enum.Font.GothamBold, 15, ARDOISE
quitter.Parent = file
Instance.new("UICorner", quitter).CornerRadius = UDim.new(0, 8)
quitter.Activated:Connect(function() Demande:FireServer("quitter") end)

-- ---------------------------------------------------------------- bandeau du duel
local bandeau = cadre(ecran, UDim2.fromOffset(460, 52), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
bandeau.Visible = false
local nomMoi = texte(bandeau, "You", UDim2.new(0.5, -70, 1, 0), UDim2.fromOffset(16, 0), BLEU, Enum.Font.GothamBold, 17)
local nomAdv = texte(bandeau, "", UDim2.new(0.5, -70, 1, 0), UDim2.new(0.5, 54, 0, 0), ROUGE, Enum.Font.GothamBold, 17,
	Enum.TextXAlignment.Right)
texte(bandeau, "VS", UDim2.fromOffset(40, 52), UDim2.new(0.5, -20, 0, 0), DISCRET, Enum.Font.GothamBlack, 16,
	Enum.TextXAlignment.Center)
local pastilles = {moi = {}, adv = {}}
for i = 1, Arene.MANCHES_GAGNANTES do
	for cote, x in {moi = -40 - i * 18, adv = 26 + i * 18} do
		local p = Instance.new("Frame")
		p.Size, p.Position = UDim2.fromOffset(12, 12), UDim2.new(0.5, x, 0.5, -6)
		p.BackgroundColor3, p.BorderSizePixel = Color3.fromRGB(60, 70, 88), 0
		p.Parent = bandeau
		Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
		pastilles[cote][i] = p
	end
end
local function majScore(d)
	nomAdv.Text = d.adversaire or ""
	for i = 1, Arene.MANCHES_GAGNANTES do
		pastilles.moi[i].BackgroundColor3 = if (d.scoreMoi or 0) >= i then BLEU else Color3.fromRGB(60, 70, 88)
		pastilles.adv[i].BackgroundColor3 = if (d.scoreAdversaire or 0) >= i then ROUGE else Color3.fromRGB(60, 70, 88)
	end
end

-- ---------------------------------------------------------------- grandes annonces au centre
local annonce = texte(ecran, "", UDim2.fromOffset(900, 120), UDim2.fromScale(0.5, 0.36), TEXTE, Enum.Font.GothamBlack, 72,
	Enum.TextXAlignment.Center)
annonce.AnchorPoint = Vector2.new(0.5, 0.5)
annonce.TextStrokeTransparency, annonce.TextTransparency = 0.4, 1
local sousAnnonce = texte(ecran, "", UDim2.fromOffset(900, 40), UDim2.fromScale(0.5, 0.36), DISCRET, Enum.Font.GothamBold, 24,
	Enum.TextXAlignment.Center)
sousAnnonce.AnchorPoint = Vector2.new(0.5, -1.6)
sousAnnonce.TextStrokeTransparency, sousAnnonce.TextTransparency = 0.6, 1
local echelle = Instance.new("UIScale", annonce)

local jetonAnnonce = 0
local function annoncer(contenu: string, couleur: Color3?, sous: string?, duree: number?)
	jetonAnnonce += 1
	local jeton = jetonAnnonce
	annonce.Text, annonce.TextColor3, annonce.TextTransparency = contenu, couleur or TEXTE, 0
	sousAnnonce.Text, sousAnnonce.TextTransparency = sous or "", 0
	echelle.Scale = 1.6
	TweenService:Create(echelle, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	task.delay(duree or 0.9, function()
		if jeton ~= jetonAnnonce then return end
		local info = TweenInfo.new(0.3)
		TweenService:Create(annonce, info, {TextTransparency = 1}):Play()
		TweenService:Create(sousAnnonce, info, {TextTransparency = 1}):Play()
	end)
end

-- ---------------------------------------------------------------- écran de fin
local fin = cadre(ecran, UDim2.fromOffset(380, 300), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
fin.Visible = false
local finTitre = texte(fin, "", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 14), TEXTE, Enum.Font.GothamBlack, 34,
	Enum.TextXAlignment.Center)
local grandInsigne = Insigne.creer(fin, 120)
grandInsigne.cadre.AnchorPoint, grandInsigne.cadre.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 62)
local echelleInsigne = Instance.new("UIScale", grandInsigne.cadre)
local finRang = texte(fin, "", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 188), TEXTE, Enum.Font.GothamBlack, 22,
	Enum.TextXAlignment.Center)
local finCote = texte(fin, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 218), DISCRET, Enum.Font.GothamBold, 17,
	Enum.TextXAlignment.Center)
finCote.RichText = true
local finPromo = texte(fin, "", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 250), TEXTE, Enum.Font.GothamBlack, 22,
	Enum.TextXAlignment.Center)

local function afficherFin(d)
	local victoire = d.victoire
	finTitre.Text = if victoire then "VICTORY" else "DEFEAT"
	finTitre.TextColor3 = if victoire then Color3.fromRGB(255, 222, 140) else ROUGE
	local avant, apres = Arene.rang(d.avant), Arene.rang(d.apres)
	grandInsigne.maj(d.avant)
	finRang.Text = string.upper(avant.nom) .. (if avant.division ~= "" then " " .. avant.division else "")
	finRang.TextColor3 = avant.clair
	local ecart = d.apres - d.avant
	local signe = if ecart >= 0 then "+" else ""
	local couleur = if ecart >= 0 then VERT else ROUGE
	finCote.Text = `{d.avant}  →  {d.apres}   <font color="#{couleur:ToHex()}">({signe}{ecart})</font>`
		.. (if d.forfait then "\n<font size=\"13\">by forfeit</font>" else "")
	finPromo.Text = ""
	fin.Visible = true
	echelleInsigne.Scale = 0.6
	TweenService:Create(echelleInsigne, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	-- changement de rang ou de division : l'insigne bascule sur le nouveau, avec une annonce
	local change = avant.nom ~= apres.nom or avant.division ~= apres.division
	if change then
		task.delay(1.1, function()
			local monte = d.apres > d.avant
			TweenService:Create(echelleInsigne, TweenInfo.new(0.18), {Scale = 0.2}):Play()
			task.wait(0.18)
			grandInsigne.maj(d.apres)
			finRang.Text = string.upper(apres.nom) .. (if apres.division ~= "" then " " .. apres.division else "")
			finRang.TextColor3 = apres.clair
			finPromo.Text = if monte then "RANK UP!" else "Rank down"
			finPromo.TextColor3 = if monte then apres.clair else DISCRET
			TweenService:Create(echelleInsigne, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Scale = if monte then 1.15 else 1}):Play()
		end)
	end
	task.delay(6, function() fin.Visible = false end)
end

-- ---------------------------------------------------------------- messages du serveur
Message.OnClientEvent:Connect(function(genre: string, d)
	if genre == "Rang" then
		majFiche(d.cote, d.victoires, d.defaites)
	elseif genre == "File" then
		file.Visible = d ~= nil
		if d then
			fileTexte.Text = if d.taille < 2 then "Searching for an opponent…" else `In queue  ·  {d.position}/{d.taille}`
		end
	elseif genre == "Debut" then
		file.Visible, fin.Visible = false, false
		bandeau.Visible = true
		majScore(d)
		local r = Arene.rang(d.coteAdversaire)
		annoncer("DUEL", TEXTE, `vs {d.adversaire}  ·  {r.nom} {r.division}`, 1.2)
	elseif genre == "Manche" then
		majScore(d)
		annoncer(`ROUND {d.manche}`, TEXTE, nil, 0.8)
		for i = d.compte - 1, 1, -1 do
			task.delay(d.compte - i, function() annoncer(tostring(i), ARGENT, nil, 0.7) end)
		end
	elseif genre == "Combat" then
		annoncer("FIGHT!", Color3.fromRGB(255, 222, 140), nil, 0.6)
	elseif genre == "FinManche" then
		majScore(d)
		if d.gagneeParMoi then
			annoncer("ROUND WON", BLEU, `{d.scoreMoi} - {d.scoreAdversaire}`, 2)
		else
			annoncer("ROUND LOST", ROUGE, `{d.scoreMoi} - {d.scoreAdversaire}`, 2)
		end
	elseif genre == "Fin" then
		bandeau.Visible = false
		afficherFin(d)
		majFiche(d.apres)
	end
end)

Demande:FireServer("rang")
