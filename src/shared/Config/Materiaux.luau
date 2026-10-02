-- Matériaux de construction, minés et récoltés en expédition (hors Tour).
-- Chaque palier de style a ses deux matériaux, ceux qu'on voit sur les bâtiments de ce style
-- (validés le 02/10/2026). Les noms affichés sont en anglais.
local Materiaux = {}

Materiaux.ORDRE = {"Bluestone", "Timber", "NightBasalt", "SilverOre", "Quartz", "GoldOre"}

Materiaux.NOMS = {
	Bluestone = "Bluestone",
	Timber = "Timber",
	NightBasalt = "Night Basalt",
	SilverOre = "Silver Ore",
	Quartz = "Quartz",
	GoldOre = "Gold Ore",
}

-- palier de style -> ses deux matériaux (le premier est la pierre, le second le bois ou le métal)
Materiaux.PAR_PALIER = {
	{"Bluestone", "Timber"},
	{"NightBasalt", "SilverOre"},
	{"Quartz", "GoldOre"},
}

return Materiaux
