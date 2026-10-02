-- Assemble la faille spatio-temporelle du palier P1 à partir de l'import Blender
-- (blender/export_p1/Faille_P1.fbx) : posée sur son lot, porte tournée vers la place centrale,
-- déchirure en Neon avec lumière qui pulse et éclats, lierre de ChatGPT (PMU_Lierre_Grimpant)
-- sur le tambour. Construit ServerStorage.Batiments.Faille.P1 et l'affiche dans Workspace.Batiments.
-- Relançable (tant que l'import ou le P1 existe), annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local ECHELLE = 1.5
local CENTRE = Vector3.new(78 * ECHELLE, 0.42, 29 * ECHELLE)   -- lot de la faille (plan ×1,5), sur le dallage
local VERS = Vector3.new(0, 0, 8 * ECHELLE)                     -- la porte regarde la place centrale
local BLENDER_BAS = -0.4                                        -- dessous de la plateforme dans Blender (z)
local ASPECT = {  -- suffixe -> couleur, matériau, collision, ombre
	PierreA = {Color3.fromRGB(92, 108, 130), Enum.Material.Slate, true, true},   -- trois tons proches
	PierreB = {Color3.fromRGB(101, 117, 138), Enum.Material.Slate, true, true},
	PierreC = {Color3.fromRGB(84, 99, 120), Enum.Material.Slate, true, true},
	Joint = {Color3.fromRGB(58, 68, 84), Enum.Material.Slate, true, true},
	Gravure = {Color3.fromRGB(112, 128, 150), Enum.Material.Slate, false, true},
	Sombre = {Color3.fromRGB(40, 48, 60), Enum.Material.Slate, true, true},
	Porte = {Color3.fromRGB(62, 74, 92), Enum.Material.Slate, true, true},
	Argent = {Color3.fromRGB(205, 212, 222), Enum.Material.Metal, false, true},
	Mousse = {Color3.fromRGB(88, 128, 56), Enum.Material.LeafyGrass, false, false},
	Lumiere = {Color3.fromRGB(140, 235, 245), Enum.Material.Neon, false, false},
}
-- lierre : sur le tambour (rayon 15, au-dessus du podium à z = 5), entre les colonnes, loin de la porte
local LIERRE_ANGLES = {36, 108, 144, 216, 288}   -- degrés comptés depuis la porte
local R_TAMBOUR, Z_PODIUM = 15, 5

local rec = CHS:TryBeginRecording("Faille P1 (kit Blender)")
local ok, err = pcall(function()
	local import = workspace:FindFirstChild("Faille_P1")
	assert(import, "Importe d'abord blender/export_p1/Faille_P1.fbx (modèle Faille_P1 dans Workspace).")

	-- repère de l'import : centre au sol, face avant (-Y Blender) vers -Z dans Studio
	local cf, size = import:GetBoundingBox()
	local origineImport = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 - BLENDER_BAS, cf.Position.Z)
	local decalage = origineImport:ToObjectSpace(import:GetPivot())
	local dir = ((VERS - CENTRE) * Vector3.new(1, 0, 1)).Unit
	local cadre = CFrame.lookAt(CENTRE, CENTRE + dir)          -- LookVector = devant de la faille
	import:PivotTo(cadre * decalage)

	local p1 = Instance.new("Model")
	p1.Name = "P1"
	p1:SetAttribute("LotId", "Faille")
	p1:SetAttribute("Palier", 1)
	for _, p in import:GetDescendants() do
		if p:IsA("BasePart") then
			local sorte = p.Name:match("^Faille_(%a+)_?%d*$")   -- les gros maillages peuvent être coupés en _1, _2…
			local a = ASPECT[sorte]
			assert(a, "Maillage inattendu : " .. p.Name)
			p.Color, p.Material, p.CanCollide, p.CastShadow = a[1], a[2], a[3], a[4]
			p.CanTouch, p.Anchored = false, true
			p.Parent = p1
		end
	end
	import:Destroy()

	-- la déchirure : lumière qui pulse et éclats qui s'échappent vers la porte
	local lumiere = p1.Faille_Lumiere
	local halo = Instance.new("PointLight")
	halo.Color = Color3.fromRGB(140, 235, 245)
	halo.Brightness, halo.Range, halo.Shadows = 3, 24, false
	halo.Parent = lumiere
	local eclats = Instance.new("ParticleEmitter")
	eclats.Name = "Eclats"
	eclats.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	eclats.Color = ColorSequence.new(Color3.fromRGB(170, 245, 255))
	eclats.LightEmission = 1
	eclats.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	eclats.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	eclats.Lifetime = NumberRange.new(2, 3.5)
	eclats.Rate = 12
	eclats.Speed = NumberRange.new(1.5, 3)
	eclats.SpreadAngle = Vector2.new(25, 35)
	eclats.EmissionDirection = Enum.NormalId.Front
	eclats.Parent = lumiere
	local pulse = Instance.new("Script")   -- pulsation lente de la lumière, côté serveur
	pulse.Name = "Pulsation"
	pulse.Source = [[
local halo = script.Parent:FindFirstChildOfClass("PointLight")
local t = 0
while true do
	t += task.wait(0.05)
	halo.Brightness = 2.6 + 0.9 * math.sin(t * 1.7)
end
]]
	pulse.Parent = lumiere

	-- lierre de ChatGPT sur le tambour (son pivot est à sa base, côté mur ; il « regarde » vers l'extérieur)
	local lierre = SS.Kit_Rempart:FindFirstChild("PMU_Lierre_Grimpant")
	if lierre then
		local rng = Random.new(29)
		for _, deg in LIERRE_ANGLES do
			local a = math.rad(-90 + deg)                               -- -90° = la porte, dans Blender
			local local_ = Vector3.new(-R_TAMBOUR * math.cos(a), Z_PODIUM, R_TAMBOUR * math.sin(a))  -- Blender -> repère
			local pos = cadre:PointToWorldSpace(local_)
			local dehors = cadre:VectorToWorldSpace(Vector3.new(-math.cos(a), 0, math.sin(a)))
			local l = lierre:Clone()
			l.Name = "Lierre"
			l:PivotTo(CFrame.lookAt(pos + dehors * 0.15, pos + dehors * 2))
			l:ScaleTo(rng:NextNumber(1.3, 1.8))
			for _, d in l:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanTouch = true, false, false end
			end
			l.Parent = p1
		end
	end

	-- rangement du palier et affichage
	local dossier = SS.Batiments:FindFirstChild("Faille") or Instance.new("Folder")
	dossier.Name, dossier.Parent = "Faille", SS.Batiments
	if dossier:FindFirstChild("P1") then dossier.P1:Destroy() end
	p1.Parent = dossier
	local scene = workspace:FindFirstChild("Batiments")
	if scene:FindFirstChild("Faille") then scene.Faille:Destroy() end
	local copie = p1:Clone()
	copie.Name = "Faille"
	copie.Parent = scene
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
local cf, size = workspace.Batiments.Faille:GetBoundingBox()
return string.format("Faille P1 posée en (%.0f, %.0f), %.0f × %.0f × %.0f studs", cf.Position.X, cf.Position.Z, size.X, size.Y, size.Z)
