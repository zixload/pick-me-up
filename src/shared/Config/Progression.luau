-- Progression du joueur : niveau global et expérience. Premier jet, à rééquilibrer.
local Progression = {}

Progression.NIVEAU_MAX = 50

-- expérience nécessaire pour passer du niveau n au niveau n + 1
function Progression.xpPourNiveau(n: number): number
	return math.floor(100 * n ^ 1.5)
end

return Progression
