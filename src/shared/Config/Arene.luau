-- Arène classée : duels en manches, cote Elo et rangs. Premier jet (02/10/2026) : 1v1 entre héros,
-- une seule arène de test dans la place (plus tard, une dimension à part atteinte par la Faille).
-- Pas de limite de temps : une manche se gagne quand l'adversaire est à terre.
local Arene = {}

Arene.CENTRE = Vector3.new(0, 0, -900)   -- loin de la base, au-dessus du vide
Arene.RAYON = 42                          -- rayon du sol ; un mur invisible retient les joueurs
Arene.ECART = 18                          -- distance de chaque héros au centre au début d'une manche
Arene.MANCHES_GAGNANTES = 2               -- premier à deux manches
Arene.COMPTE_A_REBOURS = 3                -- secondes figées avant chaque manche
Arene.PAUSE_ENTRE_MANCHES = 3             -- secondes d'annonce après une manche
Arene.RETOUR = CFrame.new(0, 4, 138)      -- point de la base où l'on revient après un duel
Arene.ENTREE = Vector3.new(0, 3.5, 12)    -- borne « Ranked Duel » au centre de la place

-- cote Elo
Arene.COTE_DEPART = 1000
Arene.K = 32

-- Rangs : matières de la base et étoiles des héros de l'œuvre. Chaque rang (sauf le dernier) se
-- divise en III, II, I. Couleurs : clair et sombre de l'insigne. Noms et titres affichés en anglais.
Arene.RANGS = {
	{nom = "Stone", titre = "Recruit", min = 900, etoiles = 1,
		clair = Color3.fromRGB(150, 166, 190), sombre = Color3.fromRGB(62, 74, 94)},
	{nom = "Iron", titre = "Fighter", min = 1100, etoiles = 2,
		clair = Color3.fromRGB(186, 190, 200), sombre = Color3.fromRGB(78, 82, 96)},
	{nom = "Silver", titre = "Duelist", min = 1250, etoiles = 3,
		clair = Color3.fromRGB(232, 238, 248), sombre = Color3.fromRGB(128, 146, 172)},
	{nom = "Gold", titre = "Champion", min = 1400, etoiles = 4,
		clair = Color3.fromRGB(255, 222, 140), sombre = Color3.fromRGB(184, 120, 40)},
	{nom = "Quartz", titre = "Paragon", min = 1600, etoiles = 5,
		clair = Color3.fromRGB(255, 240, 246), sombre = Color3.fromRGB(214, 160, 190)},
	{nom = "Seven Star", titre = "Legend", min = 1850, etoiles = 7,
		clair = Color3.fromRGB(150, 236, 255), sombre = Color3.fromRGB(120, 70, 220)},
}
local CHIFFRES = {"III", "II", "I"}

-- rang d'une cote : {nom, titre, division ("" pour le dernier rang), etoiles, clair, sombre, indice}
function Arene.rang(cote: number)
	local indice = 1
	for i, r in Arene.RANGS do
		if cote >= r.min then indice = i end
	end
	local r = Arene.RANGS[indice]
	local suivant = Arene.RANGS[indice + 1]
	local division = ""
	if suivant then
		local part = math.clamp((cote - r.min) / (suivant.min - r.min), 0, 0.999)
		division = CHIFFRES[math.floor(part * 3) + 1]
	end
	return {nom = r.nom, titre = r.titre, division = division, etoiles = r.etoiles,
		clair = r.clair, sombre = r.sombre, indice = indice}
end

-- nouvelle cote du gagnant et du perdant
function Arene.elo(gagnant: number, perdant: number): (number, number)
	local attendu = 1 / (1 + 10 ^ ((perdant - gagnant) / 400))
	local gain = math.max(1, math.floor(Arene.K * (1 - attendu) + 0.5))
	return gagnant + gain, math.max(0, perdant - gain)
end

return Arene
