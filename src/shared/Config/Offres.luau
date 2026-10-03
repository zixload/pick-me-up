-- Offres du jour (validées le 03/10/2026) : un cadeau gratuit par jour et un petit marché de 3 échanges payés
-- en or du jeu (pas en Robux), en quantité limitée, renouvelés chaque jour à 4 h, heure de Paris (Config.Quetes).
-- Le marché donne un usage à l'or en dehors des bâtiments et permet de compléter le matériau qui manque.
-- Premier jet des prix, à rééquilibrer. Tout texte affiché est en anglais.
local Offres = {}

Offres.CADEAU = {nom = "Daily Gift", contenu = {Or = 100, Materiaux = {Bluestone = 3, Timber = 3}},
	description = "A small gift from the Administration, waiting for you every day. Come back tomorrow for another one."}

Offres.NB_ECHANGES = 3

-- échanges tirés chaque jour ; prix en or, limite d'achats par jour
Offres.ECHANGES = {
	{id = "Bluestone20", nom = "Bluestone Bundle", prix = 300, limite = 2, rarete = 2, contenu = {Materiaux = {Bluestone = 20}},
		description = "Freshly cut blocks from the quarries, sold by the stack."},
	{id = "Timber20", nom = "Timber Bundle", prix = 300, limite = 2, rarete = 2, contenu = {Materiaux = {Timber = 20}},
		description = "Seasoned logs, tied and ready for the carpenters."},
	{id = "Bluestone50", nom = "Bluestone Cart", prix = 700, limite = 1, rarete = 3, contenu = {Materiaux = {Bluestone = 50}},
		description = "A full cart of stone, at a better price than the small bundles."},
	{id = "Timber50", nom = "Timber Cart", prix = 700, limite = 1, rarete = 3, contenu = {Materiaux = {Timber = 50}},
		description = "A full cart of timber, at a better price than the small bundles."},
	{id = "NightBasalt5", nom = "Night Basalt", prix = 600, limite = 1, rarete = 3, contenu = {Materiaux = {NightBasalt = 5}},
		description = "Rare dark stone, offered today by a passing merchant. Worth keeping for the Night Basalt style."},
	{id = "SilverOre5", nom = "Silver Ore", prix = 600, limite = 1, rarete = 3, contenu = {Materiaux = {SilverOre = 5}},
		description = "A few nuggets of raw silver. Worth keeping for the Night Basalt style."},
	{id = "Quartz3", nom = "Quartz Shards", prix = 900, limite = 1, rarete = 4, contenu = {Materiaux = {Quartz = 3}},
		description = "Pale shards of quartz, rarely seen on the market. Masters save them for the Quartz style."},
}

function Offres.echange(id: string)
	for _, e in Offres.ECHANGES do
		if e.id == id then return e end
	end
	return nil
end

return Offres
