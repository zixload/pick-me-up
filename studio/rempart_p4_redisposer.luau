-- Redispose le rempart en quartz (palier P3) sur N travées au lieu de N_ANCIEN (base agrandie de 1,5 :
-- 44 -> 77 puis 77 -> 66 le 01/10/2026),
-- à partir de ses propres pièces : celles du pilier 0 et de la travée 0 servent de modèle,
-- avec leur position relative au repère de leur emplacement. Annulable d'un Ctrl+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local N_ANCIEN, N, MODULE = 77, 66, 20
local UP = Vector3.yAxis

local function rayon(n) return (MODULE / 2) / math.sin(math.pi / n) end
local function repere(pos)
	local avant = (-pos * Vector3.new(1, 0, 1)).Unit
	return CFrame.fromMatrix(pos, (-avant):Cross(UP), UP)
end
-- repère d'un pilier (sommet k du polygone) ou d'une travée (milieu du côté k)
local function cadre(n, k, travee)
	local a = 2 * math.pi * k / n + (travee and math.pi / n or 0)
	local r = travee and rayon(n) * math.cos(math.pi / n) or rayon(n)
	return repere(Vector3.new(math.cos(a), 0, math.sin(a)) * r)
end

local rec = CHS:TryBeginRecording("Rempart P3 redisposé")
local ok, err = pcall(function()
	local dossier = SS.Batiments.Rempart
	local ancien = dossier.P3
	local pas = 2 * math.pi / N_ANCIEN
	local modeles = {}
	for _, c in ancien:GetChildren() do
		local p = c:GetPivot().Position
		local a = math.atan2(p.Z, p.X) % (2 * math.pi)
		local pilier = c.Name:find("Pilier") ~= nil
		local index = pilier and (math.floor(a / pas + 0.5) % N_ANCIEN) or math.floor(a / pas)
		if index == 0 then
			table.insert(modeles, {c, cadre(N_ANCIEN, 0, not pilier):ToObjectSpace(c:GetPivot()), not pilier})
		end
	end
	assert(#modeles > 0, "Aucune pièce trouvée au pilier 0 ou à la travée 0 du P3.")

	local p3 = Instance.new("Model")
	p3.Name = "P3"
	p3:SetAttribute("LotId", "Rempart")
	p3:SetAttribute("Palier", 3)
	for k = 0, N - 1 do
		for _, m in modeles do
			local c = m[1]:Clone()
			c:PivotTo(cadre(N, k, m[3]) * m[2])
			c.Parent = p3
		end
	end
	ancien:Destroy()
	p3.Parent = dossier
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then error(err) end
return string.format("Rempart P3 : %d pièces sur %d travées, rayon %.1f", #SS.Batiments.Rempart.P3:GetChildren(), N, rayon(N))
