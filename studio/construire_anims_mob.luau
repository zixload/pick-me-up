-- Construit les animations d'un mob (KeyframeSequence) à partir du JSON généré par
-- blender/mobs/export_anims_roblox.py (src/shared/AnimationsMobs/<Nom>.txt, une StringValue synchronisée par Rojo :
-- l'outil Studio ne peut pas « require » un module du jeu, il lit donc du texte).
-- Chaque image : [temps, déplacement de l'os racine (donnees.racine) x, y, z, puis w, x, y, z de chaque os dans l'ordre de « os »].
-- Rangées dans ServerStorage.RBX_ANIMSAVES.<Nom> : l'éditeur d'animation les propose au chargement (… → Load)
-- pour les vérifier sur le modèle et les publier. À lancer en mode édition.
local NOM = "Gobelin_Guerrier"

local ServerStorage = game:GetService("ServerStorage")
local texte = game:GetService("ReplicatedStorage").Shared.AnimationsMobs:FindFirstChild(NOM)
local donnees = game:GetService("HttpService"):JSONDecode(texte.Value)

-- L'éditeur ne liste que le dossier relié au modèle (ObjectValue.Value = le modèle dans le Workspace), et la
-- version récente lit aussi le dossier AnimSaves du modèle : on remplit les deux.
-- le modèle importé : celui dont la pièce (MeshPart) porte le nom donnees.piece et contient les os
local rig
for _, m in workspace:GetChildren() do
	local piece = m:IsA("Model") and m:FindFirstChild(donnees.piece)
	if piece and piece:IsA("MeshPart") and piece:FindFirstChildWhichIsA("Bone") then rig = m end
end
assert(rig, "importer d'abord le modèle " .. donnees.piece .. " dans le Workspace")
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES") or Instance.new("Folder")
saves.Name, saves.Parent = "RBX_ANIMSAVES", ServerStorage
local dossier
for _, d in saves:GetChildren() do
	if d:IsA("ObjectValue") and d.Value == rig then dossier = d end
end
if not dossier then
	dossier = Instance.new("ObjectValue")
	dossier.Name, dossier.Value, dossier.Parent = donnees.piece, rig, saves
end
local animSaves = rig:FindFirstChild("AnimSaves") or Instance.new("ObjectValue")
animSaves.Name, animSaves.Parent = "AnimSaves", rig

local indice, enfants = {}, {}
for i, os_ in donnees.os do
	indice[os_] = i
	local parent = donnees.parents[i]
	local cle = if parent ~= "" then parent else "__racine"
	enfants[cle] = enfants[cle] or {}
	table.insert(enfants[cle], os_)
end

local faites = {}
for nom, anim in donnees.animations do
	local ancienne = dossier:FindFirstChild(donnees.piece .. "_" .. nom)
	if ancienne then ancienne:Destroy() end
	local seq = Instance.new("KeyframeSequence")
	seq.Name, seq.Loop = donnees.piece .. "_" .. nom, anim.boucle
	seq.Priority = Enum.AnimationPriority[anim.priorite]
	for _, image in anim.images do
		local kf = Instance.new("Keyframe")
		kf.Time = image[1]
		local racine = Instance.new("Pose")
		racine.Name, racine.Weight = donnees.piece, 0
		racine.Parent = kf
		local function poser(nomOs, parent)
			local k = 4 + (indice[nomOs] - 1) * 4
			local p = Instance.new("Pose")
			p.Name, p.Weight = nomOs, 1
			p.EasingStyle, p.EasingDirection = Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
			local x, y, z = 0, 0, 0
			if nomOs == donnees.racine then x, y, z = image[2], image[3], image[4] end
			p.CFrame = CFrame.new(x, y, z, image[k + 2], image[k + 3], image[k + 4], image[k + 1])
			p.Parent = parent
			for _, enfant in enfants[nomOs] or {} do poser(enfant, p) end
		end
		for _, os_ in enfants.__racine do poser(os_, racine) end
		kf.Parent = seq
	end
	local copie = animSaves:FindFirstChild(seq.Name)
	if copie then copie:Destroy() end
	seq:Clone().Parent = animSaves
	seq.Parent = dossier
	table.insert(faites, seq.Name .. " (" .. #anim.images .. " images)")
end
table.sort(faites)
return "Construites dans ServerStorage.RBX_ANIMSAVES." .. donnees.piece .. " :\n" .. table.concat(faites, "\n")
