-- Arène classée, premier jet : duels 1v1 entre héros, en manches, sans limite de temps.
-- File d'attente (borne « Ranked Duel » sur la place, /duel, /leave), une seule arène de test.
-- Une manche : compte à rebours figé, combat, le premier à terre la perd. Premier à deux manches.
-- Fin de duel : cote Elo mise à jour et sauvegardée. Quitter le jeu ou réapparaître pendant un duel
-- le fait perdre par forfait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Donnees = require(script.Parent.Donnees)
local Combat = require(script.Parent.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Arene)

local Arene = {}

local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
reseau.Name = "Reseau"
reseau.Parent = ReplicatedStorage
local function distant(classe, nom)
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end
local Message = distant("RemoteEvent", "Arene")      -- serveur -> client : (type, données)
local Demande = distant("RemoteEvent", "AreneFile")  -- client -> serveur : "rejoindre" | "quitter" | "rang"

local file: {Player} = {}   -- joueurs en attente, dans l'ordre d'arrivée
local duel = nil            -- duel en cours (une seule arène pour l'instant)
local prochainId = 0

local function cote(j: Player): number
	local d = Donnees.profil(j)
	return d and d.Cote or Config.COTE_DEPART
end

local function envoyerRang(j: Player)
	local d = Donnees.profil(j)
	if d then
		Message:FireClient(j, "Rang", {cote = d.Cote, victoires = d.Victoires, defaites = d.Defaites})
	end
end

local function envoyerFile()
	for i, j in file do
		Message:FireClient(j, "File", {position = i, taille = #file})
	end
end

local function retirerDeFile(j: Player)
	local i = table.find(file, j)
	if i then
		table.remove(file, i)
		Message:FireClient(j, "File", nil)
		envoyerFile()
	end
end

-- ---------------------------------------------------------------- l'arène (provisoire, en blocs)
local function construireArene()
	local dossier = workspace:FindFirstChild("Arene_Test") or Instance.new("Folder")
	dossier.Name = "Arene_Test"
	dossier:ClearAllChildren()
	dossier.Parent = workspace
	local c, r = Config.CENTRE, Config.RAYON
	local function disque(nom, rayon, y0, y1, couleur, matiere)
		local p = Instance.new("Part")
		p.Name, p.Shape, p.Anchored = nom, Enum.PartType.Cylinder, true
		p.Size = Vector3.new(y1 - y0, rayon * 2, rayon * 2)
		p.CFrame = CFrame.new(c + Vector3.new(0, (y0 + y1) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Color, p.Material = couleur, matiere
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = dossier
		return p
	end
	-- basalte noir nuit et filets d'argent, comme le palier P2
	disque("Bord", r + 1.2, -3, -0.2, Color3.fromRGB(205, 212, 222), Enum.Material.Metal)
	disque("Sol", r, -3, 0, Color3.fromRGB(30, 40, 58), Enum.Material.Slate)
	disque("Anneau", r * 0.55, -0.1, 0.03, Color3.fromRGB(205, 212, 222), Enum.Material.Metal)
	disque("AnneauInterieur", r * 0.55 - 0.4, -0.1, 0.05, Color3.fromRGB(30, 40, 58), Enum.Material.Slate)
	disque("Centre", 3, -0.1, 0.07, Color3.fromRGB(205, 212, 222), Enum.Material.Metal)
	-- mur invisible qui retient les joueurs sur le sol
	local n = 40
	for i = 1, n do
		local a = 2 * math.pi * i / n
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Transparency = "Mur", true, 1
		p.Size = Vector3.new(2 * math.pi * (r + 1) / n + 1, 40, 1)
		local pos = c + Vector3.new(math.cos(a) * (r + 1), 20, math.sin(a) * (r + 1))
		p.CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
		p.Parent = dossier
	end
end

-- borne d'entrée au centre de la place : rejoindre ou quitter la file
local function poserEntree()
	local borne = workspace:FindFirstChild("Borne_Arene") or Instance.new("Part")
	borne.Name = "Borne_Arene"
	borne.Anchored, borne.CanCollide, borne.CanTouch, borne.CanQuery = true, false, false, false
	borne.Transparency, borne.Size = 1, Vector3.new(2, 4, 2)
	borne.CFrame = CFrame.new(Config.ENTREE)
	borne:ClearAllChildren()
	local invite = Instance.new("ProximityPrompt")
	invite.ObjectText, invite.ActionText = "Ranked Duel", "Join / leave queue"
	invite.HoldDuration, invite.MaxActivationDistance, invite.RequiresLineOfSight = 0.3, 14, false
	invite.Parent = borne
	borne.Parent = workspace
	return invite
end

-- ---------------------------------------------------------------- duel
local function humanoide(j: Player): Humanoid?
	return j.Character and j.Character:FindFirstChildOfClass("Humanoid")
end

local function figer(j: Player, oui: boolean)
	j:SetAttribute("Fige", if oui then true else nil)
	local h = humanoide(j)
	if h then   -- la vitesse suit l'attribut Fige côté client (Course.client)
		h.JumpHeight = if oui then 0 else 7.2
	end
end

local function autre(d, j: Player): Player
	return if d.joueurs[1] == j then d.joueurs[2] else d.joueurs[1]
end

-- même message à chacun, vu de son côté (son score d'abord)
local function diffuser(d, genre: string, extra)
	for _, j in d.joueurs do
		if j.Parent then
			local adv = autre(d, j)
			local donnees = {
				adversaire = adv.DisplayName, coteAdversaire = cote(adv), manche = d.manche,
				scoreMoi = d.score[j], scoreAdversaire = d.score[adv], manches = Config.MANCHES_GAGNANTES,
			}
			for k, v in extra or {} do
				donnees[k] = if type(v) == "function" then v(j) else v
			end
			Message:FireClient(j, genre, donnees)
		end
	end
end

local lancerSiPossible

local function liberer(j: Player)
	j:SetAttribute("PvP", nil)
	j:SetAttribute("Arene", nil)
	figer(j, false)
	Combat.reinitialiser(j)
	if j.Character then j.Character:PivotTo(Config.RETOUR) end
end

local function terminer(d, gagnant: Player, forfait: boolean)
	if d.fini then return end
	d.fini, d.enCours = true, false
	for _, lien in d.liens do lien:Disconnect() end
	local perdant = autre(d, gagnant)
	local avantG, avantP = cote(gagnant), cote(perdant)
	local apresG, apresP = Config.elo(avantG, avantP)
	Donnees.modifier(gagnant, function(x) x.Cote = apresG; x.Victoires += 1 end)
	Donnees.modifier(perdant, function(x) x.Cote = apresP; x.Defaites += 1 end)
	diffuser(d, "Fin", {
		victoire = function(j) return j == gagnant end,
		forfait = forfait,
		avant = function(j) return if j == gagnant then avantG else avantP end,
		apres = function(j) return if j == gagnant then apresG else apresP end,
	})
	for _, j in d.joueurs do
		if j.Parent then figer(j, true) end
	end
	task.wait(3.5)
	for _, j in d.joueurs do
		if j.Parent then
			liberer(j)
			envoyerRang(j)
		end
	end
	duel = nil
	lancerSiPossible()
end

local function debutManche(d)
	d.manche += 1
	for i, j in d.joueurs do
		Combat.reinitialiser(j)
		local pos = Config.CENTRE + Vector3.new(if i == 1 then -Config.ECART else Config.ECART, 3.5, 0)
		if j.Character then
			j.Character:PivotTo(CFrame.lookAt(pos, Vector3.new(Config.CENTRE.X, pos.Y, Config.CENTRE.Z)))
		end
		figer(j, true)
	end
	diffuser(d, "Manche", {compte = Config.COMPTE_A_REBOURS})
	task.wait(Config.COMPTE_A_REBOURS)
	if d.fini then return end
	for _, j in d.joueurs do figer(j, false) end
	d.enCours = true
	diffuser(d, "Combat")
end

-- un joueur tombe à terre : la manche revient à l'autre
Combat.surKO = function(perdant: Player)
	local d = duel
	if not d or not d.enCours or not table.find(d.joueurs, perdant) then return end
	d.enCours = false
	local gagnant = autre(d, perdant)
	d.score[gagnant] += 1
	for _, j in d.joueurs do figer(j, true) end
	diffuser(d, "FinManche", {gagneeParMoi = function(j) return j == gagnant end})
	task.wait(Config.PAUSE_ENTRE_MANCHES)
	if d.fini then return end
	if d.score[gagnant] >= Config.MANCHES_GAGNANTES then
		terminer(d, gagnant, false)
	else
		debutManche(d)
	end
end

local function lancer(a: Player, b: Player)
	prochainId += 1
	local d = {id = prochainId, joueurs = {a, b}, score = {[a] = 0, [b] = 0}, manche = 0,
		fini = false, enCours = false, liens = {}}
	duel = d
	for _, j in d.joueurs do
		retirerDeFile(j)
		j:SetAttribute("PvP", true)
		j:SetAttribute("Arene", d.id)
		-- réapparaître (reset) pendant un duel = forfait
		table.insert(d.liens, j.CharacterRemoving:Connect(function()
			task.spawn(terminer, d, autre(d, j), true)
		end))
	end
	diffuser(d, "Debut")
	task.spawn(debutManche, d)
end

lancerSiPossible = function()
	if duel then return end
	-- on écarte ceux qui n'ont plus de personnage ou de profil
	for i = #file, 1, -1 do
		local j = file[i]
		if not j.Parent or not Donnees.profil(j) or not humanoide(j) then table.remove(file, i) end
	end
	if #file >= 2 then
		lancer(file[1], file[2])
	end
end

local function rejoindre(j: Player)
	if table.find(file, j) or (duel and table.find(duel.joueurs, j)) or not Donnees.profil(j) then return end
	table.insert(file, j)
	envoyerFile()
	lancerSiPossible()
end

local function quitter(j: Player)
	if duel and table.find(duel.joueurs, j) then
		task.spawn(terminer, duel, autre(duel, j), true)
	else
		retirerDeFile(j)
	end
end

function Arene.demarrer()
	construireArene()
	local invite = poserEntree()
	invite.Triggered:Connect(function(j)
		if table.find(file, j) then quitter(j) else rejoindre(j) end
	end)

	Demande.OnServerEvent:Connect(function(j, quoi)
		if quoi == "rejoindre" then rejoindre(j)
		elseif quoi == "quitter" then quitter(j)
		elseif quoi == "rang" then envoyerRang(j) end
	end)

	-- commandes de chat ouvertes à tous les joueurs
	local dossier = TextChatService:FindFirstChild("CommandesArene") or Instance.new("Folder")
	dossier.Name = "CommandesArene"
	dossier.Parent = TextChatService
	for nom, action in {Duel = {"/duel", rejoindre}, Quitter = {"/leave", quitter}} do
		local c = dossier:FindFirstChild(nom) or Instance.new("TextChatCommand")
		c.Name, c.PrimaryAlias = nom, action[1]
		c.Parent = dossier
		c.Triggered:Connect(function(source)
			local j = Players:GetPlayerByUserId(source.UserId)
			if j then action[2](j) end
		end)
	end

	Donnees.Change:Connect(envoyerRang)   -- profil chargé : le joueur reçoit son rang
	-- quitter le jeu en plein duel : forfait enregistré avant la fermeture du profil
	table.insert(Donnees.avantDepart, quitter)
end

return Arene
