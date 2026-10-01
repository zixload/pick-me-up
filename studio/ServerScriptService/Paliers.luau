-- Paliers : affiche le palier d'un lot (bâtiment ou rempart) et anime le changement.
-- Les modèles de chaque palier vivent dans ServerStorage.Batiments.<Lot>.P<n> ;
-- le palier affiché est Workspace.Batiments.<Lot>, qui porte l'attribut Palier.
-- Animation : une vague part de l'origine donnée. Chaque pièce de l'ancien palier s'enfonce
-- dans un nuage de fumée, la pièce du nouveau palier remonte à sa place, sur un grondement de pierre.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SS = game:GetService("ServerStorage")

local Paliers = {}

local SON_GRONDEMENT = "rbxassetid://9113218938" -- Avalanche Deep Crumbling 4 (ProSoundEffects)
local DUREE_VAGUE = 3       -- secondes entre la première et la dernière pièce
local ENFONCEMENT = 8       -- studs : profondeur d'où sort, ou où rentre, une pièce
local T_SORTIE, T_ENTREE, DECALAGE_ENTREE = 0.6, 0.8, 0.25

local enCours = {}

local function scene()
	local s = workspace:FindFirstChild("Batiments")
	if not s then
		s = Instance.new("Folder")
		s.Name = "Batiments"
		s.Parent = workspace
	end
	return s
end

local function parts(inst)
	local t = {}
	if inst:IsA("BasePart") then table.insert(t, inst) end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end

-- pièces animées une à une : enfants du modèle, en descendant dans les dossiers
local function pieces(model, t)
	t = t or {}
	for _, c in model:GetChildren() do
		if c:IsA("PVInstance") then
			table.insert(t, c)
		elseif c:IsA("Folder") then
			pieces(c, t)
		end
	end
	return t
end

local function boite(piece)
	if piece:IsA("Model") then return piece:GetBoundingBox() end
	return piece.CFrame, piece.Size
end

local function jouerSon(id, volume, duree)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = workspace
	s:Play()
	if duree then
		task.delay(duree, function()
			TweenService:Create(s, TweenInfo.new(1), {Volume = 0}):Play()
		end)
	end
	Debris:AddItem(s, (duree or 6) + 1.5)
end

local function fumee(cframe, largeur)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(math.max(largeur, 2), 1, 3)
	p.CFrame = cframe + Vector3.new(0, 1, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(214, 210, 200))
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(1.4, 2.4)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Drag = 1.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	p.Parent = workspace
	e:Emit(math.clamp(math.floor(largeur), 6, 16))
	Debris:AddItem(p, 3)
end

-- Palier affiché d'un lot, ou nil s'il n'est pas encore posé.
function Paliers.actuel(lot)
	local m = scene():FindFirstChild(lot)
	return m and m:GetAttribute("Palier")
end

-- Affiche le palier demandé. Sans origine, le changement est instantané (chargement de la base) ;
-- avec une origine (Vector3), il est animé en vague à partir de ce point.
-- Renvoie false si une animation est déjà en cours sur ce lot.
-- options.silencieux : pas de grondement (quand plusieurs lots évoluent ensemble, un seul suffit).
function Paliers.changer(lot, palier, origine, options)
	options = options or {}
	if enCours[lot] then return false end
	local source = SS.Batiments[lot]:FindFirstChild("P" .. palier)
	assert(source, "Pas de modèle P" .. palier .. " pour " .. lot)

	local s = scene()
	local ancien = s:FindFirstChild(lot)
	local nouveau = source:Clone()
	nouveau.Name = lot
	if not origine or not ancien then
		if ancien then ancien:Destroy() end
		nouveau.Parent = s
		return true
	end

	enCours[lot] = true
	ancien.Name = lot .. "_Sortant"

	-- retard de chaque pièce selon sa distance (au sol) à l'origine
	local dist, dmin, dmax = {}, math.huge, 0
	for _, m in {ancien, nouveau} do
		for _, c in pieces(m) do
			local d = ((boite(c).Position - origine) * Vector3.new(1, 0, 1)).Magnitude
			dist[c] = d
			dmin, dmax = math.min(dmin, d), math.max(dmax, d)
		end
	end
	local function retard(c)
		return dmax > dmin and (dist[c] - dmin) / (dmax - dmin) * DUREE_VAGUE or 0
	end

	-- le nouveau palier attend sous le sol, invisible
	local cibles = {}
	for _, c in pieces(nouveau) do
		for _, p in parts(c) do
			cibles[p] = {p.CFrame, p.Transparency}
			p.CFrame = p.CFrame - Vector3.new(0, ENFONCEMENT, 0)
			p.Transparency = 1
		end
	end
	nouveau.Parent = s

	local infoSortie = TweenInfo.new(T_SORTIE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local infoEntree = TweenInfo.new(T_ENTREE, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local fumees = {}
	for _, c in pieces(ancien) do
		task.delay(retard(c), function()
			local cf, taille = boite(c)
			-- une seule bouffée par emplacement (la mousse et le mur d'une travée partagent la même)
			local cle = math.floor(cf.Position.X / 6) .. ":" .. math.floor(cf.Position.Z / 6)
			if not fumees[cle] then
				fumees[cle] = true
				fumee(CFrame.new(cf.Position.X, 0, cf.Position.Z) * cf.Rotation, taille.X)
			end
			for _, p in parts(c) do
				TweenService:Create(p, infoSortie, {CFrame = p.CFrame - Vector3.new(0, ENFONCEMENT, 0), Transparency = 1}):Play()
			end
		end)
	end
	for _, c in pieces(nouveau) do
		task.delay(retard(c) + DECALAGE_ENTREE, function()
			for _, p in parts(c) do
				local cible = cibles[p]
				TweenService:Create(p, infoEntree, {CFrame = cible[1], Transparency = cible[2]}):Play()
			end
		end)
	end

	if not options.silencieux then
		jouerSon(SON_GRONDEMENT, 0.7, DUREE_VAGUE + 0.5)
	end
	task.delay(DUREE_VAGUE + DECALAGE_ENTREE + T_ENTREE, function()
		ancien:Destroy()
		enCours[lot] = nil
	end)
	return true
end

return Paliers
