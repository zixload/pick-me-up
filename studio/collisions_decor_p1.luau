-- Rend solides les détails du lobby P1 posés par ChatGPT (Workspace.Decor_Lobby_P1) : structures des
-- lanternes, roches, mannequins, cibles de tir, râtelier, bannière. Restent sans collision : les
-- coulures de mousse et les petits cailloux plats (on buterait dessus), et le mobilier, qui a déjà ses
-- propres collisions invisibles (Collision_*). Relançable, annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")

local EXCLUS = {"Mousse", "Cailloux"}

local rec = CHS:TryBeginRecording("Collisions du décor P1")
local solides, laisses = 0, 0
local ok, err = pcall(function()
	local decor = workspace:FindFirstChild("Decor_Lobby_P1")
	assert(decor, "Workspace.Decor_Lobby_P1 introuvable.")
	local mobilier = decor:FindFirstChild("Mobilier")
	for _, d in decor:GetDescendants() do
		if d:IsA("BasePart") and not (mobilier and d:IsDescendantOf(mobilier)) then
			local exclu = false
			for _, mot in EXCLUS do
				if d.Name:find(mot) then exclu = true end
			end
			if exclu then
				laisses += 1
			else
				d.CanCollide, d.CanTouch = true, false
				solides += 1
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return string.format("Décor P1 : %d pièces rendues solides, %d laissées sans collision (mousse, cailloux)", solides, laisses)
