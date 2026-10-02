-- Trois paliers visuels au lieu de quatre (02/10/2026) : le style quartz et or, rangé jusqu'ici
-- en P4, devient le P3. Renomme ServerStorage.Batiments.<Lot>.P4 en P3 (attribut Palier = 3)
-- et met à jour la copie affichée. Relançable, annulable d'un Ctrl+Z. À lancer hors du mode Play.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local rec = CHS:TryBeginRecording("Paliers : P4 devient P3")
local faits = {}
local ok, err = pcall(function()
	for _, lot in SS.Batiments:GetChildren() do
		local p4 = lot:FindFirstChild("P4")
		if p4 then
			assert(not lot:FindFirstChild("P3"), lot.Name .. " a déjà un P3 : à trancher à la main.")
			p4.Name = "P3"
			p4:SetAttribute("Palier", 3)
			table.insert(faits, lot.Name)
		end
	end
	local scene = workspace:FindFirstChild("Batiments")
	if scene then
		for _, m in scene:GetChildren() do
			if m:GetAttribute("Palier") == 4 then m:SetAttribute("Palier", 3) end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return "P4 renommé en P3 pour : " .. (if #faits > 0 then table.concat(faits, ", ") else "aucun lot")
