-- Test des paliers sans back end : affiche le palier choisi d'un lot dans Workspace.Batiments.
-- Usage dans la barre de commande : changer LOT et PALIER puis exécuter. Annulable d'un Ctrl+Z.
-- Les modèles de chaque palier vivent dans ServerStorage.Batiments.<Lot>.P<n>.
local LOT, PALIER = "Rempart", 4

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local rec = CHS:TryBeginRecording("Palier " .. LOT .. " P" .. PALIER)
local ok, err = pcall(function()
	local dossier = SS:WaitForChild("Batiments"):WaitForChild(LOT)

	-- première fois : l'enceinte en quartz posée à la main devient le palier P4 du rempart
	local quartz = workspace:FindFirstChild("PMU_Rempart")
	if LOT == "Rempart" and quartz and not dossier:FindFirstChild("P4") then
		quartz.Name = "P4"
		quartz:SetAttribute("LotId", "Rempart")
		quartz:SetAttribute("Palier", 4)
		quartz.Parent = dossier
	end

	local source = dossier:FindFirstChild("P" .. PALIER)
	assert(source, "Pas de modèle P" .. PALIER .. " pour " .. LOT)

	local scene = workspace:FindFirstChild("Batiments") or Instance.new("Folder")
	scene.Name, scene.Parent = "Batiments", workspace
	local actuel = scene:FindFirstChild(LOT)
	if actuel then actuel:Destroy() end
	local copie = source:Clone()
	copie.Name = LOT
	copie.Parent = scene
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
print(LOT .. " affiché au palier P" .. PALIER)
