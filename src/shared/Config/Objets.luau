-- Catalogue des objets montrés dans l'inventaire : catégories (bandeau de gauche) et fiche de chaque objet.
-- Tout texte affiché est en anglais. Rareté de 1 à 5 étoiles : elle donne la couleur de la carte.
-- image : rbxassetid de l'icône (vide : la carte montre un losange). Icônes provisoires dessinées par
-- ui/inventaire_v01/icones.py, à remplacer par de vraies icônes.
local Objets = {}

Objets.CATEGORIES = {
	{id = "Materiaux", nom = "Materials", icone = "rbxassetid://126628429385620"},
	{id = "Equipement", nom = "Equipment", icone = "rbxassetid://88706714211108"},
	{id = "Consommables", nom = "Consumables", icone = "rbxassetid://107927855555738"},
}

-- id -> fiche. Les matériaux ont le même id que dans Config.Materiaux (et le profil du joueur).
Objets.LISTE = {
	Bluestone = {nom = "Bluestone", categorie = "Materiaux", type = "Building Material", rarete = 2, image = "rbxassetid://104924613733889",
		effets = {"Upgrades buildings in the first style"},
		description = "Blue-grey stone mined on expeditions, outside the Tower. Paired with Timber, it raises the walls of a young base.",
		source = "Mined on expeditions"},
	Timber = {nom = "Timber", categorie = "Materiaux", type = "Building Material", rarete = 2, image = "rbxassetid://109674347849677",
		effets = {"Upgrades buildings in the first style"},
		description = "Seasoned logs gathered on expeditions. Beams, doors and scaffolds of the first style are cut from it.",
		source = "Gathered on expeditions"},
	NightBasalt = {nom = "Night Basalt", categorie = "Materiaux", type = "Building Material", rarete = 3, image = "rbxassetid://137223979602772",
		effets = {"Upgrades buildings in the Night Basalt style"},
		description = "A dense black rock with a faint blue sheen. Only bases whose master has cleared floor 10 of the Tower can work it.",
		source = "Mined on expeditions"},
	SilverOre = {nom = "Silver Ore", categorie = "Materiaux", type = "Building Material", rarete = 3, image = "rbxassetid://71060504247809",
		effets = {"Upgrades buildings in the Night Basalt style"},
		description = "Raw silver veined through grey rock. Smelted into the trims and crests of the Night Basalt style.",
		source = "Mined on expeditions"},
	Quartz = {nom = "Quartz", categorie = "Materiaux", type = "Building Material", rarete = 4, image = "rbxassetid://98379098239707",   -- rendu 3D (ui/inventaire_v01/icone_quartz.py)
		effets = {"Upgrades buildings in the Quartz style"},
		description = "Pale, almost translucent stone. Reserved for masters who have cleared floor 50 of the Tower.",
		source = "Mined on expeditions"},
	GoldOre = {nom = "Gold Ore", categorie = "Materiaux", type = "Building Material", rarete = 4, image = "rbxassetid://113697874391024",
		effets = {"Upgrades buildings in the Quartz style"},
		description = "Heavy nuggets of gold. Beaten into the ornaments that crown the Quartz style.",
		source = "Mined on expeditions"},
	Epee = {nom = "Starter Sword", categorie = "Equipement", type = "Sword", rarete = 1, image = "rbxassetid://100637868854122",
		effets = {"Three-hit combo", "Equipped"},
		description = "A plain, well-balanced blade handed to every new hero. It has seen more training dummies than monsters.",
		source = "Given at the start"},
	Bouclier = {nom = "Round Shield", categorie = "Equipement", type = "Shield", rarete = 1, image = "rbxassetid://122102386138740",
		effets = {"Parry incoming blows", "Equipped"},
		description = "A round shield strapped to the left forearm. Raised at the right moment, it turns an attack into an opening.",
		source = "Given at the start"},
}

-- ordre d'affichage dans chaque catégorie
Objets.ORDRE = {"Bluestone", "Timber", "NightBasalt", "SilverOre", "Quartz", "GoldOre", "Epee", "Bouclier"}

-- l'équipement que tout héros possède (épée et bouclier de départ)
Objets.EQUIPEMENT_DE_DEPART = {Epee = 1, Bouclier = 1}

return Objets
