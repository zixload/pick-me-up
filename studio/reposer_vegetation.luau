-- Repose chaque modèle de Workspace.Vegetation (arbres, buissons, fleurs, herbe haute) sur le Terrain
-- sous son pivot. À relancer après une modification du relief (studio/terrain_herbe.luau).
-- Idempotent : le décalage déjà appliqué est mémorisé dans l'attribut SolY. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.Terrain}
local function sol(x, z)
	local r = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
	return r and r.Position.Y or 0
end

local rec = CHS:TryBeginRecording("Reposer la végétation")
local n, decal = 0, 0
local ok, err = pcall(function()
	for _, dossier in workspace.Vegetation:GetChildren() do
		for _, m in dossier:GetChildren() do
			if m:IsA("Model") then
				local p = m:GetPivot().Position
				local y = sol(p.X, p.Z)
				local avant = m:GetAttribute("SolY") or 0
				if math.abs(y - avant) > 0.02 then
					m:PivotTo(m:GetPivot() + Vector3.new(0, y - avant, 0))
					decal += 1
				end
				m:SetAttribute("SolY", y)
				n += 1
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return string.format("Végétation : %d modèles vérifiés, %d déplacés", n, decal)
