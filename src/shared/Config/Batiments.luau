-- Bâtiments (lots) de la base : nom affiché, modèles à afficher, déblocage, coût, position de la borne.
-- Les valeurs sont un premier jet, à rééquilibrer ensemble. Positions : centres du plan directeur ×1,5.
--   depart   : niveau au premier lancement (1 = construit, 0 = emplacement réservé à construire)
--   debloque : niveau global requis pour le construire (niveau 1)
--   cout     : coût en or du niveau 2 ; chaque niveau suivant coûte CROISSANCE fois plus
--   visuels  : lots de ServerStorage.Batiments affichés selon le palier (plusieurs pour l'enceinte)
local Batiments = {}

Batiments.NIVEAU_MAX = 20
Batiments.CROISSANCE = 1.35
-- palier visuel atteint à partir de chaque niveau de bâtiment (plan directeur : P1, P2 au 5, P3 au 10, P4 au 20)
Batiments.SEUILS_PALIERS = {{palier = 1, niveau = 1}, {palier = 2, niveau = 5}, {palier = 3, niveau = 10}, {palier = 4, niveau = 20}}

Batiments.ORDRE = {
	"Enceinte", "Faille", "Invocation", "Logements", "Logements_Annexe", "Cantine", "Entrainement",
	"Forge", "Traitement_Metaux", "Menuiserie", "Infirmerie", "Administration",
	"Chambre_Synthese", "Salle_Magie", "Terrain_Magique", "Station_Transfert",
}

Batiments.LOTS = {
	-- nom : affiché au joueur, donc en anglais (noms anglais du webtoon)
	Enceinte = {nom = "Rampart & Pavement", visuels = {"Rempart", "Sol"}, depart = 1, debloque = 1, cout = 400, position = {0, 12}},
	Faille = {nom = "Space-Time Rift", visuels = {"Faille"}, depart = 1, debloque = 1, cout = 300, position = {117, 43.5}},
	Invocation = {nom = "Summoning Hall", visuels = {"Invocation"}, depart = 1, debloque = 1, cout = 300, position = {18, -123}},
	Logements = {nom = "Lodging", visuels = {"Logements"}, depart = 1, debloque = 1, cout = 200, position = {-130.5, -78}},
	Logements_Annexe = {nom = "Lodging Annex", visuels = {"Logements_Annexe"}, depart = 1, debloque = 1, cout = 200, position = {-132, -16.5}},
	Cantine = {nom = "Restaurant", visuels = {"Cantine"}, depart = 1, debloque = 1, cout = 200, position = {-139.5, 52.5}},
	Entrainement = {nom = "Training Center", visuels = {"Entrainement"}, depart = 1, debloque = 1, cout = 250, position = {-84, -126}},
	Forge = {nom = "Smithy", visuels = {"Forge"}, depart = 1, debloque = 1, cout = 250, position = {-52.5, 82.5}},
	Traitement_Metaux = {nom = "Metal Processing", visuels = {"Traitement_Metaux"}, depart = 1, debloque = 1, cout = 250, position = {-54, 138}},
	Menuiserie = {nom = "Woodworking Shop", visuels = {"Menuiserie"}, depart = 0, debloque = 5, cout = 600, position = {-91.5, 132}},
	Infirmerie = {nom = "Infirmary", visuels = {"Infirmerie"}, depart = 1, debloque = 1, cout = 200, position = {51, 138}},
	Administration = {nom = "Administration", visuels = {"Administration"}, depart = 1, debloque = 1, cout = 200, position = {144, -67.5}},
	Chambre_Synthese = {nom = "Synthesis Chamber", visuels = {"Chambre_Synthese"}, depart = 0, debloque = 8, cout = 1000, position = {75, -135}},
	Salle_Magie = {nom = "Hall of Magic", visuels = {"Salle_Magie"}, depart = 0, debloque = 15, cout = 1500, position = {82.5, -40.5}},
	Terrain_Magique = {nom = "Magic Training Grounds", visuels = {"Terrain_Magique"}, depart = 0, debloque = 20, cout = 2000, position = {-33, -151.5}},
	Station_Transfert = {nom = "Transfer Station", visuels = {"Station_Transfert"}, depart = 0, debloque = 25, cout = 2500, position = {-45, -84}},
}

return Batiments
