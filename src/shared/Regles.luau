-- Règles d'amélioration, partagées : le serveur les applique (il fait foi), le client s'en sert
-- pour afficher le coût et les conditions avant même de demander.
local Batiments = require(script.Parent.Config.Batiments)

local Regles = {}

-- palier visuel correspondant à un niveau de bâtiment (0 = pas encore construit)
function Regles.palier(niveau: number): number
	local p = 0
	for _, s in Batiments.SEUILS_PALIERS do
		if niveau >= s.niveau then p = s.palier end
	end
	return p
end

-- coût en or pour atteindre le niveau cible (la construction, niveau 1, coûte le prix de base)
function Regles.cout(lotId: string, niveauCible: number): number
	local lot = Batiments.LOTS[lotId]
	return math.floor(lot.cout * Batiments.CROISSANCE ^ math.max(niveauCible - 2, 0) + 0.5)
end

-- niveau global requis : le déblocage du lot, et un bâtiment ne dépasse pas d'un niveau celui du joueur
function Regles.niveauRequis(lotId: string, niveauCible: number): number
	return math.max(Batiments.LOTS[lotId].debloque, niveauCible - 1)
end

-- Peut-on passer ce lot au niveau suivant ? Renvoie ok, raison (si refus, en anglais : affichée au joueur)
-- et le détail.
function Regles.verifier(donnees, lotId: string)
	local lot = Batiments.LOTS[lotId]
	if not lot then
		return false, "Unknown building.", {}
	end
	local niveau = donnees.Batiments[lotId] or lot.depart
	local cible = niveau + 1
	local detail = {
		niveau = niveau,
		cible = cible,
		cout = Regles.cout(lotId, cible),
		requis = Regles.niveauRequis(lotId, cible),
		palierActuel = Regles.palier(niveau),
		palierCible = Regles.palier(cible),
	}
	if niveau >= Batiments.NIVEAU_MAX then
		return false, "Max level reached.", detail
	end
	if donnees.Niveau < detail.requis then
		return false, `Requires global level {detail.requis}.`, detail
	end
	if donnees.Or < detail.cout then
		return false, `You need {detail.cout - donnees.Or} more gold.`, detail
	end
	return true, nil, detail
end

return Regles
