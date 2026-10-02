-- Règles d'amélioration, partagées : le serveur les applique (il fait foi), le client s'en sert
-- pour afficher le coût et les conditions avant même de demander.
local Batiments = require(script.Parent.Config.Batiments)
local Materiaux = require(script.Parent.Config.Materiaux)

local Regles = {}

-- palier de style correspondant à un niveau de bâtiment (0 = pas encore construit)
function Regles.palier(niveau: number): number
	local p = 0
	for _, s in Batiments.SEUILS_PALIERS do
		if niveau >= s.niveau then p = s.palier end
	end
	return p
end

-- palier de style déverrouillé par l'étage atteint dans la Tour (celui des lots automatiques)
function Regles.palierTour(etage: number): number
	local p = 1
	for _, s in Batiments.SEUILS_PALIERS do
		if etage >= s.etage then p = s.palier end
	end
	return p
end

-- étage de Tour à franchir pour atteindre ce niveau de bâtiment (0 si aucun)
function Regles.etageRequis(niveauCible: number): number
	for _, s in Batiments.SEUILS_PALIERS do
		if s.niveau == niveauCible then return s.etage end
	end
	return 0
end

-- coût en or pour atteindre le niveau cible (la construction, niveau 1, coûte le prix de base)
function Regles.cout(lotId: string, niveauCible: number): number
	local lot = Batiments.LOTS[lotId]
	return math.floor(lot.cout * Batiments.CROISSANCE ^ math.max(niveauCible - 2, 0) + 0.5)
end

-- matériaux pour atteindre le niveau cible : ceux du palier visé, donc ceux du style actuel tant
-- qu'on reste dans le même palier, et ceux du nouveau style pour le niveau qui en change.
-- Renvoie une liste {{id, quantite}}.
function Regles.materiaux(lotId: string, niveauCible: number)
	local lot = Batiments.LOTS[lotId]
	local palierCible = Regles.palier(niveauCible)
	local seuil = niveauCible > 1 and palierCible ~= Regles.palier(niveauCible - 1)
	local base = lot.cout / Batiments.MATERIAUX_DIVISEUR * Batiments.MATERIAUX_CROISSANCE ^ math.max(niveauCible - 2, 0)
		* (if seuil then Batiments.MATERIAUX_SEUIL else 1)
	local liste = {}
	for i, id in Materiaux.PAR_PALIER[palierCible] do
		local poids = lot.dosage and lot.dosage[i] or 1
		table.insert(liste, {id, math.max(1, math.floor(base * poids + 0.5))})
	end
	return liste
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
		palierActuel = Regles.palier(niveau),
		palierCible = Regles.palier(cible),
	}
	if niveau >= Batiments.NIVEAU_MAX then
		return false, "Max level reached.", detail
	end
	detail.cout = Regles.cout(lotId, cible)
	detail.materiaux = Regles.materiaux(lotId, cible)
	detail.etage = Regles.etageRequis(cible)
	if niveau == 0 and lot.parent then
		detail.parent = lot.parent
		local id, requis = lot.parent[1], lot.parent[2]
		if (donnees.Batiments[id] or 0) < requis then
			return false, `Requires {Batiments.LOTS[id].nom} level {requis}.`, detail
		end
	end
	if (donnees.Etage or 0) < detail.etage then
		return false, `Clear Floor {detail.etage} of the Tower to unlock.`, detail
	end
	if donnees.Or < detail.cout then
		return false, `You need {detail.cout - donnees.Or} more gold.`, detail
	end
	for _, m in detail.materiaux do
		local manque = m[2] - (donnees.Materiaux[m[1]] or 0)
		if manque > 0 then
			return false, `You need {manque} more {Materiaux.NOMS[m[1]]}.`, detail
		end
	end
	return true, nil, detail
end

return Regles
