-- Boutique en Robux (03/10/2026) : seulement ce qui existe déjà dans le jeu (or, matériaux) ; les invocations 5★
-- et les armes viendront quand leur contenu sera fait. Tout texte affiché est en anglais.
-- produit : identifiant du « Developer Product » créé sur le Creator Dashboard du jeu (Monetization > Developer
-- Products, par le propriétaire du jeu). Tant qu'il vaut 0, l'article s'affiche mais ne peut pas être acheté.
-- prix : en Robux, affiché seulement (le vrai prix est celui du produit sur le Dashboard : garder les deux égaux).
-- unique : ne s'achète qu'une fois par joueur.
local Boutique = {}

Boutique.RAYONS = {
	{id = "Offres", nom = "Special Offers", icone = "rbxassetid://73972245179955"},   -- petite étoile
	{id = "Or", nom = "Gold", icone = "rbxassetid://134775045623355"},                -- pièce
	{id = "Materiaux", nom = "Materials", icone = "rbxassetid://126628429385620"},    -- cube
}

Boutique.ARTICLES = {
	{id = "StarterPack", rayon = "Offres", nom = "Starter Pack", prix = 99, produit = 0, unique = true, rarete = 5,
		image = "rbxassetid://76413057251104", etiquette = "Once",
		contenu = {Or = 2000, Materiaux = {Bluestone = 30, Timber = 30}},
		description = "Everything a new master needs to raise their first buildings. Can be bought only once."},
	{id = "BourseOr", rayon = "Or", nom = "Gold Pouch", prix = 49, produit = 0, rarete = 3,
		image = "rbxassetid://134775045623355", contenu = {Or = 1000},
		description = "A small pouch of gold coins. Enough for an early upgrade."},
	{id = "CoffreOr", rayon = "Or", nom = "Gold Chest", prix = 199, produit = 0, rarete = 4,
		image = "rbxassetid://134775045623355", etiquette = "+10%", contenu = {Or = 5500},
		description = "A heavy chest of gold. Ten percent more gold for every Robux than the pouch."},
	{id = "TresorRoyal", rayon = "Or", nom = "Royal Vault", prix = 799, produit = 0, rarete = 5,
		image = "rbxassetid://134775045623355", etiquette = "Best value", contenu = {Or = 30000},
		description = "The treasury of a seasoned master. The best rate of gold for your Robux."},
	{id = "CaisseBatisseur", rayon = "Materiaux", nom = "Builder's Crate", prix = 99, produit = 0, rarete = 3,
		image = "rbxassetid://118032124896002", contenu = {Materiaux = {Bluestone = 50, Timber = 50}},
		description = "Stone and timber straight from the quarries. Everything the first-style buildings are made of."},
}

function Boutique.article(id: string)
	for _, a in Boutique.ARTICLES do
		if a.id == id then return a end
	end
	return nil
end

function Boutique.parProduit(produit: number)
	if produit == 0 then return nil end
	for _, a in Boutique.ARTICLES do
		if a.produit == produit then return a end
	end
	return nil
end

return Boutique
